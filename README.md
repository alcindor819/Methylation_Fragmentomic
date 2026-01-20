![AppVeyor](https://img.shields.io/badge/MATLAB2020a-red)
# Methylation_Fragmentomic
if you have any question please contact wangyunze@webmail.hzau.edu.cn 



## Introduction
This repository contains the source code for the paper "Decoding the coupled epigenetic-fragmentomic principles of circulating DNA for robust and interpretable cancer diagnosis".
This code provides modules for **FAME model construction，the regression of Fragmentomic and Methylation**.


## Overview of this work
<p align="center">
  <img src="/Fig/work_flow2.jpg" width="100%"/> 
</p>


## Table of Contents
 - [Environment](#Environment)
 - [Data_download](#Data)
 - [Regression model](#RM)
 - [MHB clustering](#MC)
 - [FAME](#FAME)
   
<a name="Environment"></a>
## 1 Environment

First, Please install MATLAB
Then, get the code.
```
git clone --recursive https://github.com/alcindor819/Methylation_Fragmentomic.git
```

<a name="Environment"></a>
## 2 Data_download
Download all files
```
mkdir data_download
cd data_download
wget -c https://zenodo.org/record/17697714/
```


<a name="Data"></a>

## 3 Regression model
Method: LSBoost (least-squares gradient boosting)
First, cd to the path.
```
cd Methylation_Fragmentomic/Regression model/
```
Calling the **Fig2_CrossRegression_Fragmentomics_Methylation.m** .
```
PARPOOL_SIZE = 8;                           % Number of workers
DATA_PATH    = 'data_download';
FEATURE_FILE = 'feature_name.mat';          % Contains feature{1..12}
OUTPUT_FILE  = 'mean_corr_vs_tree.xlsx';
METH_IDX = 1:7;                             % Seven methylation features
FRAG_IDX = [10, 12];                        % Selected fragmentomic features
INPUT_IDX_ALL = [METH_IDX, FRAG_IDX];       % 9 predictors total
TREE_LIST = [5, 10, 50, 100, 500, 1000,... 
             2000, 5000, 10000];            % # of trees to evaluate
MIN_VALID_POINTS = 20;                      % Minimum data points for regression
MIN_STD = 1e-4;                              % Skip near-constant predictors
```

```
Output:
File: mean_corr_vs_tree_FX.xlsx(Rows: number of boosting trees, Columns: input feature names,Values: mean residual correlations (lower values indicate stronger explanatory power))
```


<a name="RM"></a>

## 4 MHB clustering

This script classifies MHB (Methylation Haplotype Block) regions into two biologically interpretable classes based on their dominant source of variability.

First, unsupervised K-means clustering (K = 2) is performed using methylation features only, ensuring that cluster formation is driven by epigenetic patterns rather than fragmentation signals.
Next, each cluster is assigned a semantic label by comparing the relative variability of fragmentation features versus methylation features within the cluster.

Regions with higher normalized variability in fragmentomic features are labeled as fragmentation-dominant (blue regions), whereas regions dominated by methylation variability are labeled as methylation-dominant (red regions).

The resulting red–blue partition provides a compact and interpretable stratification of MHB regions into regulatory-open versus structurally constrained genomic domains.

Input features
```
Methylation features: indices 1–7
Fragmentomic features: indices 8–12
Total regions analyzed: 17,611 MHBs
```
Feature aggregation
```
For each MHB region, feature values are averaged across training samples
Invalid values (-1 or NaN) are excluded
```
Clustering
```
Method: K-means
Number of clusters: K = 2
Input: mean methylation features only
Replicates: 10 (fixed random seed for reproducibility)
```

<a name="MC"></a>


## 5 FAME
This module evaluates all cancer tasks in the HRA003209 dataset and generates the figures used in Figure 5 of the manuscript.
For each cancer type, it loads prediction scores, computes model performance, and produces ROC curves, correction heatmaps, cumulative-positive curves, and AUC/Sensitivity barplots.


1. Load Metadata and Configuration

Reads the list of 12 candidate fragmentomic/methylation-based features.

Reads the seven cancer task names.

Loads pre-processed training and test cohort information for 3209 samples.

Defines feature indices (bj) to use for first-layer SVMs.
2. First-Layer Modeling: Single-Modality SVMs

For each selected feature:

Trains a single SVM classifier in a 10-fold cross-validation setting.

Applies trained models to the independent test set.

Saves per-fold ROC information and prediction scores.

Each first-layer SVM produces one probability score per sample.

3. Second-Layer Modeling: Stacking SVM (FAME)

Concatenates the first-layer SVM scores.

Trains a second-layer SVM to obtain the FAME ensemble model.

Computes AUC and sensitivity at 95% specificity for:

Cross-validation (with 95% CI)

Independent validation

4. Visualization

Automatically generates:

ROC curves for CV and IV (one figure per cancer type)

Optional bar charts:

CV AUC with 95% CI

CV Sensitivity@95% specificity with 95% CI

IV AUC (no CI)

IV Sensitivity@95% specificity

All figures are saved under:





First, navigate to the evaluation folder.
```
cd FAME/
```

Running the main evaluation script:
```
Main_Stacking_3209
```
The parameters used in the script are listed at the beginning.
Below is a detailed explanation of each parameter and an example setting.

```
%% ======================= Paths and Basic Settings =======================
% Root directory for your code and metadata files.
% (Users should modify this path according to their local environment.)
code_root = '/path/to/your/code_directory/';

% Excel file listing all feature names (first column contains 12 features).
% Place the file "data_need.xlsx" under code_root or update the path below.
feature_list_file = fullfile(code_root, 'data_need.xlsx');

% Excel file listing all cancer task names (first column contains 7 cancers).
% Place "canname.xlsx" under code_root or update the path below.
cancer_list_file  = fullfile(code_root, 'canname.xlsx');


%% ======================= Data Input Paths ===============================
% Root directory for all dataset files.
% Users should point this to the directory that contains:
%   - 3209Train_info.mat
%   - 3209Test_info.mat
%   - Feature matrices such as 3209_Train_MM.mat, 3209_Test_MM.mat, etc.
data_root = '/path/to/your/data_directory/';

% Metadata files containing training and testing sample information.
train_info_file = fullfile(data_root, '3209Train_info.mat');
test_info_file  = fullfile(data_root, '3209Test_info.mat');


%% ======================= Data Prefix Settings ===========================
% Prefix used for constructing data filenames.
% For example, if your data files follow the format:
%   3209_Train_*.mat
%   3209_Test_*.mat
% then set:
data_prefix = '3209';


%% ======================= Feature Selection ==============================
% Indices of selected features (from the 12 available features).
% Users can modify this based on their own experiment design.
bj = [2 6 8 12];   % example selection


```

After running the script, you will see:
```
k_ROC_XXX.svg
v_ROC_XXX.svg

```





