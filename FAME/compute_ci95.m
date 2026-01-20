function stats = compute_ci95(x)
% G95
%   Compute mean and 95% confidence interval for a vector x
%   stats = [lower; mean; upper]

    x = x(:);
    m  = mean(x);
    se = std(x) / sqrt(numel(x));
    ci = 1.96 * se;

    stats = [m - ci; m; m + ci];
end

