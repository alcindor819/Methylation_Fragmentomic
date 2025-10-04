
[~,~,r] = xlsread('/home/wyz/0Work2/data_need.xlsx');
[~,~,r1] = xlsread('/home/wyz/0Work2/canname.xlsx');
auc_sum = zeros(size(r,1),1);
for j = 1:size(r1,1)
    canname = cell2mat(r1(j));
for i = 1:size(r,1)
    name = strcat('/home/wyz/0Work2/diag/3209/score/ks/kskres_score_',canname,'_3209_Train_',cell2mat(r(i,1)),'.mat');
    a = load(name);
    score1 = a.train_score(:,1);
    train_label = a.train_score(:,2);
    score2 = a.test_score(:,1);
    test_label = a.test_score(:,2);
    nb_svm = fitcsvm(score1, train_label);
    [~, score] = predict(nb_svm,score2);
    [X, Y, ~, auc] = perfcurve(test_label, score(:,2), '1');
    auc_sum(i) = auc;
    
    
    if i==1
        train_score = score1;
        test_score = score2;
    else
        train_score = [train_score score1];
        test_score = [test_score score2];
    end
end
save(['/home/wyz/0Work2/diag/3209/score/','3209_k_score_',canname],'train_score','test_score','train_label','test_label','auc_sum');
end
quit;