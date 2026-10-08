# Reproducibility

## Scope

This project packages the existing Python FAME and FAME-GW workflows for binary cancer-versus-healthy comparisons in HRA003209. It begins with precomputed features and retains the fixed training and independent-validation cohorts.

The scope does not include alignment, methylation calling, feature extraction from sequencing reads, or FAME-multi. The stored feature matrices are therefore part of the reproducibility inputs, rather than intermediate files that this repository regenerates.

## Inputs

The complete cohort contains 1,277 samples: 894 in the training cohort and 383 in the independent validation cohort. A task selects the specified cancer type and healthy controls within each cohort; a single cancer-specific model does not use all 1,277 samples.

All modalities must use the sample identifiers and original feature order recorded in the packaged data. Sample alignment must be based on identifiers, not assumed row positions. The feature schema and sample metadata are documented in [DATA_FORMAT.md](DATA_FORMAT.md).

The eight feature groups contain 357,947 features in total; individual dimensions are recorded in the data manifest. The EDM block has 5,632 columns, with an overall layout of 22 autosomes × 256 features. The exact chromosome–motif mapping has not been verified for every original column. Original column order is preserved, with positional identifiers where annotation is unverified.

Run the validator before training:

```bash
python -m fame validate --data data/hra003209 --checksums
```

Checksum verification checks file integrity against the supplied manifest. It does not establish that an unverified biological column annotation is correct.

## Models

| Model | Base models | Second-layer model |
| --- | --- | --- |
| FAME | Linear SVMs for PDR, MBS, WPS, EDM | Linear SVM |
| FAME-GW | Linear SVMs for PDR, MBS, WPS, EDM, GWM, MFR, CAFF, EM | Random forest |

A second-layer model is trained on base-model predictions generated out of fold within the available training samples. It must not be trained on base-model scores fitted to the same samples used to produce those scores.

The implementation fixes the model settings used by the packaged workflow. It does not use the independent validation cohort to choose model settings or the better-performing implementation.

## Independent validation: `--evaluation test`

1. Select the task's cancer cases and healthy controls from the fixed training cohort.
2. Generate base-model out-of-fold scores using 10-fold cross-validation within these training samples.
3. Fit the second-layer model using those out-of-fold scores and the training labels.
4. Refit each base model on all available training samples for the task.
5. Score the corresponding cancer cases and healthy controls in the independent validation cohort, then apply the fitted second-layer model.

The independent validation labels are used for evaluation, not model fitting. Training-set transformations must be applied unchanged to the held-out cohort.

## Nested cross-validation: `--evaluation cv`

With the default `--folds 10`, the training cohort is evaluated with 10 outer folds. For each outer fold:

1. Set aside the outer test fold.
2. Within the remaining outer training samples, generate base-model scores using 10 inner folds.
3. Fit the second-layer model on these inner out-of-fold scores.
4. Refit the base models using the full outer training portion.
5. Predict the held-out outer fold and save its scores.

Training-dependent preprocessing and feature selection belong within the applicable training fold. A single feature selection performed on the complete training cohort before outer cross-validation would change this evaluation design.

`--evaluation both` runs nested cross-validation and independent validation. These evaluations answer different questions and should be reported separately.

## Reference scores and ROC plots

The repository includes reference sample-level predictions in `examples/reference_predictions/predictions.tsv` for quick inspection:

```bash
python -m fame demo --outdir results/demo
```

The demo recomputes metrics and plots from saved scores. It checks that the installed plotting and metric workflow can read those files; it is not evidence that the current training implementation reproduces them.

Full numerical verification requires fitting the models on the packaged features with the same configuration and comparing new predictions with the reference scores. Comparisons should include sample identifiers, label alignment, score direction, and both cross-validation and independent-validation results.

Two common cross-validation summaries are distinct:

- **Pooled AUC:** concatenate held-out predictions from all outer folds and compute one ROC AUC.
- **Mean fold AUC:** compute an AUC within each outer fold and average the fold values.

These need not agree, especially when score scales vary across folds. A ROC drawn from pooled scores must be labeled with the pooled AUC, rather than the mean fold AUC. An SVM decision score is not automatically a calibrated probability.

The frozen reference scores give the following AUCs, rounded to four decimal places. CV values here use pooled outer-fold predictions.

| Task | FAME CV | FAME independent validation | FAME-GW CV | FAME-GW independent validation |
| --- | ---: | ---: | ---: | ---: |
| BRCA | 0.9671 | 0.9397 | 0.9682 | 0.9733 |
| COREAD | 0.9565 | 0.9758 | 0.9840 | 0.9980 |
| ESCA | 0.9351 | 0.9111 | 0.9830 | 0.9840 |
| LIHC | 0.9610 | 0.9464 | 0.9911 | 0.9986 |
| NSCLC | 0.9163 | 0.9212 | 0.9836 | 0.9833 |
| PACA | 0.9870 | 0.9805 | 0.9995 | 0.9969 |
| STAD | 0.9740 | 0.9814 | 0.9856 | 0.9982 |

These values document the reference predictions, not the outcome of a new full training run of this package.

## Runtime and environment

The environment file records the Python and package versions used for this release. A clean Python 3.12 virtual-environment installation has passed with the pinned dependencies; the Conda environment selects Python 3.11. Save the complete command and program outputs when running an analysis.

The full nested workflow can take hours. Historical runs of the existing scripts used approximately 29–53 minutes per cancer for FAME and 153–221 minutes per cancer for FAME-GW; the seven-task runs took approximately 4.3 hours and 19.9 hours, respectively, with four workers. These are historical measurements, not a runtime guarantee for this package or another computer.

For a first training run, use one task, `--evaluation test`, and a modest worker count. The full eight-modality numeric input is about 1.70 GiB after decompression. Validation loads those arrays into memory; model fitting also needs subsets and working arrays, so compressed download size is not a RAM requirement. The three 115,759-column matrices dominate the input size, and additional workers can increase peak memory use.

Historical FAME-GW logs included an SVM convergence warning. A completed run alone does not resolve a convergence warning; retain it with the run logs and check the affected fit before accepting the result.

## Relationship to earlier implementations

This repository is a reorganization of an existing Python implementation, not a newly asserted exact translation of the historical MATLAB implementation. Identical algorithm names do not imply identical defaults, solvers, preprocessing, folds, score scales, or floating-point results.

Reference-score agreement and MATLAB equivalence are separate claims. Any formal comparison should state which implementation, data package, configuration, and metric definition were compared. The project does not claim bit-for-bit MATLAB equivalence.

## Release status

This is a release-preparation version. The complete feature package has been exported, and all eight matrices passed exact read-back checks against the loaded reference inputs. Its NPZ files total 954,585,038 bytes; the complete directory including metadata is approximately 959 MB. The dataset is separate from the code and awaits public release. A public data URL and Zenodo DOI have not yet been assigned. Publication metadata, the code archive DOI, the software license, and the final Figure 1 still need to be supplied by the authors.

Known limitations should remain explicit when the repository is published, including the unverified EDM column annotations and the exact level of training-versus-reference verification completed for this version.
