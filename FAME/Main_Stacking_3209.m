%% ========================================================================
%  Main_Stacking_3209.m
%
%  Purpose:
%     - Read feature and cancer names
%     - For each cancer task, run 2-layer SVM stacking:
%         * 10-fold cross validation on training set
%         * Independent validation on test set
%     - Save CV and IV metrics
%     - Plot bar charts of AUC and sensitivity at 95% specificity
%     - Plot ROC curves for each task (CV and IV)
%
%  Note:
%     - First layer: one SVM per feature
%     - Second layer: SVM on concatenated first layer scores
%
% ========================================================================

clear; clc; close all;
rng(0, 'twister');

%% ======================= Paths and basic settings =======================
% Root path for code and meta files
code_root = 'D:\wyzwork\0工作2\code\';

% Excel files
feature_list_file = fullfile(code_root, 'data_need.xlsx');   % 12 feature names, first column
cancer_list_file  = fullfile(code_root, 'canname.xlsx');     % 7 cancer names, first column

% Data path
data_root = 'E:\下载数据\3209\';

% Info files
train_info_file = fullfile(data_root, '3209Train_info.mat');
test_info_file  = fullfile(data_root, '3209Test_info.mat');

% Data prefix, e.g. 3209_Train_MM.mat
data_prefix = '3209';

% Feature indices to use (example)
bj = [2 6 8 12];   % indices in [1..12]

% Output directory for figures and results
fig_root = fullfile(code_root, 'figs_stacking_3209');
if ~exist(fig_root, 'dir')
    mkdir(fig_root);
end
roc_cv_dir = fullfile(fig_root, 'roc_cv');
roc_iv_dir = fullfile(fig_root, 'roc_iv');
if ~exist(roc_cv_dir, 'dir'); mkdir(roc_cv_dir); end
if ~exist(roc_iv_dir, 'dir'); mkdir(roc_iv_dir); end

%% ======================= Read feature and cancer names ==================
[~,~,feat_raw] = xlsread(feature_list_file);
feature_names = feat_raw(1:12, 1);    % 12 x 1 cell

[~,~,can_raw] = xlsread(cancer_list_file);
cancer_names = can_raw(1:7, 1);       % 7 x 1 cell

%% ======================= Load train and test info =======================
load(train_info_file, 'train_info');  % expects variable train_info
load(test_info_file,  'test_info');   % expects variable test_info

%% ======================= Preallocate result containers ==================
num_tasks = numel(cancer_names);

cv_auc        = zeros(num_tasks, 1);   % ENS mean AUC (CV)
cv_sens95     = zeros(num_tasks, 1);   % ENS mean Sens95 (CV)
iv_auc        = zeros(num_tasks, 1);   % ENS AUC (IV)
iv_sens95     = zeros(num_tasks, 1);   % ENS Sens95 (IV)

% ENS 的 95%CI（交叉验证），三列 [lower, mean, upper]
cv_auc_stats_ens  = nan(num_tasks, 3);
cv_sens_stats_ens = nan(num_tasks, 3);

