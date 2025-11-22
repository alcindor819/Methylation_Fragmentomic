%% ================================================================
%  Fig2_MethylationToFragmentomics_Regression
%
%  Goal:
%     Evaluate how well DNA methylation features (MM, MBS, PDR, etc.)
%     can predict fragmentomic metrics (WPS, IFS, FDI, OCF, Coverage).
%
%  Method:
%     For each fragmentomic target (features 8–12):
%         - regress using LSBoost from all 12 feature candidates
%         - skip trivial self-regression
%         - compute Spearman correlation between residuals and target
%     Aggregate mean residual correlations across samples.
%
%  Output:
%     Excel file: mean_corr_vs_tree_FX.xlsx
%     Rows = #Trees, Columns = 12 input features
%
% ================================================================

clear; clc;

%% ====================== Global Parameters =======================
PARPOOL_SIZE = 24;
DATA_PATH    = '/home/wyz/0Work2/fig2/1/data/';
FEATURE_FILE = 'feature_name.mat';
OUTPUT_FILE  = 'mean_corr_vs_tree_FX.xlsx';

INPUT_IDX_ALL = 1:12;     % all features used as predictors
TARGET_IDX    = 8:12;     % fragmentomic features to be predicted

TREE_LIST = [5, 10, 50, 100, 500, 1000, 2000, 5000, 10000];

MIN_VALID_POINTS = 20;    % minimum data points required
MIN_STD = 1e-4;           % predictor must vary

parpool('local', PARPOOL_SIZE, 'IdleTimeout', 240);
addpath(DATA_PATH);

%% =================== Load Feature Names =========================
load(fullfile(DATA_PATH, FEATURE_FILE));   % loads `feature`
input_names  = feature(INPUT_IDX_ALL);
target_names = feature(TARGET_IDX); %#ok<NASGU>

%% =================== Load Feature Data ==========================
% feature_data{i}: rows = genomic bins, columns = samples
feature_data = cell(1, 12);
for i = 1:12
    load(fullfile(DATA_PATH, ['2298_', feature{i}, '.mat']));  % loads feature_all
    feature_data{i} = feature_all;
end

num_samples = size(feature_data{1}, 2);

%% ================== Result Matrix (Trees × Features) ============
mean_corr_mat = NaN(length(TREE_LIST), length(INPUT_IDX_ALL));

%% ================= Core Loop: Regression Across Trees ===========

for t = 1:length(TREE_LIST)
    tree_num = TREE_LIST(t);

    fprintf('[INFO] Tree=%d | Running residual correlation (Targets: 8–12)\n', tree_num);

    % corr_tensor(target × input × sample)
    corr_tensor = NaN(numel(TARGET_IDX), numel(INPUT_IDX_ALL), num_samples);

    %% ============= Compute Residual Correlations =============
    for ti = 1:numel(TARGET_IDX)

        tgt = TARGET_IDX(ti);
        Y_all = feature_data{tgt};

        for ii = 1:numel(INPUT_IDX_ALL)
            xi = INPUT_IDX_ALL(ii);

            % Skip self-regression
            if xi == tgt
                continue;
            end

            X_all = feature_data{xi};

            parfor s = 1:num_samples
                x = X_all(:, s);
                y = Y_all(:, s);

                valid = (x ~= -1) & (y ~= -1) & ~isnan(x) & ~isnan(y);

                if sum(valid) < MIN_VALID_POINTS || std(x(valid)) < MIN_STD
                    continue;
                end

                try
                    Mdl = fitrensemble( ...
                        x(valid), y(valid), ...
                        'Method', 'LSBoost', ...
                        'NumLearningCycles', tree_num, ...
                        'Learners', templateTree('MaxNumSplits', 10), ...
                        'LearnRate', 0.1);

                    y_pred = predict(Mdl, x(valid));
                    resid  = y(valid) - y_pred;

                    corr_tensor(ti, ii, s) = corr(resid, y(valid), 'Type', 'Spearman');

                catch
                    corr_tensor(ti, ii, s) = NaN;
                end
            end
        end
    end

    %% ========== Mean across all fragmentomic targets ==========
    for ii = 1:numel(INPUT_IDX_ALL)

        vals = corr_tensor(:, ii, :);

        % If input index is also a target (8–12), remove matched target row
        if any(TARGET_IDX == INPUT_IDX_ALL(ii))
            remove_row = find(TARGET_IDX == INPUT_IDX_ALL(ii));
            keep_rows = setdiff(1:numel(TARGET_IDX), remove_row);
            vals = corr_tensor(keep_rows, ii, :);
        end

        mean_corr_mat(t, ii) = mean(vals(:), 'omitnan');
    end
end

%% ======================= Save Output ============================
T = array2table(mean_corr_mat, 'VariableNames', input_names);
T.TreeNum = TREE_LIST(:);
T = movevars(T, 'TreeNum', 'Before', 1);

writetable(T, OUTPUT_FILE);
disp(['Results saved to ', OUTPUT_FILE]);

quit;
