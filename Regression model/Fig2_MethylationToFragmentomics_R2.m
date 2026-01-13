%% ================================================================
%  Fig2_MethylationToFragmentomics_R2
%
%  Goal:
%     Evaluate how well methylation features (1–7) plus other inputs
%     can predict fragmentomic features (8–12) using LSBoost models.
%
%  Method:
%     For each fragmentomic target (features 8–12):
%        - regress using LSBoost from all 12 input features
%        - skip trivial self-regression (xi == target)
%        - compute sample-wise R²
%     Aggregate mean R² across samples and tree numbers.
%
%  Output:
%     mean_r2_vs_treeFX.xlsx
%
% ================================================================

clear; clc;

%% ==================== Global Parameters =========================
PARPOOL_SIZE = 24;
DATA_PATH    = '/home/wyz/0Work2/fig2/1/data/';
FEATURE_FILE = 'feature_name.mat';
OUTPUT_FILE  = 'mean_r2_vs_treeFX.xlsx';

INPUT_IDX_ALL = 1:12;      % all 12 features as predictors
TARGET_IDX    = 8:12;      % fragmentomic features to be predicted (5 features)

TREE_LIST = [5, 10, 50, 100, 500, 1000, ...
             2000, 5000, 10000];

MIN_VALID_POINTS = 20;
MIN_STD = 1e-4;

parpool('local', PARPOOL_SIZE, 'IdleTimeout', 240);
addpath(DATA_PATH);

%% ===================== Load Feature Names =======================
load(fullfile(DATA_PATH, FEATURE_FILE));   % loads "feature"
input_names = feature(INPUT_IDX_ALL);

%% ====================== Load All Feature Data ===================
feature_data = cell(1, 12);
for i = 1:12
    load(fullfile(DATA_PATH, ['2298_', feature{i}, '.mat']));
    feature_data{i} = feature_all;   % rows = bins, cols = samples
end

num_samples = size(feature_data{1}, 2);

%% ================== Result Matrix (Trees × Inputs) ==============
mean_r2_mat = NaN(length(TREE_LIST), length(INPUT_IDX_ALL));

%% ========================= Main Loop =============================
for t = 1:length(TREE_LIST)
    tree_num = TREE_LIST(t);
    fprintf('[INFO] Trees = %d | Computing R² (Targets 8–12)\n', tree_num);

    % r2_tensor(target × input × sample)
    r2_tensor = NaN(numel(TARGET_IDX), numel(INPUT_IDX_ALL), num_samples);

    %% -------- Compute R² for Each Target/Feature Pair --------
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
                    % LSBoost regressor
                    Mdl = fitrensemble( ...
                        x(valid), y(valid), ...
                        'Method', 'LSBoost', ...
                        'NumLearningCycles', tree_num, ...
                        'Learners', templateTree('MaxNumSplits', 10), ...
                        'LearnRate', 0.1);

                    y_pred = predict(Mdl, x(valid));

                    % Compute R²
                    ss_res = sum((y(valid) - y_pred).^2);
                    ss_tot = sum((y(valid) - mean(y(valid))).^2);
                    r2_tensor(ti, ii, s) = 1 - ss_res / ss_tot;

                catch
                    r2_tensor(ti, ii, s) = NaN;
                end
            end
        end
    end

    %% -------- Compute Mean R² Across All Targets --------
    for ii = 1:numel(INPUT_IDX_ALL)

        vals = r2_tensor(:, ii, :);

        % If this input feature is also a target (8–12), remove matched row
        if any(TARGET_IDX == INPUT_IDX_ALL(ii))
            ti_excl = find(TARGET_IDX == INPUT_IDX_ALL(ii));
            keep_rows = setdiff(1:numel(TARGET_IDX), ti_excl);
            vals = r2_tensor(keep_rows, ii, :);
        end

        mean_r2_mat(t, ii) = mean(vals(:), 'omitnan');
    end
end

%% =========================== Save ===============================
T = array2table(mean_r2_mat, 'VariableNames', input_names);
T.TreeNum = TREE_LIST(:);
T = movevars(T, 'TreeNum', 'Before', 1);

writetable(T, OUTPUT_FILE);

disp(['Results saved to ', OUTPUT_FILE]);
quit;
