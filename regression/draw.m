% 自动处理日志文件并绘图：fig2a 样式
clear; clc;
log_files = {'1.log', '2.log', '3.log'};

% 设置颜色（前7为甲基化，后2为片段）
colors = [
    102,194,165;
    141,160,203;
    231,138,195;
    166,216,84;
    255,217,47;
    229,196,148;
    179,179,179;
    252,141,98;
    227,26,28
] / 255;

% 样本数据容器
T = table();

% 读取所有日志行
for file = log_files
    fid = fopen(file{1}, 'r');
    block_target = '';
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if startsWith(line, '[INFO] Regression task:')
            parts = strsplit(extractAfter(line, ':'), '←');
            target = strtrim(parts{1});
            input = strtrim(parts{2});
        elseif startsWith(line, '[DONE]')
            tokens = regexp(line, 'Tree=(\d+) \| R\u00b2=([-\d.]+) \| Pearson=([-\d.]+) \| Spearman=([-\d.]+) \| MSE=([-\d.]+)', 'tokens');
            if ~isempty(tokens)
                tokens = tokens{1};
                T = [T; table({target}, {input}, str2double(tokens{1}), str2double(tokens{2}), ...
                    str2double(tokens{3}), str2double(tokens{4}), str2double(tokens{5}), 'VariableNames', ...
                    {'Target','Input','Tree','R2','Pearson','Spearman','MSE'})];
            end
        end
    end
    fclose(fid);
end

% 目标和输入顺序
targets = unique(T.Target, 'stable');
inputs = unique(T.Input, 'stable');

fig_dir = 'fig2a_from_log';
if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

for ct = ["Pearson", "Spearman"]
    for tr = unique(T.Tree)'
        fig = figure('Visible','off','Position',[200,200,1200,500]); hold on;
        mat_mean = NaN(length(targets), length(inputs));
        mat_err = NaN(length(targets), length(inputs));

        for ti = 1:length(targets)
            for ii = 1:length(inputs)
                idx = strcmp(T.Target, targets{ti}) & strcmp(T.Input, inputs{ii}) & T.Tree == tr;
                vals = T{idx, ct};
                if isempty(vals); continue; end
                mat_mean(ti,ii) = mean(vals);
                mat_err(ti,ii) = 1.96 * std(vals) / sqrt(length(vals));
            end
        end

        hb = bar(mat_mean, 'grouped');
        for k = 1:length(inputs)
            set(hb(k), 'FaceColor', colors(k,:), 'DisplayName', inputs{k});
        end

        [ngroups, nbars] = size(mat_mean);
        groupwidth = min(0.8, nbars/(nbars+1.5));
        for i = 1:nbars
            x = (1:ngroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
            errorbar(x, mat_mean(:,i), mat_err(:,i), 'k', 'linestyle', 'none', 'LineWidth', 2);
        end

        xticks(1:length(targets));
        xticklabels(targets);
        xtickangle(45);
        ylim([-0.1 1]);
        ylabel(sprintf('Residual–%s correlation', ct));
        title(sprintf('Tree=%d | %s Corr', tr, ct));
        legend('Location','northeastoutside');
        grid on;
        saveas(fig, fullfile(fig_dir, sprintf('fig2a_tree%d_%s.svg', tr, lower(ct))));
        close(fig);
    end
end
