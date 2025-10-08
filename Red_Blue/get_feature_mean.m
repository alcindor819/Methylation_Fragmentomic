function [mean_feat, valid_rows] = get_feature_mean(prefix, feature, meth_idx)
    num_regions = 17136;
    mean_feat = zeros(num_regions, 12);

    for i = 1:12
        load([prefix, '_', feature{i}, '.mat']);  % 变量名为 feature_all
        X = feature_all;
        X(X == -1) = NaN;
        mean_feat(:, i) = mean(X, 2, 'omitnan');
    end

    valid_rows = sum(~isnan(mean_feat(:, meth_idx)), 2) >= 5;
end