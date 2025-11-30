function plot_bar_metric(values, labels, y_label, fig_title, save_path)
% PLOT_BAR_METRIC
%   Simple bar plot for 7 cancer tasks.
%
% Inputs:
%   values    - numeric vector, length = number of tasks
%   labels    - cell array of char, cancer names
%   y_label   - y axis label string
%   fig_title - figure title string
%   save_path - path to save the figure (e.g. *.png)

    figure('Color','w');
    bar(values);
    set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels, ...
             'XTickLabelRotation', 45, 'FontSize', 10);
    ylabel(y_label, 'FontSize', 12);
    title(fig_title, 'FontSize', 12);
    grid on;

    if nargin >= 5 && ~isempty(save_path)
        [save_dir,~,~] = fileparts(save_path);
        if ~exist(save_dir, 'dir')
            mkdir(save_dir);
        end
        saveas(gcf, save_path);
    end
end
