%声明
%“编号”是在matlab中使用的。从1开始。
%“ID”是句子或者单词本身使用的，从w0000开始。
%两者之间有相差1的关系。

clear all;
clc;
%%
addpath(genpath('D:\iCode\GitHub\libsvm\matlab'));
addpath(genpath('D:\iCode\HMM_Matlab\HMMall'));

load data\HMM_model_s3_m3_dim61_370sign_forP50
sentence_names = importdata('input\sentences_209.txt');
teatDataPath = 'dim61_CTskp_fullFrame_209sentences'; 
% dim334_CTskp_fullFrame_209sentences 
% dim334_CTskp_allFrame_manually_209sentences
% dim61_CTskp_fullFrame_209sentences

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
draw = 1;    %1:显示视频。 0：不显示视频
windowSize = 20;   %滑动窗口的大小
T = 130;    % 帧数
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

        VideoPath = ['D:\iData\continousSentence\P08_02\S08_'...
            num2str(sentence_names{sentenceID}(2:5)) '_1_0_20130412.oni\color.avi'];
        videoObj = mmreader(VideoPath);             %读视频文件
        
        
        showText_result1 = 'none';
        showText_result2 = 'none';
        for k=1:nframes
            if draw == 1
                currentFrame = read(videoObj, k);%读取第k帧
                imshow(currentFrame);
%                 tempshow = zeros(480,640);
%                 imshow(tempshow);
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
                
                data_HMM = TestData(:,t:t_);
                data_norm = (insertFrame(data_HMM',T))';
     
                loglik = zeros(1,classNum);
                for d=1:classNum
%                     fprintf('Testing data: P%d \n', d);
                    loglik(d) = mhmm_logprob(data_norm, prior{d}, transmat{d}, mu{d}, Sigma{d}, mixmat{d});
                end
                
                [score_sort, index_sort] = sort(loglik,'descend');
                index_max = index_sort(1);
                
                showText_result1 = ['Frame: ' num2str(k) ' /Sign: '...
                    chineseIDandMean{1,index_max}{1,2} ' /score' num2str(score_sort(1))];
                showText_result2 = ['Candidates: ' chineseIDandMean{1,index_sort(2)}{1,2} '/'...
                            chineseIDandMean{1,index_sort(3)}{1,2} '/'...
                            chineseIDandMean{1,index_sort(4)}{1,2} '/'...
                            chineseIDandMean{1,index_sort(5)}{1,2} ];
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



