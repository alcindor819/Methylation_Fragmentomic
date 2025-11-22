function h = plot_sens_bar_ind(all_sens, task_names, model_names, colors)
% all_sens: T × M matrix
% task_names: T × 1 cell
% model_names: 1 × M cell
% colors: M × 3 RGB

[T, M] = size(all_sens);

h = figure;
hold on;

bar_handle = bar(all_sens, 'grouped');

% 修复颜色匹配（避免 bar 个数小于 model_names 出现 legend 报错）
for i = 1:length(bar_handle)
    if i <= size(colors,1)
        set(bar_handle(i), 'FaceColor', colors(i,:));
    end
end

% 设置横轴
set(gca, 'XTick', 1:T, 'XTickLabel', task_names, 'FontName', 'Arial');
xtickangle(45);  % 标签倾斜防止重叠

% 图例只展示实际有的
legend(model_names(1:length(bar_handle)), ...
       'Location', 'southoutside', 'Orientation', 'horizontal');

ylabel('Sensitivity @ 95% Specificity', 'FontName', 'Arial');
ylim([0.5 1]);
title('Independent Validation Sensitivity (95% Specificity)', 'FontName', 'Arial');
grid on;
set(gcf, 'Color', 'w');
end
