%����
%����š�����matlab��ʹ�õġ���1��ʼ��
%��ID���Ǿ��ӻ��ߵ��ʱ���ʹ�õģ���w0000��ʼ��
%����֮�������1�Ĺ�ϵ��

clear all;
clc;
%%
addpath(genpath('D:\iCode\GitHub\libsvm\matlab'));
addpath(genpath('D:\iCode\HMM_Matlab\HMMall'));

% ��ȡ class_correlation��������������ϵͼ��
load data\class_correlation_model_1000;   

% ��ȡģ�Ϳ�
load data\HMM_model_s3_m3_dim61_1000sign_forP31

% ��ȡ���Կ�
sentence_names = importdata('input\sentences_100.txt');
teatDataPath = 'dim61_CTskp_allFrame_manually_100sentences_1000sign'; 

% ���ļ���ȷ����ǰ��ά��
idx = strfind(teatDataPath,'_');
dimFinalIdx = idx(1,1)-1;
dim = str2double(teatDataPath(4:dimFinalIdx));

%��ȡ������˼�Ͷ�Ӧ��ID��
ChinesePath = 'input\wordlist_4414.txt';
chineseIDandMean = ChineseDataread(ChinesePath);

%��ȡ�õ���ID���ϱ�ʾ�ľ���
sentences_meaning_number_Path = 'input\sentence_meaning_ID_random_1000.txt';
sentences_meaning_number = ChineseDataread(sentences_meaning_number_Path);

% ��ȡ���Դʻ�ID
vocabulary = importdata('input\sign_1000_zeng.txt');


classNum = 1000;
sample = 3;    %��n֡����
draw = 0;    %1:��ʾ��Ƶ�� 0������ʾ��Ƶ
thre = 0;
windowSize = 40;   %�������ڵĴ�С
fidName = ['result\HMM_result' '_NoSegModel_thre' num2str(thre) '_skip' ...
    num2str(sample) '_win' num2str(windowSize) '_random100_1000sign_BP2D_G2.txt' ];
fid = fopen(fidName,'wt');
%%
for groupID =  2:2
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
    
    
    % ��1��ʼ��209�����ӱ�ţ� �����ӵ�ID���Ǵ�w0000��ʼ
    for sentenceID = 1:length(sentence_names)    
        sign_recognized_ID = [];
        sign_recognized_ID_Final = [];
        fprintf('Processing data: Group %d--Sentence %d\n', groupID, sentenceID);
        data = importdata([groupName sentence_names{sentenceID} '.txt'], ' ', 1);
        groundTruth_ = importdata([groundTruthFileFolderName sentence_names{sentenceID} '.txt'], ' ', 1);
        [h, w] = size(data.data);  % h:֡��  w:ά��
        TestData = (data.data)';
        groundTruth = groundTruth_.data;
        nframes = size(TestData, 2);
        correctFrame = 0;
        selectFrame = 0;
        currentLabel = -1;    % ��Ϊ����ÿ֡����label���������������ÿ֡��label��
        
        
        showText_result1 = 'none';
        showText_result2 = 'none';
        showText_true = 'Truth:';
        % ��ȷ����˼
        trueSenLen = size(sentences_meaning_number{1,1+sentenceID},2);
        totalsigns = totalsigns + trueSenLen;
        sign_groundTruth_ID = zeros(1, trueSenLen) - 1;      % ��ȷ��Sign ID
        recognizeCount = 0;          % sign_recognized_ID   % ʶ������ĵ�Sign ID
        for sign_i = 1:trueSenLen
            sign_groundTruth_ID(sign_i) = str2double(sentences_meaning_number{1,1+sentenceID}{1,sign_i});
            showText_true = [showText_true chineseIDandMean{1,sign_groundTruth_ID(sign_i)+1}{1,2} '/'];
        end
        
%         TopNindex_ID = zeros(5,300);
%         TopNscore_ID = zeros(5,300);
%         TopNcount = 1;
        score_all = [];
        
        for k=1:nframes
            showText_pace = ['Sentence ID: ' sentence_names{sentenceID}(2:5) ', '...
                   num2str(k) '/' num2str(nframes) ' frames, '];
            if k>windowSize/2 && k<nframes - windowSize/2 && mod(k,sample)==0
                t = k - windowSize/2;
                t_= k + windowSize/2;
                
                data_norm = TestData(:,t:t_);
     
                loglik = zeros(1,classNum);
                for d=1:classNum
                    loglik(d) = mhmm_logprob(data_norm, prior{d}, transmat{d}, mu{d}, Sigma{d}, mixmat{d});
                end
                
                [score_sort, index_sort] = sort(loglik,'descend');
