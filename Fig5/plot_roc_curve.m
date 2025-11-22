function [h, AUCs, sens_95] = plot_roc_curve(a, r1, canname)
labels = a.test_label;
scores = [a.ens_score, a.test_score1];  % N × K+1
[num_samples, num_models] = size(scores);
model_names = [{'ENS'}, r1(:)'];

% 配色
other_colors = distinguishable_colors(num_models - 1, [1 1 1; 1 0 0]);
colors = [1 0 0; other_colors];

h = figure;
hold on;

AUCs = zeros(1, num_models);
sens_95 = nan(1, num_models);  % 新增 Sens@95%Spec

for i = 1:num_models
    [FPR, TPR, ~, AUC] = perfcurve(labels, scores(:, i), 1);
    AUCs(i) = AUC;

    specificity = 1 - FPR;
    pos = find(specificity >= 0.95, 1, 'last');
    if ~isempty(pos)
        sens_95(i) = TPR(pos);
    end

    plot(FPR, TPR, 'Color', colors(i,:), 'LineWidth', (i==1)*1.5 + (i~=1)*0.5);
end

legend_labels = cell(1, num_models);
for i = 1:num_models
    legend_labels{i} = sprintf('%s AUC: %.4f', model_names{i}, AUCs(i));
end
legend(legend_labels, 'Location', 'southeast', 'FontSize', 10, 'FontName', 'Arial');

xlabel('False Positive Rate', 'FontName', 'Arial', 'FontSize', 12);
ylabel('True Positive Rate', 'FontName', 'Arial', 'FontSize', 12);
title(['ROC Curve - ', canname], 'FontName', 'Arial', 'FontSize', 14);
grid on;
xlim([0 1]); ylim([0 1]);
set(gcf, 'Color', 'w');
end
