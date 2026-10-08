"""Fixed FAME and FAME-GW binary classifiers with leakage-free evaluation.

Both models share the same first-layer estimators. FAME uses four modality
scores and a linear SVM; FAME-GW uses eight scores and a random forest. All
preprocessing is fitted inside the relevant training fold. The independent
test labels are used only to report performance, never to select a model.
"""

from __future__ import annotations

from dataclasses import dataclass
from time import perf_counter
from typing import Callable, Optional

import numpy as np
from joblib import Parallel, delayed, parallel_config
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import average_precision_score, roc_auc_score, roc_curve
from sklearn.model_selection import StratifiedKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import LinearSVC, SVC
from threadpoolctl import threadpool_limits


BASE_FEATURES = ["WPS", "EDM", "PDR", "MBS"]
GW_FEATURES = BASE_FEATURES + ["GWM", "EM", "CAFF", "MFR"]
DEFAULT_TASKS = ["BRCA", "COREAD", "ESCA", "LIHC", "NSCLC", "PACA", "STAD"]

Progress = Optional[Callable[[str], None]]


def _emit(progress: Progress, message: str) -> None:
    if progress is not None:
        progress(message)


def make_base_model(seed: int = 42) -> Pipeline:
    """Construct the fixed first-layer model used by the reference analysis."""
    return Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler()),
        ("clf", LinearSVC(
            C=1.0, class_weight="balanced", max_iter=5000,
            dual="auto", random_state=seed,
        )),
    ])


def make_meta_model(model: str, seed: int = 42):
    """Construct a prespecified second layer; no candidate search is run."""
    if model == "fame":
        return Pipeline([
            ("scaler", StandardScaler()),
            ("clf", SVC(
                kernel="linear", C=1.0, class_weight="balanced",
                probability=False, random_state=seed,
            )),
        ])
    if model == "fame-gw":
        return RandomForestClassifier(
            n_estimators=500, max_features="sqrt",
            class_weight="balanced_subsample", random_state=seed, n_jobs=1,
        )
    raise ValueError(f"Unknown model {model!r}; choose 'fame' or 'fame-gw'.")


def get_score(model, X: np.ndarray) -> np.ndarray:
    """Return the score for class 1 (cancer), not a thresholded prediction."""
    if hasattr(model, "decision_function"):
        scores = model.decision_function(X)
    else:
        class_index = int(np.flatnonzero(np.asarray(model.classes_) == 1)[0])
        scores = model.predict_proba(X)[:, class_index]
    scores = np.asarray(scores, dtype=float)
    if scores.ndim != 1 or not np.isfinite(scores).all():
        raise RuntimeError("The model returned invalid binary scores.")
    return scores


def evaluate_scores(y: np.ndarray, score: np.ndarray) -> dict[str, float]:
    """Report AUC, AP, and ROC sensitivity at specificity >= 0.95.

    The last value describes this evaluation ROC. It is not a clinical
    threshold selected in training or a guarantee on future specificity.
    """
    y = np.asarray(y)
    score = np.asarray(score, dtype=float)
    if y.ndim != 1 or score.shape != y.shape:
        raise ValueError("Labels and scores must be aligned one-dimensional arrays.")
    if not np.isfinite(score).all():
        raise ValueError("Scores contain non-finite values.")
    if len(np.unique(y)) < 2:
        return {"auc": float("nan"), "ap": float("nan"), "sens_at_95spec": float("nan")}
    fpr, tpr, _ = roc_curve(y, score)
    eligible = 1.0 - fpr >= 0.95
    return {
        "auc": float(roc_auc_score(y, score)),
        "ap": float(average_precision_score(y, score)),
        "sens_at_95spec": float(np.max(tpr[eligible])) if eligible.any() else 0.0,
    }


def _labels(y, name: str, require_both: bool = True) -> np.ndarray:
    arr = np.asarray(y)
    if arr.ndim != 1 or arr.size == 0 or not np.isin(arr, [0, 1]).all():
        raise ValueError(f"{name} must be a nonempty one-dimensional array of 0/1 labels.")
    if require_both and len(np.unique(arr)) != 2:
        raise ValueError(f"{name} must contain both healthy (0) and cancer (1) samples.")
    return arr.astype(int, copy=False)


