%% ========================================================================
%  Fig3_MHB_Clustering_Fragment_vs_Methylation
%
%  Goal:
%     Perform unsupervised clustering (K = 2) on MHB regions using
%     methylation features, then determine whether each cluster is
%     fragmentation-dominant or methylation-dominant based on
%     relative variability (frag_var − meth_var).
%
%  Output:
%     dominant_type : 17611 × 1 vector
%         1 = fragmentation-dominant (blue region)
%         2 = methylation-dominant (red region)
%     region_cluster_class.mat
%
% ========================================================================

clear; clc;

%% ======================== Global Parameters =============================
DATA_PATH = 'D:\wyzwork\0工作2\fig2\data\';
MHB_PATH  = 'D:\wyzwork\0工作2\fig3\MHB2\';
FEATURE_ROOT = 'E:\下载数据\3209\';

NUM_REGIONS = 17611;
METH_IDX = 1:7;
FRAG_IDX = 8:12;

addpath(DATA_PATH);

%% ========================= Load Feature Names ===========================
load(fullfile(DATA_PATH, 'feature_name.mat'));   % loads cell array "feature" (12×1)

%% ========================= Load MHB Indices =============================
load(fullfile(MHB_PATH, 'peak_bj.mat'));          % indicator of MHB regions
load(fullfile(MHB_PATH, '3209Train_info.mat'));

%% ====================== Compute Mean & Variability ======================
feature_mean = zeros(NUM_REGIONS, 12);
feature_std  = zeros(NUM_REGIONS, 12);

for i = 1:12
    load(fullfile(FEATURE_ROOT, ['3209_Train_', feature{i}, '.mat']));  % loads mrtix_me
    X = mrtix_me(peak_bj == 1, 1:352);      % extract valid MHB rows

    X(X == -1) = NaN;                       % treat -1 as invalid
    feature_mean(:, i) = mean(X, 2, 'omitnan');
    feature_std(:, i)  = std(X, 0, 2, 'omitnan');
end

%% ======================= Select Valid Regions ===========================
valid_rows = sum(~isnan(feature_mean(:, METH_IDX)), 2) >= 5;
X = feature_mean(valid_rows, METH_IDX);

%% ============================= K-Means ==================================
rng(0);
labels = kmeans(X, 2, 'Replicates', 10);

%% ====================== Determine Cluster Semantics ======================
% Relative variability: frag_var − meth_var
meth_var = std(feature_mean(valid_rows, METH_IDX), 0, 2, 'omitnan') ./ ...
           mean(feature_mean(valid_rows, METH_IDX), 2, 'omitnan');

frag_var = std(feature_mean(valid_rows, FRAG_IDX), 0, 2, 'omitnan') ./ ...
           mean(feature_mean(valid_rows, FRAG_IDX), 2, 'omitnan');

delta = frag_var - meth_var;
delta(isnan(delta)) = 0;

% Mean delta per cluster → which cluster is fragmentation-dominant?
d1 = mean(delta(labels == 1));
d2 = mean(delta(labels == 2));

if d1 > d2
    frag_cluster = 1;
    meth_cluster = 2;
else
    frag_cluster = 2;
    meth_cluster = 1;
end

%% ========================== Assign Final Labels ==========================
final_label = nan(NUM_REGIONS, 1);
final_label(valid_rows) = labels;

dominant_type = nan(NUM_REGIONS, 1);
dominant_type(final_label == frag_cluster) = 1;   % fragmentation-dominant (blue)
dominant_type(final_label == meth_cluster) = 2;   % methylation-dominant (red)

save('region_cluster_class.mat', 'dominant_type');

%% ============================== Plot ====================================
frag_std = mean(feature_std(valid_rows, FRAG_IDX), 2, 'omitnan');
meth_std = mean(feature_std(valid_rows, METH_IDX), 2, 'omitnan');

figure;
hold on;
scatter(frag_std(labels == frag_cluster), meth_std(labels == frag_cluster), ...
    5, [0, 0.4470, 0.7410], 'filled');  % blue-ish: fragmentation-dynamic

scatter(frag_std(labels == meth_cluster), meth_std(labels == meth_cluster), ...
    3, [0.8500, 0.3250, 0.0980], 'filled');  % red-ish: methylation-dynamic

xlabel('RSD(Fragmentation features)');
ylabel('RSD(Methylation features)');
legend({'Fragmentation-dominant', 'Methylation-dominant'});
title('MHB Region Clustering: Fragmentation vs Methylation Variability');
axis square;
grid on;