%                 index_max = index_sort(1);
%                 predict_label_P1 = index_max-1;
                predict_label_P1 = str2double(vocabulary{index_sort(1,1),1}(2:5));
                index_max = predict_label_P1+1;
                
                if score_sort(1)>thre
                    score_all = [score_all loglik'];

                    showText_result1 = ['Sign: '...
                        chineseIDandMean{1,index_max}{1,2} ' /score' num2str(score_sort(1))...
                        ' /groundTruth: ' chineseIDandMean{1,groundTruth(k)+1}{1,2}];
%                     showText_result2 = ['Candidates: ' chineseIDandMean{1,index_sort(2)}{1,2} '/'...
%                                 chineseIDandMean{1,index_sort(3)}{1,2} '/'...
%                                 chineseIDandMean{1,index_sort(4)}{1,2} '/'...
%                                 chineseIDandMean{1,index_sort(5)}{1,2} ];
                            
                    currentLabel = predict_label_P1;
                    % ���label���ظ��Ļ��ͼ�¼������ȡ����¼��
                     if recognizeCount == 0
                         recognizeCount = recognizeCount + 1;
                         sign_recognized_ID(recognizeCount) = predict_label_P1;
                         labelCount(recognizeCount) = 1;    % ��¼��label���ֵĴ���
                     elseif sign_recognized_ID(recognizeCount) ~= predict_label_P1 
                         recognizeCount = recognizeCount + 1;
                         sign_recognized_ID(recognizeCount) = predict_label_P1;
                         labelCount(recognizeCount) = 1;
                     else
                         labelCount(recognizeCount) = labelCount(recognizeCount) + 1;
                     end
                     
                      % ��ȷ��֡��ͳ��
                     totalFrames = totalFrames + 1;
                     selectFrame = selectFrame +1;
                     if predict_label_P1 == groundTruth(k) 
                         totalCorrectFrame = totalCorrectFrame + 1;
                         correctFrame = correctFrame + 1;
                     end
                end
                
            end
            

            clc;
            fprintf('%s \n%s \n%s \n%s \n', showText_pace, showText_true, showText_result1,showText_result2);
            
        end
        
        
        sign_recognized_ID_Final = BP_2D_HMM(score_all, classNum, vocabulary, class_correlation);
        
        
        
         % �˴���ʶ���groundTruth�������������Ƚϣ�������ɾ�ĵ���Ŀ��ͳ�ơ� Delete, Insert, Substitue
        [distance, insert, delete, substitute, correctSign] = editDis(sign_groundTruth_ID, sign_recognized_ID_Final); % sign_recognized_ID
        totalCorrectSign = totalCorrectSign + correctSign;
        totalDistance = totalDistance + distance;
        totalInsert = totalInsert+insert;
        totalDelete = totalDelete+delete;
        totalSubstitute = totalSubstitute+substitute;
        
        % ������
        fprintf(fid, 'S%s:\t%d\t%d\t%f\t%d\t%d\t%f\t%d\t%d\t%d\t%d\n', sentence_names{sentenceID}(2:5), correctFrame, selectFrame...
            , correctFrame/selectFrame,correctSign, trueSenLen, correctSign/trueSenLen, distance, insert, delete, substitute);
%         totalFrames = totalFrames + nframes-windowSize;
%         totalCorrectFrame = totalCorrectFrame + correctFrame;
    end
    % ������ͳ�ƽ��
    fprintf(fid, 'Ave.:\t%d\t%d\t%f\t%d\t%d\t%f\t%d\t%d\t%d\t%d \n', totalCorrectFrame,...
        totalFrames, totalCorrectFrame/totalFrames, totalCorrectSign, totalsigns,...
        totalCorrectSign/totalsigns, totalDistance,totalInsert,totalDelete,totalSubstitute);
end
fclose(fid);


