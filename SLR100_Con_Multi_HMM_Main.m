%声明
%“编号”是在matlab中使用的。从1开始。
%“ID”是句子或者单词本身使用的，从w0000开始。
%两者之间有相差1的关系。

clear all;
clc;
%%
addpath(genpath('D:\iCode\GitHub\libsvm\matlab'));
addpath(genpath('D:\iCode\HMM_Matlab\HMMall'));

% 读取 class_correlation变量。即，类间关系图。
load data\class_correlation_model_100_7g;   

% 读取模型库
load data\HMM_model_s3_m3_dim61_100sign_forP19

% 读取测试库
sentence_names = importdata('input\sentences_100.txt');
teatDataPath = 'dim61_CTskp_allFrame_manually_100sentences_100sign'; 

% 从文件名确定当前的维数
idx = strfind(teatDataPath,'_');
dimFinalIdx = idx(1,1)-1;
dim = str2double(teatDataPath(4:dimFinalIdx));

%读取中文意思和对应的ID号
ChinesePath = 'input\wordlist_4414.txt';
chineseIDandMean = ChineseDataread(ChinesePath);

%读取用单词ID集合表示的句子
sentences_meaning_number_Path = 'input\sentence_meaning_ID_random_100.txt';
sentences_meaning_number = ChineseDataread(sentences_meaning_number_Path);

% 读取测试词汇ID
vocabulary = importdata('input\sign_100_7g.txt');
for i=1:100
    vocabulary_new(i) = str2double(vocabulary{i,1}(2:5));
end

classNum = 100;
sample = 3;    %隔n帧采样
draw = 0;    %1:显示视频。 0：不显示视频
thre = 0;
windowSizes(1) = 30; % 滑动窗口的大小
windowSizes(2) = 40;
windowSizes(3) = 60;
fidName = ['result\HMM_result' '_NoSegModel_thre' num2str(thre) '_skip' ...
    num2str(sample) '_win' num2str(windowSizes(1)) num2str(windowSizes(2)) ...
    num2str(windowSizes(3)) '_random100_100sign_BP3D_1in_3vots_G19.txt' ];