%% ======================= Main loop over cancer tasks ====================
%% ======================= Main loop over cancer tasks ====================
for k = 1:num_tasks
    cancer_name = cancer_names{k};
    cancer_name_char = char(cancer_name);
    fprintf('==== Running task %d / %d: %s vs healthy ====\n', ...
        k, num_tasks, cancer_name_char);
    
    [cv_auc(k), cv_sens95(k), cv_auc_stats, cv_sens_stats, ...
     iv_auc(k), iv_sens95(k), iv_auc_vec, iv_sens_vec, ...
     roc_cv_models, roc_iv_models] = run_one_cancer_task( ...
        cancer_name, bj, feature_names, data_root, data_prefix, ...
        train_info, test_info);

    % ENS 的 95%CI 记录下来用于条形图
    cv_auc_stats_ens(k, :)  = cv_auc_stats(:, 1)';   % ENS 是第一个模型
    cv_sens_stats_ens(k, :) = cv_sens_stats(:, 1)';

    % 模型名字：ENS + 单模态特征名
    feat_names_sel = feature_names(bj);
    feat_names_sel = cellfun(@char, feat_names_sel, 'UniformOutput', false);
    model_names = [{'FAME'}, feat_names_sel(:)'];

    % 安全文件名
    safe_name = regexprep(cancer_name_char, '\W', '_');

    % CV ROC
    fig_path_cv = fullfile(roc_cv_dir, sprintf('ROC_CV_%s.png', safe_name));
    plot_roc_curve_cv_stacking(roc_cv_models, cv_auc_stats, cv_sens_stats, ...
        model_names, cancer_name_char, fig_path_cv);

    % IV ROC
    fig_path_iv = fullfile(roc_iv_dir, sprintf('ROC_IV_%s.png', safe_name));
    plot_roc_curve_iv_stacking(roc_iv_models, iv_auc_vec, iv_sens_vec, ...
        model_names, cancer_name_char, fig_path_iv);
end
close all;

%% ======================= Save numeric results ===========================
results_file = fullfile(code_root, 'StackingResults_3209.mat');
save(results_file, ...
    'cancer_names', 'bj', ...
    'cv_auc_stats', 'cv_sens_stats', ...
    'iv_auc_vec', 'iv_sens_vec', ...
    'roc_cv_models', 'roc_iv_models');
fprintf('Results saved to %s\n', results_file);

% %% ======================= Plot bar charts ================================
% cancer_labels = cellfun(@char, cancer_names, 'UniformOutput', false);
% 
% % CV AUC + 95%CI
% plot_bar_metric_cv(cv_auc_stats_ens, cancer_labels, ...
%     'AUC', 'Cross validation AUC (ENS)', ...
%     fullfile(fig_root, 'Bar_CV_AUC_ENS_7cancers.png'));
% 
% % CV Sens95 + 95%CI
% plot_bar_metric_cv(cv_sens_stats_ens, cancer_labels, ...
%     'Sensitivity at 95% specificity', 'Cross validation Sensitivity (ENS, 95% specificity)', ...
%     fullfile(fig_root, 'Bar_CV_Sens95_ENS_7cancers.png'));
% 
% % IV AUC（无误差棒）
% plot_bar_metric(iv_auc, cancer_labels, ...
%     'AUC', 'Independent validation AUC (ENS)', ...
%     fullfile(fig_root, 'Bar_IV_AUC_ENS_7cancers.png'));
% 
% % IV Sens95（无误差棒）
% plot_bar_metric(iv_sens95, cancer_labels, ...
%     'Sensitivity at 95% specificity', 'Independent validation Sensitivity (ENS, 95% specificity)', ...
%     fullfile(fig_root, 'Bar_IV_Sens95_ENS_7cancers.png'));


% %% ======================= Plot ROC curves for each task ==================
% for k = 1:num_tasks
%     cancer_name = cancer_labels{k};
%     safe_name = regexprep(cancer_name, '\W', '_');
%     
%     % CV ROC
%     fig_path_cv = fullfile(roc_cv_dir, sprintf('ROC_CV_%s.png', safe_name));
%     plot_roc_curve(roc_cv{k}.fpr, roc_cv{k}.tpr, roc_cv{k}.auc, ...
%         sprintf('Cross validation ROC: %s vs healthy', cancer_name), ...
%         fig_path_cv);
%     
%     % IV ROC
%     fig_path_iv = fullfile(roc_iv_dir, sprintf('ROC_IV_%s.png', safe_name));
%     plot_roc_curve(roc_iv{k}.fpr, roc_iv{k}.tpr, roc_iv{k}.auc, ...
%         sprintf('Independent validation ROC: %s vs healthy', cancer_name), ...
%         fig_path_iv);
% end
% 
% fprintf('All plots generated in %s\n', fig_root);
