#!/usr/bin/env python3
"""Maintainer-only, lossless export of the frozen HRA003209 model inputs.

This does not extract biological features or train a model. Supply the original
analysis script as the authoritative loader. No original files are modified.
"""
from __future__ import annotations

import argparse
import csv
import gc
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import sys
from datetime import datetime, timezone

import numpy as np
import pandas as pd


MODALITIES = ("WPS", "EDM", "PDR", "MBS", "GWM", "EM", "CAFF", "MFR")
N_FEATURES = dict(WPS=115759, EDM=5632, PDR=115759, MBS=115759,
                  GWM=2897, EM=256, CAFF=39, MFR=1846)
LABELS = {"HEALTHY", "BRCA", "COREAD", "ESCA", "LIHC", "NSCLC", "PACA", "STAD"}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def file_record(path: Path, root: Path | None = None) -> dict:
    return {"path" if root else "name": str(path.relative_to(root)) if root else path.name,
            "sha256": sha256(path), "bytes": path.stat().st_size}


def write_json(path: Path, payload: dict) -> None:
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, ensure_ascii=False, allow_nan=False) + "\n",
                   encoding="utf-8")
    tmp.replace(path)


def write_table(path: Path, frame: pd.DataFrame, resume: bool) -> None:
    text = frame.to_csv(sep="\t", index=False, lineterminator="\n")
    if path.exists():
        if not resume or path.read_text(encoding="utf-8") != text:
            raise ValueError(f"Existing metadata differs; refusing to overwrite: {path}")
        return
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)


