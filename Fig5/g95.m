function res=g95(aucscore)

y=aucscore;
yMean = mean(y);
N=length(aucscore);
ySEM = std(y)/sqrt(N);
left=yMean  -  1.96*ySEM;
right=yMean  +  1.96*ySEM;
res = [left mean(aucscore) right];


end