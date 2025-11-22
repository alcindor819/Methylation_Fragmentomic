# Methylation_Fragmentomic
if you have any question please contact wangyunze@webmail.hzau.edu.cn and i will reply you
![AppVeyor](https://img.shields.io/badge/MATLAB2020a-red)


## Introduction
This repository contains the source code, and package for the paper "Cancer Diagnosis Based on Methylation and Fragmentomic Information from cfDNA Methylation Haplotype Blocks".
This code provides modules for **FAME model construction，the regression of Fragmentomic and Methylation**, as well as modules for **K-fold cross-validation, independent validation and tissue-of-origin inference for cancer classification**.



## Overview of FAME model
<p align="center">
  <img src="Fig/1.png" width="100%"/> 
</p>


## Table of Contents
 - [Environment](#Environment)
 - [Preparation work](#Preparation)
 - [Data preprocessing](#Data_preprocessing)
 - [Identifying dispersed regions](#Identifying_dispersed_regions)
 - [Diagnostic](#Diagnostic)
 - [Citation](#Citation)

<a name="Environment"></a>
## 1 Environment

First, Please install MATLAB
Then, get the code.
```
git clone --recursive https://github.com/alcindor819/FDI_code_MATLAB.git
```

<a name="Preparation"></a>
## 2 Preparation

```
cd FDI_code_MATLAB/FDI/Basic_info/
```
```
wget -c https://zenodo.org/record/3928546/files/GC.zip
```
```
wget -c https://zenodo.org/record/3928546/files/mappability.zip
```
Then, unzip them.
```
unzip GC.zip
```
```
unzip mappability.zip
```
```
cd FDI_code_MATLAB/FDI/Basic_info//Dispersed_region_identify/bed_folder/
wget -c BH01.bed
```
There is a sample bed file in /FDI/Basic_info/Dispersed_region_identify/bed_folder/ .

<a name="Data_preprocessing"></a>
## 3 Data_preprocessing
You need to convert all the bed files you want to use into mat files that can be used directly by the code.
First, cd to the Data Preprocessing folder.
```
cd FDI\Data preprocessing
```
Calling the **user_processing function.m** .
```
user_processing(bed_info_path,bed_folder,numWorkers,res_folder,name_col)
```
You need an xlsx file with all the sample information, including sample names, positive and negative labels of the samples.
You should give the position of the column with the sample name in the xlsx file.
```
bed_info_path = '\FDI\bed\Cristiano_dataset_ID.xlsx';%A sample could be this
name_col = 1;%The column stores the sample name.
```
You need a folder dedicated to the bed files.
```
bed_folder = '\FDI\bed\';%A sample could be this
```
You will need a folder dedicated to the generated mat files
```
res_folder = '\FDI\mat\';%A sample could be this
```
You can choose numWorkers according to the performance of your computer, the higher its value the more parallel resources, the faster it runs.
```
numWorkers = 2;%A sample could be this
```
After the code finishes, you'll get the mat format data for all the samples in the res_folder.

<a name="Fig2_regression"></a>


## 4 Fig2_regression

First, move to the folder containing this script.
```
cd Fig2/FragmentomicsToMethylation_R2/
```
Calling the main R² evaluation script:
```
Fig2_FragmentomicsToMethylation_R2()
```


The parameters used in this script are defined at the top of the file and can be modified by the user.
```
PARPOOL_SIZE = 8;                       % Number of workers for parallel computing
DATA_PATH    = '/home/wyz/0Work2/fig2/1/data/'; 
FEATURE_FILE = 'feature_name.mat';      % Contains 12 feature names
OUTPUT_FILE  = 'mean_r2_vs_tree.xlsx';  % Output XLSX file

METH_IDX = 1:7;                         % Methylation feature indices
FRAG_IDX = [10, 12];                    % Selected fragmentomic features
INPUT_IDX_ALL = [METH_IDX, FRAG_IDX];   % Total predictors used (9 features)

TREE_LIST = [5,10,50,100,500,1000,2000,5000,10000];   % Number of boosting trees

MIN_VALID_POINTS = 20;                  % Minimum valid bin count per sample
MIN_STD          = 1e-4;                % Exclude near-constant predictors
```
What the script does

Loads all 12 fragmentomic + methylation feature matrices (2298_featureName.mat)

For each methylation target feature (1–7):

Regress using LSBoost from the 9 candidate predictors

Skip trivial cases where the predictor and target are identical

Compute R² per sample

Aggregate R² across samples and tree numbers

Save results to Excel
After execution, the script produces:
mean_r2_vs_tree.xlsx


**Fig2_regression.**
<p align="center">
  <img src="/Fig/Fig S2_01.jpg" width="100%"/> 
</p>
