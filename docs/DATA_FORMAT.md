# FAME feature data format

The release starts from precomputed feature matrices. It does not process FASTQ,
BAM, methylation calls, or fragment coordinates. The HRA003209 package preserves
the original 894 training and 383 independent-validation samples. Each cancer is
evaluated against the healthy controls; other cancer labels are excluded from
that binary task.

## Files

| File | Contents |
| --- | --- |
| `samples.tsv` | `sample_id`, `split` (`train` or `test`), `label` |
| `regions.tsv` | `feature_id`, `chrom`, `start`, `end` for the 115,759 shared regional columns |
| `features/MODALITY.npz` | Compressed numeric matrices, sample IDs, and ordered feature IDs |
| `manifest.json` | Schema version, dimensions, source basenames, and SHA-256 checksums |
| `validation.json` | Exact read-back checks, sample checks, and descriptive numeric statistics |
| `SHA256SUMS` | Checksums of every public data file except this checksum list itself |

Allowed labels are `HEALTHY`, `BRCA`, `COREAD`, `ESCA`, `LIHC`, `NSCLC`, `PACA`, and
`STAD`. Samples are listed in original training order, followed by original test
order. Labels are metadata and are never included among numeric features.

## Matrix contract

Every NPZ file has exactly these five keys. It can be opened with
`numpy.load(path, allow_pickle=False)`.

| Key | Type | Shape / meaning |
| --- | --- | --- |
| `X_train` | `float32` | 894 rows × number of features |
| `X_test` | `float32` | 383 rows × number of features |
| `train_ids` | NumPy Unicode | 894 sample IDs, in matrix row order |
| `test_ids` | NumPy Unicode | 383 sample IDs, in matrix row order |
| `feature_ids` | NumPy Unicode | Ordered column IDs, shared by both matrices |

All matrices use samples as rows. There are no pickled Python objects. Sample
IDs must match `samples.tsv` exactly, and feature order must be preserved.

| Modality | Columns | Feature IDs | Used by |
| --- | ---: | --- | --- |
| WPS | 115,759 | `region000001`–`region115759` | FAME, FAME-GW |
| EDM | 5,632 | `EDM_0001`–`EDM_5632` | FAME, FAME-GW |
| PDR | 115,759 | `region000001`–`region115759` | FAME, FAME-GW |
| MBS | 115,759 | `region000001`–`region115759` | FAME, FAME-GW |
| GWM | 2,897 | Original TSV column names | FAME-GW |
| EM | 256 | Original TSV column names | FAME-GW |
| CAFF | 39 | Original TSV column names | FAME-GW |
| MFR | 1,846 | Original TSV column names | FAME-GW |

EDM is the original chromosome-resolved representation: 22 autosomes × 256
end-motif features. Its supplied ordinal IDs preserve the exact original matrix
order. The exact mapping of each ordinal column to its chromosome and 4-mer has
not been independently verified and is not supplied. Do not infer that mapping
from the separately named genome-wide EM features. New EDM matrices must follow
the original column order; the released cohort can be reproduced without a
motif-label mapping.

The regional IDs refer to the original `region500bp.xlsx` row order. Chromosome,
start, and end values are copied without shifting coordinates. The original
coordinate origin and endpoint-inclusivity convention have not been independently
verified; do not treat the table as a certified BED file without checking its
provenance.

## Numeric preservation and checks

Export uses the frozen analysis script's loaders as the numerical reference:
cast to `float32`, orient the matrices, align external TSV rows to the fixed
sample lists, and convert nonfinite values to `NaN`. This matches the existing
Python model input. Compression is lossless relative to that loaded `float32`
input; it is not a promise to preserve any additional precision in source MAT or
TSV files.

Negative values, including `-1`, are preserved. Export does not impute, normalize,
select features, or remove constant columns. Those model operations belong inside
the appropriate training folds. For the original MAT files, the authoritative
loader selects `mrtix_me` (or its documented equivalent), not auxiliary
`mrtix_queshi` arrays.

Each exported numeric array is read back and compared element by element with
`numpy.array_equal(..., equal_nan=True)`. ID arrays, shapes, and dtypes are also
checked. `validation.json` records missing, negative, `-1`, all-missing-column,
and constant-column counts for each split. A constant finite column means that
all its finite entries have the same value; it may also contain missing entries.

`manifest.json` has `schema_version: 1`, `dataset: "HRA003209"`, and
`status: "complete"` only after every modality passes. The `modalities` object is
keyed by modality name; each value contains `path`, `shape.X_train`,
`shape.X_test`, `dtype`, `bytes`, `sha256`, and source basename/checksum records.
The `metadata` object records `samples`, `regions`, and `validation` paths and
checksums. Absolute author-server paths are excluded from this public package.

## Maintainer export

`scripts/prepare_hra003209.py` is for the authors' source files, not a required
installation step for ordinary users. Its dependencies additionally include
`h5py` and `openpyxl`. Point `--legacy-module` at the trusted, frozen original
Python analysis script. That script must protect its training entry point with
`if __name__ == "__main__"`.

```bash
python scripts/prepare_hra003209.py \
  --feature-dir /path/to/original/FAME_feature \
  --spotmas-dir /path/to/original/SPOTMAS_fragment \
  --themis-dir /path/to/original/THEMIS/features \
  --regions /path/to/original/region500bp.xlsx \
  --legacy-module /path/to/original/frozen_analysis.py \
  --output /path/to/new/data/hra003209 \
  --private-provenance /path/to/private/source_provenance.json
```

The exporter processes one modality at a time and never trains a model. It
refuses a nonempty output directory unless `--resume` is supplied. Resume still
loads the original sources and fully verifies existing files; mismatches stop
the export instead of overwriting data. Keep private provenance outside the
public data directory. It contains original absolute file locations for the
authors' audit trail.
