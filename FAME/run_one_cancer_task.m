function [cv_auc_ens, cv_sens_ens, cv_auc_stats, cv_sens_stats, ...
          iv_auc_ens, iv_sens_ens, iv_auc_vec, iv_sens_vec, ...
          roc_cv_models, roc_iv_models] = run_one_cancer_task( ...
              cancer_name, bj, feature_names, data_root, data_prefix, ...
              train_info, test_info)
% RUN_ONE_CANCER_TASK
%   Run 2-layer SVM stacking for a single cancer vs healthy task.
%
% Outputs (model顺序全是 {ENS, feat1, feat2, ...}):
%   cv_auc_ens     - ENS 在 CV 的 AUC 均值
%   cv_sens_ens    - ENS 在 CV 的 Sens@95%Spec 均值
%   cv_auc_stats   - 3 x K AUC stats (所有模型)
%   cv_sens_stats  - 3 x K Sens stats (所有模型)
%   iv_auc_ens     - ENS 在 IV 的 AUC
%   iv_sens_ens    - ENS 在 IV 的 Sens@95%Spec
%   iv_auc_vec     - K x 1 IV AUC 向量
%   iv_sens_vec    - K x 1 IV Sens 向量
%   roc_cv_models  - 1 x K 结构体数组（CV ROC）
%   roc_iv_models  - 1 x K 结构体数组（IV ROC）

    cancer_name_char = char(cancer_name);

    % ---- 构造训练集标签 ----
    train_label_all = train_info(:, 3);  % cell array of class names
    is_healthy_tr   = strcmp(train_label_all, 'healthy');
    is_cancer_tr    = strcmp(train_label_all, cancer_name_char);
    keep_tr         = is_healthy_tr | is_cancer_tr;

    label_tr_cell   = train_label_all(keep_tr);
    y_train         = double(strcmp(label_tr_cell, cancer_name_char));  % 1 cancer, 0 healthy

    % ---- 构造测试集标签 ----
    test_label_all = test_info(:, 3);
    is_healthy_te  = strcmp(test_label_all, 'healthy');
    is_cancer_te   = strcmp(test_label_all, cancer_name_char);
    keep_te        = is_healthy_te | is_cancer_te;

    label_te_cell  = test_label_all(keep_te);
    y_test         = double(strcmp(label_te_cell, cancer_name_char));

    % ---- 读取所选模态的特征矩阵 ----
    num_feats = numel(bj);

    X_train_feats = cell(1, num_feats);
    X_test_feats  = cell(1, num_feats);

    for idx = 1:num_feats
        feat_idx  = bj(idx);
        feat_name = feature_names{feat_idx};
        feat_name = char(feat_name);

        % Train feature file
        train_file = fullfile(data_root, ...
            sprintf('%s_Train_%s.mat', data_prefix, feat_name));
        S_tr = load(train_file, 'mrtix_me');   % 115759 x n_train
        X_tr_full = S_tr.mrtix_me';            % n_train x 115759
        X_train_feats{idx} = X_tr_full(keep_tr, :);

        % Test feature file
        test_file = fullfile(data_root, ...
            sprintf('%s_Test_%s.mat', data_prefix, feat_name));
        S_te = load(test_file, 'mrtix_me');
        X_te_full = S_te.mrtix_me';            % n_test x 115759
        X_test_feats{idx} = X_te_full(keep_te, :);

        fprintf('Loaded feature %s for task %s (train %d x %d, test %d x %d)\n', ...
            feat_name, cancer_name_char, ...
            size(X_train_feats{idx},1), size(X_train_feats{idx},2), ...
            size(X_test_feats{idx},1),  size(X_test_feats{idx},2));
    end

    % ---- 10-fold stacking CV ----
    [cv_scores_models, cv_auc_stats, cv_sens_stats, roc_cv_models] = ...
        run_cv_stacking(X_train_feats, y_train);

    % ENS 是第一个模型
    cv_auc_ens  = cv_auc_stats(2, 1);
    cv_sens_ens = cv_sens_stats(2, 1);

    % ---- 独立验证 stacking ----
    [iv_scores_models, iv_auc_vec, iv_sens_vec, roc_iv_models] = ...
        run_iv_stacking(X_train_feats, X_test_feats, y_train, y_test);

    iv_auc_ens  = iv_auc_vec(1);
    iv_sens_ens = iv_sens_vec(1);

    fprintf('Task %s: CV AUC = %.4f (Sens95 = %.4f) | IV AUC = %.4f (Sens95 = %.4f)\n', ...
        cancer_name_char, cv_auc_ens, cv_sens_ens, iv_auc_ens, iv_sens_ens);
end
