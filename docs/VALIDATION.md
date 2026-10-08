# Release validation: 0.1.0

Validation date: 2026-09-30. This records completed checks for this release,
separately from the historical reference results.

## Data package

- All eight modalities were aligned to the fixed 894 training and 383 independent
  validation sample IDs, with no overlap between the two cohorts.
- Numeric arrays were exported at the same `float32` precision used by the
  reference Python loader. Every array and ID vector passed exact read-back
  comparison; original column order was retained.
- The ZIP archive contains 13 public files and passed member CRC checks. Its
  SHA-256, size, and extraction instructions are in [the data directory](../data/README.md).
- The installed data reader also loaded the complete package and passed
  `python -m fame validate --checksums` on the server.

## Installation and packaging

- A new Python 3.12 virtual environment installed the project and all seven pinned
  direct dependencies successfully with `python -m pip install -e .`.
- `python -m fame demo` generated seven PNG/SVG ROC pairs and 28 metric rows.
- A wheel was built and installed; the same demo passed outside the source tree,
  confirming that the reference prediction files are included in the package.
- Python 3.9 syntax compatibility was checked. The Conda environment file selects
  Python 3.11; creation of a fresh Conda environment has not been separately tested.

## Model checks

The four automated tests passed with the pinned dependencies. They check outer
validation-fold isolation, independence from test labels, stable results across
one and two workers, model save/reload behavior, feature-width rejection, and
failure before fitting when the requested folds are not feasible.

A small numerical comparison with the frozen original Python scripts used all
eight modalities, missing values, and three-fold nested validation. FAME and
FAME-GW had maximum absolute score difference 0.0 for both cross-validation and
independent-validation predictions in that comparison.

The quick demo reuses frozen scores and does not retrain models. Full-size real
training results and their verification scope are recorded separately below.

## Real BRCA training and independent validation

Both models were fitted on the complete BRCA task: 398 training samples and 165
independent-validation samples, using seed 42 and 10 folds for training the
second layer on out-of-fold base-model scores. This check used eight workers on
the server; the reader-facing default remains two workers. The validation,
training, comparison, and saved-model checks finished in approximately 5.5 minutes.

| Model | New independent-validation AUC | Reference AUC | Maximum absolute score difference |
| --- | ---: | ---: | ---: |
| FAME | 0.9396551724 | 0.9396551724 | approximately 0.00262422 |
| FAME-GW | 0.9732758621 | 0.9732758621 | 0.0 |

FAME's scores are not bit-for-bit identical to the frozen reference. Their sample
ranking is identical (Spearman correlation 1.0), so the ROC curve and AUC agree;
the mean absolute score difference is approximately 0.00029816. FAME-GW scores
match exactly for all 165 samples.

A lightweight follow-up compared the four base-model test-score vectors with
both historical runs: maximum differences were below 4e-15. The FAME difference
therefore arises in the training out-of-fold-score / second-layer fitting chain,
not in the final base-model test predictions. Its exact cause has not been
established. The old implementation used threaded fitting and the new one uses
process workers; this is a possible factor, not a proven explanation.

Both saved models were reloaded through the `predict` command and applied to six
real samples. Their scores matched the new training run (maximum numerical
difference below 5e-16). An intentionally incorrect feature-column order was
rejected. The small outputs are included in
[examples/real_validation_BRCA](../examples/real_validation_BRCA/).

The seven-task reference plots are bundled, but complete retraining of all seven
tasks and full-size nested cross-validation have not been rerun for this release.
The completed checks above define the current verification scope.
