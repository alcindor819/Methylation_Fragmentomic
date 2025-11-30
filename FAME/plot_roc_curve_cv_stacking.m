function h = plot_roc_curve_cv_stacking(roc_models, auc_stats, sens_stats, ...
                                        model_names, canname, save_path)
% PLOT_ROC_CURVE_CV_STACKING
%   绘制 10 折交叉验证的 ROC 曲线，5 条曲线 + AUC / Sens95 的 95%CI。
%
%   修复：不再把虚线对角线纳入 legend。

    K = numel(roc_models);
    if numel(model_names) ~= K
        error('Number of model_names does not match number of ROC models.');
    end

    % 配色：第一个红色，其余 distinguishable_colors
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
    %  关键修改：保存模型句柄
    % ============================
    h_models = gobjects(K,1);

    for i = 1:K
        fpr_i = roc_models(i).fpr;
        tpr_i = roc_models(i).tpr;

        lw = (i == 1) * 1.8 + (i ~= 1) * 1.0;
        h_models(i) = plot(fpr_i, tpr_i, 'Color', colors(i,:), 'LineWidth', lw);
    end

    % ============================
    %  图例：只绑定模型曲线句柄
    % ============================
    legend_labels = cell(1, K);
    for i = 1:K
        if any(isnan(auc_stats(:, i)))
            legend_labels{i} = sprintf('%s : AUC NA', model_names{i});
        else
            legend_labels{i} = sprintf('%s : AUC = %.4f [%.4f, %.4f]; Sens95 = %.3f [%.3f, %.3f]', ...
                model_names{i}, ...
                auc_stats(2,i), auc_stats(1,i), auc_stats(3,i), ...
                sens_stats(2,i), sens_stats(1,i), sens_stats(3,i));
        end
    end

    % legend 只接收模型句柄，不包括虚线
    legend(h_models, legend_labels, 'Location', 'southoutside', ...
        'Orientation', 'vertical', ...
        'FontSize', 9, 'FontName', 'Arial');

    % ============================
    % 画对角线（不加入 legend）
    % ============================
    plot([0 1], [0 1], '--', 'Color', [0.7 0.7 0.7]);

    xlabel('False Positive Rate', 'FontName', 'Arial', 'FontSize', 12);
    ylabel('True Positive Rate',  'FontName', 'Arial', 'FontSize', 12);
    title(sprintf('ROC Curve (CV) - %s vs healthy', canname), ...
        'FontName', 'Arial', 'FontSize', 14);
    grid on;
    xlim([0 1]); ylim([0 1]);

    if nargin >= 6 && ~isempty(save_path)
        [save_dir,~,~] = fileparts(save_path);
        if ~exist(save_dir, 'dir'); mkdir(save_dir); end
        saveas(h, save_path);
    end
end
