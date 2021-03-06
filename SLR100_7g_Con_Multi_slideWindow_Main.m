%声明
%“编号”是在matlab中使用的。从1开始。
%“ID”是句子或者单词本身使用的，从w0000开始。
%两者之间有相差1的关系。

clear all;
clc;
%% Settings and Initials
addpath(genpath('D:\iCode\GitHub\libsvm\matlab'));

% 读取模型库
load data\model_HierarSeg_100sign7g_forP19

% 读取 class_correlation变量。即，类间关系图。
load data\class_correlation_model_100_7g;   % class_correlation: 100*100

% 读取测试库
sentence_names = importdata('input\sentences_100.txt');
teatDataPath = 'dim334_CTskp_allFrame_manually_100sentences_100sign_7g'; 

% 读取用单词ID集合表示的句子
sentences_meaning_number_Path = 'input\sentence_meaning_ID_random_100.txt'; 
sentences_meaning_number = ChineseDataread(sentences_meaning_number_Path);

% 从文件名确定当前的维数
idx = strfind(teatDataPath,'_');
dimFinalIdx = idx(1,1)-1;
dim = str2double(teatDataPath(4:dimFinalIdx));

% 读取中文意思和对应的ID号
ChinesePath = 'input\wordlist_4414.txt';
chineseIDandMean = ChineseDataread(ChinesePath);

% 读取测试词汇ID
vocabulary = model_precomputed.Label;

classNum = 100;
subSpaceSize = 10;   % 子空间大小
gap = 3;            % 隔n帧采样
thre = 0.73;        % score>thre 的视为有效  0.77
windowSizes(1) = 30; % 滑动窗口的大小
windowSizes(2) = 40;
windowSizes(3) = 60;
fidName = ['result\result' '_noSegModel_thre' num2str(thre) '_skip' ...
    num2str(gap) '_win' num2str(windowSizes(1)) num2str(windowSizes(2)) ...
    num2str(windowSizes(3)) '_random100_100sign_BP3D_1in_2vots_G19.txt' ];
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
    
    % 从1开始的100个句子编号， 而句子的ID都是从w0000开始
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
        
        %首先通过一个函数建立cov快查表
        P = cell(1,h);
        Q = cell(1,h);
        for t=1:h
            P{1,t} = sum(TestData(:,1:t),2);
            Q{1,t} = TestData(:,1:t)*TestData(:,1:t)';
        end

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
        score_all = cell(3,1);
        
        for w=1:3
            windowSize = windowSizes(w);
            for k=1:gap:nframes
                showText_pace = ['Sentence ID: ' sentence_names{sentenceID}(2:5) ', '...
                   num2str(k) '/' num2str(nframes) ' frames, repetition:' num2str(w)];
               
               % 快速计算Cov及其子空间，即GCM。
                t = max(k - floor(windowSize/2), 1);
                t_= min(k + floor(windowSize/2), nframes);
                Para_ARMA_test{1}.C = grasp_region(t, t_, P, Q, subSpaceSize);
                
                test_label(1) = t;
                ValKernel = kernel_ARMA_Continuous(Para_ARMA_train,Para_ARMA_test);
                VValKernel = [(1:1)',ValKernel'];
                [predict_label_P1, accuracy_P1, dec_values_P1] = ...
                    svmpredict(test_label, VValKernel, model_precomputed,'-q');  % '-q'用来去除输出结果信息
                index_max = predict_label_P1 + 1;

                % 计算SVM的概率，来自one-to-one的信息.
                score = dec_values_score(dec_values_P1, classNum); 
%                 [score_sort, index_sort] = sort(score,'descend');
                score_max = max(score);
                
                % Rank 1 的概率大于阈值的视为有效
                if score_max > 0
                    % score_all{w} = [score_all{w} score'];
                    score_all{w}(:,k) = score';

                    showText_result1 = ['Sign: '...
                        chineseIDandMean{1,index_max}{1,2} ' /score' num2str(score_max)...
                        ' /groundTruth: ' chineseIDandMean{1,groundTruth(k)+1}{1,2}];
%                     showText_result2 = ['Candidates: ' chineseIDandMean{1,index_sort(2)}{1,2} '/'...
%                          chineseIDandMean{1,index_sort(3)}{1,2} '/'...
%                          chineseIDandMean{1,index_sort(4)}{1,2} '/'...
%                          chineseIDandMean{1,index_sort(5)}{1,2} ];
%                     currentLabel = predict_label_P1;

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
%             maxScore = max(max(max(score_all{1}(:,i)),max(score_all{2}(:,i))), max(score_all{3}(:,i)));
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
        % 对句子的整体parsing.

        % Spotting with BP_3D
        sign_recognized_ID_Final = BP_3D(score_all_new, classNum, vocabulary, class_correlation);
        %-------------------------------------------------------------------
        
        % 此处对识别和groundTruth这两个序列作比较，返回增删改的数目并统计。 Delete, Insert, Substitue
        [distance, insert, delete, substitute, correctSign] = editDis(sign_groundTruth_ID, sign_recognized_ID_Final);
        totalCorrectSign = totalCorrectSign + correctSign;
        totalDistance = totalDistance + distance;
        totalInsert = totalInsert+insert;
        totalDelete = totalDelete+delete;
        totalSubstitute = totalSubstitute+substitute;
        
        % 输出结果
        fprintf(fid, 'S%s:\t%d\t%d\t%f\t%d\t%d\t%f\t%d\t%d\t%d\t%d\n', sentence_names{sentenceID}(2:5), correctFrame, selectFrame...
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



