function h = plot_sens_bar_cv(all_sens_stats, task_names, model_names, colors)
% all_sens_stats: T × M × 3 结构，T 个任务，M 个模型，第3维为 [下限 中位 上限]
% task_names: T × 1 cell
% model_names: 1 × M cell
% colors: M × 3 RGB矩阵（与 ROC 曲线一致）

[T, M, ~] = size(all_sens_stats);
mean_sens = squeeze(all_sens_stats(:,:,2));
lower_sens = squeeze(all_sens_stats(:,:,2) - all_sens_stats(:,:,1));
upper_sens = squeeze(all_sens_stats(:,:,3) - all_sens_stats(:,:,2));

h = figure;
hold on;

bar_handle = bar(mean_sens, 'grouped');
for i = 1:M
    set(bar_handle(i), 'FaceColor', colors(i,:));
end

% 添加误差棒
ngroups = T;
nbars = M;
groupwidth = min(0.8, nbars/(nbars+1.5));
for i = 1:nbars
    x = (1:ngroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
    errorbar(x, mean_sens(:,i), lower_sens(:,i), upper_sens(:,i), ...
        'k', 'linestyle', 'none', 'LineWidth', 1);
end

set(gca, 'XTick', 1:T, 'XTickLabel', task_names, 'FontName', 'Arial');
legend(model_names, 'Location', 'southoutside', 'Orientation', 'horizontal');
ylabel('Sensitivity @ 95% Specificity', 'FontName', 'Arial');
ylim([0.5 1]);
title('Cross-Validation Sensitivity (95% Specificity)');
grid on;
set(gcf, 'Color', 'w');
end
