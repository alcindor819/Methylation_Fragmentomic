# Score new feature matrices

The `predict` command applies one saved cancer-specific model to matching feature matrices. It returns continuous scores and does not train or select a model.

Use a model produced by an independent-validation training run, for example:

```bash
python -m fame predict \
  --model results/BRCA/fame.joblib \
  --features input.npz \
  --out results/new_samples/BRCA_predictions.tsv
```

For FAME-GW, use `fame-gw.joblib`. A run with `--task all` puts these files in cancer-specific subdirectories of its output directory. The output filename must not already exist. Load only model files you created or received from a trusted source: joblib model files contain executable Python serialization.

## Input schema

`input.npz` is a single compressed NumPy archive. It is separate from the eight training-data NPZ files described in [DATA_FORMAT.md](DATA_FORMAT.md). Open it with `numpy.load(..., allow_pickle=False)`.

| Key | Type | Shape / meaning |
| --- | --- | --- |
| `sample_ids` | NumPy Unicode | `n_samples`; unique sample identifiers in matrix row order |
| `X_WPS` | Numeric, preferably `float32` | `n_samples × 115759` |
| `ids_WPS` | NumPy Unicode | 115,759 ordered feature identifiers |
| `X_EDM`, `ids_EDM` | Same pattern | 5,632 features |
| `X_PDR`, `ids_PDR` | Same pattern | 115,759 features |
| `X_MBS`, `ids_MBS` | Same pattern | 115,759 features |
| `X_GWM`, `ids_GWM` | Same pattern; FAME-GW only | 2,897 features |
| `X_EM`, `ids_EM` | Same pattern; FAME-GW only | 256 features |
| `X_CAFF`, `ids_CAFF` | Same pattern; FAME-GW only | 39 features |
| `X_MFR`, `ids_MFR` | Same pattern; FAME-GW only | 1,846 features |

Every matrix has samples as rows. All matrices must share the row order defined by `sample_ids`. Labels and train/test splits are not required for prediction. Missing numeric entries may be represented as `NaN`; the saved model applies preprocessing fitted on its training data.

The command checks each modality's feature identifiers against the identifiers saved with the fitted model, including their order. It does not silently reorder columns. Matching identifiers alone cannot verify that the underlying features were calculated in the same way.

## Runnable format example

The following example packages the first three supplied independent-validation samples into the prediction input format. It is a file-format check using existing samples, not a new validation cohort.

Run this Python code from the project root after obtaining the complete feature package:

```python
from pathlib import Path
import numpy as np

data_dir = Path("data/hra003209/features")
modalities = ["WPS", "EDM", "PDR", "MBS"]  # FAME
# For FAME-GW, append: ["GWM", "EM", "CAFF", "MFR"]

payload = {}
for modality in modalities:
    with np.load(data_dir / f"{modality}.npz", allow_pickle=False) as source:
        sample_ids = source["test_ids"][:3].astype(str)
        if "sample_ids" in payload:
            assert np.array_equal(payload["sample_ids"], sample_ids)
        else:
            payload["sample_ids"] = sample_ids
        payload[f"X_{modality}"] = source["X_test"][:3].astype(np.float32)
        payload[f"ids_{modality}"] = source["feature_ids"].astype(str)

np.savez_compressed("input.npz", **payload)
```

Then run the `predict` command above using the model fitted for the task you want to score. To use genuinely new samples, replace these matrix values and sample IDs with the new inputs while preserving the same feature definitions and verified column order.

## Output and limits

The output TSV contains `sample_id`, `task`, `model`, and `score`. Higher scores indicate stronger evidence for the model's target cancer versus healthy controls. FAME returns a linear-SVM decision score; FAME-GW returns the random forest's class-1 probability estimate without additional probability calibration. Neither output supplies a universal diagnostic cutoff.

The four FAME modalities are all required. EDM uses the original 22-autosome × 256-feature representation. The exact mapping of its ordinal column IDs to chromosome–motif pairs has not been independently verified; newly computed EDM inputs must preserve the original column order rather than infer it from those IDs. Feature extraction is outside this repository's scope.

Applying a saved model to a new sequencing protocol or cohort is a separate validation question. This interface checks input structure and feature alignment; it does not establish transportability between laboratories.