def load_legacy(path: Path):
    # The source must be a trusted analysis script with a guarded main().
    spec = importlib.util.spec_from_file_location("fame_authoritative_export_loader", path)
    if spec is None or spec.loader is None:
        raise ValueError("Cannot load authoritative Python module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    for name in ("load_info", "load_feature_mat", "load_extra_tsv_matrix", "norm_sample_id"):
        if not callable(getattr(module, name, None)):
            raise ValueError(f"Authoritative loader lacks {name}")
    return module


def summarize(X: np.ndarray) -> dict:
    """Chunk over columns to avoid allocating whole-matrix boolean copies."""
    result = dict(nonfinite=0, nan=0, positive_infinity=0, negative_infinity=0,
                  negative=0, minus_one=0, all_missing_columns=0, constant_finite_columns=0)
    minimum, maximum = None, None
    for start in range(0, X.shape[1], 2048):
        block = X[:, start:start + 2048]
        finite = np.isfinite(block)
        result["nonfinite"] += int((~finite).sum())
        result["nan"] += int(np.isnan(block).sum())
        result["positive_infinity"] += int(np.isposinf(block).sum())
        result["negative_infinity"] += int(np.isneginf(block).sum())
        result["negative"] += int(((block < 0) & finite).sum())
        result["minus_one"] += int((block == -1).sum())
        has_finite = finite.any(axis=0)
        lo = np.min(block, axis=0, where=finite, initial=np.inf)
        hi = np.max(block, axis=0, where=finite, initial=-np.inf)
        result["all_missing_columns"] += int((~has_finite).sum())
        result["constant_finite_columns"] += int((has_finite & (lo == hi)).sum())
        if has_finite.any():
            a, b = float(lo[has_finite].min()), float(hi[has_finite].max())
            minimum = a if minimum is None else min(minimum, a)
            maximum = b if maximum is None else max(maximum, b)
    result.update(finite_minimum=minimum, finite_maximum=maximum)
    return result


def extra_feature_ids(path: Path, train_ids: list[str], test_ids: list[str], legacy) -> list[str]:
    """Preserve source feature names while verifying the loader's orientation."""
    with path.open(encoding="utf-8", newline="") as handle:
        header = next(csv.reader(handle, delimiter="\t"))
    index = pd.read_csv(path, sep="\t", usecols=[0]).iloc[:, 0].astype(str).tolist()
    all_samples = {legacy.norm_sample_id(x) for x in train_ids + test_ids}
    rows = [legacy.norm_sample_id(x) for x in index]
    columns = [legacy.norm_sample_id(x) for x in header[1:]]
    row_hits, column_hits = len(set(rows) & all_samples), len(set(columns) & all_samples)
    if row_hits >= column_hits and row_hits:
        sample_axis, names = rows, header[1:]
    elif column_hits:
        sample_axis, names = columns, index
    else:
        raise ValueError(f"No sample matches in {path.name}")
    if len(sample_axis) != len(set(sample_axis)):
        raise ValueError(f"Duplicate normalized sample IDs in {path.name}")
    if not all_samples.issubset(set(sample_axis)):
        raise ValueError(f"Missing samples in {path.name}")
    if len(names) != len(set(names)):
        raise ValueError(f"Duplicate feature IDs in {path.name}")
    normalized = [legacy.norm_sample_id(x) for x in names]
    if names != normalized:
        raise ValueError(f"Source feature names changed by legacy normalization: {path.name}")
    return names


def verify_npz(path: Path, X_train: np.ndarray, X_test: np.ndarray,
               train_ids: np.ndarray, test_ids: np.ndarray, feature_ids: np.ndarray) -> dict:
    results = {}
    expected = dict(X_train=X_train, X_test=X_test, train_ids=train_ids,
                    test_ids=test_ids, feature_ids=feature_ids)
    with np.load(path, allow_pickle=False) as saved:
        if set(saved.files) != set(expected):
            raise ValueError(f"Unexpected NPZ keys: {path.name}")
        for key, original in expected.items():
            actual = saved[key]
            same = actual.dtype == original.dtype and actual.shape == original.shape
            if key.startswith("X_"):
                same = same and np.array_equal(actual, original, equal_nan=True)
            else:
                same = same and actual.dtype.kind == "U" and np.array_equal(actual, original)
            if not same:
                raise ValueError(f"Read-back comparison failed: {path.name}/{key}")
            results[key] = True
            del actual
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--feature-dir", required=True, type=Path)
    parser.add_argument("--spotmas-dir", required=True, type=Path)
    parser.add_argument("--themis-dir", required=True, type=Path)
    parser.add_argument("--regions", required=True, type=Path)
    parser.add_argument("--legacy-module", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--private-provenance", required=True, type=Path)
    parser.add_argument("--resume", action="store_true",
                        help="Recheck existing outputs against current sources; never overwrite mismatches")
    args = parser.parse_args()
    out = args.output.resolve()
    private = args.private_provenance.resolve()
    if out in private.parents or private == out:
        raise ValueError("Private provenance must be outside the public data directory")
    if out.exists() and any(out.iterdir()) and not args.resume:
        raise ValueError("Output is not empty; use --resume to verify already exported files")
    out.mkdir(parents=True, exist_ok=True)
    (out / "features").mkdir(exist_ok=True)
    private.parent.mkdir(parents=True, exist_ok=True)
    legacy = load_legacy(args.legacy_module)
    loader_record = file_record(args.legacy_module)
    previous_manifest = out / "manifest.json"
    if previous_manifest.exists():
        previous = json.loads(previous_manifest.read_text())
        if previous.get("authoritative_loader", {}).get("sha256") != loader_record["sha256"]:
            raise ValueError("Authoritative loader changed since previous export")

    info_paths = [args.feature_dir / "3209Train_info.mat", args.feature_dir / "3209Test_info.mat"]
    train = legacy.load_info(info_paths[0], "train_info")
    test = legacy.load_info(info_paths[1], "test_info")
    if (len(train), len(test)) != (894, 383):
        raise ValueError(f"Unexpected sample numbers: {len(train)}, {len(test)}")
    train_list, test_list = train["sample"].tolist(), test["sample"].tolist()
    ids = train_list + test_list
    if any(not x for x in ids) or len(ids) != len(set(ids)):
        raise ValueError("Empty, duplicate, or overlapping original sample IDs")
    normalized = [legacy.norm_sample_id(x) for x in ids]
    if len(normalized) != len(set(normalized)):
        raise ValueError("Duplicate normalized sample IDs")
    labels = train["group"].tolist() + test["group"].tolist()
    if set(labels) != LABELS:
        raise ValueError(f"Unexpected label set: {set(labels)}")
    samples = pd.DataFrame(dict(sample_id=ids, split=["train"] * len(train) + ["test"] * len(test), label=labels))
    write_table(out / "samples.tsv", samples, args.resume)
    regions_raw = pd.read_excel(args.regions, header=None, engine="openpyxl")
    if regions_raw.shape != (115759, 3) or regions_raw.isna().any().any():
        raise ValueError(f"Unexpected region table: {regions_raw.shape}")
    regions_raw.columns = ["chrom", "start", "end"]
    for column in ("start", "end"):
        numeric = pd.to_numeric(regions_raw[column], errors="raise")
        if not np.equal(numeric, np.floor(numeric)).all():
            raise ValueError("Noninteger genomic coordinates")
        regions_raw[column] = numeric.astype(np.int64)
    region_ids = [f"region{i:06d}" for i in range(1, len(regions_raw) + 1)]
    regions_raw.insert(0, "feature_id", region_ids)
    write_table(out / "regions.tsv", regions_raw, args.resume)
    del regions_raw
    train_ids, test_ids = np.asarray(train_list, dtype=str), np.asarray(test_list, dtype=str)
    manifest = dict(schema_version=1, dataset="HRA003209", status="incomplete", n_train=894, n_test=383,
                    modalities={}, authoritative_loader=loader_record,
                    metadata={name: file_record(out / (name + ".tsv"), out) for name in ("samples", "regions")},
                    coordinate_system="Original coordinates preserved; origin and endpoint convention unverified.",
                    missing_value_policy="Legacy float32 loading; nonfinite values become NaN; negative values preserved.",
                    feature_order_policy="Exact original order; EDM has 22 x 256 columns with ordinal IDs only.")
    validation = dict(schema_version=1, dataset="HRA003209", status="incomplete", modalities={},
                      sample_checks=dict(unique_ids=True, normalized_unique_ids=True, disjoint_splits=True,
                                         expected_counts=True, expected_labels=True),
                      class_counts=samples.groupby(["split", "label"]).size().unstack(fill_value=0).to_dict(orient="index"))
    provenance = dict(created_utc=datetime.now(timezone.utc).isoformat(),
                      arguments={k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
                      python=platform.python_version(), numpy=np.__version__, pandas=pd.__version__,
                      source_files=[])
    for path in [args.legacy_module, *info_paths, args.regions]:
        provenance["source_files"].append(dict(absolute_path=str(path.resolve()), **file_record(path)))
    manifest["metadata"]["samples"]["sources"] = [file_record(p) for p in info_paths]
    manifest["metadata"]["regions"]["sources"] = [file_record(args.regions)]
    extra_paths = dict(GWM=args.spotmas_dir / "GWM_matrix.tsv", EM=args.spotmas_dir / "EM_matrix.tsv",
                       CAFF=args.themis_dir / "CAFF_arm_raw_matrix.tsv", MFR=args.themis_dir / "MFR_matrix.tsv")

    for name in MODALITIES:
        print(f"[{datetime.now().isoformat(timespec='seconds')}] Loading {name}", flush=True)
        if name in ("WPS", "EDM", "PDR", "MBS"):
            sources = [args.feature_dir / f"3209_Train_{name}.mat", args.feature_dir / f"3209_Test_{name}.mat"]
            X_train = legacy.load_feature_mat(sources[0], expected_n=894)
            X_test = legacy.load_feature_mat(sources[1], expected_n=383)
            names = [f"EDM_{i:04d}" for i in range(1, 5633)] if name == "EDM" else region_ids
        else:
            sources = [extra_paths[name]]
            names = extra_feature_ids(sources[0], train_list, test_list, legacy)
            X_train, X_test = legacy.load_extra_tsv_matrix(sources[0], train_list, test_list, name)
        if X_train.shape != (894, N_FEATURES[name]) or X_test.shape != (383, N_FEATURES[name]):
            raise ValueError(f"Unexpected {name} shape: {X_train.shape}, {X_test.shape}")
        if X_train.dtype != np.float32 or X_test.dtype != np.float32 or len(names) != N_FEATURES[name]:
            raise ValueError(f"Unexpected {name} dtype or feature names")
        feature_ids = np.asarray(names, dtype=str)
        target = out / "features" / f"{name}.npz"
        was_present = target.exists()
        if not was_present:
            temporary = target.with_suffix(".npz.tmp")
            with temporary.open("wb") as handle:
                np.savez_compressed(handle, X_train=X_train, X_test=X_test,
                                    train_ids=train_ids, test_ids=test_ids, feature_ids=feature_ids)
            temporary.replace(target)
        elif not args.resume:
            raise ValueError(f"Refusing to overwrite {target}")
        readback = verify_npz(target, X_train, X_test, train_ids, test_ids, feature_ids)
        source_records = [file_record(p) for p in sources]
        record = dict(**file_record(target, out), dtype="float32",
                      shape=dict(X_train=list(X_train.shape), X_test=list(X_test.shape)), sources=source_records)
        manifest["modalities"][name] = record
        validation["modalities"][name] = dict(read_back_exact_equal_nan=readback,
                                             sha256=record["sha256"], bytes=record["bytes"],
                                             train_stats=summarize(X_train), test_stats=summarize(X_test),
                                             reused_existing_file=was_present)
        for path, source_record in zip(sources, source_records):
            provenance["source_files"].append(dict(absolute_path=str(path.resolve()), **source_record))
        write_json(out / "manifest.json", manifest)
        write_json(out / "validation.json", validation)
        write_json(private, provenance)
        print(f"  VERIFIED {name}: {record['shape']}, {record['bytes']:,} bytes, sha256={record['sha256']}", flush=True)
        del X_train, X_test, feature_ids
        gc.collect()

    manifest["status"] = validation["status"] = "complete"
    validation["total_feature_bytes"] = sum(x["bytes"] for x in manifest["modalities"].values())
    validation["finished_utc"] = datetime.now(timezone.utc).isoformat()
    write_json(out / "validation.json", validation)
    manifest["metadata"]["validation"] = file_record(out / "validation.json", out)
    write_json(out / "manifest.json", manifest)
    checksums = []
    for path in sorted(out.rglob("*")):
        if path.is_file() and path.name != "SHA256SUMS":
            checksums.append(f"{sha256(path)}  {path.relative_to(out).as_posix()}")
    (out / "SHA256SUMS").write_text("\n".join(checksums) + "\n", encoding="utf-8")
    print(json.dumps(dict(status="complete", n_train=894, n_test=383,
                          total_feature_bytes=validation["total_feature_bytes"])), flush=True)


if __name__ == "__main__":
    main()
