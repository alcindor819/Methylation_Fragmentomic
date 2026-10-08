"""Read the versioned, sample-aligned feature package without pickle."""
from dataclasses import dataclass
from pathlib import Path
import hashlib
import json
import numpy as np
import pandas as pd

FEATURE_ORDER = ["WPS", "EDM", "PDR", "MBS", "GWM", "EM", "CAFF", "MFR"]
TASKS = ["BRCA", "COREAD", "ESCA", "LIHC", "NSCLC", "PACA", "STAD"]


def sha256(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def resolve_file(root, relative):
    p = (root / relative).resolve()
    try:
        p.relative_to(root.resolve())
    except ValueError:
        raise ValueError("Dataset file points outside the data directory: " + str(relative))
    if not p.is_file():
        raise FileNotFoundError("Required data file is missing: " + str(p))
    return p


@dataclass
class Dataset:
    train: pd.DataFrame
    test: pd.DataFrame
    X_train: dict
    X_test: dict
    feature_ids: dict
    manifest: dict


def load_dataset(directory, features=None, checksums=False, progress=None):
    root = Path(directory)
    mp = root / "manifest.json"
    if not mp.is_file():
        raise FileNotFoundError("No manifest.json in " + str(root) + ". Extract the complete HRA003209 data package here first.")
    manifest = json.loads(mp.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or manifest.get("dataset") != "HRA003209":
        raise ValueError("Unsupported data package; expected HRA003209 schema_version=1")
    if manifest.get("status") != "complete":
        raise ValueError("The feature package is incomplete; finish or resume data preparation first")
    features = list(features or FEATURE_ORDER)
    meta = manifest["metadata"]
    for value in meta.values():
        p = resolve_file(root, value["path"])
        if checksums and sha256(p) != value["sha256"]:
            raise ValueError("Checksum mismatch: " + str(p))
    samples = pd.read_csv(resolve_file(root, meta["samples"]["path"]), sep="\t", dtype=str, keep_default_na=False)
    if not {"sample_id", "split", "label"}.issubset(samples.columns):
        raise ValueError("samples.tsv must contain sample_id, split, label")
    if samples.sample_id.eq("").any() or samples.sample_id.duplicated().any():
        raise ValueError("Sample IDs must be nonempty and unique across train/test")
    if not samples.split.isin(["train", "test"]).all():
        raise ValueError("Unknown split in samples.tsv")
    if not samples.label.isin(["HEALTHY"] + TASKS).all():
        raise ValueError("Unknown class label in samples.tsv")
    train = samples[samples.split == "train"].reset_index(drop=True)
    test = samples[samples.split == "test"].reset_index(drop=True)
    if len(train) == 0 or len(test) == 0:
        raise ValueError("Both train and test splits are required")
    X_train, X_test, feature_ids = {}, {}, {}
    for feature in features:
        if feature not in manifest["modalities"]:
            raise ValueError("Missing modality in manifest: " + feature)
        spec = manifest["modalities"][feature]
        p = resolve_file(root, spec["path"])
        if checksums and sha256(p) != spec["sha256"]:
            raise ValueError("Checksum mismatch: " + str(p))
        if progress:
            progress("Loading " + feature)
        with np.load(p, allow_pickle=False) as z:
            required = {"X_train", "X_test", "train_ids", "test_ids", "feature_ids"}
            if not required.issubset(z.files):
                raise ValueError(feature + ": missing required NPZ keys")
            a, b = z["X_train"], z["X_test"]
            names = z["feature_ids"].astype(str)
            if not np.array_equal(z["train_ids"].astype(str), train.sample_id.to_numpy()):
                raise ValueError(feature + ": train sample order mismatch")
            if not np.array_equal(z["test_ids"].astype(str), test.sample_id.to_numpy()):
                raise ValueError(feature + ": test sample order mismatch")
        if a.dtype != np.float32 or b.dtype != np.float32:
            raise ValueError(feature + ": expected float32 matrices")
        if a.ndim != 2 or b.ndim != 2 or a.shape != (len(train), len(names)) or b.shape != (len(test), len(names)):
            raise ValueError(feature + ": inconsistent matrix shape")
        if len(set(names.tolist())) != len(names):
            raise ValueError(feature + ": duplicate feature IDs")
        declared = spec.get("shape", {})
        for key, value in [("X_train", a), ("X_test", b)]:
            if key in declared and list(value.shape) != list(declared[key]):
                raise ValueError(feature + ": manifest shape mismatch for " + key)
        if np.isinf(a).any() or np.isinf(b).any():
            raise ValueError(feature + ": infinity found; missing values must be NaN")
        X_train[feature], X_test[feature], feature_ids[feature] = a, b, names
    shared = [f for f in ["WPS", "PDR", "MBS"] if f in feature_ids]
    if shared:
        regions = pd.read_csv(resolve_file(root, meta["regions"]["path"]), sep="\t", dtype={"feature_id": str})
        for f in shared:
            if not np.array_equal(feature_ids[f], regions.feature_id.to_numpy()):
                raise ValueError(f + ": region order differs from regions.tsv")
    return Dataset(train, test, X_train, X_test, feature_ids, manifest)


def task_data(dataset, task):
    if task not in TASKS:
        raise ValueError("Unknown binary cancer task: " + task)
    tr = dataset.train.label.isin(["HEALTHY", task]).to_numpy()
    te = dataset.test.label.isin(["HEALTHY", task]).to_numpy()
    train, test = dataset.train.loc[tr].copy(), dataset.test.loc[te].copy()
    if train.label.nunique() != 2 or test.label.nunique() != 2:
        raise ValueError(task + ": both cancer and healthy samples are required in each split")
    return ({f: x[tr] for f, x in dataset.X_train.items()},
            {f: x[te] for f, x in dataset.X_test.items()},
            (train.label == task).to_numpy(dtype=int),
            (test.label == task).to_numpy(dtype=int), train, test)
