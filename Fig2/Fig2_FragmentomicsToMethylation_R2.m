%% ================================================================
%  Fig2_FragmentomicsToMethylation_R2
%
%  Goal:
%     Evaluate how well fragmentomic features (WPS, FDI, IFS, etc.)
%     plus methylation features together predict methylation features.
%
%  Method:
%     For each methylation target (1–7):
%        - regress using LSBoost from 9 selected predictors (1–7,10,12)
%        - skip trivial self-regression
%        - compute R² for each sample individually
%     Aggregate mean R² across samples and tree numbers.
%
%  Output:
%     mean_r2_vs_tree.xlsx
%
% ================================================================

clear; clc;

%% ==================== Global Parameters =========================
PARPOOL_SIZE = 8;
DATA_PATH    = '/home/wyz/0Work2/fig2/1/data/';
FEATURE_FILE = 'feature_name.mat';
OUTPUT_FILE  = 'mean_r2_vs_tree.xlsx';

METH_IDX = 1:7;               % methylation features
FRAG_IDX = [10, 12];          % selected fragmentomic features
INPUT_IDX_ALL = [METH_IDX, FRAG_IDX];   % predictor set (9 features)

TREE_LIST = [5, 10, 50, 100, 500, 1000, ...
             2000, 5000, 10000];

MIN_VALID_POINTS = 20;
MIN_STD = 1e-4;

parpool('local', PARPOOL_SIZE, 'IdleTimeout', 240);
addpath(DATA_PATH);

%% ===================== Load Feature Names =======================
load(fullfile(DATA_PATH, FEATURE_FILE));  % loads "feature"
input_names  = feature(INPUT_IDX_ALL);    % 9 predictor names
target_names = feature(METH_IDX); %#ok<NASGU>

%% ====================== Load All Data ===========================
feature_data = cell(1, 12);
for i = 1:12
    load(fullfile(DATA_PATH, ['2298_', feature{i}, '.mat']));
    feature_data{i} = feature_all;  % rows = bins, cols = samples
end

num_samples = size(feature_data{1}, 2);

%% =================== Result Matrix (Trees × Inputs) =============
mean_r2_mat = NaN(length(TREE_LIST), length(INPUT_IDX_ALL));

%% ========================= Main Loop =============================
for t = 1:length(TREE_LIST)
    tree_num = TREE_LIST(t);
    fprintf('[INFO] Running R² | Trees = %d\n', tree_num);

    % r2_tensor(target × input × sample)
    r2_tensor = NaN(7, length(INPUT_IDX_ALL), num_samples);

    %% ---- Compute R² for Each Target/Feature Pair ----
    for ti = 1:7
        Y_all = feature_data{METH_IDX(ti)};  % methylation target

        for ii = 1:length(INPUT_IDX_ALL)

            xi = INPUT_IDX_ALL(ii);
            if xi == METH_IDX(ti)  % skip self-prediction
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

    %% ---- Compute Mean R² for Each Input Feature ----
    for ii = 1:length(INPUT_IDX_ALL)

        if ii <= 7
            % methylation predictor: remove self row
            vals = r2_tensor([1:ii-1, ii+1:7], ii, :);
        else
            % fragmentomic predictor: use all methylation targets
            vals = r2_tensor(:, ii, :);
        end

        mean_r2_mat(t, ii) = mean(vals(:), 'omitnan');
    end
end

%% ========================== Save Output ==========================
T = array2table(mean_r2_mat, 'VariableNames', input_names);
T.TreeNum = TREE_LIST(:);
T = movevars(T, 'TreeNum', 'Before', 1);

writetable(T, OUTPUT_FILE);

disp(['Results saved to ', OUTPUT_FILE]);
quit;
