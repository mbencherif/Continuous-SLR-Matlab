%声明
%“编号”是在matlab中使用的。从1开始。
%“ID”是句子或者单词本身使用的，从w0000开始。
%两者之间有相差1的关系。

clear all;
clc;
%%
addpath(genpath('D:\iCode\GitHub\libsvm\matlab'));
addpath('CRF\bin');
addpath('CRF');

load CRF\result_dim10_97_R
load data\model_MultiSeg_370sign_forP50_new
sign_names = importdata('input\signs_283.txt');   % signs_97  signs_283
sentence_names = importdata('input\sentences_209.txt');
teatDataPath = 'dim334_CTskp_allFrame_manually_209sentences'; 
% dim334_CTskp_fullFrame_209sentences 
% dim334_CTskp_allFrame_manually_209sentences
segPath = 'input\segManually_P08_02.txt';

idx = strfind(teatDataPath,'_');
dimFinalIdx = idx(1,1)-1;
dim = str2num(teatDataPath(4:dimFinalIdx));

%读取中文意思和对应的ID号
ChinesePath = 'input\wordlist_370.txt';
chineseIDandMean = ChineseDataread(ChinesePath);

%读取用单词ID集合表示的句子
sentences_meaning_number_Path = 'input\sentences_meaning_number.txt';
sentences_meaning_number = ChineseDataread(sentences_meaning_number_Path);

classNum = 370;
rank = 2;   % 考虑前几名有效
subSpaceSize = 5;   %子空间大小
draw = 1;    %1:显示视频。 0：不显示视频
windowSize = 40;   %滑动窗口的大小
%%
fid = fopen('result\recognized sentence.txt','wt');
for groupID =  1:1
    groupName = ['D:\iData\Outputs\ftdcgrs_whj_output\' teatDataPath '\test_' num2str(groupID) '\'];
    
    % 从1开始的209个句子编号， 而句子的ID都是从w0000开始
    for sentenceID = 50:53 %length(sentence_names)    
        fprintf('Processing data: Group %d--Sentence %d\n', groupID, sentenceID);
        data = importdata([groupName sentence_names{sentenceID} '.txt'], ' ', 1);
        [h, w] = size(data.data);  % h:帧数  w:维数
        TestData = (data.data)';
        nframes = size(TestData, 2);
        

        %首先通过一个函数建立cov快查表
        for t=1:h
            P{1,t} = sum(TestData(:,1:t),2);
            Q{1,t} = TestData(:,1:t)*TestData(:,1:t)';
        end

%         VideoPath = ['D:\iData\continousSentence\P08_02\S08_'...
%             num2str(sentence_names{sentenceID}(2:5)) '_1_0_20130412.oni\color.avi'];
%         videoObj = mmreader(VideoPath);             %读视频文件
        
        
        showText_result1 = 'none';
        showText_result2 = 'none';
        for k=1:nframes
            if draw == 1
%                 currentFrame = read(videoObj, k);%读取第k帧
%                 imshow(currentFrame);
                tempshow = zeros(480,640);
%                 tempshow = reshape(TestData(1:324),18,18);
                imshow(tempshow);
                xlim=get(gca,'xlim');
                ylim=get(gca,'ylim');
            end

            % 显示正确的意思
            trueSenLen = size(sentences_meaning_number{1,1+sentenceID},2);
            showText_true = ['Sentence ' sentence_names{sentenceID}(2:5) ', '...
               num2str(k) '/' num2str(nframes) ' frames, '];
            for sign_i = 1:trueSenLen
                sign_choosen_ID = str2num(sentences_meaning_number{1,1+sentenceID}{1,sign_i});
                showText_true = [showText_true chineseIDandMean{1,sign_choosen_ID+1}{1,2} '/'];
            end
            text(sum(xlim)/2-0,sum(ylim)/2-210,showText_true,'horiz','center','color','r');
            
            if k>windowSize/2 && k<nframes - windowSize/2 && mod(k,5)==0
                t = k - windowSize/2;
                t_= k + windowSize/2;

                % 快速计算cov及其子空间，即GRASP。
                Para_ARMA_test{1}.C = grasp_region(t, t_, P, Q, subSpaceSize);

                test_label(1) = t;
                ValKernel = kernel_ARMA_Continuous(Para_ARMA_train,Para_ARMA_test);
                VValKernel = [(1:1)',ValKernel'];
                [predict_label_P1, accuracy_P1, dec_values_P1] = ...
                    svmpredict(test_label, VValKernel, model_precomputed,'-q');  % '-q'用来去除输出结果信息
                index_max = predict_label_P1 + 1;
                
                % 计算SVM的概率，来自one-to-one的信息.
                score = dec_values_score(dec_values_P1, classNum); 
                [score_sort, index_sort] = sort(score,'descend');
                
                if score_sort(1) > 0.75
                    showText_result1 = ['Frame: ' num2str(k) ' /Sign: '...
                        chineseIDandMean{1,index_max}{1,2} ' /score' num2str(score_sort(1))];
                    showText_result2 = ['Candidates: ' chineseIDandMean{1,index_sort(2)}{1,2} '/'...
                                chineseIDandMean{1,index_sort(3)}{1,2} '/'...
                                chineseIDandMean{1,index_sort(4)}{1,2} '/'...
                                chineseIDandMean{1,index_sort(5)}{1,2} ];
                end
            end
            
            if draw == 1
                text(sum(xlim)/2-200,sum(ylim)/2-150,showText_result1,'horiz','center','color','r');
                text(sum(xlim)/2-200,sum(ylim)/2-130,showText_result2,'horiz','center','color','r');
                drawnow;    %实时更新命令
            end
        end
        
    end
end
fclose(fid);



