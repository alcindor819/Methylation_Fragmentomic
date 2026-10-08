"""Export ROC curves and machine-readable metrics from sample-level scores."""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.metrics import roc_curve, roc_auc_score, average_precision_score

COLORS = {"fame": "#2563A6", "fame-gw": "#D46A36"}
NAMES = {"fame": "FAME", "fame-gw": "FAME-GW"}


def plot_predictions(predictions, outdir):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    required = {"model", "task", "split", "sample_id", "y_true", "score"}
    if not required.issubset(predictions.columns):
        raise ValueError("Prediction table is missing required columns")
    if predictions.empty:
        raise ValueError("Prediction table is empty")
    if not predictions.model.isin(NAMES).all() or not predictions.split.isin(["cv", "test"]).all():
        raise ValueError("Unknown model or split in prediction table")
    if not np.isfinite(predictions.score.to_numpy(dtype=float)).all():
        raise ValueError("Scores must be finite")
    if not predictions.y_true.isin([0, 1]).all():
        raise ValueError("Binary labels must be 0/1")
    if predictions.duplicated(["model", "task", "split", "sample_id"]).any():
        raise ValueError("Duplicate sample within a model/task/split")
    metrics, coordinates = [], []
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "svg.fonttype": "none", "pdf.fonttype": 42,
                         "axes.spines.top": False, "axes.spines.right": False})
    for task in predictions.task.drop_duplicates():
        task_rows = predictions[predictions.task == task]
        splits = [s for s in ["cv", "test"] if s in set(task_rows.split)]
        fig, axes = plt.subplots(1, len(splits), figsize=(5.2 * len(splits), 4.7), squeeze=False)
        for ax, split in zip(axes[0], splits):
            df = task_rows[task_rows.split == split]
            ax.plot([0, 1], [0, 1], linestyle="--", color="#A7A7A7", lw=1)
            for model in ["fame", "fame-gw"]:
                x = df[df.model == model]
                if x.empty:
                    continue
                y = x.y_true.to_numpy(dtype=int)
                if len(np.unique(y)) != 2:
                    raise ValueError(f"{task}/{split}/{model}: both classes are required for ROC")
                score = x.score.to_numpy(dtype=float)
                fpr, tpr, thresholds = roc_curve(y, score)
                auc_value = roc_auc_score(y, score)
                metrics.append({"task": task, "model": model, "split": split,
                                "n": len(x), "n_cancer": int(y.sum()),
                                "auc": auc_value, "average_precision": average_precision_score(y, score),
                                "sens_at_95spec": float(tpr[(1 - fpr) >= 0.95].max()),
                                "auc_definition": "pooled_sample_scores"})
                for a, b, c in zip(fpr, tpr, thresholds):
                    coordinates.append({"task": task, "model": model, "split": split,
                                        "false_positive_rate": a, "true_positive_rate": b, "threshold": c})
                ax.plot(fpr, tpr, color=COLORS[model], lw=2.2,
                        label=f"{NAMES[model]}  AUC = {auc_value:.3f}")
            ax.set(xlim=(-0.015, 1.015), ylim=(-0.015, 1.015),
                   xlabel="False positive rate", ylabel="True positive rate",
                   title="Cross-validation" if split == "cv" else "Independent validation")
            ax.set_aspect("equal", adjustable="box")
            ax.legend(loc="lower right", frameon=False, fontsize=9)
            ax.grid(alpha=.15)
        fig.suptitle(f"{task} vs healthy", fontsize=14, fontweight="bold")
        fig.tight_layout()
        fig.savefig(outdir / f"{task}_ROC.png", dpi=180, facecolor="white")
        fig.savefig(outdir / f"{task}_ROC.svg", facecolor="white")
        plt.close(fig)
    metrics = pd.DataFrame(metrics)
    metrics.to_csv(outdir / "metrics.tsv", sep="\t", index=False)
    pd.DataFrame(coordinates).to_csv(outdir / "roc_coordinates.tsv", sep="\t", index=False)
    return metrics
