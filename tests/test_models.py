"""Behavioral checks for evaluation isolation and portable fitted models."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import joblib
import numpy as np
from sklearn.model_selection import StratifiedKFold

from fame.models import GW_FEATURES, train_evaluate


def example_data():
    rng = np.random.default_rng(518)
    y_train = np.tile([0, 1], 18)
    y_test = np.tile([0, 1], 6)
    X_train, X_test = {}, {}
    for feature in GW_FEATURES:
        X_train[feature] = rng.normal(size=(len(y_train), 5)).astype(np.float32)
        X_test[feature] = rng.normal(size=(len(y_test), 5)).astype(np.float32)
        X_train[feature][:, 1] += 0.7 * y_train
        X_test[feature][:, 1] += 0.7 * y_test
        X_train[feature][0, 3] = np.nan
        X_test[feature][1, 4] = np.nan
    return X_train, X_test, y_train, y_test


class TestFAMEModels(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.train, cls.test, cls.y_train, cls.y_test = example_data()
        cls.result = train_evaluate(
            cls.train, cls.test, cls.y_train, cls.y_test,
            model="both", n_splits=3, n_jobs=1,
        )

    def test_test_labels_cannot_change_predictions_and_worker_count_is_stable(self):
        # Changing every independent-test label cannot affect either model.
        # Also exercise the bounded process-worker execution path.
        changed = train_evaluate(
            self.train, self.test, self.y_train, 1 - self.y_test,
            model="both", n_splits=3, n_jobs=2,
        )
        for name in ["fame", "fame-gw"]:
            np.testing.assert_allclose(
                changed["models"][name]["test_scores"],
                self.result["models"][name]["test_scores"], rtol=0, atol=1e-12,
            )

    def test_saved_models_reproduce_scores_and_reject_wrong_width(self):
        with tempfile.TemporaryDirectory() as folder:
            for name, record in self.result["models"].items():
                path = Path(folder) / f"{name}.joblib"
                joblib.dump(record["bundle"], path)
                restored = joblib.load(path)
                np.testing.assert_allclose(
                    restored.predict_scores(self.test), record["test_scores"],
                    rtol=0, atol=1e-12,
                )
                broken = dict(self.test)
                broken["WPS"] = broken["WPS"][:, :-1]
                with self.assertRaisesRegex(ValueError, "expected 5 columns"):
                    restored.predict_scores(broken)

    def test_nested_cv_never_fits_on_outer_validation_samples(self):
        # Track sample identity through a fake first layer. This checks the
        # split boundary independently of the SVM/scaling implementation.
        y = np.tile([0, 1], 12)
        X = {name: np.column_stack([np.arange(len(y)), y]).astype(np.float32) for name in GW_FEATURES}
        fit_sets = []

        class TrackedBase:
            def fit(self, values, labels):
                fit_sets.append(set(values[:, 0].astype(int)))
                return self

            def decision_function(self, values):
                return values[:, 1].astype(float) + values[:, 0] * 0.001

        with patch("fame.models.make_base_model", side_effect=lambda seed: TrackedBase()):
            result = train_evaluate(X, None, y, None, model="fame", evaluation="cv", n_splits=3, n_jobs=1)
        outer = list(StratifiedKFold(n_splits=3, shuffle=True, random_state=42).split(np.zeros(len(y)), y))
        # Four modalities; each has three inner fits and one outer-training fit.
        calls_per_outer_fold = 4 * (3 + 1)
        self.assertEqual(len(fit_sets), 3 * calls_per_outer_fold)
        for fold, (train_indices, validation_indices) in enumerate(outer):
            calls = fit_sets[fold * calls_per_outer_fold:(fold + 1) * calls_per_outer_fold]
            for fitted_samples in calls:
                self.assertTrue(fitted_samples.issubset(set(train_indices)))
                self.assertFalse(fitted_samples.intersection(validation_indices))
            np.testing.assert_array_equal(result["fold_ids"][validation_indices], fold + 1)
        self.assertIsNone(result["models"]["fame"]["bundle"])
        self.assertTrue(np.isfinite(result["models"]["fame"]["cv_scores"]).all())

    def test_too_small_nested_cv_fails_before_fitting(self):
        y = np.tile([0, 1], 3)
        X = {name: np.zeros((6, 2), dtype=np.float32) for name in GW_FEATURES}
        with patch("fame.models.make_base_model") as constructor:
            with self.assertRaisesRegex(ValueError, "too few training samples"):
                train_evaluate(X, None, y, None, model="fame", evaluation="cv", n_splits=3)
            constructor.assert_not_called()


if __name__ == "__main__":
    unittest.main()
