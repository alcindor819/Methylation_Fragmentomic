%% ========================================================================
%  Fig4_EvalAndPlot_Master.m
%
%  Purpose:
%     For each cancer task:
%        - Load K-fold and Validation prediction scores
#        - Plot correction-heatmaps (optional)
%        - Plot cumulative-positive curves (optional)
%        - Plot ROC curves (CV & Val)
%        - Save AUC statistics
%        - Generate final AUC and Sensitivity barplots
%
%  This script orchestrates the evaluation & visualization pipeline for
%  Figure 4 in the HRA003209 dataset.
%
% ========================================================================

clear; clc;

%% ======================= Paths & Basic Settings =========================
task_list_path   = 'D:\wyzwork\0工作2\fig4\HRA003209\ens_model\canname.xlsx';
feature_list_path = 'D:\wyzwork\0工作2\fig4\HRA003209\ens_model\data_need.xlsx';

roc_save_root    = 'D:\wyzwork\0工作2\fig4\HRA003209\ens_model\zhexian\roc\';
k_data_root      = 'D:\wyzwork\0工作2\fig4\HRA003209\ens_model\zhexian\1\';
v_data_root      = 'D:\wyzwork\0工作2\fig4\HRA003209\ens_model\zhexian\1\';
save_fig_root    = 'D:\wyzwork\0工作2\fig4\HRA003209\ens_model\zhexian\2\';

% threshold for correction-heatmap
threshold = -0.75;

% which modalities to include in model comparison
selected_modalities = [2 8 10];

%% ========================== Load Task & Model Names ======================
[~,~,task_names] = xlsread(task_list_path);
[~,~,model_rows] = xlsread(feature_list_path);

model_names = model_rows(selected_modalities, 1); 
num_tasks   = size(task_names, 1);
num_models  = 1 + length(selected_modalities);  % ENS + selected modalities

colors = [1 0 0; distinguishable_colors(num_models - 1, [1 1 1; 1 0 0])];

%% ====================== Containers for Results ===========================
AUC_stats_cv  = cell(num_tasks, 1);
AUC_ind       = cell(num_tasks, 1);
SENS_stats_cv = cell(num_tasks, 1);
SENS_ind      = cell(num_tasks, 1);

%% ====================== Main Loop: Per Task ==============================
for i = 1:num_tasks

    cancer_name = string(task_names{i});
    fprintf('\n=============================================\n');
    fprintf('Processing Cancer Type: %s\n', cancer_name);
    fprintf('=============================================\n');

    %% ---- Load K-fold Scores ----
    k_data = load(fullfile(k_data_root, ['k3209_', cancer_name, '.mat']));
    k_data.test_score1 = k_data.test_score1(:, selected_modalities);

    kpc = ['D:\wyzwork\0工作2\fig4\HRA003209\ens_model\zhexian\kpici_', ...
            cancer_name, '.mat'];

    % ---- Correction heatmap (optional) ----
    % h_corr = plot_correction_heatmap_cv_v3(k_data, model_names, cancer_name, threshold, kpc);
    % saveas(h_corr, fullfile(save_fig_root, ['k_error_heatmap_', cancer_name, '.svg']));

    % ---- Cumulative positive curve (optional) ----
    % h_cum = plot_cumulative_positive_with_subplots_cv(k_data, model_names, cancer_name, kpc);
    % saveas(h_cum, fullfile(save_fig_root, ['k_cumpos_', cancer_name, '.svg']));

    % ---- ROC (CV) ----
    [hroc_k, auc_cv, sens_cv] = plot_roc_curve_cv(k_data, model_names, cancer_name, kpc);
    saveas(hroc_k, fullfile(roc_save_root, ['k_ROC_', cancer_name, '.svg']));
    AUC_stats_cv{i}  = auc_cv;
    SENS_stats_cv{i} = sens_cv;

    %% ---- Load Validation Scores ----
    v_data = load(fullfile(v_data_root, ['v3209_', cancer_name, '.mat']));
    v_data.test_score1 = v_data.test_score1(:, selected_modalities);

    % ---- Correction heatmap (optional) ----
    h_corr_v = plot_correction_heatmap_v3(v_data, model_names, cancer_name, threshold);
    saveas(h_corr_v, fullfile(save_fig_root, ['v_error_heatmap_', cancer_name, '.svg']));

    % ---- ROC (Validation) ----
    [hroc_v, auc_val, sens_val] = plot_roc_curve(v_data, model_names, cancer_name);
    saveas(hroc_v, fullfile(roc_save_root, ['v_ROC_', cancer_name, '.svg']));
    AUC_ind{i}  = auc_val;
    SENS_ind{i} = sens_val;

    close all;
end

%% ======================== Prepare Barplot Data ===========================

% AUC (CV): T × M × 3
all_auc_stats = cat(3, AUC_stats_cv{:});
all_auc_stats = permute(all_auc_stats, [3, 2, 1]);

% AUC (Validation): T × M
all_auc_ind = cell2mat(AUC_ind);

% Sensitivity (CV): T × M × 3
all_sens_cv = cat(3, SENS_stats_cv{:});
all_sens_cv = permute(all_sens_cv, [3, 2, 1]);

% Sensitivity (Validation): T × M
all_sens_ind = reshape(cell2mat(SENS_ind), [], num_tasks)';
 

%% ============================= Draw Barplots ==============================
plot_auc_bar_cv(all_auc_stats, task_names, [{'ENS'}; model_names], colors);
plot_auc_bar_ind(all_auc_ind, task_names, [{'ENS'}; model_names], colors);

plot_sens_bar_cv(all_sens_cv, task_names, [{'ENS'}; model_names], colors);
plot_sens_bar_ind(all_sens_ind, task_names, [{'ENS'}; model_names], colors);

close all;
fprintf('\nAll tasks completed. Figures saved.\n');
