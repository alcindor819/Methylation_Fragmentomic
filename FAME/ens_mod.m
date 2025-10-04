%canname = 'ESCA';
healthyname = 'healthy';
path_info_train = '/home/wyz/0Work2/ens_model/3209Train_info.mat';
path_info_test = '/home/wyz/0Work2/ens_model/3209Test_info.mat';
[~,~,r] = xlsread('/home/wyz/0Work2/ens_model/data_need.xlsx');
dp2= '/home/wyz/0Work2/ens_model/3209_data/';
[~,~,r1] = xlsread('canname.xlsx');
for kc = 1:size(r1,1)
    canname = cell2mat(r1(kc));
    %1MM,2PDR,3CHALM,4MHL,5MCR,6MBS,7ENTROPY,8WPS,9COV,10FDI,11OCF,12IFS,13PFE，14EDM,15DEL
    auc_sum = zeros(size(r,1),1);
    for kcs = 1:size(r,1)
        
        path_data_train = strcat( dp2 ,cell2mat(r(kcs,1)),  '.mat' );
        path_data_test = strcat( dp2 ,cell2mat(r(kcs,2)),  '.mat' );
        [score1,score2,train_label,test_label] = naive_train(canname,healthyname,path_data_train,path_info_train,path_data_test,path_info_test);
        path_data_train1 = path_data_train;
        path_data_test1 = path_data_test;
        [~,~,~,auc_sum(kcs)]=perfcurve(test_label,score2,'1');
        if kcs==1
            train_score = score1;
            test_score = score2;
        else
            train_score = [train_score score1];
            test_score = [test_score score2];
        end

        
    end
    save([strcat(pwd,'/'),strcat('nres_score_',canname)],'train_score','train_label','test_score','test_label','auc_sum');
end
quit
