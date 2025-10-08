%% ================== 红蓝区：kmeans(2类) + 美化版雷达图 & 热图（分开画） ==================
clear; clc;
addpath('D:\wyzwork\0工作2\fig2\data\');   % ← 改成你的路径

% ---- 统一风格：Arial 字体 + 矢量导出 ----
set(groot, 'defaultAxesFontName','Arial', ...
           'defaultTextFontName','Arial', ...
           'defaultAxesFontSize',10, ...
           'defaultTextInterpreter','none');

% ================== 读取特征均值/STD ==================
load('feature_name.mat');   % 变量：feature（12×1 cell）
meth_idx = 1:7;
frag_idx = 8:12;
num_regions = 17136;

feature_mean = zeros(num_regions, 12);
feature_std  = zeros(num_regions, 12);
for i = 1:12
    S = load(['inhouse_', feature{i}, '.mat']);  % 变量：feature_all (num_regions × nSamples)
    X = S.feature_all;
    X(X == -1) = NaN;
    feature_mean(:, i) = mean(X, 2, 'omitnan');
    feature_std(:,  i) = std( X, 0, 2, 'omitnan');
end

% 有效区域：至少 5 个甲基化特征非 NaN
valid_rows = sum(~isnan(feature_mean(:, meth_idx)), 2) >= 5;

% ================== kmeans(2) + 标签映射（按第1个甲基化特征的簇均值） ==================
X_meth = feature_mean(valid_rows, meth_idx);  % 区域 × 7甲基化特征
rng(0);
labels0 = kmeans(X_meth, 2, 'Replicates', 10);

f1 = X_meth(:, 1);                             % 第1甲基化特征
mu1 = mean(f1(labels0 == 1), 'omitnan');
mu2 = mean(f1(labels0 == 2), 'omitnan');
if mu1 >= mu2
    blue_cluster = 1; red_cluster = 2;
else
    blue_cluster = 2; red_cluster = 1;
end
labels_local = nan(size(labels0));
labels_local(labels0 == blue_cluster) = 1;   % 1=蓝，高
labels_local(labels0 == red_cluster)  = 2;   % 2=红，低

final_label = nan(num_regions,1);
final_label(valid_rows) = labels_local;
save('region_cluster_class_kmeans_byMeth1.mat','final_label');  % 1=蓝,2=红

% 便捷索引
isBlue = labels_local == 1;
isRed  = labels_local == 2;

%% ================== 图1：高颜值雷达图（单独画） ==================
% 均值（按列）
mu_blue = mean(X_meth(isBlue, :), 1, 'omitnan');
mu_red  = mean(X_meth(isRed,  :), 1, 'omitnan');

% 为了可比性：列向量 min-max 归一化到 [0,1]
col_min = min(X_meth, [], 1, 'omitnan');
col_max = max(X_meth, [], 1, 'omitnan');
nm_blue = (mu_blue - col_min) ./ max(col_max - col_min, eps);
nm_red  = (mu_red  - col_min) ./ max(col_max - col_min, eps);

% 可选：误差带（简单 bootstrap 95%CI）
USE_CI = true; NBOOT = 500;
if USE_CI
    [lo_b, hi_b] = bootci_nan(NBOOT, X_meth(isBlue,:));
    [lo_r, hi_r] = bootci_nan(NBOOT, X_meth(isRed ,:));
    lo_b = (lo_b - col_min) ./ max(col_max - col_min, eps);
    hi_b = (hi_b - col_min) ./ max(col_max - col_min, eps);
    lo_r = (lo_r - col_min) ./ max(col_max - col_min, eps);
    hi_r = (hi_r - col_min) ./ max(col_max - col_min, eps);
else
    lo_b = nm_blue; hi_b = nm_blue;
    lo_r = nm_red;  hi_r = nm_red;
end

f1_radar = figure('Color','w','Units','pixels','Position',[100 100 720 640], ...
                  'Renderer','painters');
draw_pretty_radar(nm_blue, nm_red, lo_b, hi_b, lo_r, hi_r, feature(meth_idx), ...
    sprintf('Red vs Blue (kmeans→2; map by meth1)   N_b=%d, N_r=%d',sum(isBlue),sum(isRed)));

% 导出
f2_hm = figure('Color','w','Units','pixels','Position',[100 100 780 680], ...
               'Renderer','painters');

exportgraphics(f1_radar, 'radar_red_blue.eps', 'ContentType','vector');
exportgraphics(f2_hm,    'heatmap_red_blue.eps', 'ContentType','vector');


%% ====== 分组热图：列 z-score，并在每组内按 PCA 第1主成分排序 ======
Xz = zscore_omitnan(X_meth);

% 为排序做个简单填补（不改变可视化数据，只是用于PCA计算的Ximp）
Ximp = fillmissing(Xz, 'constant', 0);   % 或 'movmean',1

idx_red  = find(isRed);                  % 红在上
idx_blue = find(isBlue);

% --- 红组排序 ---
if numel(idx_red) >= 2
    Xr = Ximp(idx_red, :);
    [~, scoreR] = pca(Xr, 'Centered', false);
    [~, sidxR]  = sort(scoreR(:,1), 'ascend');    % ✅ 用 sort
    ord_red     = idx_red(sidxR);
else
    ord_red = idx_red;                              % 0/1 行：不排序
end

% --- 蓝组排序 ---
if numel(idx_blue) >= 2
    Xb = Ximp(idx_blue, :);
    [~, scoreB] = pca(Xb, 'Centered', false);
    [~, sidxB]  = sort(scoreB(:,1), 'ascend');     % ✅ 用 sort
    ord_blue    = idx_blue(sidxB);
else
    ord_blue = idx_blue;
end

order = [ord_red; ord_blue];
Xplot = Xz(order, :);

% 画图
f2_hm = figure('Color','w','Units','pixels','Position',[100 100 780 680], ...
               'Renderer','painters');
axes('Position',[0.12 0.12 0.68 0.78]);
imagesc(Xplot, [-3 3]); axis tight; box on;
colormap(make_diverging_cmap(256));
cb = colorbar('Location','eastoutside'); ylabel(cb,'z-score');
set(gca, 'YTick', [], 'XTick', 1:numel(meth_idx), ...
         'XTickLabel', feature(meth_idx), 'XTickLabelRotation', 30, ...
         'TickLength',[0 0]);

yl = numel(ord_red);
line([0.5, numel(meth_idx)+0.5], [yl+0.5, yl+0.5], 'Color',[0 0 0], 'LineWidth',1);

% 顶部组标签条
axes('Position',[0.12 0.915 0.68 0.03]); hold on; axis([0 1 0 1]); axis off;
nTot = size(Xplot,1); rb = yl / nTot;
patch([0 rb rb 0],[0 0 1 1],[213 94 0]/255,'EdgeColor','none');     % 红
patch([rb 1 1 rb],[0 0 1 1],[0 114 178]/255,'EdgeColor','none');   % 蓝
text(rb/2, 0.5, sprintf('Red (n=%d)', yl), 'HorizontalAlignment','center','VerticalAlignment','middle','Color','w','FontWeight','bold');
text((1+rb)/2,0.5, sprintf('Blue (n=%d)', nTot-yl), 'HorizontalAlignment','center','VerticalAlignment','middle','Color','w','FontWeight','bold');

annotation(f2_hm,'textbox',[0.12 0.93 0.68 0.05], 'String', ...
   'Red vs Blue heatmap (kmeans→2; map by meth1) | columns=z-score', ...
   'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold','FontName','Arial');

% 2020a导出SVG（可编辑）
%print(f2_hm, 'heatmap_red_blue', '-dsvg', '-painters');

%% ================== 辅助函数 ==================
function [lo, hi] = bootci_nan(nboot, X)
% 对每列做 bootstrap CI（忽略 NaN），返回 2.5% 和 97.5% 分位
    [n, p] = size(X);
    lo = nan(1,p); hi = nan(1,p);
    for j = 1:p
        xj = X(:,j); xj = xj(~isnan(xj));
        if numel(xj) < 3
            lo(j) = nanmean(xj); hi(j) = nanmean(xj);
            continue;
        end
        idx = randi(numel(xj), numel(xj), nboot);
        boots = mean(xj(idx), 1);
        lo(j) = quantile(boots, 0.025);
        hi(j) = quantile(boots, 0.975);
    end
end

function Z = zscore_omitnan(X)
% 每列 z-score，忽略 NaN
    Z = X;
    mu = mean(X, 1, 'omitnan');
    sd = std(X, 0, 1, 'omitnan');
    for j = 1:size(X,2)
        Z(:,j) = (X(:,j) - mu(j)) ./ max(sd(j), eps);
    end
end
function draw_pretty_radar(nm_blue, nm_red, lo_b, hi_b, lo_r, hi_r, labels, title_str)
% 期刊风雷达图（笛卡尔坐标实现，环形patch置信带，不遮网格）
% nm_* / lo_*/hi_* 均为 1×K，取值 [0,1]

    K = numel(labels);
    theta = linspace(0, 2*pi, K+1); theta(end) = theta(1);
    col_blue = [0 114 178]/255;
    col_red  = [213 94 0]/255;

    ax = axes; hold(ax,'on'); axis(ax,'equal'); axis(ax,[-1.2 1.2 -1.2 1.2]); axis off;

    % ===== 先画置信带（做成“环带”而非白色抠空）=====
    if ~any(isnan(hi_b)) && ~any(isnan(lo_b))
        [xhi, yhi] = pol2cart(theta, [hi_b hi_b(1)]);
        [xlo, ylo] = pol2cart(fliplr(theta), fliplr([lo_b lo_b(1)]));
        patch([xhi xlo], [yhi ylo], col_blue, 'FaceAlpha',0.15, 'EdgeColor','none');
    end
    if ~any(isnan(hi_r)) && ~any(isnan(lo_r))
        [xhi, yhi] = pol2cart(theta, [hi_r hi_r(1)]);
        [xlo, ylo] = pol2cart(fliplr(theta), fliplr([lo_r lo_r(1)]));
        patch([xhi xlo], [yhi ylo], col_red, 'FaceAlpha',0.15, 'EdgeColor','none');
    end

    % ===== 再画网格，这样网格线永远在最上层，不会被遮 =====
    grid_col = [0.85 0.85 0.85];
    for r = 0:0.2:1
        [gx, gy] = pol2cart(theta, r*ones(size(theta)));
        plot(gx, gy, 'Color',grid_col, 'LineWidth', 0.6);
    end
    for k = 1:K
        [ax1, ay1] = pol2cart([theta(k) theta(k)], [0 1]);
        plot(ax1, ay1, 'Color',grid_col, 'LineWidth', 0.6);
        [tx, ty] = pol2cart(theta(k), 1.10);
        text(tx, ty, labels{k}, 'HorizontalAlignment','center','FontName','Arial');
    end

    % ===== 轮廓线 + 顶点 =====
    [x1, y1] = pol2cart(theta, [nm_blue nm_blue(1)]);
    [x2, y2] = pol2cart(theta, [nm_red  nm_red(1)]);
    p1 = plot(x1, y1, '-', 'Color', col_blue, 'LineWidth', 2);
    p2 = plot(x2, y2, '-', 'Color', col_red,  'LineWidth', 2);

    [xb, yb] = pol2cart(theta(1:end-1), nm_blue);
    [xr, yr] = pol2cart(theta(1:end-1), nm_red);
    plot(xb, yb, 'o', 'MarkerSize', 4, 'MarkerFaceColor', col_blue, 'MarkerEdgeColor','w');
    plot(xr, yr, 'o', 'MarkerSize', 4, 'MarkerFaceColor', col_red,  'MarkerEdgeColor','w');

    legend([p1 p2], {'Blue','Red'}, 'Location','southoutside'); legend boxoff;
    title(title_str, 'FontWeight','bold','FontName','Arial');
end


function fill_cart(theta, rho, color, alpha)
% 在笛卡尔坐标下做极坐标区域填充
    [x,y] = pol2cart(theta, rho);
    patch('XData',x,'YData',y,'FaceColor',color,'FaceAlpha',alpha,'EdgeColor','none');
end

function cmap = make_diverging_cmap(n)
% 期刊风蓝-白-红，低饱和度
    if nargin < 1, n = 256; end
    % 两端色
    c1 = [33 113 181]/255;  % 蓝 (低值)
    c2 = [255 255 255]/255; % 白 (中值)
    c3 = [178 24 43]/255;   % 红 (高值)
    % 插值
    half = floor(n/2);
    cmap1 = interp1([1 half], [c1; c2], 1:half);
    cmap2 = interp1([1 half], [c2; c3], 1:half);
    cmap  = [cmap1; cmap2];
end

