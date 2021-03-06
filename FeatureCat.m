function [] = FeatureCat(varargin)

    wordsFilename = '/mounts/data/proj/sascha/corpora/GoogleNews-vectors-negative300.bin';
    wordsFilename = '/mounts/data/proj/sascha/corpora/word2vec_twitter_model/word2vec_twitter_model.bin';
    %wordsFilename = '/mounts/data/proj/fadebac/sa/data_manipulated/corpora/events2012_twitter-semeval2015/mikolov/2015-01-23-train_mikolov-no_elongated-skip-50.sh/skip-50';
    %wordsFilename = '/mounts/data/proj/fadebac/sa/data_manipulated/corpora/events2012_twitter-semeval2015/mikolov/2015-05-18-train_mikolov-no_elongated-skip-300.sh/skip-300';
    %wordsFilename = '/mounts/data/proj/sascha/corpora/GoogleNews-vectors-negative300_lower.txt';
    %wordsFilename = '/mounts/data/proj/sascha/corpora/GloVe/glove.twitter.27B.50d.txt';
    
    if any(strfind(wordsFilename, '.bin'))
        [W, dictW] = loadBinaryFile(wordsFilename, 30000);
    else
        [W, dictW] = loadTxtFile(wordsFilename);
        W(:,all(isnan(W),1)) = [];
        W = W(1:30000,:);
        dictW = dictW(1:30000,:);
    end
    
    dim = size(W,2);
    
    dictS_train = [];
    polS_train = [];    
    dictC_train = [];
    polC_train = [];
    
    sentiment_lexicons = {...
        %'/mounts/data/proj/sascha/corpora/Sentiment_Lexicon/whn_inter_gn_twitter.txt', ...
        '/mounts/data/proj/sascha/corpora/Sentiment_Lexicon/WilWieHof05.txt', ...
        %'/mounts/data/proj/sascha/corpora/Sentiment_Lexicon/HuLiu04.txt', ...
        '/mounts/data/proj/sascha/corpora/Sentiment_Lexicon/NRC-Emotion-Lexicon.txt', ...
        %'/mounts/data/proj/sascha/corpora/Sentiment_Lexicon/NRC-Hashtag-Sentiment-Lexicon.txt', ...
        %'/mounts/data/proj/sascha/corpora/Sentiment_Lexicon/Sentiment140-Lexicon.txt', ...
        %'/mounts/data/proj/sascha/corpora/Concreteness_Lexicon/bwk_concreteness_train.txt', ...
        };
    concreteness_lexicons = {...
        '/mounts/data/proj/sascha/corpora/Concreteness_Lexicon/bwk_concreteness_train.txt', ...
        };
    fallback_lexicon = '/mounts/data/proj/sascha/corpora/Sentiment_Lexicon/baseline.txt';
    
    for i=1:length(sentiment_lexicons)
        fileID = fopen(sentiment_lexicons{i});
        Table = textscan(fileID, '%s\t%f\n', 'CollectOutput',1);
        dictS_train = [dictS_train ; Table{1,1}(:, 1)];
        polS_train = [polS_train ; Table{1,2}(:, 1)];
        fclose(fileID);
    end
    [S_train, s_train] = getVectors(dictS_train, W, dictW);
    fprintf('Sentiment Lexicon training size: %d/%d\n', sum(s_train~=0), length(s_train));
    fprintf('Last word found on index %d\n', max(s_train));
    S_train(s_train == 0,:) = [];
    dictS_train(s_train == 0,:) = [];
    polS_train(s_train == 0,:) = [];
    s_train(s_train == 0,:) = [];
    s_pos = s_train(polS_train > 0.5,:);
    s_neg = s_train(polS_train < -0.5,:); 
    
    for i=1:length(concreteness_lexicons)
        fileID = fopen(concreteness_lexicons{i});
        Table = textscan(fileID, '%s\t%f\n', 'CollectOutput',1);
        dictC_train = [dictC_train ; Table{1,1}(:, 1)];
        polC_train = [polC_train ; Table{1,2}(:, 1)];
        fclose(fileID);
    end
    [C_train, c_train] = getVectors(dictC_train, W, dictW);
    fprintf('Concreteness Lexicon training size: %d/%d\n', sum(c_train~=0), length(c_train));
    fprintf('Last word found on index %d\n', max(s_train));
    C_train(c_train == 0,:) = [];
    dictC_train(c_train == 0,:) = [];
    polC_train(c_train == 0,:) = [];
    c_train(c_train == 0,:) = [];
    c_pos = c_train(polC_train > 0.5,:);
    c_neg = c_train(polC_train < -0.5,:); 
    
    % fallback lexicon    
    fileID = fopen(fallback_lexicon);
    Table = textscan(fileID, '%s\t%f\n', 'CollectOutput',1);
    dictFB = Table{1,1}(:, 1);
    polFB = Table{1,2}(:, 1);
    fclose(fileID);
    polFB = (polFB / 10);
    
    [pol_SEtrial, dict_SEtrial] = loadTxtFile('/mounts/data/proj/sascha/FeatureCat/semeval2015_taskE_trial.txt');
    [pol_FBtrial, id_FBtrial] = getVectors(dict_SEtrial, polFB, dictFB);
    [~, id_SEtrial] = getVectors(regexprep(dict_SEtrial, '#', ''), W, regexprep(dictW, '#', ''));
    [pol_SEtest, dict_SEtest] = loadTxtFile('/mounts/data/proj/sascha/FeatureCat/semeval2015_taskE.txt');
    [pol_FBtest, id_FBtest] = getVectors(dict_SEtest, polFB, dictFB);
    [~, id_SEtest] = getVectors(regexprep(dict_SEtest, '#', ''), W, regexprep(dictW, '#', ''));
    
    fileID = fopen('/mounts/data/proj/sascha/corpora/Concreteness_Lexicon/bwk_concreteness_test.txt');
    Table = textscan(fileID, '%s\t%f\n', 'CollectOutput',1);
    dict_CCtest = Table{1,1}(:, 1);
    pol_CCtest = Table{1,2}(:, 1);
    fclose(fileID);
    [~, id_CCtest] = getVectors(dict_CCtest, W, dictW);
        
    num_iters = 1000;
    batchsize = 300;
    
    Results = [];
    Settings = [];
    for a=0.0:0.1:1.0
        Settings = [Settings; a (1-a) a (1-a) a (1-a) 5 1 1 1 length(dictS_train)];
        %Settings = [Settings; 1 1 0 1 1 0 5 b 1 length(dictS_train)];
    end
    
    for w=1:size(Settings, 1)
        
        learning_rate = Settings(w,7);
        sent_size = Settings(w,8);
        conc_size = Settings(w,9);
        freq_size = Settings(w,10);
        lex_size = Settings(w,11);
        results = [];

        fprintf(['Weighting:' repmat(' %2.1f ', 1, 6) '\n'], Settings(w,1:6));
        fprintf('Learning Rate: %2.0f\n', learning_rate);
        fprintf('Size of sentiment part: %d\n', sent_size);
        fprintf('Size of conreteness part: %d\n', conc_size);
        fprintf('Size of frequency part: %d\n', freq_size);
        
        E = eye(dim);       

        rnd = RandStream('mt19937ar','Seed',0);
        RandStream.setGlobalStream(rnd);

        D = eye(dim);
        D_sent = D(01:00+sent_size,:);
        D_conc = D(11:10+conc_size,:);
        D_freq = D(21:20+freq_size,:);

        [J_history, E] = train(Settings(w,1:6), E, D_sent, D_conc, D_freq, num_iters, learning_rate, batchsize, W, s_pos, s_neg, c_pos, c_neg);
        Sent = (D_sent * E * W')';
        if corr(polS_train,Sent(s_train),'type','Kendall') < 0
            Sent = Sent .* -1;
        end
        Conc = (D_conc * E * W')';
        if corr(polC_train,Conc(c_train),'type','Kendall') < 0
            Conc = Conc .* -1;
        end
        Freq = (D_freq * E * W')';
        sample = randsample(1:5000, 1000, true);
        if corr(sample', Freq(sample),'type','Kendall') < 0
            Freq = Freq .* -1;
        end        
        
%         figure('Visible','on');
%         % smooth data
%         smoothing = 1000;
%         Freq_smooth = zeros(length(Freq)/smoothing,size(Freq,2));
%         for i=1:smoothing
%             Freq_smooth = Freq_smooth + (Freq(i:smoothing:end,:) / smoothing);
%         end
%         scatter(1:smoothing:length(Freq),Freq_smooth(:,1));
%         
%         figure('Visible','on');
%         scatter(1:length(Freq), Freq(:,1), 2, Sent(:,1), 'filled');
        
        plotConvergence(J_history);
        
%         %% Save Transformed Vectors
%         W_new = (E * W')';
%         weightString = strcat('_w', sprintf('%02.0f',a*10),sprintf('%02.0f',b*10),sprintf('%02.0f',c*10), '_');
%         file = strcat('/mounts/data/proj/sascha/FeatureCat/data/whn_skip-300', weightString, int2str(sentiment_size), 'only');
%         file = strcat('/mounts/data/proj/sascha/FeatureCat/data/SentimentLexiconGoogleNews.txt');  
%         writeToFile(file, 'w', W_new(:,1:train_size), dictW);

%         %% Get top 30
%         B = Sent(1:20000,1);
%         [~,id] = sort(B,'descend');
%         dictW(id(1:20))
%         [~,id] = sort(B,'ascend');
%         dictW(id(1:20))
        
        %% Frequency Task
        sample = randsample(1:5000, 1000, true);
%         fprintf('Correlation Frequency (%d/%d): %d\n', length(sample), length(sample), kendall);
%         figure('Visible','on');
%         scatter(sample, Freq(sample,:), 2, Freq(sample,:), 'filled');
        results = [results printResults('FREQUENCY', sample', Freq(sample), 0)];

        %% Concreteness Task        
%         figure('Visible','on');
%         scatter(polT, Conc(id_CCtest), 2, Conc(id_CCtest), 'filled');
        results = [results printResultsID('CONCRETENESS', pol_CCtest, Conc, id_CCtest, 0)];        
        
        %% SemEval-2015 task 10 E trial baseline
        %results = [results printResults('TRIAL BASELINE', pol_SEtrial, pol_FBtrial, 0)];
        
        %% SemEval-2015 task 10 E trial
        results = [results printResultsID('TRIAL', pol_SEtrial, Sent, id_SEtrial, 0)];
        fb_shift = 0;%fminbnd(@(v) fb_shift_optimizer(pol_SEtrial, Sent, id_SEtrial, pol_FBtrial, id_FBtrial, v), -1, 1);

        %% SemEval-2015 task 10 E trial fallback
        oov_shift = 0;%fminbnd(@(v) oov_shift_optimizer(pol_SEtrial, Sent, id_SEtrial, v), -1, 1);
        %results = [results printResultsID('TRIAL FALLBACK', pol_SEtrial, Sent, id_SEtrial, oov_shift)];

        %fprintf('Shift of OOV words: %3.2f\n', oov_shift);
        %fprintf('Shift of Fallback Baseline: %3.2f\n', fb_shift);
        
        %% SemEval-2015 task 10 E test baseline        
        %results = [results printResults('TEST BASELINE', pol_SEtest, pol_FBtest, 0)];

        %% SemEval-2015 task 10 E test        
        %results = [results printResultsID('TEST', pol_SEtest, Sent, id_SEtest, oov_shift)];

        %% SemEval-2015 task 10 E test fallback
        %Sent(id_SEtest) = Sent(id_SEtest) + (and(id_SEtest ==0, id_FBtest ~= 0) .* (pol_FBtest + fb_shift));
        %results = [results printResultsID('TEST FALLBACK', pol_SEtest, Sent, id_SEtest, oov_shift)];
 
        %% Add Results
        Results = [Results; Settings(w,:) results];
        %save('results.mat', 'Results');

    end
    
%     % Plot 
%     h=figure('Visible','off');
%     set(gcf, 'PaperUnits', 'centimeters');
% 	set(gcf, 'PaperPosition', [0 0 12 5]);
% 	set(gcf, 'PaperSize',[12, 5]);
%     plot(Results(:,5),Results(:,6),Results(:,5),Results(:,7),Results(:,5),Results(:,8));
%     %plot(Results_wwh(:,5),Results_wwh(:,6),Results_ncr(:,5),Results_ncr(:,6),Results_wwhs(:,5),Results_wwhs(:,6));
%     legend('trained', 'cut off', 'svd', 'Location','southwest');
%     ylabel('acc');
%     xlabel('size of subspace');
%     set(gca, 'xdir', 'reverse');
%     fName = '/mounts/Users/student/sascha/paper/FeatureCat/lexicon_size.pdf';
%     saveas(h,fName);
%     close(h);
end

function [] = plotConvergence(J_history)

    num_iters = size(J_history, 1);

    % smooth data
    smoothing = 10;
    J_history_smooth = zeros(num_iters/smoothing,size(J_history,2));
    for s_train=1:smoothing
        J_history_smooth = J_history_smooth + J_history(s_train:smoothing:end,:);
    end
    J_history = J_history_smooth;

    % Plot the convergence graph 
    figure('Visible','on');
    hold on;    
    plot(1:smoothing:num_iters, (J_history(:,1) / max(J_history(:,1))), '-', 'LineWidth', 2);
    plot(1:smoothing:num_iters, (J_history(:,2) / max(J_history(:,2))), ':', 'LineWidth', 2);
    plot(1:smoothing:num_iters, (J_history(:,3) / max(J_history(:,3))), '-', 'LineWidth', 2);
    plot(1:smoothing:num_iters, (J_history(:,4) / max(J_history(:,4))), ':', 'LineWidth', 2);
    plot(1:smoothing:num_iters, (J_history(:,5) / max(J_history(:,5))), '-', 'LineWidth', 2);
    plot(1:smoothing:num_iters, (J_history(:,6) / max(J_history(:,6))), ':', 'LineWidth', 2);
    plot(1:smoothing:num_iters, (J_history(:,7) / max(J_history(:,7))), '-', 'LineWidth', 2);
    plot(1:smoothing:num_iters, (J_history(:,8) / max(J_history(:,8))), '-', 'Color', [0.3 0.3 0.3]);
    legend('max sent','min sent', 'max conc', 'min conc', 'max freq', 'min freq', 'norm', 'learning rate');
    xlabel('iteration');
    
end

function [results] = printResultsID(name, T, W, id, oov_shift)

    P = zeros(size(id, 1), size(W, 2));
    P(id~=0) = P(id~=0) + W(id(id~=0));
    results = printResults(name, T, P, oov_shift);
    
end

function [results] = printResults(name, T, P, oov_shift)

    available = all(P, 2);
    P(available ~= 1,:) = oov_shift;

    fprintf('%s %d/%d\n', name, sum(available), length(T));
    kendall = corr(T,P,'type','Kendall');
    kendall_noOOV = corr(T(available,:),P(available,:),'type','Kendall');
    fprintf('Kendall:  %4.3f (%4.3f)\n', kendall, kendall_noOOV);
    %spearman = corr(T,P,'type','Spearman');
    %spearman_noOOV = corr(T(available,:),P(available,:),'type','Spearman');
    %fprintf('Spearman: %4.3f (%4.3f)\n', spearman, spearman_noOOV);
    %results = [kendall kendall_noOOV spearman spearman_noOOV];
    results = [kendall];
    
end

function [] = writeToFile(file, mode, A, dictA)

    fid = fopen(file, mode);

    for i=1:size(dictA,1)
        fprintf(fid, '%s', dictA{i});
        fprintf(fid,' %f',A(i,:));
        fprintf(fid,'\n');
    end

    fclose(fid);

end

function f = oov_shift_optimizer(T, W, id, v)
    P = zeros(size(id, 1), size(W, 2));
    P(id~=0) = P(id~=0) + W(id(id~=0));
    P(id==0) = P(id==0) + v;
    f = (1 - corr(T,P,'type','Kendall'));
end

function f = fb_shift_optimizer(T, W, id, polFB_trial, id_fb_trial, v)
    P = zeros(size(id, 1), size(W, 2));
    P(id~=0) = P(id~=0) + W(id(id~=0));
    P = P + (and(id ==0, id_fb_trial ~= 0) .* (polFB_trial + v));
    f = (1 - corr(T,P,'type','Kendall'));
end

% %% Frequency Toy Task
% s_head = randsample(1:2500, 3000, true);
% s_tail = randsample(2501:length(W), 3000, true);
% s_head_test = randsample(1:2500, 300, true);
% s_tail_test = randsample(2501:length(W), 300, true);
% s_head(ismember(s_head, s_head_test)) = [];
% s_tail(ismember(s_tail, s_tail_test)) = [];
% fprintf('Toy Task Frequency\n');
% results = [results toyTask(D_freq, E, W, s_head, s_tail, s_head_test, s_tail_test)];
% 
% %% Sentiment Toy Task
% fileID = fopen(test_lexicon);
% Table = textscan(fileID, '%s\t%d\n', 'CollectOutput',1);
% dictS_test = Table{1,1}(:, 1);
% polS_test = double(Table{1,2}(:, 1));
% fclose(fileID); 
% [~, s_test] = getVectors(dictS_test, W, dictW);
% s_test(ismember(s_test, s_train)) = 0;
% polS_test(s_test == 0,:) = [];
% s_test(s_test == 0,:) = [];
% fprintf('Toy Task Sentiment Test Size: %d/%d\n', length(s_test), length(dictS_test));
% s_pos_test = s_test(polS_test > 0.5,:);
% s_neg_test = s_test(polS_test < -0.5,:);
% results = [results toyTask(D_sentiment, E, W, s_pos, s_neg, s_pos_test, s_neg_test)];