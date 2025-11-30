function [cv_scores_models, auc_stats, sens_stats, roc_models] = run_cv_stacking(X_train_feats, y_train)
% RUN_CV_STACKING
%   Two-layer SVM stacking with 10-fold cross validation on training set.
%
% Inputs:
%   X_train_feats - 1 x F cell, each cell is [n_train x d_f] matrix
%   y_train       - [n_train x 1] labels, 0 or 1
%
% Outputs:
%   cv_scores_models - 1 x (F+1) cell, each [n_train x 1] scores (CV)
%                      model order: {ENS, feat1, feat2, ...}
%   auc_stats        - 3 x (F+1) matrix, [lower; mean; upper] AUC (CV)
%   sens_stats       - 3 x (F+1) matrix, [lower; mean; upper] Sens@95%Spec
%   roc_models       - 1 x (F+1) struct array, fields: fpr,tpr,thresholds,auc

    n_train   = numel(y_train);
    num_feats = numel(X_train_feats);
    num_models = num_feats + 1;  % ENS + F single features

    cvp = cvpartition(y_train, 'KFold', 10);

    % 每个模型一列：先 ENS，再每个单模态
    cv_scores_models = cell(1, num_models);
    for m = 1:num_models
        cv_scores_models{m} = zeros(n_train, 1);
    end

    % 记录每折 AUC 和 Sens@95%Spec
    auc_per_fold  = nan(num_models, cvp.NumTestSets);
    sens_per_fold = nan(num_models, cvp.NumTestSets);

    for fold = 1:cvp.NumTestSets
        tr_idx = training(cvp, fold);
        va_idx = test(cvp, fold);

        y_tr = y_train(tr_idx);
        y_va = y_train(va_idx);

        % 第一层：单模态 SVM
        base_scores_va = zeros(sum(va_idx), num_feats);
        base_scores_tr = zeros(sum(tr_idx), num_feats);

        for f = 1:num_feats
            Xf = X_train_feats{f};
            X_tr = Xf(tr_idx, :);
            X_va = Xf(va_idx, :);

            svm1 = fitcsvm(X_tr, y_tr, ...
                'KernelFunction', 'rbf', ...
                'KernelScale', 'auto', ...
                'BoxConstraint', 10, ...
                'Standardize', true, ...
                'ClassNames', [0; 1]);

            [~, score_tr] = predict(svm1, X_tr);
            [~, score_va] = predict(svm1, X_va);

            base_scores_tr(:, f) = score_tr(:, 2);
            base_scores_va(:, f) = score_va(:, 2);

            % 单模态 f 的 CV 分数写回全局
            cv_scores_models{1+f}(va_idx) = score_va(:, 2);

            % 单模态 f 的 AUC / Sens@95
            [FPR_f, TPR_f, ~, AUC_f] = perfcurve(y_va, score_va(:,2), 1);
            auc_per_fold(1+f, fold)  = AUC_f;
            sens_per_fold(1+f, fold) = compute_sens_at_spec(FPR_f, TPR_f, 0.95);
        end

        % 第二层：ENS meta SVM
        meta_svm = fitcsvm(base_scores_tr, y_tr, ...
            'KernelFunction', 'linear', ...
            'KernelScale', 'auto', ...
            'BoxConstraint', 1, ...
            'Standardize', true, ...
            'ClassNames', [0; 1]);

        [~, score_meta_va] = predict(meta_svm, base_scores_va);
        meta_va_scores = score_meta_va(:, 2);

        % ENS 的 CV 分数写回
        cv_scores_models{1}(va_idx) = meta_va_scores;

        % ENS 的 AUC / Sens@95
        [FPR_m, TPR_m, ~, AUC_m] = perfcurve(y_va, meta_va_scores, 1);
        auc_per_fold(1, fold)  = AUC_m;
        sens_per_fold(1, fold) = compute_sens_at_spec(FPR_m, TPR_m, 0.95);
    end

    % 把每个模型的折内 AUC / Sens 统计成 95%CI
    auc_stats  = nan(3, num_models);
    sens_stats = nan(3, num_models);
    for m = 1:num_models
        valid_auc  = auc_per_fold(m,  ~isnan(auc_per_fold(m,:)));
        valid_sens = sens_per_fold(m, ~isnan(sens_per_fold(m,:)));

        if ~isempty(valid_auc)
            auc_stats(:, m) = g95(valid_auc(:));
        end
        if ~isempty(valid_sens)
            sens_stats(:, m) = g95(valid_sens(:));
        end
    end

    % 为每个模型计算整体 ROC 曲线（全体样本的 CV 打分）
    roc_models = struct('fpr', [], 'tpr', [], 'thresholds', [], 'auc', []);
    roc_models = repmat(roc_models, 1, num_models);
    for m = 1:num_models
        scores_m = cv_scores_models{m};
        [fpr, tpr, thr, auc_val] = perfcurve(y_train, scores_m, 1);
        roc_models(m).fpr        = fpr;
        roc_models(m).tpr        = tpr;
        roc_models(m).thresholds = thr;
        roc_models(m).auc        = auc_val;
    end
end