def _matrices(X, features: list[str], n_rows: int, name: str) -> dict[str, np.ndarray]:
    if not isinstance(X, dict):
        raise ValueError(f"{name} must map modality names to sample-by-feature matrices.")
    missing = [feature for feature in features if feature not in X]
    if missing:
        raise ValueError(f"{name} is missing modalities: {', '.join(missing)}")
    matrices = {}
    for feature in features:
        # This is the same numerical input representation as the legacy loader.
        arr = np.asarray(X[feature], dtype=np.float32)
        if arr.ndim != 2 or arr.shape[0] != n_rows or arr.shape[1] == 0:
            raise ValueError(
                f"{name}[{feature!r}] has shape {arr.shape}; expected ({n_rows}, positive feature count)."
            )
        # Do not modify the caller's array or an input read-only memory map.
        if np.isinf(arr).any():
            arr = arr.copy()
            arr[np.isinf(arr)] = np.nan
        matrices[feature] = arr
    return matrices


@dataclass
class FittedFAME:
    """Serializable model fitted on all training samples for new predictions.

    Inputs must retain the training data's feature-column order. Array widths
    and row counts are validated here; the data loader must verify column IDs.
    A FAME score is an SVM margin. A FAME-GW score is the forest's class-1
    probability estimate, without additional probability calibration.
    """

    name: str
    features: list[str]
    feature_counts: dict[str, int]
    base_models: dict
    meta_model: object
    seed: int
    n_splits: int

    def predict_scores(self, X: dict[str, np.ndarray]) -> np.ndarray:
        if not isinstance(X, dict) or self.features[0] not in X:
            raise ValueError(f"Prediction inputs must include {', '.join(self.features)}.")
        first = np.asarray(X[self.features[0]])
        if first.ndim != 2 or first.shape[0] == 0:
            raise ValueError("Prediction inputs must be nonempty sample-by-feature matrices.")
        arrays = _matrices(X, self.features, len(first), "X")
        for feature in self.features:
            if arrays[feature].shape[1] != self.feature_counts[feature]:
                raise ValueError(
                    f"{feature}: expected {self.feature_counts[feature]} columns, "
                    f"got {arrays[feature].shape[1]}. Preserve the training feature order."
                )
        with threadpool_limits(limits=1):
            scores = np.column_stack([
                get_score(self.base_models[feature], arrays[feature])
                for feature in self.features
            ])
            return get_score(self.meta_model, scores)


def _base_fold(X, y, idx_train, idx_valid, seed: int, fold: int, feature: str):
    start = perf_counter()
    with threadpool_limits(limits=1):
        estimator = make_base_model(seed + fold)
        estimator.fit(X[idx_train], y[idx_train])
        score = get_score(estimator, X[idx_valid])
    row = {
        "feature": feature, "fold": fold,
        "n_val": int(len(idx_valid)), "n_pos": int(y[idx_valid].sum()),
        "time_sec": perf_counter() - start,
        **evaluate_scores(y[idx_valid], score),
    }
    return idx_valid, score, row


def _oof_base_scores(X_train, X_heldout, y, features, splits, seed, n_jobs, progress, context):
    """Build train OOF scores and independently refit each held-out predictor."""
    oof, heldout, fitted, rows = {}, {}, {}, []
    for feature in features:
        _emit(progress, f"{context}: {feature}, fitting {len(splits)} folds")
        X = X_train[feature]
        # Process workers and numerical libraries each have explicit limits.
        # Sharing read-only inputs by memory map avoids copying wide matrices
        # into every worker before slicing the training fold.
        with parallel_config(backend="loky", inner_max_num_threads=1):
            with Parallel(n_jobs=n_jobs, return_as="generator", max_nbytes="1M", mmap_mode="r") as parallel:
                results = parallel(
                    delayed(_base_fold)(X, y, idx_train, idx_valid, seed, fold, feature)
                    for fold, (idx_train, idx_valid) in enumerate(splits, 1)
                )
                scores = np.full(len(y), np.nan, dtype=float)
                for idx_valid, score, row in results:
                    scores[idx_valid] = score
                    rows.append(row)
                    _emit(progress, f"{context}: {feature}, fold {row['fold']}/{len(splits)} complete")
        if not np.isfinite(scores).all():
            raise RuntimeError(f"Incomplete out-of-fold predictions for {feature}.")
        # Held-out samples use a model trained on the entire relevant training
        # partition, not an average of the inner fold estimators.
        with threadpool_limits(limits=1):
            full_model = make_base_model(seed)
            full_model.fit(X, y)
            heldout[feature] = get_score(full_model, X_heldout[feature])
        oof[feature] = scores
        fitted[feature] = full_model
        _emit(progress, f"{context}: {feature}, full training fit complete")
    return oof, heldout, fitted, rows


