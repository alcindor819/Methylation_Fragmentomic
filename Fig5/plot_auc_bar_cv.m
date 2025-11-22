function h = plot_auc_bar_cv(all_auc_stats, task_names, model_names, colors)
[T, M, ~] = size(all_auc_stats);
mean_auc = squeeze(all_auc_stats(:,:,2));
lower_auc = squeeze(all_auc_stats(:,:,2) - all_auc_stats(:,:,1));
upper_auc = squeeze(all_auc_stats(:,:,3) - all_auc_stats(:,:,2));

h = figure;
hold on;

bar_handle = bar(mean_auc, 'grouped');
for i = 1:M
    set(bar_handle(i), 'FaceColor', colors(i,:));
end

% 添加误差棒
ngroups = size(mean_auc, 1);
nbars = size(mean_auc, 2);
groupwidth = min(0.8, nbars/(nbars+1.5));
for i = 1:nbars
    x = (1:ngroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
    errorbar(x, mean_auc(:,i), lower_auc(:,i), upper_auc(:,i), ...
        'k', 'linestyle', 'none', 'LineWidth', 1);
end

set(gca, 'XTick', 1:T, 'XTickLabel', task_names, 'FontName', 'Arial');
legend(model_names, 'Location', 'southoutside', 'Orientation', 'horizontal');
ylabel('AUC', 'FontName', 'Arial');
ylim([0.7 1]);
title('Cross-Validation AUCs');
grid on;
set(gcf, 'Color', 'w');
end
