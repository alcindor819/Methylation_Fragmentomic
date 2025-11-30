function h = plot_roc_curve_iv_stacking(roc_models, auc_vec, sens_vec, ...
                                        model_names, canname, save_path)
% PLOT_ROC_CURVE_IV_STACKING
%   绘制独立验证 ROC：5 条曲线，AUC 和 Sens95（无置信区间）。
%
%   修复：不让虚线进入图例。

    K = numel(roc_models);
    if numel(model_names) ~= K
        error('Number of model_names does not match number of ROC models.');
    end

    base_color = [1 0 0];
    if K > 1
        other_colors = distinguishable_colors(K-1, [1 1 1; base_color]);
        colors = [base_color; other_colors];
    else
        colors = base_color;
    end

    h = figure('Color','w');
    hold on;

    % ============================
    % 记录模型曲线句柄 (关键修正)
    % ============================
    h_models = gobjects(K,1);

    for i = 1:K
        fpr_i = roc_models(i).fpr;
        tpr_i = roc_models(i).tpr;

        lw = (i == 1) * 1.8 + (i ~= 1) * 1.0;
        h_models(i) = plot(fpr_i, tpr_i, 'Color', colors(i,:), 'LineWidth', lw);
    end

    % legend 文本
    legend_labels = cell(1, K);
    for i = 1:K
        legend_labels{i} = sprintf('%s : AUC = %.4f; Sens95 = %.3f', ...
            model_names{i}, auc_vec(i), sens_vec(i));
    end

    % ============================
    % 只给模型曲线做 legend
    % ============================
    legend(h_models, legend_labels, 'Location', 'southoutside', ...
        'Orientation', 'vertical', ...
        'FontSize', 9, 'FontName', 'Arial');

    % 对角线（不进入 legend）
    plot([0 1], [0 1], '--', 'Color', [0.7 0.7 0.7]);

    xlabel('False Positive Rate', 'FontName', 'Arial', 'FontSize', 12);
    ylabel('True Positive Rate',  'FontName', 'Arial', 'FontSize', 12);
    title(sprintf('ROC Curve (IV) - %s vs healthy', canname), ...
        'FontName', 'Arial', 'FontSize', 14);
    grid on;
    xlim([0 1]); ylim([0 1]);

    if nargin >= 6 && ~isempty(save_path)
        [save_dir,~,~] = fileparts(save_path);
        if ~exist(save_dir, 'dir'); mkdir(save_dir); end
        saveas(h, save_path);
    end
end
