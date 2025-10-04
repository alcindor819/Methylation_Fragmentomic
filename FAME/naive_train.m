function [score1,score2,train_label,test_label] = naive_train(canname,healthyname,path_data_train,path_info_train,path_data_test,path_info_test)

% === 读取特征数据 ===
a = load(path_data_train);
a1 = load(path_data_test);

% === 读取标签信息 ===
load(path_info_train);
load(path_info_test);

% % === 加载 MHB 区域标签 ===
% load('mhb_label.mat');  % 假设你把这个文件放在工作目录，变量名为 mhb_label

% === 构造原始特征矩阵 ===
train_data = a.mrtix_me';  % [样本数 × 区域数]
test_data = a1.mrtix_me';

% === 只保留 MHB 标签为 2（红类） 的区域 ===
% valid_idx = (mhb_label(:,2) == 2);  % true 表示保留红类区域
% train_data = train_data(:, valid_idx);
% test_data = test_data(:, valid_idx);

% === 构造标签 ===
bj1 = zeros(size(train_data,1),1);
bj2 = zeros(size(test_data,1),1);

for i = 1:size(train_data,1)
    name = cell2mat(train_info(i,3));
    if strcmp(name,healthyname)
        bj1(i) = 2;
    elseif strcmp(name,canname)
        bj1(i) = 1;
    end
end

for i = 1:size(test_data,1)
    name = cell2mat(test_info(i,3));
    if strcmp(name,healthyname)
        bj2(i) = 2;
    elseif strcmp(name,canname)
        bj2(i) = 1;
    end
end

% === 去掉非目标类 ===
train_data = train_data(bj1~=0,:);
test_data = test_data(bj2~=0,:);
bj1 = bj1(bj1~=0,:);
bj2 = bj2(bj2~=0,:);

train_label = bj1;
test_label = bj2;
train_label(train_label==2) = 0;
test_label(test_label==2) = 0;

% === 训练 SVM 并预测 ===
nb_svm = fitcsvm(train_data, train_label);
[~, score] = predict(nb_svm, train_data);
score1 = score(:,2);

[~, score] = predict(nb_svm, test_data);
score2 = score(:,2);

end
