function sens = compute_sens_at_spec(fpr, tpr, target_spec)
% COMPUTE_SENS_AT_SPEC
%   Compute sensitivity at a given specificity level.
%
%   target_spec is in [0,1], e.g. 0.95 means 95 percentage specificity.

    target_fpr = 1 - target_spec;

    idx = find(fpr <= target_fpr);
    if isempty(idx)
        sens = NaN;
    else
        sens = max(tpr(idx));
    end
end
