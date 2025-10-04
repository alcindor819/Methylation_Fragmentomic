
healthyname = 'healthy';
path_info_train = '/home/wyz/0Work2/ens_model/3209Train_info.mat';
[~,~,r] = xlsread('/home/wyz/0Work2/data_need.xlsx');
dp2= '/home/wyz/0Work2/ens_model/3209_data/';
[~,~,r1] = xlsread('/home/wyz/0Work2/canname.xlsx');
score_path = '/home/wyz/0Work2/diag/3209/score/ks/';
for kc = 1%1:size(r1,1)%这是对癌症类型的循环
    canname = cell2mat(r1(kc));
    %1MM,2PDR,3CHALM,4MHL,5MCR,6MBS,7ENTROPY,8WPS,9COV,10FDI,11OCF,12IFS,13PFE，14EDM,15DEL
    ddd = strcat('Step:can:',num2str(kc));
    disp(ddd);
    for kcs = 1:size(r,1)%这是对特征种类的循环
        pat = cell2mat(r(kcs));
        path_data_train = strcat( dp2 ,'3209_Train_',cell2mat(r(kcs,1)),  '.mat' );
        %path_data_test = strcat( dp2 ,'3209_Test_',cell2mat(r(kcs,2)),  '.mat' );
        [train_score,test_score] = k_train(canname,healthyname,path_data_train,path_info_train);
        
        save([score_path,strcat('kres_score_',canname,'_',pat)],'train_score','test_score');
        ddd = strcat('Step:feature:',num2str(kcs));
        disp(ddd);
    end
    
end
quit
%second

load('res_score_BRCA.mat');


bj = [2 5 8 10];
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
rank = find(vec(idx) == target, 1, 'first')


% nb_svm=fitcsvm(train_score1,train_label);
% [~, score] = predict(nb_svm,test_score1);
% [X,Y,~,auc]=perfcurve(test_label,score(:,2),'1');
% auc_sum(size(auc_sum,1)+1) = auc;
% target = auc_sum(end);
% vec = auc_sum(:);
% [~, idx] = sort(vec, 'descend');
% rank = find(vec(idx) == target, 1, 'first')

% [B, FitInfo] = lassoglm(train_score1, train_label, 'binomial', 'CV', 5, 'Alpha', 0.5);
% bestB = B(:, FitInfo.IndexMinDeviance);  % 14 × 1，最佳稀疏系数
% intercept = FitInfo.Intercept(FitInfo.IndexMinDeviance);
% yhat_test = test_score1 * bestB + intercept;
% yhat_prob = 1 ./ (1 + exp(-yhat_test));  % sigmoid 得到概率
% pred_label = yhat_prob > 0.5;  % 譬如以0.5为阈值
% [X, Y, T, AUC] = perfcurve(test_label, yhat_prob, 1);
% auc_sum(size(auc_sum,1)+1) = AUC;
% 
% 
% 
% 
% alphas = [1.0, 0.8, 0.5, 0.3, 0.1];  % 从 Lasso 到 Ridge
% for i = 1:length(alphas)
%     alpha = alphas(i);
%     [B, FitInfo] = lassoglm(train_score1, train_label, 'binomial', 'CV', 5, 'Alpha', alpha);
%     bestB = B(:, FitInfo.IndexMinDeviance);
%     selected_idx = find(bestB ~= 0);
%     
%     fprintf('Alpha = %.1f, Selected Features (%d total): ', alpha, length(selected_idx));
%     disp(selected_idx');
% end
% 
% 
% 
