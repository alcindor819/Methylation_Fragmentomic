% 主脚本：自动生成交叉验证 & 独立验证得分矩阵，并准备画图所需的 k3209/v3209 文件


function generate_all_scores_and_plot_ready(score_base, dp2, path_info_train, path_info_test, canname_path, feat_path, res_path, bj)

    % 路径准备
    score_base = '/home/wyz/0Work2/diag/3209/score/';
    dp2 = '/home/wyz/0Work2/ens_model/3209_data/';
    path_info_train = '/home/wyz/0Work2/ens_model/3209Train_info.mat';
    path_info_test = '/home/wyz/0Work2/ens_model/3209Test_info.mat';
    canname_path = '/home/wyz/0Work2/canname.xlsx';
    feat_path = '/home/wyz/0Work2/data_need.xlsx';

    [~,~,feat_list] = xlsread(feat_path);
    [~,~,can_list] = xlsread(canname_path);

    %% Step 1: 单模态提取交叉验证得分
    for kc = 1:size(can_list,1)
        canname = can_list{kc};
        for kcs = 1:size(feat_list,1)
            feat = feat_list{kcs,1};
            path_data_train = [dp2, '3209_Train_', feat, '.mat'];
            [train_score,test_score] = k_train(canname,'healthy',path_data_train,path_info_train);
            save([score_base,'kskres_score_',canname,'_3209_Train_',feat,'.mat'],'train_score','test_score');
        end
    end

    %% Step 2: 合并每个模态的交叉验证得分，生成 3209_k_score_
    for j = 1:size(can_list,1)
        canname = can_list{j};
        auc_sum = zeros(size(feat_list,1),1);
        for i = 1:size(feat_list,1)
            feat = feat_list{i,1};
            a = load([score_base,'kskres_score_',canname,'_3209_Train_',feat,'.mat']);
            score1 = a.train_score(:,1);
            train_label = a.train_score(:,2);
            score2 = a.test_score(:,1);
            test_label = a.test_score(:,2);
            model = fitcsvm(score1, train_label);
            [~, score] = predict(model, score2);
            [~, ~, ~, auc] = perfcurve(test_label, score(:,2), '1');
            auc_sum(i) = auc;
            if i == 1
                train_score_all = score1;
                test_score_all = score2;
            else
                train_score_all = [train_score_all score1];
                test_score_all = [test_score_all score2];
            end
        end
        save([score_base,'3209_k_score_',canname], 'train_score_all','test_score_all','train_label','test_label','auc_sum');
    end

    %% Step 3: 独立验证提取第一层得分，生成 nres_score_
    for kc = 1:size(can_list,1)
        canname = can_list{kc};
        auc_sum = zeros(size(feat_list,1),1);
        for kcs = 1:size(feat_list,1)
            feat = feat_list{kcs,1};
            path_data_train = [dp2, '3209_Train_', feat, '.mat'];
            path_data_test = [dp2, feat, '.mat'];
            [s1, s2, train_label, test_label] = naive_train(canname,'healthy',path_data_train,path_info_train,path_data_test,path_info_test);
            [~, ~, ~, auc_sum(kcs)] = perfcurve(test_label,s2,'1');
            if kcs == 1
                train_score_all = s1;
                test_score_all = s2;
            else
                train_score_all = [train_score_all s1];
                test_score_all = [test_score_all s2];
            end
        end
        save([score_base,'nres_score_',canname], 'train_score_all','train_label','test_score_all','test_label','auc_sum');
    end

    %% Step 4: 生成画图用的 v3209 和 k3209
    
    bj = 1:12;  % 使用的特征索引

    for i = 1:size(can_list,1)
        canname = can_list{i};
        % 独立验证：v3209
        a = load([score_base, 'nres_score_',canname,'.mat']);
        train_score1 = a.train_score_all(:,bj);
        test_score1 = a.test_score_all(:,bj);
        train_label = a.train_label;
        test_label = a.test_label;
        auc_sum = a.auc_sum(bj);
        model = fitcsvm(train_score1, train_label);
        [~, score] = predict(model,test_score1);
        [~, ~, ~, auc] = perfcurve(test_label, score(:,2), '1');
        auc_sum(end+1) = auc;
        [~, idx] = sort(auc_sum(:), 'descend');
        rank = find(auc_sum(idx) == auc, 1);
        ens_score = score(:,2);
        save([res_path,'v3209_',canname],'test_score1','ens_score','train_score1','test_label','train_label','rank');

        % 交叉验证：k3209
        a = load([score_base, '3209_k_score_',canname,'.mat']);
        train_score1 = a.train_score_all(:,bj);
        test_score1 = a.test_score_all(:,bj);
        train_label = a.train_label;
        test_label = a.test_label;
        auc_sum = a.auc_sum(bj);
        model = fitcsvm(train_score1, train_label);
        [~, score] = predict(model,test_score1);
        [~, ~, ~, auc] = perfcurve(test_label, score(:,2), '1');
        auc_sum(end+1) = auc;
        [~, idx] = sort(auc_sum(:), 'descend');
        rank = find(auc_sum(idx) == auc, 1);
        ens_score = score(:,2);
        save([res_path,'k3209_',canname],'test_score1','ens_score','train_score1','test_label','train_label','rank');
    end
end
