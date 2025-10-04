% ========== 参数与初始化 ==========
clear; clc;
parpool('local', 8, 'IdleTimeout', 240);
addpath('/home/wyz/0Work2/fig2/1/data/');

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

% 存放均值结果：行=树数，列=输入特征
mean_corr_mat = NaN(length(tree_list), length(input_idx_all));

for t = 1:length(tree_list)
    tree_num = tree_list(t);
    corr_tensor = NaN(7, 9, num_samples); % 目标 × 输入 × 样本

    % 计算残差相关
    for ti = 1:7
        Y_all = feature_data{meth_idx(ti)};

        for ii = 1:9
            xi = input_idx_all(ii);
            if xi == meth_idx(ti)  % 排除自我预测
                continue;
            end
            X_all = feature_data{xi};

            parfor s = 1:num_samples
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
                    cval = corr(resid, y(valid), 'Type', 'Spearman');
                    corr_tensor(ti, ii, s) = cval;
                catch
                    corr_tensor(ti, ii, s) = NaN;
                end
            end
        end
    end

    % ===== 按输入特征求均值 =====
    for ii = 1:9
        if ii <= 7
            vals = corr_tensor([1:ii-1, ii+1:7], ii, :); % 排除自我
        else
            vals = corr_tensor(:, ii, :); % 片段模式保留全部
        end
        mean_corr_mat(t, ii) = mean(vals(:), 'omitnan');
    end
end

% 保存到 Excel
T = array2table(mean_corr_mat, 'VariableNames', input_names);
T.TreeNum = tree_list(:);
T = movevars(T, 'TreeNum', 'Before', 1);
writetable(T, 'mean_corr_vs_tree.xlsx');

disp('结果已保存到 mean_corr_vs_tree.xlsx');
quit;