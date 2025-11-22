function [h, AUC_stats, sens_95_stats] = plot_roc_curve_cv(a, r1, canname, kpc)
labels = a.test_label;
scores = [a.ens_score, a.test_score1];
[num_samples, num_models] = size(scores);
model_names = [{'ENS'}, r1(:)'];

% 配色
other_colors = distinguishable_colors(num_models - 1, [1 1 1; 1 0 0]);
colors = [1 0 0; other_colors];

% 10折索引
test_pici = load(kpc);
test_pici = test_pici.test_pici;

h = figure;
hold on;

AUC_stats = nan(3, num_models);
sens_95_stats = nan(3, num_models);  % 新增：Sens@95%Spec

for i = 1:num_models
    auc_per_fold = nan(10,1);
    sens_per_fold = nan(10,1);

    for fold = 1:10
        idx = (test_pici == fold);
        if ~any(idx), continue; end
        X_fold = scores(idx, i);
        Y_fold = labels(idx);
        if sum(Y_fold==1)>0 && sum(Y_fold==0)>0
            [FPR, TPR, ~, AUC] = perfcurve(Y_fold, X_fold, 1);
            auc_per_fold(fold) = AUC;

            specificity = 1 - FPR;
            pos = find(specificity >= 0.95, 1, 'last');
            if ~isempty(pos)
                sens_per_fold(fold) = TPR(pos);
            end
        end
    end

    % 保存AUC统计
    valid_auc = auc_per_fold(~isnan(auc_per_fold));
    if ~isempty(valid_auc)
        AUC_stats(:, i) = g95(valid_auc);
    end

    % 保存Sensitivity统计
    valid_sens = sens_per_fold(~isnan(sens_per_fold));
    if ~isempty(valid_sens)
        sens_95_stats(:, i) = g95(valid_sens);
    end

    [Xall, Yall, ~, ~] = perfcurve(labels, scores(:, i), 1);
    plot(Xall, Yall, 'Color', colors(i,:), 'LineWidth', (i==1)*1.5 + (i~=1)*0.5);
end

legend_labels = cell(1, num_models);
for i = 1:num_models
    if any(isnan(AUC_stats(:,i)))
        legend_labels{i} = sprintf('%s (AUC=NA)', model_names{i});
    else
        legend_labels{i} = sprintf('%s : AUC = %.4f (95 CI %.4f - %.4f)', ...
    model_names{i}, AUC_stats(2,i), AUC_stats(1,i), AUC_stats(3,i));
    end
end
legend(legend_labels, 'Location', 'southeast', 'FontSize', 10, 'FontName', 'Arial');

xlabel('False Positive Rate', 'FontName', 'Arial', 'FontSize', 12);
ylabel('True Positive Rate', 'FontName', 'Arial', 'FontSize', 12);
title(['ROC Curve (CV) - ', canname], 'FontName', 'Arial', 'FontSize', 14);
grid on;
xlim([0 1]); ylim([0 1]);
set(gcf, 'Color', 'w');
end
