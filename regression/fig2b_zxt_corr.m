% ========= 折线图：不同树数 vs 9个特征的均值相关 =========
clear; clc;

% 1) 读表
xlsx_path = 'D:\wyzwork\0工作2\fig2\b\mean_corr_vs_tree_inhouse.xlsx';
T = readtable(xlsx_path, 'PreserveVariableNames', true);

tree_list = T{:,1};                         % 第一列：树的数量
feat_names_tbl = T.Properties.VariableNames(2:end);
Y = table2array(T(:, 2:end));               % 数值矩阵：[#tree × 9]

% 希望的特征顺序（用于与颜色一一对应）
desiredOrder = {'MM','PDR','CHALM','MHL','MCR','MBS','ENTROPY','FDI','IFS'};
[ok, idxMap] = ismember(desiredOrder, feat_names_tbl);
if ~all(ok)
    warning('列名与期望不完全一致，将按表中顺序作图。缺失：%s', strjoin(desiredOrder(~ok), ', '));
    feat_names = feat_names_tbl;
else
    Y = Y(:, idxMap);
    feat_names = desiredOrder;
end

% 2) 颜色（甲基化7 + 片段模式2）
meth_colors = [ ...
    102,194,165;
    141,160,203;
    231,138,195;
    166,216,84;
    255,217,47;
    229,196,148;
    179,179,179] / 255;
frag_colors = [252,141,98; 227,26,28] / 255;
colors = [meth_colors; frag_colors];

% 3) 画图（横坐标等距，但显示真实树数标签）
set(groot,'defaultAxesFontName','Arial');
set(groot,'defaultTextFontName','Arial');

x = 1:numel(tree_list);                     % 等距位置
fig = figure('Color','w','Position',[100,100,1200,520]); hold on;

markers = {'o','s','^','v','d','>','<','p','h'};  % 9种不同标记，便于区分
for i = 1:size(Y,2)
    plot(x, Y(:,i), ...
        'LineWidth', 2.2, ...
        'Marker', markers{i}, ...
        'MarkerSize', 5.5, ...
        'Color', colors(i,:));
end

xlim([min(x) max(x)]);
xticks(x); xticklabels(string(tree_list));  % 只显示树数标签，位置等距
xlabel('Number of trees');                  % 横轴标题（标签等距）
ylabel('Mean residual correlation');        % 纵轴标题（你这是相关均值）
ylim([0 1]);                                % 按需调整
grid on; box off;

legend(feat_names, 'Location','eastoutside', 'FontName','Arial');
title('Mean residual correlation vs. tree count', 'FontWeight','normal');

% 4) 保存
out_svg = 'D:\wyzwork\0工作2\fig2\b\mean_corr_vs_tree_line_inhouse.svg';
print(fig, out_svg, '-dsvg', '-painters');
fprintf('✅ 已保存：%s\n', out_svg);
