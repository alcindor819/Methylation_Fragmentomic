# HRA003209 feature data

The complete FAME / FAME-GW feature package has been prepared and validated.
Public release on Zenodo is pending; no DOI or public download link has been
assigned yet. The feature archive is distributed separately from the code.

| Item | Value |
| --- | --- |
| Archive | `FAME_HRA003209_features_v0.1.0.zip` |
| Size | 958,884,439 bytes (958.9 MB; 914.5 MiB) |
| Samples | 894 training; 383 independent validation |
| Modalities | WPS, EDM, PDR, MBS, GWM, EM, CAFF, MFR |
| Archive layout | Top-level `hra003209/` directory; 13 public files |
| SHA-256 | `fd9d249b6c6da7942731a0abab2bd0db791dada0b9800dce9395e6542e0e8308` |

The ZIP stores its members without additional compression because the numeric
matrices are already compressed NPZ files. Its CRC checks have passed. Each
matrix was read back and compared exactly with the original model-loader output
at `float32` precision, including ID arrays and matrix order.

After obtaining the separately released archive, place it in the repository root
and extract it from that directory:

```bash
python -m zipfile -e FAME_HRA003209_features_v0.1.0.zip data/
```

This creates `data/hra003209/manifest.json`, `samples.tsv`, `regions.tsv`,
`validation.json`, `SHA256SUMS`, and eight NPZ files under `features/`.

The companion `.zip.sha256` records the checksum above. On systems with
`sha256sum`, verify the archive before extraction:

```bash
sha256sum -c FAME_HRA003209_features_v0.1.0.zip.sha256
```

`manifest.example.json` is a copy of the verified public manifest, provided to
document file names, dimensions, checksums, and source basenames before download.
It is not a substitute for the actual feature files. See
[`docs/DATA_FORMAT.md`](../docs/DATA_FORMAT.md) for the array contract, missing-value
policy, regional coordinate caveat, and chromosome-resolved EDM column-order
requirements.

The public archive contains no private server paths or private provenance files.
