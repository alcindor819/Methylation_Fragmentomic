%证明片段模式有部分甲基化的信息，但是甲基化也有片段模式没有的信息
% ========== 初始化 ========== 
clear; clc;
parpool('local', 16);
addpath('/home/wyz/0Work2/fig2/1/data/');

fig_dir = 'fig2a_svg_output';
if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

load('feature_name.mat');  % feature{1~12}

meth_idx = 1:7;
frag_idx = [10, 12];
input_idx_all = [meth_idx, frag_idx];
input_names = feature(input_idx_all);
target_names = feature(meth_idx);

% 加载所有数据
feature_data = cell(1, 12);
for i = 1:12
    load(['2298_', feature{i}, '.mat']);
    feature_data{i} = feature_all;
end

num_samples = size(feature_data{1}, 2);
tree_list = [5, 10, 50, 100, 500, 1000, 2000, 5000, 10000];

meth_colors = [
    102,194,165;   % MM
    141,160,203;   % PDR
    231,138,195;   % CHALM
    166,216,84;    % MHL
    255,217,47;    % MCR
    229,196,148;   % MBS
    179,179,179    % ENTROPY
] / 255;
frag_colors = [
    252,141,98;    % FDI
    227,26,28      % IFS
] / 255;
colors = [meth_colors; frag_colors];

% ========== 主循环 ========== 
for ct = 1:2  % 1=Pearson, 2=Spearman
    for t = 1:length(tree_list)
        tree_num = tree_list(t);
        fprintf('[INFO] Start Tree=%d | Corr=%s\n', tree_num, ternary(ct==1, 'Pearson', 'Spearman'));

        % 残差相关系数矩阵：目标×输入×样本 = 7×9×5
        corr_tensor = NaN(7, 9, 5);

        for ti = 1:7
            Y_all = feature_data{meth_idx(ti)};

            for ii = 1:9
                xi = input_idx_all(ii);
                if xi == meth_idx(ti); continue; end
                X_all = feature_data{xi};

                for s = 1:num_samples
                    x = X_all(:, s);
                    y = Y_all(:, s);
                    valid = (x~=-1) & (y~=-1) & ~isnan(x) & ~isnan(y);
                    if sum(valid) < 20 || std(x(valid)) < 1e-4
                        continue;
                    end
                    try
                        Mdl = fitrensemble(x(valid), y(valid), ...
                            'Method', 'LSBoost', ...
                            'NumLearningCycles', tree_num, ...
                            'Learners', templateTree('MaxNumSplits', 10), ...
                            'LearnRate', 0.1);
                        y_pred = predict(Mdl, x(valid));
                        resid = y(valid) - y_pred;

                        cval = corr(resid, y(valid), ...
                            'Type', ternary(ct==1, 'Pearson', 'Spearman'));
                        corr_tensor(ti, ii, s) = cval;
                    catch
                        corr_tensor(ti, ii, s) = NaN;
                    end
                end
            end
        end

        % ========== 画 grouped bar 图 ========== 
        means = squeeze(mean(corr_tensor, 3, 'omitnan'));  % 7×9
        errs = squeeze(1.96 * std(corr_tensor, 0, 3, 'omitnan') ./ sqrt(sum(~isnan(corr_tensor), 3)));  % 7×9

        fig = figure('Visible', 'off', 'Position', [200, 200, 1200, 500]);
        hold on;

        hb = bar(means, 'grouped');  % 每组一个target，组内9个输入
        for k = 1:9
            set(hb(k), 'FaceColor', colors(k,:), 'DisplayName', input_names{k});
        end

        [ngroups, nbars] = size(means);  % ngroups=7, nbars=9
        groupwidth = min(0.8, nbars/(nbars + 1.5));

        for i = 1:nbars
            % 计算每个组里，第i个柱子的位置
            x = (1:ngroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
            errorbar(x, means(:,i), errs(:,i), ...
                'k', 'linestyle', 'none', 'LineWidth', 2, 'CapSize', 10);
        end

        xticks(1:7);
        xticklabels(target_names);
        xtickangle(45);
        ylim([-0.1, 1]);
        ylabel(sprintf('Residual–%s correlation', ternary(ct==1, 'Pearson', 'Spearman')));
        title(sprintf('Tree=%d | %s Corr', tree_num, ternary(ct==1, 'Pearson', 'Spearman')));

        legend(hb, input_names, 'Location', 'northeastoutside');
        grid on;

        % 保存图
        fname = sprintf('fig2a_tree%d_%s.svg', tree_num, lower(ternary(ct==1, 'Pearson', 'Spearman')));
        saveas(fig, fullfile(fig_dir, fname));
        close(fig);
    end
end

quit;
