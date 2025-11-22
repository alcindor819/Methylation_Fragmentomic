function h = plot_auc_bar_ind(all_auc, task_names, model_names, colors)
h = figure;
hold on;

bar_handle = bar(all_auc, 'grouped');
for i = 1:length(bar_handle)
    set(bar_handle(i), 'FaceColor', colors(i,:));
end

set(gca, 'XTick', 1:length(task_names), 'XTickLabel', task_names, 'FontName', 'Arial');
legend(model_names, 'Location', 'southoutside', 'Orientation', 'horizontal');
ylabel('AUC', 'FontName', 'Arial');
ylim([0.7 1]);
title('Independent Validation AUCs');
grid on;
set(gcf, 'Color', 'w');
end
