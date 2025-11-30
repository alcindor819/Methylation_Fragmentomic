function [iv_scores_models, auc_vec, sens_vec, roc_models] = run_iv_stacking( ...
    X_train_feats, X_test_feats, y_train, y_test)
% RUN_IV_STACKING
%   Two-layer SVM stacking for independent validation.
%
% Inputs:
%   X_train_feats - 1 x F cell, each [n_train x d_f]
%   X_test_feats  - 1 x F cell, each [n_test x d_f]
%   y_train       - [n_train x 1] labels (0 or 1)
%   y_test        - [n_test x 1] labels (0 or 1)
%
% Outputs:
%   iv_scores_models - 1 x (F+1) cell, each [n_test x 1] scores
%                      model order: {ENS, feat1, feat2, ...}
%   auc_vec          - (F+1) x 1 AUC vector
%   sens_vec         - (F+1) x 1 Sens@95%Spec vector
%   roc_models       - 1 x (F+1) struct array, fields: fpr,tpr,thresholds,auc

    num_feats  = numel(X_train_feats);
    num_models = num_feats + 1;

    n_test  = numel(y_test);

    base_scores_tr = zeros(numel(y_train), num_feats);
    base_scores_te = zeros(n_test,          num_feats);

    iv_scores_models = cell(1, num_models);

    % 第一层：单模态
    for f = 1:num_feats
        X_tr = X_train_feats{f};
        X_te = X_test_feats{f};

        svm1 = fitcsvm(X_tr, y_train, ...
            'KernelFunction', 'rbf', ...
            'KernelScale', 'auto', ...
            'BoxConstraint', 10, ...
            'Standardize', true, ...
            'ClassNames', [0; 1]);

        [~, score_tr] = predict(svm1, X_tr);
        [~, score_te] = predict(svm1, X_te);

        base_scores_tr(:, f) = score_tr(:, 2);
        base_scores_te(:, f) = score_te(:, 2);

        iv_scores_models{1+f} = score_te(:, 2);
    end

    % 第二层：ENS
    meta_svm = fitcsvm(base_scores_tr, y_train, ...
        'KernelFunction', 'linear', ...
        'KernelScale', 'auto', ...
        'BoxConstraint', 1, ...
        'Standardize', true, ...
        'ClassNames', [0; 1]);

    [~, score_meta_te] = predict(meta_svm, base_scores_te);
    iv_scores_models{1} = score_meta_te(:, 2);

    % AUC + Sens@95%Spec + ROC
    auc_vec    = zeros(num_models, 1);
    sens_vec   = nan(num_models, 1);
    roc_models = struct('fpr', [], 'tpr', [], 'thresholds', [], 'auc', []);
    roc_models = repmat(roc_models, 1, num_models);

    for m = 1:num_models
        scores_m = iv_scores_models{m};
        [fpr, tpr, thr, auc_val] = perfcurve(y_test, scores_m, 1);
        auc_vec(m)  = auc_val;
        sens_vec(m) = compute_sens_at_spec(fpr, tpr, 0.95);

        roc_models(m).fpr        = fpr;
        roc_models(m).tpr        = tpr;
        roc_models(m).thresholds = thr;
        roc_models(m).auc        = auc_val;
    end
end
