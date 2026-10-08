# FAME 与 FAME-GW

从已提取的 cfDNA 特征开始，完成癌症与健康对照的二分类、性能评估及 ROC 绘图。

[English](README.md) · [数据格式](docs/DATA_FORMAT.md) · [新样本预测](docs/NEW_SAMPLES.md) · [复现说明](docs/REPRODUCIBILITY.md)

本项目整理已有的 Python 实现，使用 HRA003209 数据集。输入为特征矩阵，不需要原始测序数据；本版不包含 FAME-multi。

| 模型 | 输入 | 融合方式 |
| --- | --- | --- |
| FAME | PDR、MBS、WPS、EDM | 各模态线性 SVM → 第二层线性 SVM |
| FAME-GW | 上述四模态 + GWM、MFR、CAFF、EM | 各模态线性 SVM → 第二层随机森林 |

## 安装环境

下载或克隆项目，在项目根目录打开终端：

```bash
conda env create -f environment.yml
conda activate fame
```

环境文件会安装 Python、所需依赖及本项目，无需 MATLAB。安装时需要联网下载依赖。下面的命令均在项目根目录运行。

已有 Python 3.9–3.12 的用户也可以使用虚拟环境：

```bash
python -m venv .venv
# Linux / macOS：
source .venv/bin/activate
# Windows PowerShell 改用：
# .venv\Scripts\Activate.ps1
python -m pip install -e .
```

已在全新的 Python 3.12 虚拟环境中验证固定版本依赖与本项目安装成功。

## 先运行一个快速示例

```bash
python -m fame demo --outdir results/demo
```

该命令使用项目附带的正式参考预测分数，生成七张 ROC 图及 `metrics.tsv`。每张图分别展示交叉验证和独立验证，并对比两个模型。**这一步不训练模型，也不需要下载完整特征数据。**

图同时保存为 PNG 和可编辑 SVG，例如 `results/demo/BRCA_ROC.svg`。每次运行需指定新的或空的输出目录；再次尝试可用 `--outdir results/demo2`。

## 放置并检查数据

完整特征包与代码分开发放。数据 ZIP 内已有顶层 `hra003209/` 目录，将其解压到项目的 `data/` 目录。确认文件路径为 `data/hra003209/manifest.json`，然后检查：

```bash
python -m fame validate --data data/hra003209 --checksums
```

数据包含 **894 例训练样本和 383 例独立验证样本**。每个癌种任务使用其中对应的癌症样本及健康对照。

| 特征 | 每个样本的特征数 |
| --- | ---: |
| PDR / MBS / WPS | 各 115,759 |
| EDM | 5,632，即 22 条常染色体 × 256 |
| GWM | 2,897 |
| MFR | 1,846 |
| CAFF | 39 |
| EM | 256 |

数据包保存原始列顺序及样本编号。EDM 的整体布局已确认，但各列对应的染色体与末端序列映射尚未逐列核实，因此保留按原列序生成的编号，不能把这些编号当作已验证的生物学注释。

**数据发布状态：**完整数据包已整理完成，八组矩阵均通过逐值读回一致性检查。压缩 NPZ 合计约 955 MB，含说明及其他元数据的完整目录约 959 MB，目前待公开发布，尚无公开下载地址或 Zenodo DOI。已有作者提供的数据包可直接放入上述目录；快速示例不受此影响。完整格式见 [数据说明](docs/DATA_FORMAT.md)。

## 运行真实训练与独立验证

建议首次先运行一个癌种：

```bash
python -m fame run \
  --data data/hra003209 \
  --task BRCA \
  --model both \
  --evaluation test \
  --outdir results/BRCA \
  --jobs 2
```

| 参数 | 可选值 | 含义 |
| --- | --- | --- |
| `--task` | `BRCA` / `COREAD` / `ESCA` / `LIHC` / `NSCLC` / `PACA` / `STAD` / `all` | 单个癌种或全部癌种，各自与健康对照比较 |
| `--model` | `fame` / `fame-gw` / `both` | 选择 FAME、FAME-GW 或二者 |
| `--evaluation` | `test` / `cv` / `both` | 独立验证、嵌套交叉验证或二者 |
| `--jobs` | 正整数 | 请求使用的并行工作进程数 |

`test` 在固定训练队列内生成折外分数以训练第二层模型，再评估独立验证队列。`cv` 默认使用外层 10 折、内层 10 折的嵌套交叉验证，耗时明显更长。默认随机种子为 42；复现参考流程时保留默认折数及随机种子。

结果保存到 `--outdir` 指定的目录：`predictions.tsv` 为逐样本预测，`metrics.tsv` 为性能指标，`*_ROC.png/svg` 为 ROC 图，另有 ROC 坐标、折内指标、运行配置及完成摘要。独立验证运行还会保存 `fame.joblib` 和/或 `fame-gw.joblib`；运行全部癌种时，这些模型保存在各癌种子目录。每次运行需使用新的或空的输出目录。详细参数可查看：

```bash
python -m fame run --help
```

## 对格式一致的新特征打分

```bash
python -m fame predict \
  --model results/BRCA/fame.joblib \
  --features input.npz \
  --out results/new_samples/BRCA_predictions.tsv
```

新样本 `input.npz` 包含样本编号、各模态矩阵及对应特征编号，格式与训练数据包不同。具体说明及可运行示例见 [新样本预测](docs/NEW_SAMPLES.md)。输入必须沿用训练数据的特征定义、计算方式和列顺序；不能仅改列名就认为其他来源的特征可以直接通用。

## 复现时注意

- 这是多个“单癌种对健康”的二分类任务，不提供多分类诊断。
- 合并全部交叉验证预测后计算的 AUC，与各折 AUC 的平均值不同；比较结果时须使用相同统计口径。
- 本项目整理的是已有 Python 实现，不承诺与历史 MATLAB 输出逐位一致。

更完整的验证设计与版本说明见 [复现说明](docs/REPRODUCIBILITY.md)，本版本已完成的检查见 [验证记录](docs/VALIDATION.md)。

历史 MATLAB 代码及原手稿分析脚本保留在[历史版本](https://github.com/alcindor819/Methylation_Fragmentomic/tree/legacy-matlab-2026-10-08)中。