fid = fopen(fidName,'wt');
%%
for groupID =  19:19
    groupName = ['D:\iData\Outputs\ftdcgrs_whj_output\' teatDataPath '\test_' num2str(groupID) '\'];
    groundTruthFileFolderName = ['D:\iData\Outputs\ftdcgrs_whj_output\' teatDataPath...
        '\groundTruth_' num2str(groupID) '\'];
    fprintf(fid, 'The test group: G_%s \n', num2str(groupID));
    fprintf(fid, '%s:/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s\n',...
        'sentenceID', 'correctFrame', 'totalFrame',...
        'rate_frame','correctSign', 'groundtruth', 'rate_sign', 'distance',...
        'insert', 'delete', 'substitute');
    totalFrames = 0;
    totalCorrectFrame = 0;
    totalsigns = 0;
    totalCorrectSign = 0;
    totalDistance = 0;
    totalInsert = 0;
    totalDelete = 0;
    totalSubstitute = 0;
    
    
    % 从1开始的209个句子编号， 而句子的ID都是从w0000开始
    for sentenceID = 1:length(sentence_names)    
        sign_recognized_ID = [];
        sign_recognized_ID_Final = [];
        fprintf('Processing data: Group %d--Sentence %d\n', groupID, sentenceID);
        data = importdata([groupName sentence_names{sentenceID} '.txt'], ' ', 1);
        groundTruth_ = importdata([groundTruthFileFolderName sentence_names{sentenceID} '.txt'], ' ', 1);
        [h, w] = size(data.data);  % h:帧数  w:维数
        TestData = (data.data)';
        groundTruth = groundTruth_.data;
        nframes = size(TestData, 2);
        correctFrame = 0;
        selectFrame = 0;
        currentLabel = -1;    % 因为不是每帧都有label，用这个变量分配每帧的label。
        
        
        showText_result1 = 'none';
        showText_result2 = 'none';
        showText_true = 'Truth:';
        % 正确的意思
        trueSenLen = size(sentences_meaning_number{1,1+sentenceID},2);
        totalsigns = totalsigns + trueSenLen;
        sign_groundTruth_ID = zeros(1, trueSenLen) - 1;      % 正确的Sign ID
        recognizeCount = 0;          % sign_recognized_ID   % 识别出来的的Sign ID
        for sign_i = 1:trueSenLen
            sign_groundTruth_ID(sign_i) = str2double(sentences_meaning_number{1,1+sentenceID}{1,sign_i});
            showText_true = [showText_true chineseIDandMean{1,sign_groundTruth_ID(sign_i)+1}{1,2} '/'];
        end
        
        TopNindex_ID = zeros(5,300);
        TopNscore_ID = zeros(5,300);
        TopNcount = 1;
%         score_all = [];
        score_all = cell(3,1);
        
        for w=1:3
            windowSize = windowSizes(w);
            for k=1:sample:nframes
                showText_pace = ['Sentence ID: ' sentence_names{sentenceID}(2:5) ', '...
                       num2str(k) '/' num2str(nframes) ' frames, repetition:' num2str(w)];
%                 if k>windowSize/2 && k<nframes - windowSize/2 && mod(k,sample)==0
                    t = max(k - windowSize/2,1);
                    t_= min(k + windowSize/2,nframes);

                    data_norm = TestData(:,t:t_);

                    loglik = zeros(1,classNum);
                    for d=1:classNum
                        loglik(d) = mhmm_logprob(data_norm, prior{d}, transmat{d}, mu{d}, Sigma{d}, mixmat{d});
                    end

                    [score_sort, index_sort] = sort(loglik,'descend');
%                     index_max = index_sort(1);
%                     predict_label_P1 = index_max-1;
                    predict_label_P1 = str2double(vocabulary{index_sort(1,1),1}(2:5));
                    index_max = predict_label_P1+1;

                    if score_sort(1)>thre
%                         score_all = [score_all loglik'];
                        score_all{w}(:,k) = loglik';

                        showText_result1 = ['Sign: '...
                            chineseIDandMean{1,index_max}{1,2} ' /score' num2str(score_sort(1))...
                            ' /groundTruth: ' chineseIDandMean{1,groundTruth(k)+1}{1,2}];
%                         showText_result2 = ['Candidates: ' chineseIDandMean{1,index_sort(2)}{1,2} '/'...
%                                     chineseIDandMean{1,index_sort(3)}{1,2} '/'...
%                                     chineseIDandMean{1,index_sort(4)}{1,2} '/'...
%                                     chineseIDandMean{1,index_sort(5)}{1,2} ];

                        currentLabel = predict_label_P1;
                        % 如果label不重复的话就记录，否则取消记录。
                         if recognizeCount == 0
                             recognizeCount = recognizeCount + 1;
                             sign_recognized_ID(recognizeCount) = predict_label_P1;
                             labelCount(recognizeCount) = 1;    % 记录该label出现的次数
                         elseif sign_recognized_ID(recognizeCount) ~= predict_label_P1 
                             recognizeCount = recognizeCount + 1;
                             sign_recognized_ID(recognizeCount) = predict_label_P1;
                             labelCount(recognizeCount) = 1;
                         else
                             labelCount(recognizeCount) = labelCount(recognizeCount) + 1;
                         end
                         
                          % 正确的帧数统计
                         totalFrames = totalFrames + 1;
                         selectFrame = selectFrame + 1;
                         if predict_label_P1 == groundTruth(k) 
                             totalCorrectFrame = totalCorrectFrame + 1;
                             correctFrame = correctFrame+1;
                         end
                         
                    end

%                 end


%                 % 正确的帧数统计
%                 if currentLabel == groundTruth(k)
%                     correctFrame = correctFrame + 1;
%                 end

                clc;
                fprintf('%s \n%s \n%s \n%s \n', showText_pace, showText_true, showText_result1,showText_result2);

            end
        end
        %-------------------------------------------------------------------
        % 整理score_all
        score_all_new = cell(3,1);
        size_score = size(score_all{1},2);
        for i=1:size_score
            maxScore = max(max(max(score_all{1}(:,i)),max(score_all{2}(:,i))), max(score_all{3}(:,i)));
            
            score_max(1) = max(score_all{1}(:,i));
            score_max(2) = max(score_all{2}(:,i));
            score_max(3) = max(score_all{3}(:,i));
            [score_max_sort,~] = sort(score_max,'descend');
            
            if score_max_sort(1) > thre
                for w=1:3
                    score_all_new{w} = [score_all_new{w} score_all{w}(:,i)];
                end
            end
            
        end
        %-------------------------------------------------------------------
        
        for w=1:3
            score_all_new{w}(score_all_new{w}<=0)=10000;
            min_score = min(min(score_all_new{w}));
            score_all_new{w}(score_all_new{w}>9999)=0;
            max_score = max(max(score_all_new{w}));
            for i=1:size(score_all_new{w},1)
                for j=1:size(score_all_new{w},2)
                    if score_all_new{w}(i,j)>0
                        score_all_new{w}(i,j) = (score_all_new{w}(i,j)-min_score)/(max_score-min_score);
                    end
                end
            end
        end
        
        
        % Spotting with BP_3D
%         sign_recognized_ID_Final = BP_3D_HMM(score_all_new, classNum);
        sign_recognized_ID_Final = BP_3D(score_all_new, classNum, vocabulary_new, class_correlation);
        
        
        
         % 此处对识别和groundTruth这两个序列作比较，返回增删改的数目并统计。 Delete, Insert, Substitue
        [distance, insert, delete, substitute, correctSign] = editDis(sign_groundTruth_ID, sign_recognized_ID_Final); % sign_recognized_ID
        totalCorrectSign = totalCorrectSign + correctSign;
        totalDistance = totalDistance + distance;
        totalInsert = totalInsert+insert;
        totalDelete = totalDelete+delete;
        totalSubstitute = totalSubstitute+substitute;
        
        % 输出结果
        fprintf(fid, 'S%s:\t%d\t%d\t%f\t%d\t%d\t%f\t%d\t%d\t%d\t%d\n', sentence_names{sentenceID}(2:5), correctFrame,selectFrame ...
            , correctFrame/selectFrame,correctSign, trueSenLen, correctSign/trueSenLen, distance, insert, delete, substitute);
%         totalFrames = totalFrames + nframes-windowSize;
%         totalCorrectFrame = totalCorrectFrame + correctFrame;
    end
    % 输出最后统计结果
    fprintf(fid, 'Ave.:\t%d\t%d\t%f\t%d\t%d\t%f\t%d\t%d\t%d\t%d \n', totalCorrectFrame,...
        totalFrames, totalCorrectFrame/totalFrames, totalCorrectSign, totalsigns,...
        totalCorrectSign/totalsigns, totalDistance,totalInsert,totalDelete,totalSubstitute);
end
fclose(fid);



