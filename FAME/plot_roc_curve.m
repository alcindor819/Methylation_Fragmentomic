function plot_roc_curve(fpr, tpr, auc_value, fig_title, save_path)
% PLOT_ROC_CURVE
%   Plot ROC curve and display AUC in legend.

    figure('Color','w');
    plot(fpr, tpr, 'LineWidth', 2); hold on;
    plot([0 1], [0 1], '--', 'LineWidth', 1);
    xlabel('False positive rate');
    ylabel('True positive rate');
    title(fig_title, 'FontSize', 12);
    axis([0 1 0 1]);
    grid on;
    legend(sprintf('AUC = %.4f', auc_value), 'Location', 'SouthEast');

    if nargin >= 5 && ~isempty(save_path)
        [save_dir,~,~] = fileparts(save_path);
        if ~exist(save_dir, 'dir')
            mkdir(save_dir);
        end
        saveas(gcf, save_path);
    end
end
