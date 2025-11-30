function plot_bar_metric_cv(stats_3col, labels, y_label, fig_title, save_path)
% PLOT_BAR_METRIC_CV
%   条形图 + 误差棒（95%CI）
%
% Inputs:
%   stats_3col - [T x 3] 矩阵，每行 [lower, mean, upper]
%   labels     - 1 x T cell，任务名
%   y_label    - y轴标签
%   fig_title  - 标题
%   save_path  - PNG 路径

    mean_vals = stats_3col(:, 2);
    lower     = stats_3col(:, 1);
    upper     = stats_3col(:, 3);

    err_lower = mean_vals - lower;
    err_upper = upper - mean_vals;

    T = numel(mean_vals);

    figure('Color','w');
    hold on;

    bh = bar(mean_vals, 'FaceColor', [0.3 0.6 0.9]);
    set(bh, 'EdgeColor', 'none');

    % 误差棒
    x = 1:T;
    errorbar(x, mean_vals, err_lower, err_upper, ...
        'k', 'LineStyle', 'none', 'LineWidth', 1);

    set(gca, 'XTick', 1:T, 'XTickLabel', labels, ...
             'XTickLabelRotation', 45, ...
             'FontName', 'Arial', 'FontSize', 10);
    ylabel(y_label, 'FontName', 'Arial', 'FontSize', 12);
    title(fig_title, 'FontName', 'Arial', 'FontSize', 13);
    grid on;

    if nargin >= 5 && ~isempty(save_path)
        [save_dir,~,~] = fileparts(save_path);
        if ~exist(save_dir, 'dir'); mkdir(save_dir); end
        saveas(gcf, save_path);
    end
end
