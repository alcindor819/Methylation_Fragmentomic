# FAME and FAME-GW

Binary cancer classification from precomputed cfDNA methylation and fragmentomic features.

[中文说明](README.zh-CN.md) · [Data format](docs/DATA_FORMAT.md) · [New samples](docs/NEW_SAMPLES.md) · [Reproducibility](docs/REPRODUCIBILITY.md)

This repository provides a Python workflow for **FAME** and **FAME-GW** on the HRA003209 dataset. It starts from feature matrices and supports cancer-versus-healthy classification, cross-validation, independent validation, and ROC plots. It does not require raw sequencing reads and does not implement FAME-multi.

| Model | Input groups | Integration |
| --- | --- | --- |
| FAME | PDR, MBS, WPS, EDM | One linear SVM per group, followed by a linear SVM |
| FAME-GW | PDR, MBS, WPS, EDM, GWM, MFR, CAFF, EM | One linear SVM per group, followed by a random forest |

## 1. Install

Download or clone this repository, open a terminal in its root directory, and run:

```bash
conda env create -f environment.yml
conda activate fame
```

The environment file installs Python and the required packages, including this project. Installation downloads dependencies and requires internet access. Run the commands below from the repository root. No MATLAB installation is required.

If you already have Python 3.9–3.12, you can use a virtual environment instead:

```bash
python -m venv .venv
# Linux / macOS:
source .venv/bin/activate
# Windows PowerShell, use instead:
# .venv\Scripts\Activate.ps1
python -m pip install -e .
```

A clean Python 3.12 virtual environment has been verified to install this project with its pinned dependencies.

## 2. Try the included ROC example

```bash
python -m fame demo --outdir results/demo
```

This command uses the included reference prediction scores to produce seven ROC figures, each with cross-validation and independent-validation panels comparing both models, plus `metrics.tsv`. **It does not train models or require the full feature dataset.** It is the quickest way to check installation and inspect the expected outputs.

Outputs are written as PNG and editable SVG files, for example `results/demo/BRCA_ROC.png` and `results/demo/BRCA_ROC.svg`. Repeated runs require a new or empty output directory, such as `--outdir results/demo2`.

## 3. Prepare the feature dataset

The full feature dataset is distributed separately from the code. The data ZIP contains a top-level `hra003209/` directory: extract it into this project's `data/` directory. The resulting path to the manifest should be `data/hra003209/manifest.json`. Then run:

```bash
python -m fame validate --data data/hra003209 --checksums
```

The dataset contains **894 training samples and 383 independent validation samples**. Each feature file preserves sample identifiers and feature order. See [Data format](docs/DATA_FORMAT.md) for the complete file layout and input requirements.

| Feature group | Features per sample |
| --- | ---: |
| PDR | 115,759 |
| MBS | 115,759 |
| WPS | 115,759 |
| EDM | 5,632 |
| GWM | 2,897 |
| MFR | 1,846 |
| CAFF | 39 |
| EM | 256 |

EDM contains 256 features for each of 22 autosomes. The provided matrix retains its original column order. A verified mapping from every column to its chromosome and end motif is not yet available; column identifiers must not be interpreted as verified biological annotations.

**Data availability:** the complete feature package has been prepared and all eight exported matrices have passed exact read-back checks. The compressed NPZ files total 954,585,038 bytes; the complete directory including metadata is approximately 959 MB. The package awaits public release, and a public download link and Zenodo DOI have not yet been assigned. If you have the package from the authors, place it in the directory above. The included ROC example works without it.

## 4. Train and evaluate

Start with one cancer type and independent validation:

```bash
python -m fame run \
  --data data/hra003209 \
  --task BRCA \
  --model both \
  --evaluation test \
  --outdir results/BRCA \
  --jobs 2
```

`test` uses the fixed training cohort to fit the models and evaluates them on the independent validation cohort. Within the training cohort, out-of-fold base-model scores are used to train the second-layer model.

| Option | Choices | Meaning |
| --- | --- | --- |
| `--task` | `BRCA`, `COREAD`, `ESCA`, `LIHC`, `NSCLC`, `PACA`, `STAD`, `all` | Compare each selected cancer type with healthy controls |
| `--model` | `fame`, `fame-gw`, `both` | Choose the model or run both |
| `--evaluation` | `test`, `cv`, `both` | Independent validation, nested cross-validation, or both |
| `--jobs` | Positive integer | Limit the requested parallel workers |
| `--folds` | Integer, default `10` | Number of folds; changing it changes the reference evaluation design |
| `--seed` | Integer, default `42` | Random seed |

To include nested cross-validation, replace `--evaluation test` with `--evaluation both`. To run all supported cancer types, replace `--task BRCA` with `--task all`. Full nested cross-validation is substantially more expensive than the ROC example; try a single task first.

The single-task command above creates:

| Output | Contents |
| --- | --- |
| `predictions.tsv` | Sample identifiers, labels, and model scores |
| `metrics.tsv` | AUC, average precision, and maximum sensitivity at specificity ≥95% on the evaluation ROC |
| `roc_coordinates.tsv` | ROC coordinates and score thresholds |
| `BRCA_ROC.png`, `BRCA_ROC.svg` | ROC figures |
| `base_fold_metrics.tsv` | First-layer fold metrics |
| `config.json`, `run_summary.json` | Configuration, package versions, and completion summary |
| `fame.joblib`, `fame-gw.joblib` | Fitted models when independent validation is requested |

Cross-validation also creates `fold_metrics.tsv`. With `--task all`, fitted models and individual task outputs are placed in cancer-specific subdirectories, and combined prediction and metric tables are saved in the main output directory. Use a new or empty output directory for each run.

## 5. Score matching new features

```bash
python -m fame predict \
  --model results/BRCA/fame.joblib \
  --features input.npz \
  --out results/new_samples/BRCA_predictions.tsv
```

`input.npz` has a different layout from the training-data files: it contains sample IDs, one matrix per required modality, and the exact feature IDs used by the fitted model. See [New samples](docs/NEW_SAMPLES.md) for the schema and a runnable file-format example. The interface requires features prepared in the same way and order as the training data; it does not make arbitrary external datasets interchangeable.

Use `python -m fame --help` and `python -m fame run --help` for command details.

## Validation and interpretation

- Each task is a separate cancer-versus-healthy comparison. These outputs are not a multiclass diagnosis or a single pooled pan-cancer model.
- By default, cross-validation uses 10 outer folds and 10 inner folds. Inner out-of-fold scores train the second-layer model; the outer test fold remains held out.
- Independent validation uses the fixed 894/383 cohort split; only the relevant cancer cases and healthy controls enter each task.
- ROC AUC computed from pooled cross-validation predictions can differ from the mean of the individual fold AUCs. Compare like with like.
- This release organizes the existing Python implementation. It does not claim bit-for-bit equivalence to historical MATLAB results.

See [Reproducibility](docs/REPRODUCIBILITY.md) for the evaluation design, reference-score checks, and release status, and [Release validation](docs/VALIDATION.md) for the checks completed on this version.

## Citation and license

Publication metadata, the dataset DOI, and the archived code DOI will be added when finalized. A software license must be selected by the authors before public release; this preparation version does not assign one.

The manuscript's Figure 1 can be added as the project overview image when the final figure is supplied.

Earlier MATLAB code and manuscript analysis scripts are retained in the [legacy version](https://github.com/alcindor819/Methylation_Fragmentomic/tree/legacy-matlab-2026-10-08).
