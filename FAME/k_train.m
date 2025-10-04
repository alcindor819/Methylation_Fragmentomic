function [score1, score2] = k_train(canname, healthyname, path_data_train, path_info_train)
    rng('default');
    fold = 10;

    % === 加载训练数据和标签信息 ===
    a = load(path_data_train);
    load(path_info_train);
    train_data = a.mrtix_me';  % 每行一个样本

    % === 加载 MHB 标签，筛选红类区域（标签为2） ===
%     load('mhb_label.mat');  % 默认变量名为 mhb_label
%     valid_idx = (mhb_label(:,2) == 2);  % 只保留红类区域
%     train_data = train_data(:, valid_idx);  % 按区域筛选

    % === 构造标签 ===
    bj1 = zeros(size(train_data,1),1);
    for i = 1:size(train_data,1)
        name = cell2mat(train_info(i,3));
        if strcmp(name, healthyname)
            bj1(i) = 2;
        elseif strcmp(name, canname)
            bj1(i) = 1;
        end
    end

    % === 去掉无关样本（非目标类） ===
    train_data = train_data(bj1 ~= 0, :);
    train_info = train_info(bj1 ~= 0, :);
    bj1 = bj1(bj1 ~= 0);
    train_label = bj1;
    train_label(train_label == 2) = 0;

    % === 为交叉验证准备索引 ===
    c1 = train_info(train_label == 0, 1);
    h1 = train_info(train_label == 1, 1);
    dataname = [c1; h1];
    N = length(train_label);
    n1 = zeros(N,1);
    for ii = 1:N
        if ismember(dataname(ii), h1)
            n1(ii) = 1;
        else
            n1(ii) = 0;
        end
    end
    Indices = crossvalind('Kfold', n1, fold);

    % === 执行交叉验证 ===
    for k = 1:fold
        k_train_data = train_data(Indices ~= k,:);
        k_test_data  = train_data(Indices == k,:);
        k_train_label = train_label(Indices ~= k);
        k_test_label  = train_label(Indices == k);

        nb_svm = fitcsvm(k_train_data, k_train_label);
        [~, score] = predict(nb_svm, k_train_data);
        score1 = score(:,2);
        [~, score] = predict(nb_svm, k_test_data);
        score2 = score(:,2);

        score1(:,2) = k_train_label;
        score2(:,2) = k_test_label;
        score1(:,3) = k;
        score2(:,3) = k;

        if k == 1
            score11 = score1;
            score22 = score2;
        else
            score11 = [score11; score1];
            score22 = [score22; score2];
        end
    end

    score1 = score11;
    score2 = score22;
end