def _splits(y: np.ndarray, n_splits: int, seed: int):
    if np.bincount(y, minlength=2).min() < n_splits:
        raise ValueError(f"Each training class needs at least {n_splits} samples for {n_splits}-fold CV.")
    return list(StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=seed).split(np.zeros(len(y)), y))


def train_evaluate(
    X_train: dict[str, np.ndarray],
    X_test: dict[str, np.ndarray] | None,
    y_train,
    y_test,
    model: str = "both",
    evaluation: str = "test",
    n_splits: int = 10,
    seed: int = 42,
    n_jobs: int = 2,
    progress: Progress = None,
) -> dict:
    """Train/evaluate one healthy-versus-cancer task.

    ``evaluation='test'`` trains base OOF scores on the training partition,
    fits the fixed meta model, and predicts the independent test partition.
    ``evaluation='cv'`` runs strict nested CV on training samples only, with
    ``n_splits`` folds at both levels. ``'both'`` does both evaluations.
    FAME and FAME-GW share repeated first-layer fits when ``model='both'``.

    Return structure::

        {
            "models": {
                "fame": {
                    "features": [...],
                    "cv_scores": array | None, "test_scores": array | None,
                    "metrics": {"cv": {...}, "test": {...}},
                    "fold_metrics": [...], "bundle": FittedFAME | None,
                },
                "fame-gw": {...},
            },
            "fold_ids": array | None,  # 1-based outer folds, in training row order
            "base_fold_metrics": [...],  # includes evaluation and outer_fold
            "config": {...},
        }

    Scores preserve input row order. CV-only runs return no final fitted
    bundle. Test labels may contain one class (metrics then become NaN).
    ``X_test`` and ``y_test`` may be None for CV-only evaluation. Final
    training meta-layer fitted scores are deliberately not reported as CV.
    """
    if model not in {"both", "fame", "fame-gw"}:
        raise ValueError("model must be 'both', 'fame', or 'fame-gw'.")
    if evaluation not in {"both", "cv", "test"}:
        raise ValueError("evaluation must be 'both', 'cv', or 'test'.")
    if isinstance(n_splits, bool) or not isinstance(n_splits, (int, np.integer)) or n_splits < 2:
        raise ValueError("n_splits must be an integer >= 2.")
    if isinstance(n_jobs, bool) or not isinstance(n_jobs, (int, np.integer)) or n_jobs < 1:
        raise ValueError("n_jobs must be a positive integer; use an explicit worker limit.")
    if isinstance(seed, bool) or not isinstance(seed, (int, np.integer)) or not 0 <= seed < 2**32 - n_splits * 101:
        raise ValueError("seed must be a nonnegative integer with room for nested-fold seed offsets.")
    seed, n_splits, n_jobs = int(seed), int(n_splits), int(n_jobs)
    names = ["fame", "fame-gw"] if model == "both" else [model]
    feature_sets = {name: list(BASE_FEATURES if name == "fame" else GW_FEATURES) for name in names}
    features = list(GW_FEATURES if "fame-gw" in names else BASE_FEATURES)
    y = _labels(y_train, "y_train")
    train = _matrices(X_train, features, len(y), "X_train")
    outer_splits = _splits(y, n_splits, seed)
    run_cv, run_test = evaluation in {"cv", "both"}, evaluation in {"test", "both"}
    if run_cv:
        # Reject impossible inner CV before doing any expensive fits.
        for fold, (idx_train, _) in enumerate(outer_splits, 1):
            if np.bincount(y[idx_train], minlength=2).min() < n_splits:
                raise ValueError(
                    f"Outer fold {fold} has too few training samples per class for "
                    f"{n_splits}-fold inner CV. Use a smaller n_splits."
                )
    test, yt = None, None
    if run_test:
        yt = _labels(y_test, "y_test", require_both=False)
        test = _matrices(X_test, features, len(yt), "X_test")
        for feature in features:
            if train[feature].shape[1] != test[feature].shape[1]:
                raise ValueError(f"Train/test feature counts differ for {feature}.")
    result = {
        "models": {
            name: {
                "features": feature_sets[name],
                "cv_scores": np.full(len(y), np.nan, dtype=float) if run_cv else None,
                "test_scores": None, "metrics": {}, "fold_metrics": [], "bundle": None,
            }
            for name in names
        },
        "fold_ids": np.zeros(len(y), dtype=int) if run_cv else None,
        "base_fold_metrics": [],
        "config": {
            "model": model, "evaluation": evaluation, "n_splits": n_splits,
            "seed": seed, "n_jobs": n_jobs, "n_train": len(y),
            "n_test": len(yt) if run_test else 0,
            "meta_models": {name: "linear_svm" if name == "fame" else "random_forest_500" for name in names},
        },
    }
    if run_cv:
        for fold, (idx_train, idx_valid) in enumerate(outer_splits, 1):
            start = perf_counter()
            context = f"CV outer fold {fold}/{n_splits}"
            _emit(progress, f"{context}: training={len(idx_train)}, validation={len(idx_valid)}")
            X_inner = {feature: train[feature][idx_train] for feature in features}
            X_outer_valid = {feature: train[feature][idx_valid] for feature in features}
            inner_seed = seed + fold * 100
            inner_splits = _splits(y[idx_train], n_splits, inner_seed)
            oof, heldout, _, base_rows = _oof_base_scores(
                X_inner, X_outer_valid, y[idx_train], features, inner_splits,
                inner_seed, n_jobs, progress, context,
            )
            result["base_fold_metrics"].extend(
                {"evaluation": "cv", "outer_fold": fold, **row} for row in base_rows
            )
            result["fold_ids"][idx_valid] = fold
            for name in names:
                selected = feature_sets[name]
                Z_train = np.column_stack([oof[feature] for feature in selected])
                Z_valid = np.column_stack([heldout[feature] for feature in selected])
                with threadpool_limits(limits=1):
                    # The original analysis uses the global seed for every
                    # outer-fold meta estimator, not the inner-fold seed.
                    meta = make_meta_model(name, seed)
                    meta.fit(Z_train, y[idx_train])
                    score = get_score(meta, Z_valid)
                record = result["models"][name]
                record["cv_scores"][idx_valid] = score
                metrics = evaluate_scores(y[idx_valid], score)
                record["fold_metrics"].append({
                    "outer_fold": fold, "n_val": len(idx_valid),
                    "n_pos": int(y[idx_valid].sum()),
                    "time_sec": perf_counter() - start, **metrics,
                })
                _emit(progress, f"{context}: {name} AUC={metrics['auc']:.5f}")
        for name in names:
            record = result["models"][name]
            record["metrics"]["cv"] = evaluate_scores(y, record["cv_scores"])
    if run_test:
        oof, heldout, fitted, base_rows = _oof_base_scores(
            train, test, y, features, outer_splits, seed, n_jobs, progress, "Independent test",
        )
        result["base_fold_metrics"].extend(
            {"evaluation": "test", "outer_fold": 0, **row} for row in base_rows
        )
        for name in names:
            selected = feature_sets[name]
            Z_train = np.column_stack([oof[feature] for feature in selected])
            Z_test = np.column_stack([heldout[feature] for feature in selected])
            with threadpool_limits(limits=1):
                meta = make_meta_model(name, seed)
                meta.fit(Z_train, y)
                score = get_score(meta, Z_test)
            record = result["models"][name]
            record["test_scores"] = score
            record["metrics"]["test"] = evaluate_scores(yt, score)
            record["bundle"] = FittedFAME(
                name=name, features=selected,
                feature_counts={feature: train[feature].shape[1] for feature in selected},
                base_models={feature: fitted[feature] for feature in selected},
                meta_model=meta, seed=seed, n_splits=n_splits,
            )
            _emit(progress, f"Independent test: {name} AUC={record['metrics']['test']['auc']:.5f}")
    return result
