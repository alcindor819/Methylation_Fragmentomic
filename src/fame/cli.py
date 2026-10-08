"""Small command-line interface for installation checks and real analyses."""
from __future__ import annotations
import argparse
from datetime import datetime
from importlib.metadata import version
import json
from pathlib import Path
import sys
import time
import numpy as np
import pandas as pd
import joblib
from . import __version__
from .data import FEATURE_ORDER, TASKS, load_dataset, task_data, sha256
from .plotting import plot_predictions


def log(message):
    print(datetime.now().strftime("[%H:%M:%S] ") + message, flush=True)


def versions():
    return {name: version(name) for name in
            ["numpy", "pandas", "scipy", "scikit-learn", "matplotlib", "joblib", "threadpoolctl"]}


def output_directory(path):
    path = Path(path)
    if path.exists() and any(path.iterdir()):
        raise ValueError("Output directory is not empty. Choose a new --outdir: " + str(path))
    path.mkdir(parents=True, exist_ok=True)
    return path


def demo(args):
    out = output_directory(args.outdir)
    source = Path(__file__).parent / "reference" / "predictions.tsv"
    predictions = pd.read_csv(source, sep="\t")
    predictions.to_csv(out / "predictions.tsv", sep="\t", index=False)
    metrics = plot_predictions(predictions, out)
    (out / "run_info.json").write_text(json.dumps({
        "mode": "reference_score_demo", "trains_models": False,
        "package_version": __version__, "reference_sha256": sha256(source),
        "versions": versions(), "n_curves": len(metrics),
    }, indent=2) + "\n")
    log(f"Demo complete: {len(metrics)} ROC curves in {out.resolve()}. No models were trained.")


def validate(args):
    data = load_dataset(args.data, checksums=args.checksums, progress=log)
    summary = {"dataset": data.manifest["dataset"], "n_train": len(data.train),
               "n_test": len(data.test), "checksums_verified": bool(args.checksums),
               "modalities": {f: {"train": list(x.shape), "test": list(data.X_test[f].shape)}
                              for f, x in data.X_train.items()}}
    print(json.dumps(summary, indent=2))
    log("Data validation passed.")


def run(args):
    from .models import train_evaluate
    if args.jobs < 1 or args.folds < 2:
        raise ValueError("--jobs must be >=1 and --folds must be >=2")
    selected = FEATURE_ORDER[:4] if args.model == "fame" else FEATURE_ORDER
    data = load_dataset(args.data, features=selected, checksums=args.checksums, progress=log)
    tasks = TASKS if args.task == "all" else [args.task]
    out = output_directory(args.outdir)
    config = {"package_version": __version__, "dataset": data.manifest["dataset"],
              "model": args.model, "evaluation": args.evaluation, "tasks": tasks,
              "folds": args.folds, "seed": args.seed, "jobs": args.jobs,
              "versions": versions(), "python": sys.version,
              "data_manifest_sha256": sha256(Path(args.data) / "manifest.json"),
              "model_selection": "fixed, no test-set selection"}
    (out / "config.json").write_text(json.dumps(config, indent=2) + "\n")
    all_predictions, all_fold_metrics, all_base_metrics = [], [], []
    t0 = time.perf_counter()
    for task in tasks:
        log(f"Starting {task}; evaluation={args.evaluation}, model={args.model}")
        xtr, xte, ytr, yte, train, test = task_data(data, task)
        result = train_evaluate(xtr, xte, ytr, yte, model=args.model,
                                evaluation=args.evaluation, n_splits=args.folds,
                                seed=args.seed, n_jobs=args.jobs, progress=log)
        target = out / task if len(tasks) > 1 else out
        target.mkdir(parents=True, exist_ok=True)
        task_predictions = []
        for model, values in result["models"].items():
            for split, samples, y, scores in [
                ("cv", train, ytr, values["cv_scores"]),
                ("test", test, yte, values["test_scores"]),
            ]:
                if scores is None:
                    continue
                frame = pd.DataFrame({"model": model, "task": task, "split": split,
                                      "sample_id": samples.sample_id.to_numpy(),
                                      "label": samples.label.to_numpy(), "y_true": y, "score": scores})
                if split == "cv":
                    frame["fold_id"] = result["fold_ids"]
                task_predictions.append(frame)
            for row in values["fold_metrics"]:
                all_fold_metrics.append({"task": task, "model": model, **row})
            bundle = values["bundle"]
            if bundle is not None:
                payload = {"schema_version": 1, "task": task, "model": bundle,
                           "feature_ids": {f: data.feature_ids[f] for f in values["features"]},
                           "versions": config["versions"], "seed": args.seed,
                           "n_splits": args.folds}
                joblib.dump(payload, target / f"{model}.joblib", compress=3)
        for row in result["base_fold_metrics"]:
            all_base_metrics.append({"task": task, **row})
        frame = pd.concat(task_predictions, ignore_index=True)
        frame.to_csv(target / "predictions.tsv", sep="\t", index=False)
        plot_predictions(frame, target)
        all_predictions.append(frame)
        # A completed task remains usable if a later task is interrupted.
        combined = pd.concat(all_predictions, ignore_index=True)
        combined.to_csv(out / "predictions.tsv", sep="\t", index=False)
        if all_fold_metrics:
            pd.DataFrame(all_fold_metrics).to_csv(out / "fold_metrics.tsv", sep="\t", index=False)
        pd.DataFrame(all_base_metrics).to_csv(out / "base_fold_metrics.tsv", sep="\t", index=False)
        log(f"Finished {task}")
    if len(tasks) > 1:
        plot_predictions(pd.concat(all_predictions, ignore_index=True), out)
    (out / "run_summary.json").write_text(json.dumps({
        "status": "complete", "elapsed_seconds": time.perf_counter() - t0,
        "tasks": tasks, "evaluation": args.evaluation,
    }, indent=2) + "\n")
    log("All requested tasks complete: " + str(out.resolve()))


