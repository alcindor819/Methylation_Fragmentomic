function get_data_pre(r,score_pathv,score_pathk,res_path,bj)

for i = 1:size(r,1)
    
    canname = cell2mat(r(i));
    
    load([score_pathv,canname,'.mat']);
%bj = 1:15;
train_score1 = train_score(:,bj);
test_score1 = test_score(:,bj);
auc_sum = auc_sum(bj);
nb_svm = fitcsvm(train_score1, train_label, ...
                 'KernelFunction', 'rbf', ...
                 'KernelScale', 'auto', ...
                 'BoxConstraint', 10, ...
                 'Standardize', true);
[~, score] = predict(nb_svm,test_score1);
[X, Y, ~, auc] = perfcurve(test_label, score(:,2), '1');
auc_sum(size(auc_sum,1)+1) = auc;
target = auc_sum(end);
vec = auc_sum(:);
[~, idx] = sort(vec, 'descend');
rank = find(vec(idx) == target, 1, 'first');
ens_score = score(:,2);
%save(['D:\wyzwork\0工作2\HRA003209\ens_model\zhexian\1\','v3209_',canname],'ens_score','test_score1','rank','test_label');
save([res_path,'v3209_',canname],'test_score1','ens_score','train_score1','test_label','train_label','rank');
%save(['D:\wyzwork\0工作2\fig4\diag\3209\','vauc3209_',canname],'auc','rank');
end



for i = 1:size(r,1)
    
    canname = cell2mat(r(i));
    
    load([score_pathk,canname,'.mat']);

%bj = 1:14;
train_score1 = train_score(:,bj);
test_score1 = test_score(:,bj);
auc_sum = auc_sum(bj);
nb_svm = fitcsvm(train_score1, train_label, ...
                 'KernelFunction', 'rbf', ...
                 'KernelScale', 'auto', ...
                 'BoxConstraint', 10, ...
                 'Standardize', true);
[~, score] = predict(nb_svm,test_score1);
[X, Y, ~, auc] = perfcurve(test_label, score(:,2), '1');
auc_sum(size(auc_sum,1)+1) = auc;
target = auc_sum(end);
vec = auc_sum(:);
[~, idx] = sort(vec, 'descend');
rank = find(vec(idx) == target, 1, 'first');
ens_score = score(:,2);
%save(['D:\wyzwork\0工作2\fig4\diag\3209\','k3209_',canname],'test_score1','train_score1','test_label','train_label');
save([res_path,'k3209_',canname],'ens_score','test_score1','rank','test_label','train_score1','train_label');
end
end

