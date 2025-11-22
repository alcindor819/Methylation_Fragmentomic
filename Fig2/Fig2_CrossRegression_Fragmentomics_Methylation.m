%% ================================================================
%  Cross-Regression Between Fragmentomic and Methylation Features
%  Computes how well each feature explains others using LSBoost.
%  Output: mean residual–feature Spearman correlations vs #Trees
% ================================================================

clear; clc;

%% ======================= Global Parameters ======================
PARPOOL_SIZE = 8;                           % Number of workers
DATA_PATH    = '/home/wyz/0Work2/fig2/1/data/';
FEATURE_FILE = 'feature_name.mat';          % Contains feature{1..12}
OUTPUT_FILE  = 'mean_corr_vs_tree.xlsx';

METH_IDX = 1:7;                             % Seven methylation features
FRAG_IDX = [10, 12];                        % Selected fragmentomic features
INPUT_IDX_ALL = [METH_IDX, FRAG_IDX];       % 9 predictors total

TREE_LIST = [5, 10, 50, 100, 500, 1000,... 
             2000, 5000, 10000];            % # of trees to evaluate

MIN_VALID_POINTS = 20;                      % Minimum data points for regression
MIN_STD = 1e-4;                              % Skip near-constant predictors

parpool('local', PARPOOL_SIZE, 'IdleTimeout', 240);
addpath(DATA_PATH);

%% =================== Load Feature Names =========================
load(FEATURE_FILE);              % loads "feature" cell array
input_names  = feature(INPUT_IDX_ALL);
target_names = feature(METH_IDX);

%% =================== Load All Feature Matrices ==================
% feature_data{i}: rows = genomic regions, columns = samples
feature_data = cell(1, 12);

for i = 1:12
    load(fullfile(DATA_PATH, ['2298_', feature{i}, '.mat']));  % loads "feature_all"
    feature_data{i} = feature_all;
end

num_samples = size(feature_data{1}, 2);

%% ================== Prepare Result Matrix =======================
% Rows: number of trees
% Cols: 9 input features (7 methyl + 2 fragmentomic)
mean_corr_mat = NaN(length(TREE_LIST), length(INPUT_IDX_ALL));

%% ================================================================
%  Core Computation: Residual Correlations for Each Tree Setting
% ================================================================
for t = 1:length(TREE_LIST)
    tree_num = TREE_LIST(t);

    % corr_tensor(target_feature_idx, input_feature_idx, sample)
    corr_tensor = NaN(7, length(INPUT_IDX_ALL), num_samples);

    for ti = 1:7
        Y_all = feature_data{METH_IDX(ti)};  % methylation target

        for ii = 1:length(INPUT_IDX_ALL)

            xi = INPUT_IDX_ALL(ii);
            if xi == METH_IDX(ti)
                continue;                    % Skip self-prediction
            end

            X_all = feature_data{xi};

            parfor s = 1:num_samples
                x = X_all(:, s);
                y = Y_all(:, s);

                % Valid points (no -1 flags, no NaN)
                valid = (x ~= -1) & (y ~= -1) & ~isnan(x) & ~isnan(y);

                if sum(valid) < MIN_VALID_POINTS || std(x(valid)) < MIN_STD
                    continue;
                end

                try
                    % LSBoost regression model
                    Mdl = fitrensemble( ...
                        x(valid), y(valid), ...
                        'Method', 'LSBoost', ...
                        'NumLearningCycles', tree_num, ...
                        'Learners', templateTree('MaxNumSplits', 10), ...
                        'LearnRate', 0.1);

                    y_pred = predict(Mdl, x(valid));
                    resid  = y(valid) - y_pred;

                    % Residual-feature Spearman correlation
                    corr_tensor(ti, ii, s) = corr(resid, y(valid), 'Type', 'Spearman');

                catch
                    corr_tensor(ti, ii, s) = NaN;
                end
            end
        end
    end

    %% ======== Compute Mean Correlation for Each Input Feature ========
    for ii = 1:length(INPUT_IDX_ALL)
        if ii <= 7
            % For methylation predictors: exclude self-row
            vals = corr_tensor([1:ii-1, ii+1:7], ii, :);
        else
            % For fragmentomic predictors: keep all rows
            vals = corr_tensor(:, ii, :);
        end

        mean_corr_mat(t, ii) = mean(vals(:), 'omitnan');
    end
end

%% ======================= Save Results ===========================
T = array2table(mean_corr_mat, 'VariableNames', input_names);
T.TreeNum = TREE_LIST(:);
T = movevars(T, 'TreeNum', 'Before', 1);

writetable(T, OUTPUT_FILE);

disp(['Results saved to ', OUTPUT_FILE]);
quit;