def predict(args):
    saved = joblib.load(args.model)
    if not isinstance(saved, dict) or saved.get("schema_version") != 1:
        raise ValueError("Unsupported model file")
    model = saved["model"]
    with np.load(args.features, allow_pickle=False) as z:
        ids = z["sample_ids"].astype(str)
        if ids.ndim != 1 or len(set(ids.tolist())) != len(ids) or len(ids) == 0:
            raise ValueError("sample_ids must be a nonempty unique one-dimensional array")
        matrices = {}
        for f in model.features:
            if not np.array_equal(z[f"ids_{f}"].astype(str), saved["feature_ids"][f]):
                raise ValueError(f + ": feature IDs/order differ from model")
            matrices[f] = z[f"X_{f}"]
            if matrices[f].ndim != 2:
                raise ValueError(f + ": expected a two-dimensional feature matrix")
            if matrices[f].shape[0] != len(ids):
                raise ValueError(f + ": sample count differs from sample_ids")
    score = model.predict_scores(matrices)
    target = Path(args.out)
    if target.exists():
        raise ValueError("Output already exists: " + str(target))
    target.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame({"sample_id": ids, "task": saved["task"], "model": model.name, "score": score}).to_csv(target, sep="\t", index=False)
    log(f"Predicted {len(ids)} samples: {target.resolve()}")


def main(argv=None):
    parser = argparse.ArgumentParser(description="FAME / FAME-GW binary classification from cfDNA feature matrices")
    parser.add_argument("--version", action="version", version=__version__)
    subs = parser.add_subparsers(dest="command", required=True)
    p = subs.add_parser("demo", help="Replot bundled reference ROC curves; no training or large data download")
    p.add_argument("--outdir", default="results/demo")
    p.set_defaults(func=demo)
    p = subs.add_parser("validate", help="Validate a feature data package")
    p.add_argument("--data", required=True)
    p.add_argument("--checksums", action="store_true")
    p.set_defaults(func=validate)
    p = subs.add_parser("run", help="Train and evaluate fixed binary classifiers")
    p.add_argument("--data", required=True)
    p.add_argument("--task", choices=TASKS + ["all"], default="BRCA")
    p.add_argument("--model", choices=["fame", "fame-gw", "both"], default="both")
    p.add_argument("--evaluation", choices=["test", "cv", "both"], default="test")
    p.add_argument("--outdir", required=True)
    p.add_argument("--jobs", type=int, default=2)
    p.add_argument("--folds", type=int, default=10)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--checksums", action="store_true")
    p.set_defaults(func=run)
    p = subs.add_parser("predict", help="Predict using a trusted saved model and matching feature IDs")
    p.add_argument("--model", required=True)
    p.add_argument("--features", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(func=predict)
    args = parser.parse_args(argv)
    try:
        args.func(args)
    except (ValueError, FileNotFoundError, KeyError) as exc:
        parser.exit(2, f"Error: {exc}\n")
    return 0
