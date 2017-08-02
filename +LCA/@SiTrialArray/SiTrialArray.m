classdef SiTrialArray < handle
%
%   TrialArray < handle
%
%
% DHO, 5/08.
% SAH, 10/11.
%
%
%
    properties
        trials = {};
        orphanBehavTrials = {};
        orphanShankTrials = {};
        orphanWhiskersTrials = {};
        performanceRegion = []; % Beginning and ending behavioral trial numbers for block of trials in which mouse is performing.
        whiskerTrialTimeOffset = 0; % in sec, positive for whisker timeseries starting after spikes, behavior.
        depth = NaN; % Recording depth
        recordingLocation = '';
    end

    properties (Dependent = true)
        cellNum
        shankNum
        mouseName
        sessionName
        trialNums
        hitTrialNums
        hitTrialInds
        missTrialNums
        missTrialInds
        falseAlarmTrialNums
        falseAlarmTrialInds
        correctRejectionTrialNums
        correctRejectionTrialInds
        whiskerTrialNums % Trial nums where there is whisker tracking data.
        whiskerTrialInds % Indicates with 1 or 0 whether there is whisker tracking data for each trial in array.
        trialTypes
        %         trimmedTrialNums
        trialCorrects
        fractionCorrect
        %spikeRatesInHz
      %  meanSpikeRateInHz
       % stdDevSpikeRateInHz
    end

    methods (Access = public)
        function obj = SiTrialArray(behav_trial_array, shanks_trial_array, varargin)
            %
            %   obj = SiTrialArray(behav_trial_array, clust_trial_array, varargin)
            %
            % behav_trial_array: Solo.BehavSiTrialArray object.
            % clust_trial_array: LCA.ClustTrialArray object.
            % varargin: optional Whisker.WhiskerSignalTrialArray, Whisker.WhiskerTrialLiteArray or 
            %           Whisker.WhiskerMeasurementsTrialArray object.
            %
            %
            if nargin > 0

                if ~isa(behav_trial_array,'Solo.BehavTrialArray')
                    error('First argument must be a class of type Solo.BehavTrialArray')
                end
                if ~isa(shanks_trial_array,'LCA.ShanksTrialArray')
                    error('Second argument must be a cell containing classes of type LCA.ShanksTrialArray')
                end
                if nargin > 2
                    whiskerInclude = 1;
                    whisker_trial_array = varargin{1};
                    if ~isa(whisker_trial_array,'Whisker.WhiskerSignalTrialArray') && ...
                            ~isa(whisker_trial_array,'Whisker.WhiskerTrialLiteArray') && ...
                            ~isa(whisker_trial_array,'Whisker.WhiskerMeasurementsTrialArray')
                        error(['Third argument must be a class of type Whisker.WhiskerSignalTrialArray, '...
                            'Whisker.WhiskerTrialLiteArray, or Whisker.WhiskerMeasurementsTrialArray'])
                    end
                else
                    whiskerInclude = 0;
                end

                % Pair corresponding Solo.BehavTrial and LCA.SpikesTrial objects
                % by trialNum into LCA.Trial objects.
                trial_nums_behav = behav_trial_array.trialNums;
                trial_nums_shanks = shanks_trial_array.trialNums;

                % Make only trials where we have both a behavior trial and a spikes trial:
                common_trial_nums = intersect(trial_nums_shanks, trial_nums_behav);
                orphan_shanks_trials_with_trial_num_0_ind = find(trial_nums_shanks==0); % Occasionally bitcode is given/read incorrectly, results in trialNum=0.

                % Additionally, include a whisker trial if we find one with a matching trial number
                % and a WhiskerSignalTrialArray or WhiskerMeasurementsTrialArray was given as an argument.
                if whiskerInclude
                    trial_nums_whisker = whisker_trial_array.trialNums;
                end

                if isempty(common_trial_nums)
                    error('No common trial numbers.')
                end
                
                
                n = 1;
                for k=1:length(common_trial_nums)
                    trial_num = common_trial_nums(k);
                    ind_behav = find(trial_nums_behav==trial_num);
                    ind_shanks = find(trial_nums_shanks==trial_num);

                    if whiskerInclude
                        ind_whisker = find(trial_nums_whisker==trial_num);
                        if length(ind_whisker) > 1
                            error(['Found multiple whisker trials for trial_num=' int2str(trial_num)])
                        elseif length(ind_whisker)==1
                            whiskerIncludeTrial = 1;
                        else
                            whiskerIncludeTrial = 0;
                        end
                    else
                        whiskerIncludeTrial = 0;
                    end

                    if length(ind_shanks) > 1
                        disp(['Trial num ' int2str(trial_num) ' occurs more than once in the SpikesTrialArray---skipping.'])
                    elseif length(ind_behav) > 1
                        disp(['Trial num ' int2str(trial_num) ' occurs more than once in the BehavTrialArray---skipping.']) % Shouldn't happen; just making sure.
                    else
                        if whiskerIncludeTrial
                            obj.trials{n} = LCA.SiTrial(behav_trial_array.trials{ind_behav},shanks_trial_array.shankTrials{ind_shanks},whisker_trial_array.trials{ind_whisker});
                        else
                            obj.trials{n} = LCA.SiTrial(behav_trial_array.trials{ind_behav},shanks_trial_array.shankTrials{ind_shanks});
                        end
                        n = n + 1;
                    end
                end


                % Fill in orphan SpikesTrials, which don't match any BehavTrial:
                if ~isempty(orphan_shanks_trials_with_trial_num_0_ind)
                    num_orphans_shanks = 1;
                    for k=orphan_shanks_trials_with_trial_num_0_ind
                        obj.orphanShanksTrials{num_orphans_spikes} = shanks_trial_array.shankTrials{k};
                        num_orphans_shanks = num_orphans_shanks + 1;
                    end
                end

                obj.performanceRegion = behav_trial_array.performanceRegion;

            end


        end

        function set_whiskerTrialTimeOffset(obj, offsetInSec)
            obj.whiskerTrialTimeOffset = offsetInSec;
        end

        function r = length(obj)
            r = length(obj.trials);
        end

        function r = beamBreakTimes(obj,varargin)
            %
            % r = beamBreakTimes(obj,varargin)
            %
            % varargin: optional vector of trial numbers.
            %
            
            r = cellfun(@(x) x.beamBreakTimes, obj.trials,'UniformOutput',false);
            if nargin>1
                r = r(ismember(obj.trialNums, varargin{1}));
            end
        end

        function r = pinDescentOnsetTimes(obj,varargin)
            % r = pinDescentOnsetTimes(obj,varargin)
            %
            %   varargin: optional vector of trial numbers.
            %
            r = cellfun(@(x) x.pinDescentOnsetTime, obj.trials);
            if nargin>1
                r = r(ismember(obj.trialNums, varargin{1}));
            end
        end

        function r = pinAscentOnsetTimes(obj,varargin)
            % r = pinAscentOnsetTimes(obj,varargin)
            %
            %   varargin: optional vector of trial numbers.
            %
            r = cellfun(@(x) x.pinAscentOnsetTime, obj.trials);
            if nargin>1
                r = r(ismember(obj.trialNums, varargin{1}));
            end
        end

        function r = answerLickTimes(obj,varargin)
            % r = answerLickTimes(obj,varargin)
            %
            %   varargin: optional vector of trial numbers.
            %
            r = cellfun(@(x) x.answerLickTime, obj.trials,'UniformOutput',false);
            if nargin>1
                r = r(ismember(obj.trialNums, varargin{1}));
            end
        end

        function r = spikeCountInTimeWindow(obj, clust, startTimeInSec, endTimeInSec)
            % r = spikeCountInTimeWindow(startTimeInSec, endTimeInSec)
            %
            %   Start and stop times are inclusive.
            %
            %
            r = cellfun(@(x) x.spikeCountInTimeWindow(clust, startTimeInSec, endTimeInSec), obj.trials,'UniformOutput',0);
        end
        
        function r = spikeRateInHzTimeWindow(obj, clust, startTimeInSec, endTimeInSec)
            % r = spikeRateInHzTimeWindow(startTimeInSec, endTimeInSec)
            %
            %   Start and stop times are inclusive.
            %
            %
            r = cellfun(@(x) x.spikeRateInHzTimeWindow(clust, startTimeInSec, endTimeInSec), obj.trials,'UniformOutput',0);
        end

        function r = meanSpikeRateInHzTimeWindow(obj, clust, startTimeInSec, endTimeInSec)
            %
            % r = MeanSpikeRateInHzTimeWindow(startTimeInSec, endTimeInSec)
            %
            % Gives mean spike rate within given time window across all trials
            % in the TrialArray.
            %
            % Start and stop times are inclusive.
            %
            %
            r = mean(obj.spikeRateInHzTimeWindow(clust, startTimeInSec, endTimeInSec));
        end

        function r = stdDevSpikeRateInHzTimeWindow(obj, clust, startTimeInSec, endTimeInSec)
            %
            % r = StdDevSpikeRateInHzTimeWindow(startTimeInSec, endTimeInSec)
            %
            % Gives standard deviation of spike rate within given time window across all trials
            % in the TrialArray.
            %
            % Start and stop times are inclusive.
            %
            %
            r = std(obj.spikeRateInHzTimeWindow(clust, startTimeInSec, endTimeInSec),1);
        end


        %         function [h,se] = PSTH(obj, trial_nums, bin_centers)
        %             %
        %             %             [h,x] = PSTH_resampSE(obj, trial_nums, nbins_or_centers_vector, nsamps)
        %             %
        %             %                If varargin% bin centers specified in x.
        %             %
        %             nbins = length(bin_centers);
        %
        %             if length(bin_centers) < 2
        %                 error('Input bin_centers must be a vector of bin centers for histogramming.')
        %             end
        %
        %             ntrials = length(trial_nums);
        %             individualTrialHistograms = zeros(ntrials,nbins);
        %             binWidthInSec = bin_centers(2)-bin_centers(1);  % All bins must be equal size for this transformation to Hz.
        %
        %             n=1;
        %             for k=trial_nums
        %                 ind = find(obj.trialNums==k);
        %                 if isempty(ind) || length(ind)>1
        %                     error(['Trial number' num2str(k) 'is missing or is not unique.'])
        %                 end
        %
        %                 st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
        %                 h0 = hist(st((st>0)), bin_centers); % Before histogramming, remove 0 spike time entries that indicate that no spikes were found.
        %                 individualTrialHistograms(n,:) = h0 ./ binWidthInSec;
        %
        %                 n=n+1;
        %             end
        %
        %             h = mean(individualTrialHistograms,1);
        %             se =  std(individualTrialHistograms,0,1)./ sqrt(ntrials);
        %
        %         end


        function [h,se] = PSTH(obj, trial_nums, bin_centers, varargin)
            %
            %    [h,se] = PSTH(obj, trial_nums, bin_centers, varargin)
            %
            %    varargin{1} specifies optional vector of alignment times of the same size as trial_nums.
            %
            nbins = length(bin_centers);

            if length(bin_centers) < 2
                error('Input bin_centers must be a vector of bin centers for histogramming.')
            end

            if nargin > 3
                alignmentTimes = varargin{1};
                if length(alignmentTimes)~=length(trial_nums)
                    error('Alignment times vector must have same length as trial_nums argument.')
                end
            else
                alignmentTimes = zeros(length(trial_nums),1);
            end

            ntrials = length(trial_nums);
            individualTrialHistograms = zeros(ntrials,nbins);
            binWidthInSec = bin_centers(2)-bin_centers(1);  % All bins must be equal size for this transformation to Hz.

            n=1;
            for k=1:length(trial_nums)
                ind = find(obj.trialNums==trial_nums(k));
                if isempty(ind) || length(ind)>1
                    error(['Trial number ' num2str(trial_nums(k)) ' is missing or is not unique.'])
                end

                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                st = st(st > 0); % IMPORTANT: Before histogramming or subtracting alignment offset, remove 0 spike time entries that indicate that no spikes were found.

                st = st - alignmentTimes(n);
                h0 = hist(st, bin_centers);
                individualTrialHistograms(n,:) = h0 ./ binWidthInSec;
                n=n+1;
            end

            h = mean(individualTrialHistograms,1);
            se =  std(individualTrialHistograms,0,1)./ sqrt(ntrials);

        end
        
        function [h,se] = PSTH_burstSpikes(obj, trial_nums, bin_centers, varargin)
            %
            %    [h,se] = PSTH(obj, trial_nums, bin_centers, varargin)
            %
            %    varargin{1} specifies optional vector of alignment times of the same size as trial_nums.
            %        Can be empty array ([]) placeholder in order to use varargin{2}.
            %
            %     varargin{2} specifies optional instantaneous spike rate threshold
            %       that determines when spikes are considered to be within a
            %       burst.  Default is 100 Hz.
            %
            nbins = length(bin_centers);

            if length(bin_centers) < 2
                error('Input bin_centers must be a vector of bin centers for histogramming.')
            end

            if nargin > 3
                alignmentTimes = varargin{1};
                if isempty(alignmentTimes)
                    alignmentTimes = zeros(length(trial_nums),1);
                elseif length(alignmentTimes)~=length(trial_nums)
                    error('Alignment times vector must have same length as trial_nums argument.')
                end
            else
                alignmentTimes = zeros(length(trial_nums),1);
            end
            if nargin > 4
                InstSpikeRateThresh = varargin{2};
            else
                InstSpikeRateThresh = 100; % Hz.  Note that a default is also defined in SpikesTrial class.
            end

            ntrials = length(trial_nums);
            individualTrialHistograms = zeros(ntrials,nbins);
            binWidthInSec = bin_centers(2)-bin_centers(1);  % All bins must be equal size for this transformation to Hz.

            n=1;
            for k=trial_nums
                ind = find(obj.trialNums==k);
                if isempty(ind) || length(ind)>1
                    error(['Trial number' num2str(k) 'is missing or is not unique.'])
                end

                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.burstSpikeTimes(InstSpikeRateThresh) / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                st = st(st > 0); % IMPORTANT: Before histogramming or subtracting alignment offset, remove 0 spike time entries that indicate that no spikes were found.

                st = st - alignmentTimes(n);
                h0 = hist(st, bin_centers);
                individualTrialHistograms(n,:) = h0 ./ binWidthInSec;
                n=n+1;
            end

            h = mean(individualTrialHistograms,1);
            se =  std(individualTrialHistograms,0,1)./ sqrt(ntrials);

        end


        function R = PSTH_bootstrapped(obj, nboot, trial_nums, bin_centers, varargin)
            %
            %    [h,se] = PSTH_bootstrapped(obj, trial_nums, bin_centers, varargin)
            %
            %    Draws N trials with replacement where N=length(trial_nums), and computes a PSTH
            %       for this sample.  Repeats nboot times.  Returns all nboot PSTHs
            %       in matrix R.  R has dimensions nboot x length(PSTH).
            %
            %
            %
            %    varargin{1} specifies optional vector of alignment times of the same size as trial_nums.
            %
            nbins = length(bin_centers);

            if length(bin_centers) < 2
                error('Input bin_centers must be a vector of bin centers for histogramming.')
            end

            if nargin > 4
                alignmentTimes = varargin{1};
                if length(alignmentTimes)~=length(trial_nums)
                    error('Alignment times vector must have same length as trial_nums argument.')
                end
            else
                alignmentTimes = zeros(length(trial_nums),1);
            end

            ntrials = length(trial_nums);
            individualTrialHistograms = zeros(ntrials,nbins);
            binWidthInSec = bin_centers(2)-bin_centers(1);  % All bins must be equal size for this transformation to Hz.

            n=1;
            for k=trial_nums
                ind = find(obj.trialNums==k);
                if isempty(ind) || length(ind)>1
                    error(['Trial number' num2str(k) 'is missing or is not unique.'])
                end

                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                st = st(st > 0); % IMPORTANT: Before histogramming or subtracting alignment offset, remove 0 spike time entries that indicate that no spikes were found.

                st = st - alignmentTimes(n);
                h0 = hist(st, bin_centers);
                individualTrialHistograms(n,:) = h0 ./ binWidthInSec;
                n=n+1;
            end

            R = zeros(nboot,nbins);
            for k=1:nboot
                resampledTrials = zeros(ntrials,nbins);
                for j=1:ntrials
                    r = randperm(ntrials);
                    resampledTrials(j,:) = individualTrialHistograms(r(1),:);
                end
                R(k,:) = mean(resampledTrials,1);
            end

        end




        function r = get_all_spike_times(obj, trial_nums, clustNum, varargin)
            %
            %     r = get_all_spike_times(obj, trial_nums, varargin)
            %
            %     If trial_nums is empty matrix ([]), all trials are included.
            %
            %     varargin{1} specifies optional vector of alignment times of the same size as trial_nums.
            %       Can be empty array ([]) placeholder in order to use varargin{2}.
            %
            %     varargin{2} specifies optional time window (in seconds; inclusive) to include spikes
            %       from.  Spikes outside this window are ignored. Can be either an
            %       1 X 2 vector with form [startTimeInSec endTimeInSec] in which
            %       case the window is applied to all trials, or an N x 2 matrix
            %       where N = length(trial_nums) that gives a separate window
            %       for each trial in trial_nums.
            %
            %     r is an N x 3 matrix where N is the number of spikes, with form:
            %           [TrialCount BehavioralTrialNumber TimeOfSpike].
            %
            %     Spike times are given in seconds.
            %
            trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            if isempty(trial_nums)
                trial_nums = obj.trialNums;
            end

            ntrials = length(trial_nums);

            if nargin > 4 && ~isempty(varargin{1})
                alignmentTimes = varargin{1};
                if length(alignmentTimes) ~= ntrials
                    error('Alignment times vector must have same length as trial_nums argument.')
                end
            else
                alignmentTimes = zeros(ntrials,1);
            end

            restrictWindow = [];
            if nargin > 5
                restrictWindow = varargin{2};
                if length(restrictWindow)==2
                    restrictWindow = repmat([restrictWindow(1) restrictWindow(2)], [1 ntrials]);
                elseif length(restrictWindow) ~= ntrials
                    error('varargin{2} must be equal length as trial_nums')
                end
            end

            if isempty(restrictWindow)
                r = [];
                for k=1:ntrials
                    ind = find(obj.trialNums==trial_nums(k));
                    st = double(obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes) ./ obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                    if max(st) > 0
                        r = [r; repmat(k,size(st)), repmat(obj.trials{ind}.trialNum,size(st)), st - alignmentTimes(k)];
                    end
                end
            else
                r = [];
                for k=1:ntrials
                    ind = find(obj.trialNums==trial_nums(k));
                    st = double(obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes) ./ obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                    st = st(st >= restrictWindow(k,1) & st <= restrictWindow(k,2));
                    if max(st) > 0
                        r = [r; repmat(k,size(st)), repmat(obj.trials{ind}.trialNum,size(st)), st - alignmentTimes(k)];
                    end
                end
            end

        end

        function r = get_all_interspike_intervals(obj, trial_nums, clustNum, varargin)
            %
            %     r = get_all_interspike_intervals(obj, trial_nums, varargin)
            %
            %     If trial_nums is empty matrix ([]), all trials are included.
            %
            %     varargin{1} specifies optional time window (in seconds; inclusive) to include spikes
            %       from.  Spikes outside this window are ignored. Can be either an
            %       1 X 2 vector with form [startTimeInSec endTimeInSec] in which
            %       case the window is applied to all trials, or an N x 2 matrix
            %       where N = length(trial_nums) that gives a separate window
            %       for each trial in trial_nums.
            %
            %     r is an (N-1) x 3 matrix where N is the number of spikes, with form:
            %           [TrialCount BehavioralTrialNumber TimeBetweenSpikeNAndSpikeN+1].
            %
            %     Interspike intervals are computed separately for each trial that has
            %       more than one spike.  Intervals are given in seconds.
            %
            %
            trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            if isempty(trial_nums)
                trial_nums = obj.trialNums;
            end

            ntrials = length(trial_nums);

            restrictWindow = [];
            if nargin > 3 && ~isempty(varargin{1})
                restrictWindow = varargin{2};
                if length(restrictWindow)==2
                    restrictWindow = repmat([restrictWindow(1) restrictWindow(2)], [1 ntrials]);
                elseif length(restrictWindow) ~= ntrials
                    error('varargin{2} must be equal length as trial_nums')
                end
            end

            if isempty(restrictWindow)
                r = [];
                for k=1:ntrials
                    ind = find(obj.trialNums==trial_nums(k));
                       st = double(obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes) ./ obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                    if numel(st) > 1
                        r = [r; repmat(k,size(st)-[1 0]), repmat(obj.trials{ind}.trialNum,size(st)-[1 0]), diff(st)];
                    end
                end
            else
                r = [];
                for k=1:ntrials
                    ind = find(obj.trialNums==trial_nums(k));
                    st = double(obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes) ./ obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                    st = st(st >= restrictWindow(k,1) & st <= restrictWindow(k,2));
                    if numel(st) > 1
                        r = [r; repmat(k,size(st)-[1 0]), repmat(obj.trials{ind}.trialNum,size(st)-[1 0]), diff(st)];
                    end
                end
            end

        end

        function r = get_all_lick_times(obj, trial_nums, varargin)
            %
            %     r = get_all_lick_times(obj, trial_nums, varargin)
            %
            %     If trial_nums is empty matrix ([]), all trials are included.
            %
            %     varargin{1} specifies optional vector of alignment times of the same size as trial_nums.
            %       Can be empty array ([]) placeholder in order to use varargin{2}.
            %
            %     varargin{2} specifies optional time window (in seconds; inclusive) to include licks
            %       from.  Licks outside this window are ignored. Can be either an
            %       1 X 2 vector with form [startTimeInSec endTimeInSec] in which
            %       case the window is applied to all trials, or an N x 2 matrix
            %       where N = length(trial_nums) that gives a separate window
            %       for each trial in trial_nums.
            %
            %     r is an N x 3 matrix where N is the number of licks, with form:
            %           [TrialCount BehavioralTrialNumber TimeOfLick].
            %
            trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            if isempty(trial_nums)
                trial_nums = obj.trialNums;
            end

            ntrials = length(trial_nums);

            if nargin > 2 && ~isempty(varargin{1})
                alignmentTimes = varargin{1};
                if length(alignmentTimes) ~= ntrials
                    error('Alignment times vector must have same length as trial_nums argument.')
                end
            else
                alignmentTimes = zeros(ntrials,1);
            end

            restrictWindow = [];
            if nargin > 3
                restrictWindow = varargin{2};
                if length(restrictWindow)==2
                    restrictWindow = repmat([restrictWindow(1) restrictWindow(2)], [1 ntrials]);
                elseif length(restrictWindow) ~= ntrials
                    error('varargin{2} must be equal length as trial_nums')
                end
            end

            if isempty(restrictWindow)
                r = [];
                for k=1:ntrials
                    ind = find(obj.trialNums==trial_nums(k));
                    %                     st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes ./ obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                    st = obj.trials{ind}.beamBreakTimes;
                    if ~isempty(st)
                        r = [r; repmat(k,size(st)), repmat(obj.trials{ind}.trialNum,size(st)), st - alignmentTimes(k)];
                    end
                end
            else
                r = [];
                for k=1:ntrials
                    ind = find(obj.trialNums==trial_nums(k));
                    st = obj.trials{ind}.beamBreakTimes;
                    st = st(st >= restrictWindow(k,1) & st <= restrictWindow(k,2));
                    if ~isempty(st)
                        r = [r; repmat(k,size(st)), repmat(obj.trials{ind}.trialNum,size(st)), st - alignmentTimes(k)];
                    end
                end
            end

        end

        function r = get_all_spike_times_burstSpikes(obj, trial_nums, varargin)
            %
            %     r = get_all_spike_times(obj, trial_nums, varargin)
            %
            %     If trial_nums is empty matrix ([]), all trials are included.
            %
            %     varargin{1} specifies optional vector of alignment times of the same size as trial_nums.
            %       Can be empty array ([]) placeholder in order to use varargin{2}.
            %
            %     varargin{2} specifies optional instantaneous spike rate threshold
            %       that determines when spikes are considered to be within a
            %       burst.  Default is 100 Hz.
            %       Can be empty array ([]) placeholder in order to use varargin{2}.
            %
            %     varargin{3} specifies optional time window (in seconds; inclusive) to include spikes
            %       from.  Spikes outside this window are ignored. Can be either an
            %       1 X 2 vector with form [startTimeInSec endTimeInSec] in which
            %       case the window is applied to all trials, or an N x 2 matrix
            %       where N = length(trial_nums) that gives a separate window
            %       for each trial in trial_nums.
            %
            %
            %     r is an N x 3 matrix where N is the number of spikes, with form:
            %           [TrialCount BehavioralTrialNumber TimeOfSpike].
            %
            %
            trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            if isempty(trial_nums)
                trial_nums = obj.trialNums;
            end

            ntrials = length(trial_nums);

            if nargin > 2 && ~isempty(varargin{1})
                alignmentTimes = varargin{1};
                if isempty(alignmentTimes)
                    alignmentTimes = zeros(ntrials,1);
                elseif length(alignmentTimes) ~= ntrials
                    error('Alignment times vector must have same length as trial_nums argument.')
                end
            else
                alignmentTimes = zeros(ntrials,1);
            end

            if nargin > 3 && ~isempty(varargin{2})
                InstSpikeRateThresh = varargin{2};
            else
                InstSpikeRateThresh = 100; % Hz.  Note that a default is also defined in SpikesTrial class.
            end

            restrictWindow = [];
            if nargin > 4
                restrictWindow = varargin{3};
                if length(restrictWindow)==2
                    restrictWindow = repmat([restrictWindow(1) restrictWindow(2)], [1 ntrials]);
                elseif length(restrictWindow) ~= ntrials
                    error('varargin{2} must be equal length as trial_nums')
                end
            end

            if isempty(restrictWindow)
                r = [];
                for k=1:ntrials
                    ind = find(obj.trialNums==trial_nums(k));
                    st = obj.trials{ind}.shanksTrial.clustData{clustNum}.burstSpikeTimes(InstSpikeRateThresh) ./ obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                    if max(st) > 0
                        r = [r; repmat(k,size(st)), repmat(obj.trials{ind}.trialNum,size(st)), st - alignmentTimes(k)];
                    end
                end
            else
                r = [];
                for k=1:ntrials
                    ind = find(obj.trialNums==trial_nums(k));
                    st = obj.trials{ind}.shanksTrial.clustData{clustNum}.burstSpikeTimes(InstSpikeRateThresh) ./ obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                    st = st(st >= restrictWindow(k,1) & st <= restrictWindow(k,2));
                    if max(st) > 0
                        r = [r; repmat(k,size(st)), repmat(obj.trials{ind}.trialNum,size(st)), st - alignmentTimes(k)];
                    end
                end
            end

        end



        function handles = plot_spike_raster(obj, trial_nums, clustNum, varargin)
            %
            %     [] = plot_spike_raster(obj, trial_nums, varargin)
            %
            %     Returns vector of handles to line objects that make up the
            %     raster tick marks.
            %
            %     If trial_nums is empty matrix ([]), all trials are included.
            %
            %     varargin{1} is one of two strings: 'BehavTrialNum', or 'Sequential', and
            %           specifies what values to plot on the y-axis.
            %
            %     varargin{2} specifies optional vector of alignment times of the same size as trial_nums.
            %           Can be empty matrix ([]) to get access to varargin{3}.
            %
            %     varargin{3}, if the string 'lines' is given, raster is plotted with
            %           vertical lines instead of dots.  Dots are the default.
            %


            if nargin==3 % default is to plot in 'Sequential' mode.
                plotTypeString = 'Sequential';
                allSpikeTimes = obj.get_all_spike_times(trial_nums,clustNum);
                plotSymType=0;
            elseif nargin==4
                plotTypeString = varargin{1};
                allSpikeTimes = obj.get_all_spike_times(trial_nums,clustNum);
                plotSymType=0;
            elseif nargin==5
                plotTypeString = varargin{1};
                alignmentTimes = varargin{2};
                allSpikeTimes = obj.get_all_spike_times(trial_nums,clustNum, alignmentTimes);
                plotSymType=0;
            elseif nargin==6
                plotTypeString = varargin{1};
                alignmentTimes = varargin{2};
                plotSymString = varargin{3};
                allSpikeTimes = obj.get_all_spike_times(trial_nums,clustNum, alignmentTimes);
                if strcmp(plotSymString,'lines')
                    plotSymType=1; % plot with lines
                else
                    plotSymType=0; % plot with dots
                end
            else
                error('Too many inputs.')
            end

            % Leave error checking to get_all_spike_times().

            %             cla;
            fs=10;
            switch plotTypeString
                case 'BehavTrialNum'
                    if ~isempty(allSpikeTimes)
                        if plotSymType==0
                            handles = plot(allSpikeTimes(:,3), allSpikeTimes(:,2), 'k.');
                        else
                            x=allSpikeTimes(:,3);
                            y=allSpikeTimes(:,2);
                            yy = [y-.5 y+.5]';
                            xx = [x x]';
                            handles = line(xx,yy,'Color','black');
                        end
                    else
                        handles = [];
                    end
                    ylabel('Behavior trial number','FontSize',fs)
                    xlabel('Sec','FontSize',fs)

                case 'Sequential'
                    if ~isempty(allSpikeTimes)
                        if plotSymType==0
                            handles = plot(allSpikeTimes(:,3), allSpikeTimes(:,1), 'k.');
                        else
                            x=allSpikeTimes(:,3);
                            y=allSpikeTimes(:,1);
                            yy = [y-.5 y+.5]';
                            xx = [x x]';
                            handles = line(xx,yy,'Color','black');
                        end
                    else
                        handles = [];
                    end
                    ylabel('Trial number','FontSize',fs)
                    xlabel('Sec','FontSize',fs)

                otherwise
                    error('Invalid string argument.')
            end
        end

        function handles = plot_lick_raster(obj, trial_nums, varargin)
            %
            %   Plots all beam breaks as rasterplot. 
            %
            %   Returns vector of handles to line objects that make up the
            %   raster tick marks.
            %
            %     [] = plot_lick_raster(obj, trial_nums, varargin)
            %
            %     If trial_nums is empty matrix ([]), all trials are included.
            %
            %     varargin{1} is one of two strings: 'BehavTrialNum', or 'Sequential', and
            %           specifies what values to plot on the y-axis.
            %
            %     varargin{2} specifies optional vector of alignment times of the same size as trial_nums.
            %           Can be empty matrix ([]) to get access to varargin{3}.
            %
            %     varargin{3}, if the string 'lines' is given, raster is plotted with
            %           vertical lines instead of dots.  Dots are the default.
            %
            %
            % NOTE: Will be in register from plot generated by plot_spike_raster, so can be plotted
            %   on the same axes (e.g., after "hold on" command). However, the user must ensure
            %   that the overall time range of the licks and spikes are treated properly. That is,
            %   that both lick times and spike times occur over the range, say, of [0 s, 5 s].
            %
            %

            if nargin==2 % default is to plot in 'Sequential' mode.
                plotTypeString = 'Sequential';
                allLickTimes = obj.get_all_lick_times(trial_nums);
                plotSymType=0;
            elseif nargin==3
                plotTypeString = varargin{1};
                allLickTimes = obj.get_all_lick_times(trial_nums);
                plotSymType=0;
            elseif nargin==4
                plotTypeString = varargin{1};
                alignmentTimes = varargin{2};
                allLickTimes = obj.get_all_lick_times(trial_nums, alignmentTimes);
                plotSymType=0;
            elseif nargin==5
                plotTypeString = varargin{1};
                alignmentTimes = varargin{2};
                plotSymString = varargin{3};
                allLickTimes = obj.get_all_lick_times(trial_nums, alignmentTimes);
                if strcmp(plotSymString,'lines')
                    plotSymType=1; % plot with lines
                else
                    plotSymType=0; % plot with dots
                end
            else
                error('Too many inputs.')
            end

            % Leave error checking to get_all_spike_times().
            %             cla;
            fs=10;
            switch plotTypeString
                case 'BehavTrialNum'
                    if ~isempty(allLickTimes)
                        if plotSymType==0
                            handles = plot(allLickTimes(:,3), allLickTimes(:,2), 'm.');
                        else
                            x=allLickTimes(:,3);
                            y=allLickTimes(:,2);
                            yy = [y-.5 y+.5]';
                            xx = [x x]';
                            handles = line(xx,yy,'Color','magenta');
                        end
                    else
                        handles = [];
                    end
                    ylabel('Behavior trial number','FontSize',fs)
                    xlabel('Sec','FontSize',fs)

                case 'Sequential'
                    if ~isempty(allLickTimes)
                        if plotSymType==0
                            handles = plot(allLickTimes(:,3), allLickTimes(:,1), 'm.');
                        else
                            x=allLickTimes(:,3);
                            y=allLickTimes(:,1);
                            yy = [y-.5 y+.5]';
                            xx = [x x]';
                            handles = line(xx,yy,'Color','magenta');
                        end
                    else
                        handles = [];
                    end
                    ylabel('Trial number','FontSize',fs)
                    xlabel('Sec','FontSize',fs)

                otherwise
                    error('Invalid string argument.')
            end
        end





        function [] = plot_spike_raster_burstSpikes(obj, trial_nums, varargin)
            %
            %     [] = plot_spike_raster_burstSpikes(obj, trial_nums, varargin)
            %
            %     Like plot_spike_raster() except plots only spikes ocurring
            %       as part of a burst.
            %
            %     If trial_nums is empty matrix ([]), all trials are included.
            %
            %     varargin{1} is one of two strings: 'BehavTrialNum', or 'Sequential', and
            %           specifies what values to plot on the y-axis.
            %
            %     varargin{2} specifies optional vector of alignment times of the same size as trial_nums.
            %        Can be empty array ([]) placeholder in order to use varargin{3}.
            %
            %     varargin{3} specifies optional instantaneous spike rate threshold
            %       that determines when spikes are considered to be within a
            %       burst.  Default is 100 Hz.
            %

            if nargin==2 % default is to plot in 'Sequential' mode.
                plotTypeString = 'Sequential';
                allSpikeTimes = obj.get_all_spike_times_burstSpikes(trial_nums);
            elseif nargin==3
                plotTypeString = varargin{1};
                allSpikeTimes = obj.get_all_spike_times_burstSpikes(trial_nums);
            elseif nargin==4
                plotTypeString = varargin{1};
                alignmentTimes = varargin{2};
                if isempty(alignmentTimes)
                    alignmentTimes = zeros(length(trial_nums),1);
                end
                allSpikeTimes = obj.get_all_spike_times_burstSpikes(trial_nums, alignmentTimes);
            elseif nargin==5
                plotTypeString = varargin{1};
                alignmentTimes = varargin{2};
                if isempty(alignmentTimes)
                    alignmentTimes = zeros(length(trial_nums),1);
                end
                InstSpikeRateThresh = varargin{3};
                allSpikeTimes = obj.get_all_spike_times_burstSpikes(trial_nums, alignmentTimes, InstSpikeRateThresh);
            else
                error('Too many inputs.')
            end

            % Leave error checking to get_all_spike_times().


            cla
            switch plotTypeString
                case 'BehavTrialNum'
                    if ~isempty(allSpikeTimes)
                        plot(allSpikeTimes(:,3), allSpikeTimes(:,2), 'k.')
                    end
                    ylabel('Behavior trial number','FontSize',15)
                    xlabel('Sec','FontSize',15)

                case 'Sequential'
                    if ~isempty(allSpikeTimes)
                        plot(allSpikeTimes(:,3), allSpikeTimes(:,1), 'k.')
                    end
                    ylabel('Sequential trial number','FontSize',15)
                    xlabel('Sec','FontSize',15)

                otherwise
                    error('Invalid string argument.')
            end
        end

        function [Y,T] = get_whisker_curvature(obj, tid, varargin)
            %
            %     Y = get_whisker_curvature(obj, tid)
            %     T = get_whisker_curvature(obj, tid, trial_nums)
            %
            %    varargin{1}: Optional vector of trial numbers.
            %    tid: whisker trajectory ID.
            %
            %   Y is cell array of curvature vectors (units of pixels^(-1)).
            %   T is cell array of time vectors of same length as Y (units of seconds). 
            %
            %   
            %
            if nargin > 2
                trial_nums = varargin{1};
                trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            else
                trial_nums = obj.trialNums;
            end
            
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            
            ntrials = length(trial_nums);
            
            Y = cell(1,ntrials);
            T = cell(1,ntrials);
            
            for k=1:ntrials
                ind = find(obj.trialNums==trial_nums(k));
                [y,t] = obj.trials{ind}.whiskerTrial.get_curvature(tid);
                Y{k} = y;
                T{k} = t;
            end
            
        end
        
        function [Y,T] = get_whisker_curvatureDot(obj, tid, varargin)
            %
            %     Y = get_whisker_curvatureDot(obj, tid)
            %     T = get_whisker_curvatureDot(obj, tid, trial_nums)
            %
            %    varargin{1}: Optional vector of trial numbers.
            %    tid: whisker trajectory ID.
            %
            %   Y is cell array of curvatureDot vectors.
            %   T is cell array of time vectors of same length as Y. 
            %
            % 
            if nargin > 2
                trial_nums = varargin{1};
                trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            else
                trial_nums = obj.trialNums;
            end
            
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            
            ntrials = length(trial_nums);
            
            Y = cell(1,ntrials);
            T = cell(1,ntrials);
            
            for k=1:ntrials
                ind = find(obj.trialNums==trial_nums(k));
                [y,t] = obj.trials{ind}.whiskerTrial.get_curvatureDot(tid);
                Y{k} = y;
                T{k} = t;
            end
            
        end
        
        function [Y,T] = get_whisker_position(obj, tid, varargin)
            %
            %     [Y,T] = get_whisker_position(obj, tid)
            %     [Y,T] = get_whisker_position(obj, tid, trial_nums)
            %
            %    varargin{1}: Optional vector of trial numbers.
            %    tid: whisker trajectory ID.
            %
            %   Y is cell array of position vectors.
            %   T is cell array of time vectors of same length as Y.
            %
            %
            if nargin > 2
                trial_nums = varargin{1};
                trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            else
                trial_nums = obj.trialNums;
            end
            
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            
            ntrials = length(trial_nums);
            
            Y = cell(1,ntrials);
            T = cell(1,ntrials);
            
            for k=1:ntrials
                ind = find(obj.trialNums==trial_nums(k));
                [y,t] = obj.trials{ind}.whiskerTrial.get_position(tid);
                Y{k} = y;
                T{k} = t;
            end
            
        end
        
        function [Y,T] = get_mean_whisker_position(obj, varargin)
            %
            %     [Y,T] = get_mean_whisker_position(obj)
            %     [Y,T] = get_mean_whisker_position(obj, trial_nums)
            %
            %    varargin{1}: Optional vector of trial numbers.
            %
            %   Y is cell array of position vectors. Each vector gives
            %   the ***mean position of all whiskers*** (tids) in each trial.
            %   This is for use, e.g., in determining whether there is overall
            %   whisking after fully-automated tracking.
            %
            %   T is cell array of time vectors of same length as Y.
            %
            %
            if nargin > 1
                trial_nums = varargin{1};
                trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            else
                trial_nums = obj.trialNums;
            end
            
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            
            ntrials = length(trial_nums);
            
            Y = cell(1,ntrials);
            T = cell(1,ntrials);
            
            for k=1:ntrials
                ind = find(obj.trialNums==trial_nums(k));
                [y,t] = obj.trials{ind}.whiskerTrial.get_mean_position;
                Y{k} = y;
                T{k} = t;
            end
            
        end
        
        function [Y,T] = get_whisker_velocity(obj, tid, varargin)
            %
            %     Y = get_whisker_velocity(obj, tid)
            %     T = get_whisker_velocity(obj, tid, trial_nums)
            %
            %    varargin{1}: Optional vector of trial numbers.
            %    tid: whisker trajectory ID.
            %
            %   Y is cell array of velocity vectors.
            %   T is cell array of time vectors of same length as Y. 
            %
            % 
            if nargin > 2
                trial_nums = varargin{1};
                trial_nums = trial_nums(ismember(trial_nums, obj.trialNums));
            else
                trial_nums = obj.trialNums;
            end
            
            invalid_trial_nums = setdiff(trial_nums, obj.trialNums);
            if ~isempty(invalid_trial_nums)
                disp(['Warning: requested trials ' num2str(invalid_trial_nums) 'do not exist in TrialArray.']);
            end
            
            ntrials = length(trial_nums);
            
            Y = cell(1,ntrials);
            T = cell(1,ntrials);
            
            for k=1:ntrials
                ind = find(obj.trialNums==trial_nums(k));
                [y,t] = obj.trials{ind}.whiskerTrial.get_velocity(tid);
                Y{k} = y;
                T{k} = t;
            end
            
        end
        
        function r = detectFirstContacts(obj, tid, trial_nums, varargin)
            %
            %   r = detectFirstContacts(obj, tid, trial_nums, varargin)
            %
            % varargin{1}: Optional threshold in units of standard deviation
            % of whisker curvature during baseline period, measured across
            % all trials in trial_nums. Default is 5.
            %
            %
            if nargin > 3
               STD_thresh = varargin{1};
            else
               STD_thresh = 5;%5;
            end
            
            [Y,T] = obj.get_whisker_curvature(tid, trial_nums);
%             [Y,T] = obj.get_whisker_curvatureDot(tid, trial_nums);
            
            baselineTimeEnd = 0.3; % sec
            
            y = cell2mat(Y); %(:));
            t = cell2mat(T); %(:));
            
            t = t + obj.whiskerTrialTimeOffset; % Compensate for any difference between video and physiology triggering times.
            
            thresh = STD_thresh*std(y(t<=baselineTimeEnd),1);
            
            ntrials=length(trial_nums);
            
            r = cell(1,ntrials);
            
            for k=1:ntrials
                t=T{k};
                y=Y{k};
                
                y = y - mean(y(t<=baselineTimeEnd));
                % Find first contact:
                c = t(find((abs(y)>thresh) & (t>0.4) & t <= 1,1,'first'));
                r{k} = c;
%                 
%                 plot(t,y,'k-')
%                 line([min(t) max(t)],[thresh thresh],'Color','r','LineStyle','--')
%                 line([min(t) max(t)],[-thresh -thresh],'Color','r','LineStyle','--')
%                 title(int2str(k)); xlim([0 1.1])
%                 if isempty(c)
%                     title('No contacts')
%                 else
%                     line([c c],[min(y) max(y)],'LineStyle','--','Color','g')
%                 end
%                 pause; cla
            end
        end
        
        
        function r = spikeRateForEpochs(obj, trial_nums, epochs)
            %
            % r = spikeRateForEpochs(obj, trial_nums, epochs)
            %
            %   trial_nums: Vector of trial numbers.
            %
            %   epochs: Cell array of N x 2 matrices, of form
            %       [epoch1StartTime epoch1EndTime
            %       epoch2StartTime epoch2EndTime
            %            .
            %            .
            %       epochNStartTime epochNEndTime].  There is one cell
            %       array element (N x 2 matrix) per trial.
            %
            %       r: cell array of spike rates for each epoch given in
            %           epochs.  r is same length as epochs and each element
            %           is an N x 1 matrix of form [epoch1FiringRate
            %                                   epoch2FiringRate
            %                                   etc].
            %
            %   If an element of epochs is empty, the corresponding
            %   element of output r is also empty.
            %
            %
            %   Size of trial_nums and epochs must match.
            %
            %
            %
            ntrials = length(trial_nums);
            
            if length(epochs) ~= ntrials
                error('Inputs trial_nums and epochs must of of same length.')
            end
            
            r = cell(1,ntrials);
            allSpikes = obj.get_all_spike_times(trial_nums);
            if isempty(allSpikes) % No spikes at all
                return
            end
            for k=1:ntrials
                trialSpikes = allSpikes(allSpikes(:,2)==trial_nums(k),:);
                
                trialEpochs = epochs{k};
                
                if ~isempty(trialEpochs)
                    nepochs = size(trialEpochs,1);
                    epochRates = zeros(1,nepochs);
                    if ~isempty(trialSpikes)
                        for j=1:nepochs
                            epochStart = trialEpochs(j,1); epochEnd = trialEpochs(j,2);
                            epochSpikeCount = length(find(trialSpikes(:,3) >= epochStart & trialSpikes(:,3) <= epochEnd));
                            epochRates(j) = epochSpikeCount / (epochEnd-epochStart); % times are in sec, so rate now in Hz.
                        end
                    end
                    r{k} = epochRates;
                end
            end
        end
        
        
        function [whiskingEpochs,nonWhiskingEpochs] = detectWhiskingEpochs(obj, tid, trial_nums, varargin) 
            %
            %   [whiskingEpochs,nonWhiskingEpochs] = detectWhiskingEpochs(obj, tid, trial_nums, varargin)
            %
            % varargin{1}: Optional 1 x 2 vector of form 
            % [whiskingPercentile nonWhiskingPercentile]. Gives thresholds
            % in units of percentile of 
            % whisker position observations after filtering at whisking frequency,
            % differentiating to get velocity, rectifying, and smoothing to get
            % envelope. Percentile is computed across all trials in trial_nums.
            % Times when signal exceeds whiskingPercentile are scored as
            % ocurring during whisking epochs. Times when signal is below
            % nonWhiskingPercentile are scored as occuring during non-whisking
            % epochs. Default value is [75 25].
            %
            % varargin{2}: Optional span of moving average in units of samples. 
            %   Must be odd. Passed as argument to smooth(x,varargin{2},'moving') 
            %   and used to smooth the whisking-band filtered, differentiated,
            %   rectified whisker position signal in order to get the envelope
            %   of the signal. Default is 15.
            %
            % varargin{3}: Optional threshold for number of contiguous individual
            %   samples that must be scored as whisking (or nonwhisking) 
            %   and contiguous in order for them to be counted as an epoch
            %   of whisking (or non-whisking). Default is 25 
            %   (i.e., 50 ms for 500 Hz sampling).
            %
            % N.B.: Because detectWhiskingEpochs() operates based on percentile
            %   values, it's important to pass trial_nums that include the
            %   full range of whisking behavior. Typically this should include
            %   all or most trials from a behavioral session. 
            %  
            %   Further, it may be necessary to set all parameters separately
            %   for each session after inspection of the data.
            %
            % RETURNS:
            %
            %   whiskingEpochs: a cell array of length(trial_nums).
            %   nonWhiskingEpochs: a cell array of length(trial_nums).
            %       
            %   Each entry of these cell arrays is either empty (if no
            %   epochs were found) or contains an N x 2 matrix of form: 
            %   [epoch1StartTime epoch1EndTime; 
            %    epoch2StartTime epoch2EndTime
            %    etc...                       ]
            %
            %   where N is the number of detected epochs.
            %
            %
            %
            %
            if nargin > 3
                thresholds = varargin{1};
                whiskingPercentile = thresholds(1);
                nonWhiskingPercentile = thresholds(2);
            else
                whiskingPercentile = 75;
                nonWhiskingPercentile = 35;
            end
                           
            if nargin > 4
                span = varargin{2};
                if ~mod(span,2)
                    error('varargin{2} must be an odd integer.')
                end
            else
                span = 31;
            end
            
            if nargin > 5
                minEpochSizeInSamples = varargin{3};
            else
                minEpochSizeInSamples = 25;
            end
            
            ntrials=length(trial_nums);
            
            [Y,T] = obj.get_whisker_position(tid, trial_nums);
             
            % Filter whisker position at whisking frequencies:
            bandPassCutOffsInHz = [5 25];
            
            ind = find(obj.trialNums==trial_nums(1));
            sampleRate = 1 / obj.trials{ind}.whiskerTrial.framePeriodInSec; % Assume all trials taken at same frame rate!!!

%             fp = unique(cellfun(@(x) x.whiskerTrial.framePeriodInSec, obj.trials(trial_nums)));
%             if length(fp) ~= 1
%                 error('detectWhiskingEpochs requires video sampling rate to be same for all trials.')
%             else
%                 sampleRate = 1/fp;
%             end
%             disp(num2str(sampleRate))
            
            
            W1 = bandPassCutOffsInHz(1) / (sampleRate/2);
            W2 = bandPassCutOffsInHz(2) / (sampleRate/2);
            [b,a]=butter(2,[W1 W2]);
            
            % Filter, differentiate, rectify, smooth:
            YY = cell(1,ntrials);
            for k=1:ntrials
                y = Y{k};
                yy = filtfilt(b, a, y);
                yyy = smooth(abs([0 diff(yy)]),span);
                YY{k} = yyy;
%                 t=T{k};
%                 plot(t,y,'k-'); hold on
%                 plot(t,yy,'r-')
%                 plot(t,yyy,'g-')
%                 title(int2str(k)); xlim([0 1.1])
%                 pause; cla
            end

            % Compute percentile values on all samples from trials
            % in trial_nums.  Thresholds are specified in terms of
            % these percentiles.
            y = cell2mat(YY(:));

            thresh_above_whisking = prctile(y,whiskingPercentile);
            thresh_below_nonwhisking = prctile(y,nonWhiskingPercentile);
%             thresh_hysteresis = (thresh_above_whisking + thresh_below_nonwhisking)/2;
            
            whiskingEpochs = cell(1,ntrials);
            nonWhiskingEpochs = cell(1,ntrials);
            for k=1:ntrials
                t=T{k};
                yy=YY{k};
                
                whisking = yy > thresh_above_whisking;
                nonwhisking = yy < thresh_below_nonwhisking;
                
                % Identify contigous blocks ("epochs") of whisking:
                y = whisking; 
                if max(y) > 0
                    runs = LCA.contiguous(y,1); runs = runs{2};
                    len = runs(:,2) - runs(:,1) + 1;
                    runs = runs(len >= minEpochSizeInSamples, :); 
                    runTimes = zeros(size(runs));
                    for j=1:size(runs,1)
                        runTimes(j,:) = t(runs(j,:));
                    end
                    runTimes = runTimes + obj.whiskerTrialTimeOffset; % Compensate for any difference between video and physiology triggering times.
                    whiskingEpochs{k} = runTimes; 
                end
                
                y = nonwhisking;
                if max(y) > 0
                    runs = LCA.contiguous(y,1); runs = runs{2};
                    len = runs(:,2) - runs(:,1) + 1;
                    runs = runs(len >= minEpochSizeInSamples, :);
                    runTimes = zeros(size(runs));
                    for j=1:size(runs,1)
                        runTimes(j,:) = t(runs(j,:));
                    end
                    runTimes = runTimes + obj.whiskerTrialTimeOffset; % Compensate for any difference between video and physiology triggering times.
                    nonWhiskingEpochs{k} = runTimes;
                end
                %---------------------------------------------------------
                %-- Plot to check parameters and performance--------------
                %---------------------------------------------------------
%                 y = Y{k};
%                 %                 plot(t,y,'k-'); hold on
%                 yyy = filtfilt(b, a, y);
%                 ymin = min(yyy); ymax = max(yyy);
%                 hold on
%                 x = whiskingEpochs{k} - obj.whiskerTrialTimeOffset;  
%                 
%                 if ~isempty(x)
%                     for j=1:size(x,1)
% % %                         patch([x(j,1) x(j,1) x(j,2) x(j,2)], [ymin ymax ymax ymin],[1 0 0])
%                           p = patch([x(j,1) x(j,1) x(j,2) x(j,2)], [ymin ymax ymax ymin],[1 0 0],'FaceAlpha',0.2,'EdgeColor','none');
%                           uistack(p,'bottom')
%                     end
%                 end
%                 x = nonWhiskingEpochs{k} - obj.whiskerTrialTimeOffset;
%                 if ~isempty(x)
%                     for j=1:size(x,1)
% % %                         patch([x(j,1) x(j,1) x(j,2) x(j,2)], [ymin ymax ymax ymin],[0 1 0])
%                         p = patch([x(j,1) x(j,1) x(j,2) x(j,2)], [ymin ymax ymax ymin],[0 1 0],'FaceAlpha',0.2,'EdgeColor','none');
%                         uistack(p,'bottom')
%                     end
%                 end
%                 plot(t,yyy,'k-'); hold on
%                 plot(t,yy,'g-')
%                 line([min(t) max(t)],[thresh_above_whisking thresh_above_whisking],'Color','m','LineStyle','--')
%                 line([min(t) max(t)],[thresh_below_nonwhisking thresh_below_nonwhisking],'Color','c','LineStyle','--')
% %                 line([min(t) max(t)],[thresh_hysteresis thresh_hysteresis],'Color','k','LineStyle','--')
%                 title([obj.cellNum obj.cellCode ': ' int2str(k) '/' int2str(ntrials)]); xlim([0 1.1])
%                 pause; cla
                %---------------------------------------------------------
            end            
                      
        end
       
       
       
        function [p,pse,h,hse] = PoissonTestAcrossTrials(obj, trial_nums, bin_centers)
            %
            % [p,pse,h,hse] = PoissonTestAcrossTrials(obj, trial_nums, bin_centers)
            %
            %
            %
            nbins = length(bin_centers);

            if length(bin_centers) < 2
                error('Input bin_centers must be a vector of bin centers for histogramming.')
            end

            ntrials = length(trial_nums);
            individualTrialHistograms = zeros(ntrials,nbins);

            n=1;
            for k=trial_nums
                ind = find(obj.trialNums==k);
                if isempty(ind) || length(ind)>1
                    error(['Trial number' num2str(k) 'is missing or is not unique.'])
                end

                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                h0 = hist(st((st>0)), bin_centers); % Before histogramming, remove 0 spike time entries that indicate that no spikes were found.
                individualTrialHistograms(n,:) = h0; % spike count for bin
                n=n+1;
            end

            h = mean(individualTrialHistograms,1);
            hse =  std(individualTrialHistograms,0,1)./ sqrt(ntrials);

            lambda = repmat(h, [ntrials 1]);

            y = poisspdf(individualTrialHistograms, lambda);

            p = mean(y,1);
            pse =  std(y,0,1)./ sqrt(ntrials);
        end
        
        function [spikeRateDiff, spikeRateDiffShuffled, pval] = PermutationTest_SpikeRateDiffInWindows(obj, ...
                trial_nums, time_window_in_sec_1, time_window_in_sec_2, nsamps)
            %
            %   [spikeRateDiff, spikeRateDiffResampled, pval] = PermutationTest_SpikeRateDiffInWindows(obj, ...
            %   trial_nums, time_window_in_sec_1, time_window_in_sec_2, nsamps)
            %
            %   time_window_in_sec_1: [startTime stopTime].
            %   time_window_in_sec_2: [startTime stopTime].
            %   
            %   For time windows, startTime and stopTime are inclusive.
            %
            %   Tests for statistical significance of a difference in mean firing rates 
            %   specified by two time windows, rate(time_window_in_sec_2) - rate(time_window_in_sec_1).
            %   
            %   Method: 
            %   1. Get firing rate in both time windows for every trial, R2_i, R1_i.
            %   2. Calculate true difference in mean firing rate, spikeRateDiff = <R2> - <R1>.
            %   3. Repeat nsamps times: 
            %       -Shuffle labels (R1 vs. R2: i.e., which time window is which).
            %       -Compute spikeRateDiffShuffled = <R2_shuff> - <R1_shuff>.
            %   4. Compute pval as 1 minus fraction of shuffled values as or more extreme than
            %      true spikeRateDiff, making a two-tailed test. 
            %     
            %
            ntrials = length(trial_nums);
           
            R1 = obj.spikeRateInHzTimeWindow(time_window_in_sec_1(1), time_window_in_sec_1(2));
            R2 = obj.spikeRateInHzTimeWindow(time_window_in_sec_2(1), time_window_in_sec_2(2));
            
            ind = ismember(obj.trialNums, trial_nums);
            
            notFound = setdiff(trial_nums,obj.trialNums);
            if ~isempty(notFound)
                error(['The following trial numbers from argument trial_nums were not found: ' num2str(notFound)])
            end
            
            R1 = R1(ind);
            R2 = R2(ind);
            
            spikeRateDiff = mean(R2) - mean(R1);
            
            R = [R1 R2];
            spikeRateDiffShuffled = zeros(nsamps,1);

            for k=1:nsamps
                r = randperm(2*ntrials);
                R1shuf = R(r(1:ntrials));
                R2shuf = R(r((ntrials+1):end));
                spikeRateDiffShuffled(k) = mean(R2shuf) - mean(R1shuf);
            end

            y = 0.001:.001:1;
            x = quantile(spikeRateDiffShuffled, y);
            [x,I,junk] = unique(x); y = y(I); % throw out non-unique x values so can use interp1
            
            if spikeRateDiff > max(spikeRateDiffShuffled) || spikeRateDiff < min(spikeRateDiffShuffled)
                pval = 1/nsamps; % rather,  pval < 1/nsamps.
                %                 title(['P < ' num2str(pval)])
            elseif sum(spikeRateDiffShuffled~=0)==0 && spikeRateDiff==0  % Spike rate difference always exactly 0
                pval = 1;
                %                 title(['P = ' num2str(pval)])
            else
                yi = interp1(x,y,spikeRateDiff);
                % Two-tailed test:
                if yi <= 0.5
                    pval = 2*yi;
                elseif yi > 0.5
                    pval = 2*(1-yi);
                else
                    error(['yi = ' int2str(yi)]) % Must be NaN
                end
            end
            
%             figure; subplot(121); plot(x,y); xlabel('Resampled difference in spike rates'); ylabel('Quantile')
%             subplot(122)
%             hist(spikeRateDiffShuffled); hold on
%             plot(spikeRateDiff, 1, 'r*')
%             set(gca, 'box','off')
%             xlabel('Spike rate difference, <R2>-<R1>')
%             ylabel(['Count out of ' num2str(nsamps) ' resamples'])
%             title(['P = ' num2str(pval)])             
        end

        function [spikeCountDiff, spikeCountDiffShuffled, pval] = PermutationTest_SpikeCountDiffExpectedVsEvoked(obj, ...
                trial_nums, baseline_time_window_in_sec, evoked_time_window_in_sec, nsamps)
            %
            %   [spikeCountDiff, spikeCountDiffShuffled, pval] = PermutationTest_SpikeCountDiffExpectedVsEvoked(obj, ...
            %    trial_nums, baseline_time_window_in_sec, evoked_time_window_in_sec, nsamps)
            %
            %   baseline_time_window_in_sec: [startTime stopTime].
            %   evoked_time_window_in_sec: [startTime stopTime].
            %
            %   For time windows, startTime and stopTime are inclusive.
            %
            %   Tests for statistical significance of a difference in spike count expected
            %   from a baseline rate and actually obtained:
            %   Rate(baseline_time_window_in_sec)*deltaTimeForEvokedPeriod - Count(evoked_time_window_in_sec).
            %
            %   Method:
            %   1. Get expected spike count and evoked spike count for every trial, Cexp_i, Cevk_i.
            %   2. Calculate true difference in these counts, spikeCountDiff = <Cevk> - <Cexp>.
            %   3. Repeat nsamps times:
            %       -Shuffle labels (Cexp vs. Cevk: i.e., which count is expected and which actually evoked).
            %       -Compute spikeCountDiffShuffled = <Cevk_shuff> - <Cexp_shuff>.
            %   4. Compute pval as 1 minus fraction of shuffled values as or more extreme than
            %      true spikeCountDiff, making a two-tailed test.
            %
            %
            ntrials = length(trial_nums);
            
            deltaTimeInSec = evoked_time_window_in_sec(2)-evoked_time_window_in_sec(1);
            
            Cevk = obj.spikeCountInTimeWindow(evoked_time_window_in_sec(1), evoked_time_window_in_sec(2));
            Cexp = obj.spikeRateInHzTimeWindow(baseline_time_window_in_sec(1), baseline_time_window_in_sec(2)) * deltaTimeInSec;
            
            ind = ismember(obj.trialNums, trial_nums);
            
            notFound = setdiff(trial_nums,obj.trialNums);
            if ~isempty(notFound)
                error(['The following trial numbers from argument trial_nums were not found: ' num2str(notFound)])
            end
            
            Cevk = Cevk(ind);
            Cexp = Cexp(ind);
            
            spikeCountDiff = mean(Cevk) - mean(Cexp);
            
            C = [Cevk Cexp];
            spikeCountDiffShuffled = zeros(nsamps,1);
            
            for k=1:nsamps
                r = randperm(2*ntrials);
                Cevk_shuf = C(r(1:ntrials));
                Cexp_shuf = C(r((ntrials+1):end));
                spikeCountDiffShuffled(k) = mean(Cevk_shuf) - mean(Cexp_shuf);
            end
            
            y = 0.001:.001:1;
            x = quantile(spikeCountDiffShuffled, y);
            [x,I,junk] = unique(x); y = y(I); % throw out non-unique x values so can use interp1
            
            
            %             if spikeCountDiff > max(spikeCountDiffShuffled) || spikeCountDiff < min(spikeCountDiffShuffled)
            %                 pval = 1/nsamps; % rather,  pval < 1/nsamps.
            %             elseif sum(spikeCountDiffShuffled~=0)==0 && spikeCountDiff==0  % Spike count difference always exactly 0
            %                 pval = 1;
            %             else
            %                 yi = interp1(x,y,spikeCountDiff);
            %                 % Two-tailed test:
            %                 if yi <= 0.5
            %                     pval = 2*yi; % Instead of assuming symmetric distribution should do yii=interp1(x,y,-spikeCountDiff); pval = yi +
            %                 elseif yi > 0.5
            %                     pval = 2*(1-yi);
            %                 else
            %                     error(['yi = ' int2str(yi)]) % Must be NaN
            %                 end
            %             end
            
            if spikeCountDiff > max(spikeCountDiffShuffled) || spikeCountDiff < min(spikeCountDiffShuffled)
                pval = 1/nsamps; % rather,  pval < 1/nsamps.
            elseif sum(spikeCountDiffShuffled~=0)==0 && spikeCountDiff==0  % Spike count difference always exactly 0
                pval = 1;
            else
                yi = interp1(x,y,spikeCountDiff);
                yii = interp1(x,y,-spikeCountDiff);
                % Two-tailed test:
                if yi <= 0.5
                    if isnan(yii)
                        yii = 1;
                    end
                    pval = yi + (1-yii);
                elseif yi > 0.5
                    if isnan(yii)
                        yii = 0;
                    end
                    pval = (1-yi) + yii;
                else
                    error(['yi = ' num2str(yi) ,'yii=' num2str(yii)]) % Must be NaN
                end
            end
            
            %             figure; subplot(121); plot(x,y); xlabel('Resampled difference in spike count'); ylabel('Quantile')
            %             subplot(122)
            %             hist(spikeCountDiffShuffled); hold on
            %             plot(spikeCountDiff, 1, 'r*')
            %             set(gca, 'box','off')
            %             xlabel('Spike count difference, <C_{evoked}>-<C_{expected}>')
            %             ylabel(['Count out of ' num2str(nsamps) ' resamples'])
            %             title(['P = ' num2str(pval)])
        end


        function [distanceIndex, distanceIndexResampled, pval] = PermutationTest_DistanceIndex(obj, trial_nums1, ...
                trial_nums2, histogram_bin_centers, nsamps, varargin)
            %
            %   [distanceIndex, distanceIndexResampled, pval] = ...
            %       PermutationTest_DistanceIndex(obj, trial_nums1, trial_nums2, histogram_bin_centers, nsamps, varargin)
            %
            % Distance Index (DI) from book Methods for Neural Ensemble Recordings, 2nd Ed., Nicolelis editor.
            % Simply the Euclidean distance between the two matched PSTHs.
            %
            % varargin{1} is optional specification of region of times within histograms to
            %   restrict distance index calculation to.  Form is a 1 x 2 vector of
            %   form [startTimeInclusive stopTimeInclusive]. Restriction applies to *bin centers*,
            %   so the raw data that go into the histogram are really restricted to
            %   [startTimeInclusive - 1/2 * binwidth, startTimeInclusive + 1/2 * binwidth].
            %

            nbins = length(histogram_bin_centers);

            if length(histogram_bin_centers) < 2
                error('Input histogram_bin_centers must be a vector of bin centers for histogramming.')
            end

            ntrials1 = length(trial_nums1);
            ntrials2 = length(trial_nums2);
            ntrialsTotal = ntrials1 + ntrials2;

            individualTrialHistograms = zeros(ntrialsTotal, nbins);

            binWidthInSec = histogram_bin_centers(2)-histogram_bin_centers(1);  % All bins must be equal size for this transformation to Hz.
            
            trialNums = obj.trialNums; % keep this out of any loops; it's slow.
            
            n=1;
            for k=[trial_nums1 trial_nums2]
                ind = trialNums==k;
                if sum(ind) ~= 1 
                    error(['Trial number' num2str(k) 'is missing or is not unique.'])
                end
                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;
                                
                h0 = hist(st((st>0)), histogram_bin_centers); % Before histogramming, remove 0 spike time entries that indicate that no spikes were found.
                individualTrialHistograms(n,:) = h0 ./ binWidthInSec;
                n=n+1;
            end

            if nargin > 5
                region = varargin{1};
                if numel(region) ~= 2
                    error('varargin{1} must be 1 x 2 vector of times.')
                end
                startTimeInclusive = region(1);
                stopTimeInclusive = region(2);

                ind = histogram_bin_centers >= startTimeInclusive & histogram_bin_centers <= stopTimeInclusive;
                individualTrialHistograms = individualTrialHistograms(:,ind);
            end

            histMean1 = mean(individualTrialHistograms(1:ntrials1,:),1);
            histMean2 = mean(individualTrialHistograms((ntrials1+1):end,:),1);

            distanceIndex = sqrt(sum((histMean2-histMean1).^2));

            % Do permutation test by shuffling labels for two groups of trials.
            distanceIndexResampled = zeros(nsamps,1); n=1;
            for k=1:nsamps
                r = randperm(ntrialsTotal);
                trialsSet1 = r(1:ntrials1);
                trialsSet2 = r((ntrials1+1):end);
                histMean1 = mean(individualTrialHistograms(trialsSet1,:),1);
                histMean2 = mean(individualTrialHistograms(trialsSet2,:),1);
                distanceIndexResampled(n) = sqrt(sum((histMean2-histMean1).^2));
                n=n+1;
            end

            y = 0.001:.001:1;
            x = quantile(distanceIndexResampled, y);
            [x,I,junk] = unique(x); y = y(I); % throw out non-unique x values so can use interp1


            %   figure; plot(x,y); xlabel('Resampled distance index'); ylabel('Quantile')
            %             figure;
            %             hist(distanceIndexResampled); hold on
            %             plot(distanceIndex, 1, 'r*')
            %             set(gca, 'box','off')
            %             xlabel('Euclidean distance between histograms')
            %             ylabel(['Count out of ' num2str(nsamps) ' resamples'])

            if distanceIndex > max(distanceIndexResampled)
                pval = 1/nsamps; % rather,  pval < 1/nsamps.
                %                 title(['P < ' num2str(pval)])
            elseif length(x)==1 % No spikes
                pval = 1;
                %                 title(['P = ' num2str(pval)])
            else
                yi = interp1(x,y,distanceIndex);
                pval = 1-yi;
                %                 title(['P = ' num2str(pval)])
            end
        end


        function [distanceIndex, distanceIndexResampled, pval] = ...
                PermutationTest_DistanceIndex_burstSpikes(obj, trial_nums1, trial_nums2, histogram_bin_centers, nsamps, varargin)
            %
            %
            % Distance Index (DI) from book Methods for Neural Ensemble Recordings, 2nd Ed., Nicolelis editor.
            % Simply the Euclidean distance between the two matched PSTHs.
            %
            % Applied to timeseries of spikes occuring in bursts.
            %
            % varargin{1} is optional specification of region of times within histograms to
            %   restrict distance index calculation to.  Form is a 1 x 2 vector of
            %   form [startTimeInclusive stopTimeInclusive]. Restriction applies to *bin centers*,
            %   so the raw data that go into the histogram are really restricted to
            %   [startTimeInclusive - 1/2 * binwidth, startTimeInclusive + 1/2 * binwidth].
            %   Can be empty array ([]) placeholder in order to use varargin{2}.
            %
            % varargin{2} specifies optional instantaneous spike rate threshold
            %       that determines when spikes are considered to be within a
            %       burst.  Default is 100 Hz.
            %

            nbins = length(histogram_bin_centers);

            if length(histogram_bin_centers) < 2
                error('Input histogram_bin_centers must be a vector of bin centers for histogramming.')
            end

            ntrials1 = length(trial_nums1);
            ntrials2 = length(trial_nums2);
            ntrialsTotal = ntrials1 + ntrials2;

            individualTrialHistograms = zeros(ntrialsTotal, nbins);

            binWidthInSec = histogram_bin_centers(2)-histogram_bin_centers(1);  % All bins must be equal size for this transformation to Hz.

            if nargin > 6
                InstSpikeRateThresh = varargin{2};
            else
                InstSpikeRateThresh = 100; % Hz.  Note that a default is also defined in SpikesTrial class.
            end

            trialNums = obj.trialNums; % keep this out of any loops; it's slow.
            n=1;
            for k=[trial_nums1 trial_nums2]
                ind = trialNums==k;
                if sum(ind) ~= 1
                    error(['Trial number' num2str(k) 'is missing or is not unique.'])
                end
                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.burstSpikeTimes(InstSpikeRateThresh) / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;

                h0 = hist(st((st>0)), histogram_bin_centers); % Before histogramming, remove 0 spike time entries that indicate that no spikes were found.
                individualTrialHistograms(n,:) = h0 ./ binWidthInSec;
                n=n+1;
            end

            if nargin > 5 && ~isempty(varargin{1})
                region = varargin{1};
                if numel(region) ~= 2
                    error('varargin{1} must be 1 x 2 vector of times.')
                end
                startTimeInclusive = region(1);
                stopTimeInclusive = region(2);

                ind = histogram_bin_centers >= startTimeInclusive & histogram_bin_centers <= stopTimeInclusive;
                individualTrialHistograms = individualTrialHistograms(:,ind);
            end

            histMean1 = mean(individualTrialHistograms(1:ntrials1,:),1);
            histMean2 = mean(individualTrialHistograms((ntrials1+1):end,:),1);

            distanceIndex = sqrt(sum((histMean2-histMean1).^2));

            % Do permutation test by shuffling labels for two groups of trials.
            distanceIndexResampled = zeros(nsamps,1); n=1;
            for k=1:nsamps
                r = randperm(ntrialsTotal);
                trialsSet1 = r(1:ntrials1);
                trialsSet2 = r((ntrials1+1):end);
                histMean1 = mean(individualTrialHistograms(trialsSet1,:),1);
                histMean2 = mean(individualTrialHistograms(trialsSet2,:),1);
                distanceIndexResampled(n) = sqrt(sum((histMean2-histMean1).^2));
                n=n+1;
            end

            y = 0.001:.001:1;
            x = quantile(distanceIndexResampled, y);
            [x,I,junk] = unique(x); y = y(I); % throw out non-unique x values so can use interp1


            %   figure; plot(x,y); xlabel('Resampled distance index'); ylabel('Quantile')
            %             figure;
            %             hist(distanceIndexResampled); hold on
            %             plot(distanceIndex, 1, 'r*')
            %             set(gca, 'box','off')
            %             xlabel('Euclidean distance between histograms')
            %             ylabel(['Count out of ' num2str(nsamps) ' resamples'])

            if distanceIndex > max(distanceIndexResampled)
                pval = 1/nsamps; % rather,  pval < 1/nsamps.
                %                 title(['P < ' num2str(pval)])
            elseif length(x)==1 % No spikes
                pval = 1;
                %                 title(['P = ' num2str(pval)])
            else
                yi = interp1(x,y,distanceIndex);
                pval = 1-yi;
                %                 title(['P = ' num2str(pval)])
            end


        end

        function [stat, statResampled, pval] = ...
                PermutationTest_PeakAbsSpikeRateChange(obj, trial_nums1, trial_nums2, histogram_bin_centers, baseline_bins, nsamps, varargin)
            %
            %
            % Calculates shuffle-test significance of difference in peak absolute value of firing rate
            %   change between the two groups of trials.  Absolute difference is used to accomodate
            %   cells that get quiet upon stimulation.
            %
            % Note that by this measure if in trial set A the spike rate goes up 1 unit
            %   and in set B the rate goes down by 1 unit, these will be scored as
            %   equal (ie, as having a absolute value change of 1 unit).  Assumption is that
            %   downstream decoder is simply looking for biggest change.
            %
            % baseline_bins are the indices (1, 2, 3, etc) of the bins specified in
            %   histogram_bin_centers that should be used to calculate baseline firing rate.
            %
            % Take absolute value of difference in order to make a one-tailed test.
            %
            % varargin{1} is optional specification of region of times within histograms to
            %   restrict calculation to.  Form is a 1 x 2 vector of
            %   form [startTimeInclusive stopTimeInclusive]. Restriction applies to *bin centers*,
            %   so the raw data that go into the histogram are really restricted to
            %   [startTimeInclusive - 1/2 * binwidth, startTimeInclusive + 1/2 * binwidth].
            %

            nbins = length(histogram_bin_centers);

            if length(histogram_bin_centers) < 2
                error('Input histogram_bin_centers must be a vector of bin centers for histogramming.')
            end

            ntrials1 = length(trial_nums1);
            ntrials2 = length(trial_nums2);
            ntrialsTotal = ntrials1 + ntrials2;

            individualTrialHistograms = zeros(ntrialsTotal, nbins);

            binWidthInSec = histogram_bin_centers(2)-histogram_bin_centers(1);  % All bins must be equal size for this transformation to Hz.

            trialNums = obj.trialNums; % keep this out of any loops; it's slow.
            n=1;
            for k=[trial_nums1 trial_nums2]
                ind = trialNums==k;
                if sum(ind) ~= 1
                    error(['Trial number' num2str(k) 'is missing or is not unique.'])
                end
                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;

                h0 = hist(st((st>0)), histogram_bin_centers); % Before histogramming, remove 0 spike time entries that indicate that no spikes were found.
                individualTrialHistograms(n,:) = h0 ./ binWidthInSec;
                n=n+1;
            end

            if nargin > 6
                region = varargin{1};
                if numel(region) ~= 2
                    error('varargin{1} must be 1 x 2 vector of times.')
                end
                startTimeInclusive = region(1);
                stopTimeInclusive = region(2);

                ind = histogram_bin_centers >= startTimeInclusive & histogram_bin_centers <= stopTimeInclusive;
                individualTrialHistograms = individualTrialHistograms(:,ind);
            end

            histMean1 = mean(individualTrialHistograms(1:ntrials1,:),1);
            histMean2 = mean(individualTrialHistograms((ntrials1+1):end,:),1);

            histMean1 = histMean1 - mean(histMean1(baseline_bins)); % baseline subtract
            histMean2 = histMean2 - mean(histMean2(baseline_bins));

            stat = abs(max(abs(histMean2)) - max(abs(histMean1))); % Difference in maximum abs. value spike rate changes.

            % Do permutation test by shuffling labels for two groups of trials.
            statResampled = zeros(nsamps,1); n=1;
            for k=1:nsamps
                r = randperm(ntrialsTotal);
                trialsSet1 = r(1:ntrials1);
                trialsSet2 = r((ntrials1+1):end);
                histMean1 = mean(individualTrialHistograms(trialsSet1,:),1);
                histMean2 = mean(individualTrialHistograms(trialsSet2,:),1);
                statResampled(n) = abs(max(abs(histMean2)) - max(abs(histMean1))); % Difference in maximum abs. value spike rate changes.
                n=n+1;
            end

            y = 0.001:.001:1;
            x = quantile(statResampled, y);
            [x,I,junk] = unique(x); y = y(I); % throw out non-unique x values so can use interp1


            %   figure; plot(x,y); xlabel('Resampled distance index'); ylabel('Quantile')
            %             figure;
            %             hist(distanceIndexResampled); hold on
            %             plot(distanceIndex, 1, 'r*')
            %             set(gca, 'box','off')
            %             xlabel('Euclidean distance between histograms')
            %             ylabel(['Count out of ' num2str(nsamps) ' resamples'])

            if stat > max(statResampled)
                pval = 1/nsamps; % rather,  pval < 1/nsamps.
                %                 title(['P < ' num2str(pval)])
            elseif length(x)==1 % No spikes
                pval = 1;  % OR SHOULD THIS BE 0.5?
                %                 title(['P = ' num2str(pval)])
            elseif stat < min(statResampled)
                pval = 1;
            else
                yi = interp1(x,y,stat);
                pval = 1-yi;
                %                 title(['P = ' num2str(pval)])
            end

        end


        function [stat, statResampled, pval] = ...
                PermutationTest_SpikeCount(obj, trial_nums1, trial_nums2, nsamps, varargin)
            % function [stat, statResampled, pval] = ...
            %      PermutationTest_SpikeCount(obj, trial_nums1, trial_nums2, nsamps, varargin)
            %
            %
            % Calculates shuffle-test significance of simple count of number of spikes per trial
            %   difference between the two groups of trials.  Takes absolute value of spike count
            %   difference in order to make one-tailed test.
            %
            % varargin{1} is optional specification of region of times to
            %   restrict spike counts to.  Form is a 1 x 2 vector of
            %   form [startTimeInclusive stopTimeInclusive]. Default is full period
            %   of each trial.
            %

            ntrials1 = length(trial_nums1);
            ntrials2 = length(trial_nums2);
            ntrialsTotal = ntrials1 + ntrials2;

            individualTrialSpikeCounts = zeros(1,ntrialsTotal);

            if nargin > 4
                region = varargin{1};
                if numel(region) ~= 2
                    error('varargin{1} must be 1 x 2 vector of times.')
                end
                startTimeInclusive = region(1);
                stopTimeInclusive = region(2);
            else
                startTimeInclusive = NaN; % set flag to indicate that we'll take spikes from full trial
                stopTimeInclusive = NaN;  % set flag to indicate that we'll take spikes from full trial
            end

            trialNums = obj.trialNums; % keep this out of any loops; it's slow.
            n=1;
            for k=[trial_nums1 trial_nums2]
                ind = trialNums==k;
                if sum(ind) ~= 1
                    error(['Trial number' num2str(k) 'is missing or is not unique.'])
                end
                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;

                st = st(st>0); % Very important: get rid of 0 entries indicating no spikes.

                if ~isnan(startTimeInclusive)
                    st = st(st >= startTimeInclusive & st <= stopTimeInclusive);
                end

                individualTrialSpikeCounts(n) = numel(st);
                n=n+1;
            end


            countMean1 = mean(individualTrialSpikeCounts(1:ntrials1));
            countMean2 = mean(individualTrialSpikeCounts((ntrials1+1):end));

            stat = abs(countMean1 - countMean2);  % Simple absolute value of difference in spike count.

            % Do permutation test by shuffling labels for two groups of trials.
            statResampled = zeros(nsamps,1); n=1;
            for k=1:nsamps
                r = randperm(ntrialsTotal);
                trialsSet1 = r(1:ntrials1);
                trialsSet2 = r((ntrials1+1):end);
                countMean1 = mean(individualTrialSpikeCounts(trialsSet1));
                countMean2 = mean(individualTrialSpikeCounts(trialsSet2));
                statResampled(n) = abs(countMean1 - countMean2);  % Simple absolute value of difference in spike count.
                n=n+1;
            end

            y = 0.001:.001:1;
            x = quantile(statResampled, y);
            [x,I,junk] = unique(x); y = y(I); % throw out non-unique x values so can use interp1


            %   figure; plot(x,y); xlabel('Resampled distance index'); ylabel('Quantile')
            %             figure;
            %             hist(distanceIndexResampled); hold on
            %             plot(distanceIndex, 1, 'r*')
            %             set(gca, 'box','off')
            %             xlabel('Euclidean distance between histograms')
            %             ylabel(['Count out of ' num2str(nsamps) ' resamples'])

            if stat > max(statResampled)
                pval = 1/nsamps; % rather,  pval < 1/nsamps.
                %                 title(['P < ' num2str(pval)])
            elseif length(x)==1 % No spikes
                pval = 1;  % OR SHOULD THIS BE 0.5?
                %                 title(['P = ' num2str(pval)])
            else
                yi = interp1(x,y,stat);
                pval = 1-yi;
                %                 title(['P = ' num2str(pval)])
            end

        end
        
        function [spikeCountDiff, spikeCountDiffShuffled, pval] = PermutationTest_SpikeCountDiff(obj, ...
                trial_nums1, trial_nums2, time_window_in_sec, nsamps)
            %
            %   [spikeCountDiff, spikeCountDiffShuffled, pval] = PermutationTest_SpikeCountDiff(obj, ...
            %     trial_nums1, trial_nums2, time_window_in_sec, nsamps)
            %
            %   time_window_in_sec: [startTime stopTime].
            %
            %   For time windows, startTime and stopTime are inclusive.
            %
            %   Tests for statistical significance of a difference in mean spike count for the
            %   two groups of trials specified by trials_nums1 and trial_nums2, in the time period
            %   specified by time_window_in_sec.
            %
            %   Method:
            %   1. Get spike counts for each trial in each group of trials, C1_i, C2_i.
            %   2. Calculate true difference in these counts, spikeCountDiff = <C1> - <C2>.
            %   3. Repeat nsamps times:
            %       -Shuffle labels (C1 vs. C2: i.e., the group assignment of each trial).
            %       -Compute spikeCountDiffShuffled = <C1_shuff> - <C2_shuff>.
            %   4. Compute pval as 1 minus fraction of shuffled values as or more extreme than
            %      true spikeCountDiff, making a two-tailed test.
            %
            %                     
            r = obj.spikeCountInTimeWindow(time_window_in_sec(1), time_window_in_sec(2));
            
            ind1 = ismember(obj.trialNums, trial_nums1);
            ind2 = ismember(obj.trialNums, trial_nums2);
            
            notFound1 = setdiff(trial_nums1,obj.trialNums);
            notFound2 = setdiff(trial_nums2,obj.trialNums);
            
            if ~isempty(notFound1)
                error(['The following trial numbers from argument trial_nums1 were not found: ' num2str(notFound1)])
            end
            if ~isempty(notFound2)
                error(['The following trial numbers from argument trial_nums2 were not found: ' num2str(notFound2)])
            end
            
            C1 = r(ind1);
            C2 = r(ind2);
            
            spikeCountDiff = mean(C1) - mean(C2);
            
            C = [C1 C2];
            spikeCountDiffShuffled = zeros(nsamps,1);
            
            numC1 = length(C1);
            numC2 = length(C2);
            
            for k=1:nsamps
                r = randperm(numC1 + numC2);
                C1_shuf = C(r(1:numC1));
                C2_shuf = C(r((numC1+1):end));
                spikeCountDiffShuffled(k) = mean(C1_shuf) - mean(C2_shuf);
            end
            
            y = 0.001:.001:1;
            x = quantile(spikeCountDiffShuffled, y);
            [x,I,junk] = unique(x); y = y(I); % throw out non-unique x values so can use interp1
            
%             if spikeCountDiff > max(spikeCountDiffShuffled) || spikeCountDiff < min(spikeCountDiffShuffled)
%                 pval = 1/nsamps; % rather,  pval < 1/nsamps.
%             elseif sum(spikeCountDiffShuffled~=0)==0 && spikeCountDiff==0  % Spike count difference always exactly 0
%                 pval = 1;
%             else
%                 yi = interp1(x,y,spikeCountDiff);
%                 if isnan(yi)
%                     yi = interp1(x,y,spikeCountDiff,'linear','extrap'); % spikeCountDiff can, rarely, exceed min/max of x.
%                 end
%                 % Two-tailed test:
%                 if yi <= 0.5
%                     pval = 2*yi;
%                 elseif yi > 0.5
%                     pval = 2*(1-yi);
%                 else
%                     error(['yi = ' int2str(yi)]) % Must be NaN
%                 end
%             end
            
            if spikeCountDiff > max(spikeCountDiffShuffled) || spikeCountDiff < min(spikeCountDiffShuffled)
                pval = 1/nsamps; % rather,  pval < 1/nsamps.
            elseif sum(spikeCountDiffShuffled~=0)==0 && spikeCountDiff==0  % Spike count difference always exactly 0
                pval = 1;
            else
                yi = interp1(x,y,spikeCountDiff);
                yii = interp1(x,y,-spikeCountDiff);
                % Two-tailed test:
                if yi <= 0.5
                    if isnan(yii)
                        yii = 1;
                    end
                    pval = yi + (1-yii);
                elseif yi > 0.5
                    if isnan(yii)
                        yii = 0;
                    end
                    pval = (1-yi) + yii;
                else
                    error(['yi = ' num2str(yi) ,'yii=' num2str(yii)]) % Must be NaN
                end
            end

            
            
%             figure; subplot(121); plot(x,y); xlabel('Resampled difference in mean spike count'); ylabel('Quantile')
%             subplot(122)
%             hist(spikeCountDiffShuffled); hold on
%             plot(spikeCountDiff, 1, 'r*')
%             set(gca, 'box','off')
%             xlabel('Spike count difference, <C_1> - <C_2>')
%             ylabel(['Count out of ' num2str(nsamps) ' resamples'])
%             title(['P = ' num2str(pval)])
        end
        
        function [stat, statResampled, pval] = ...
                PermutationTest_SummedPSTHDiffs(obj, trial_nums1, trial_nums2, histogram_bin_centers, nsamps, varargin)
            %
            %
            % Calculates shuffle-test significance of summed, bin-by-bin absolute value of difference
            %   between PSTHs for two sets of trials.
            %
            %
            % varargin{1} is optional specification of region of times within histograms to
            %   restrict calculation to.  Form is a 1 x 2 vector of
            %   form [startTimeInclusive stopTimeInclusive]. Restriction applies to *bin centers*,
            %   so the raw data that go into the histogram are really restricted to
            %   [startTimeInclusive - 1/2 * binwidth, startTimeInclusive + 1/2 * binwidth].
            %

            nbins = length(histogram_bin_centers);

            if length(histogram_bin_centers) < 2
                error('Input histogram_bin_centers must be a vector of bin centers for histogramming.')
            end

            ntrials1 = length(trial_nums1);
            ntrials2 = length(trial_nums2);
            ntrialsTotal = ntrials1 + ntrials2;

            individualTrialHistograms = zeros(ntrialsTotal, nbins);

            binWidthInSec = histogram_bin_centers(2)-histogram_bin_centers(1);  % All bins must be equal size for this transformation to Hz.
           
            trialNums = obj.trialNums; % keep this out of any loops; it's slow.
            n=1;
            for k=[trial_nums1 trial_nums2]
                ind = trialNums==k;
                if sum(ind) ~= 1
                    error(['Trial number' num2str(k) 'is missing or is not unique.'])
                end
                st = obj.trials{ind}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{ind}.shanksTrial.clustData{clustNum}.sampleRate;

                h0 = hist(st((st>0)), histogram_bin_centers); % Before histogramming, remove 0 spike time entries that indicate that no spikes were found.
                individualTrialHistograms(n,:) = h0 ./ binWidthInSec;
                n=n+1;
            end

            if nargin > 5
                region = varargin{1};
                if numel(region) ~= 2
                    error('varargin{1} must be 1 x 2 vector of times.')
                end
                startTimeInclusive = region(1);
                stopTimeInclusive = region(2);

                ind = histogram_bin_centers >= startTimeInclusive & histogram_bin_centers <= stopTimeInclusive;
                individualTrialHistograms = individualTrialHistograms(:,ind);
            end

            histMean1 = mean(individualTrialHistograms(1:ntrials1,:),1);
            histMean2 = mean(individualTrialHistograms((ntrials1+1):end,:),1);

            stat = sum(abs(histMean1 - histMean2));

            % Do permutation test by shuffling labels for two groups of trials.
            statResampled = zeros(nsamps,1); n=1;
            for k=1:nsamps
                r = randperm(ntrialsTotal);
                trialsSet1 = r(1:ntrials1);
                trialsSet2 = r((ntrials1+1):end);
                histMean1 = mean(individualTrialHistograms(trialsSet1,:),1);
                histMean2 = mean(individualTrialHistograms(trialsSet2,:),1);
                statResampled(n) = sum(abs(histMean1 - histMean2));
                n=n+1;
            end

            y = 0.001:.001:1;
            x = quantile(statResampled, y);
            [x,I,junk] = unique(x); y = y(I); % throw out non-unique x values so can use interp1

            if stat > max(statResampled)
                pval = 1/nsamps; % rather,  pval < 1/nsamps.
            elseif length(x)==1 % No spikes
                pval = 1;  % OR SHOULD THIS BE 0.5?
            elseif stat < min(statResampled)
                pval = 1;
            else
                yi = interp1(x,y,stat);
                pval = 1-yi;
            end

        end


        function r = peakInstRate(obj)
            %
            % r = peakInstRate()
            %
            % Peak instantaneous firing rate in Hz FOR EACH TRIAL.
            % Equal to 1 / (minimumInterspikeInterval) if >= 2 spikes,
            % to 1 / sweepLengthInSec (eg, 5 s) if 1 spike, or to 0 if
            % there are 0 spikes.
            %
            r = cellfun(@(x) x.peakInstRate, obj.trials);
        end

        function r = maxPeakInstRate(obj)
            % Peak instaneous firing rate across ALL TRIALS in array.
            r = max(obj.peakInstRate);
        end


        %         function plot_spike_rasters_trial_types(obj)
        %            % NEED TO IMPLEMENT
        %         end


        function r = whiskerParamsBinwise(obj,trial_nums,tid,nbins,binSize)
            %
            % binSize is in sec
            %
            %         binSize=0.1; % sec
            %         nbins = 11;

            ntrials = length(trial_nums);

            spikeCount = cell(1,ntrials); velocity = cell(1,ntrials); 
            acceleration = cell(1,ntrials); position = cell(1,ntrials); 
            curvatureChange = cell(1,ntrials); curvatureDot = cell(1,ntrials);
            meanTime = cell(1,ntrials);
            for n=1:ntrials

                k = find(obj.trialNums==trial_nums(n));
                if isempty(k)
                    error('Trial num not found')
                end

                sampleRate = obj.trials{k}.shanksTrial.clustData{clustNum}.sampleRate;
                st = obj.trials{k}.shanksTrial.clustData{clustNum}.spikeTimes ./ sampleRate;
                st = st(st>0); % 0 used to indicate no spikes.

                [y,t] = obj.trials{k}.whiskerTrial.get_velocity(tid,5);
                [y2,t] = obj.trials{k}.whiskerTrial.get_acceleration(tid,5);
                [y3,t] = obj.trials{k}.whiskerTrial.get_position(tid,5);
                [c,t] = obj.trials{k}.whiskerTrial.get_curvatureDot(tid);
                [c2,t] = obj.trials{k}.whiskerTrial.get_curvatureChange(tid);

                t = t + obj.whiskerTrialTimeOffset;
                
                %     cutOffInSec = 0.6; tind = y < cutOffInSec; y = y(tind);  c = c(tind); t = t(tind);

                if isempty(t) % in case there's a trial where the trajectory tid isn't present.
                    spikeCount{n} = NaN;
                    position{n} = NaN;
                    velocity{n} = NaN;                    
                    acceleration{n} = NaN;                    
                    curvatureChange{n} = NaN;
                    curvatureDot{n} = NaN;
                    meanTime{n} = NaN;
                    continue
                end

                st = st(st<=max(t));

                spikeCountBin = zeros(1,nbins);
                positionBin = zeros(1,nbins);
                velocityBin = zeros(1,nbins);
                accelerationBin = zeros(1,nbins);
                curvatureChangeBin = zeros(1,nbins);
                curvatureDotBin = zeros(1,nbins);
                meanTimeBin = zeros(1,nbins);
                startTime = 0; endTime = binSize;
                for j=1:nbins
                    epochInd = t >= startTime & t < endTime;
                    ybin = y(epochInd);
                    y2bin = y2(epochInd);
                    y3bin = y3(epochInd);
                    cbin = c(epochInd);
                    c2bin = c2(epochInd);
                    tbin = t(epochInd);

                    spikeCountBin(j) = length(st(st >= startTime & st < endTime));
                    positionBin(j) = mean(y3bin);
                    velocityBin(j) = mean(abs(ybin));
                    accelerationBin(j) = mean(abs(y2bin));
                    curvatureChangeBin(j) = mean(abs(c2bin));
                    curvatureDotBin(j) = mean(abs(cbin));
                    meanTimeBin(j) = mean(tbin); % mean time for bin

                    startTime = startTime + binSize;
                    endTime = endTime + binSize;
                end
                spikeCount{n} = spikeCountBin;
                position{n} = positionBin;
                velocity{n} = velocityBin;
                acceleration{n} = accelerationBin;
                curvatureChange{n} = curvatureChangeBin;
                curvatureDot{n} = curvatureDotBin;
                meanTime{n} = meanTimeBin;
            end

            %             r = struct('spikeCount',spikeCount, 'whiskerPosVar', whiskerPosVar,'whiskerAvgCurv',whiskerAvgCurv);
            r.spikeCount = spikeCount;
            r.position = position;
            r.velocity = velocity;
            r.acceleration = acceleration;
            r.curvatureChange = curvatureChange;
            r.curvatureDot = curvatureDot;
            r.meanTime = meanTime;
        end
        
  function r = spikeAndLickCountsBinned(obj,trial_nums,nbins,binSize)
            %
            % binSize is in sec
            %
            %         binSize=0.1; % sec
            %         nbins = 11;

            ntrials = length(trial_nums);

            spikeCount = cell(1,ntrials); 
            lickCount = cell(1,ntrials);
            for n=1:ntrials

                k = find(obj.trialNums==trial_nums(n));
                if isempty(k)
                    error('Trial num not found')
                end

                sampleRate = obj.trials{k}.shanksTrial.clustData{clustNum}.sampleRate;
                st = obj.trials{k}.shanksTrial.clustData{clustNum}.spikeTimes ./ sampleRate;
                st = st(st>0); % 0 used to indicate no spikes.
                
                lt = obj.trials{k}.beamBreakTimes;


                spikeCountBin = zeros(1,nbins);
                lickCountBin = zeros(1,nbins);
                

                startTime = 0; endTime = binSize;
                for j=1:nbins

                    spikeCountBin(j) = length(st(st >= startTime & st < endTime));
                    lickCountBin(j) = length(lt(lt >= startTime & lt < endTime));

                    startTime = startTime + binSize;
                    endTime = endTime + binSize;
                end
                spikeCount{n} = spikeCountBin;
                lickCount{n} = lickCountBin;
            end

            r.spikeCount = spikeCount;
            r.lickCount = lickCount;

        end
        
%         function [r,time,se] = STA_whisker_bootstrap(obj,trial_nums,tid,width_in_sec,type_string,nboot)
%             %
%             %
%             %
%             %
%             [r,time,junk] = obj.STA_whisker(trial_nums,tid,width_in_sec,type_string);
%             
%             rboot = zeros(nboot,length(r));
%             
%             ntrials = length(trial_nums);
%             
%             for k=1:nboot
%                 rand_trials = randsample(trial_nums,ntrials,true);
%                 [rit,junk,junk2] = obj.STA_whisker(rand_trials,tid,width_in_sec,type_string);
%                 rboot(k,:) = rit;
%             end
%             se = std(rboot,0,1);
%         end
                
        function [r,time,se] = STA_whisker(obj,trial_nums,tid,width_in_sec,type_string)
            %
            %
            % se is standard error across *spikes*.
            %
            % type_string is either 'velocity','curvature', or 'position'.
            %
            ntrials = length(trial_nums);

            % Find out how many samples are required for a window of
            % width_in_sec duration. Assume that it's same for all
            % trials and use first trial to determine:
            k = find(obj.trialNums==trial_nums(1));
            %             framePeriodInSec = obj.trials{k}.whiskerTrial.framePeriodInSec;
            sampleRateEphys = obj.trials{k}.shanksTrial.clustData{clustNum}.sampleRate;
            samplePeriodEphys = 1 / sampleRateEphys;
            %             widthInSamples = width_in_sec / framePeriodInSec;
            widthInSamples = width_in_sec / samplePeriodEphys;
            s = zeros(1,widthInSamples); % sum
            ss = zeros(1,widthInSamples); % sum of squares, for computing STD
            
            trialNums = obj.trialNums;

            nspikes = 0; 
            for n=1:ntrials
                k = find(trialNums==trial_nums(n));
                if isempty(k)
                    error('Trial num not found')
                end

                sampleRate = obj.trials{k}.shanksTrial.clustData{clustNum}.sampleRate;
%                 if sampleRate ~= sampleRateEphys
%                     error('Sample rates for different ephys sweeps not same.') % May or may not be problem; check
%                 end
                st = obj.trials{k}.shanksTrial.clustData{clustNum}.spikeTimes ./ sampleRate;
                st = st(st>0); % 0 used to indicate no spikes.
                       
%                 %--------------------------------------------------------
%                 % Control: scramble spikes by setting to random times while
%                 % keeping the same number of spikes. Should build in some refractory period for realism.
% %                 st = randsample(tt, length(st), false);
%                 st = randsample(0:samplePeriodEphys:5, length(st), false);
%                 %--------------------------------------------------------
%                     
                
                switch type_string
                    case 'position'
                        [y,t] = obj.trials{k}.whiskerTrial.get_position(tid);
                        y = y - mean(y(1:50)); % Temp, assume baseline curvature is mean of first 50 samples.
                    case 'velocity'
                        [y,t] = obj.trials{k}.whiskerTrial.get_velocity(tid);
                    case 'curvature'
                        [y,t] = obj.trials{k}.whiskerTrial.get_curvature(tid);
                    otherwise
                        error('Invalid type_string argument')
                end

                t = t + obj.whiskerTrialTimeOffset;
                                
                % Limit to spikes for which we have stimulus timeseries
                % for at least width_in_sec beforehand:
                st = st(st<=max(t));
                st = st(st>=width_in_sec);
                
                if isempty(st) || isempty(t) % In case there's a trial where the trajectory tid isn't present or are no spikes
                    continue                 % within region of useful timeseries.
                end
                

                

                % Run interp1 once per trial, not per spike.
                tt = min(t):samplePeriodEphys:max(t);
                yy = interp1(t,y,tt); % Interpolate whisker timeseries to be at same sampling rate as spikes.
                
                for j=1:length(st)
                    spikeTime = st(j);
%                     startTime = (spikeTime - width_in_sec) + samplePeriodEphys;
%                     endTime = spikeTime;
%                     ychunk = yy(tt>=startTime & tt<=endTime);
                    endSamp = find(tt<=spikeTime,1,'last');

                    if endSamp >= widthInSamples
                        ychunk = yy((endSamp-widthInSamples+1):endSamp);
%                       tt = startTime:samplePeriodEphys:endTime;
%                       yy = interp1(t,y,tt); % Interpolate whisker timeseries to be at same sampling rate as spikes.
%                       s = s + yy;
                        s = s + ychunk;
                        ss = ss + ychunk.^2;
                        nspikes = nspikes + 1; 
                    end
                end
            end
            
            time = (-(width_in_sec-samplePeriodEphys)):samplePeriodEphys:0;
            if nspikes==0
                disp('Warning: No spikes found among all the trials')
                r = NaN; se = NaN;
            else
                r = s ./ nspikes;
                sampleVariance = (ss - (s.^2)./nspikes)./(nspikes-1);
                se = sqrt(sampleVariance)./sqrt(nspikes);
%                 se = -1;
            end
        end

        function [r,se] = LTA(obj,trial_nums,bin_centers,varargin)
            %
            %  Lick-triggered average spike histograms.
            %    
            %  bin_centers define histogram with respect to time of lick, in seconds. 
            %
            %  varargin{1}: 2-element vector of form [startTime endTime] in seconds
            %      to restrict analysis to, inclusive.
            %
            %
            
            if nargin>3
               restrictRegion = varargin{1};
            else
                restrictRegion = [];
            end
            
            nbins = length(bin_centers);
            binWidth = bin_centers(2) - bin_centers(1); % assume bins are evenly spaced!  
            
            if length(bin_centers) < 2
                error('Input bin_centers must be a vector of bin centers for histogramming.')
            end
            
            ntrials = length(trial_nums);

            s = zeros(1,nbins); % sum
            ss = zeros(1,nbins); % sum of squares, for computing STD
            trialNums = obj.trialNums;
            allLicks = obj.beamBreakTimes;
            
            nlicks = 0; 
            for n=1:ntrials
                k = find(trialNums==trial_nums(n));
                if isempty(k)
                    error('Trial num not found')
                end

               licks = allLicks{k};
                
               sweepLengthInSec = obj.trials{k}.shanksTrial.clustData{clustNum}.sweepLengthInSamples / obj.trials{k}.shanksTrial.clustData{clustNum}.sampleRate;
               
                               
                sampleRate = obj.trials{k}.shanksTrial.clustData{clustNum}.sampleRate;
                st = obj.trials{k}.shanksTrial.clustData{clustNum}.spikeTimes ./ sampleRate;
                st = st(st>0); % 0 used to indicate no spikes.
                       
                if ~isempty(restrictRegion)
                    st = st(st>=restrictRegion(1) & st<=restrictRegion(2));
                end
                
                
                % Limit to licks for which we have enough spike timeseries
                % before and after for all bin_centers.
                licks = licks(licks >= (-min(bin_centers)) & licks<=(sweepLengthInSec - max(bin_centers)));
                
                if isempty(licks) 
                    continue      
                end

                for j=1:length(licks)
                    lickTime = licks(j);
                    x = st - lickTime; % center spike times on time of lick
                    % Important: eliminate spikes outside of histogram range;
                    % otherwise the are included in end bins (see 'help hist'):
                    
                    x = x(x > (min(bin_centers)-binWidth) & x < (max(bin_centers)+binWidth));
                    
                    h = hist(x, bin_centers);
                    s = s + h;
                    ss = ss + h.^2;
                    nlicks = nlicks + 1; 
                 end
            end        

            if nlicks==0
                disp('Warning: No licks found among all the trials')
                r = NaN; se = NaN;
            else
                r = s ./ nlicks;
                sampleVariance = (ss - (s.^2)./nlicks)./(nlicks-1);
                se = sqrt(sampleVariance)./sqrt(nlicks);
            end
        end
        
        
        function viewer(obj,varargin)
            %
            % USAGE:    viewer
            %
            %   This function must be called with no arguments. Signal selection
            %       and subsequent options are then chosen through the GUI.
            %
            %   Input arguments (in varargin) are reserved for internal, recursive
            %       use of this function.
            %
            %
            %
            ms=8; lw=0.5; fs=12;
            if nargin==1 % Called with no arguments
                objname = inputname(1); % Command-line name of this instance of a SweepArray.
                h=figure('Color','white'); ht = uitoolbar(h);
                a = .20:.05:0.95; b(:,:,1) = repmat(a,16,1)'; b(:,:,2) = repmat(a,16,1); b(:,:,3) = repmat(flipdim(a,2),16,1);
                bbutton = uipushtool(ht,'CData',b,'TooltipString','Back');
                fbutton = uipushtool(ht,'CData',b,'TooltipString','Forward','Separator','on');
                set(fbutton,'ClickedCallback',[objname '.viewer(''next'')'])
                set(bbutton,'ClickedCallback',[objname '.viewer(''last'')'])
                
                m=uimenu(h,'Label','Display Type','Separator','on');
                uimenu(m,'Label','Behavior','Callback',[objname '.viewer(''behav'',''none'')'])
                uimenu(m,'Label','Behavior + Spike times','Callback',[objname '.viewer(''behavSpikes'',''none'')'])
                uimenu(m,'Label','Behavior + Spike times + Whisker timeseries','Callback',[objname '.viewer(''behavSpikesWhisker'',''none'')'])
                uimenu(m,'Label','Behavior + Spike times + Whisker timeseries / Whisking epoch, contact shading (TID 0)',...
                    'Callback',[objname '.viewer(''behavSpikesWhisker'',''whiskingEpochsContactShading'',''tid0'')'])
                uimenu(m,'Label','Behavior + Spike times + Whisker timeseries / Whisking epoch, contact shading (TID 1)',...
                    'Callback',[objname '.viewer(''behavSpikesWhisker'',''whiskingEpochsContactShading'',''tid1'')'])
                uimenu(m,'Label','Behavior + Spike times + Whisker timeseries / Whisking epoch, contact shading (TID 2)',...
                    'Callback',[objname '.viewer(''behavSpikesWhisker'',''whiskingEpochsContactShading'',''tid2'')'])
                
                uimenu(h,'Label','Jump to sweep','Separator','on','Callback',[objname '.viewer(''jumpToSweep'')']);
                
                g = struct('sweepNum',1,'trialList','','numAxes',1,'displayType','behavSpikes',...
                    'displayTypeMinor','none','whiskingEpochs',[],'nonWhiskingEpochs',[],...
                    'firstContactTimes',[],'tid',[]);
                set(h,'UserData',g);
            else
                g = get(gcf,'UserData');
            end

            
            for j = 1:length(varargin);
                argString = varargin{j};
                switch argString
                    case 'next'
                        if g.sweepNum < length(obj)
                            g.sweepNum = g.sweepNum + 1;
                        end
                    case 'last'
                        if g.sweepNum > 1
                            g.sweepNum = g.sweepNum - 1;
                        end
                    case 'jumpToSweep'
                        if isempty(g.trialList)
                            nsweeps = obj.length;
                            g.trialList = cell(1,nsweeps);
                            for k=1:nsweeps
                                g.trialList{k} = [int2str(k) ': trialNum=' int2str(obj.trialNums(k))];
                            end
                        end
                        [selection,ok]=listdlg('PromptString','Select a sweep:','ListString',...
                            g.trialList,'SelectionMode','single');
                        if ~isempty(selection) && ok==1
                            g.sweepNum = selection;
                        end
                    case 'behav'
                        g.displayType = 'behav';
                    case 'behavSpikes'
                        g.displayType = 'behavSpikes';
                    case 'behavSpikesWhisker'
                        g.displayType = 'behavSpikesWhisker';
                    case 'whiskingEpochsContactShading'
                        g.displayTypeMinor = 'whiskingEpochsContactShading';
                    case 'tid0'
                        if isempty(g.tid) || g.tid ~= 0
                            g.tid = 0;
                            [g.whiskingEpochs,g.nonWhiskingEpochs] = obj.detectWhiskingEpochs(g.tid, obj.whiskerTrialNums); 
                            g.firstContactTimes = obj.detectFirstContacts(g.tid, obj.whiskerTrialNums);
                        end
                    case 'tid1'
                        if isempty(g.tid) || g.tid ~= 1
                            g.tid = 1;
                            [g.whiskingEpochs,g.nonWhiskingEpochs] = obj.detectWhiskingEpochs(g.tid, obj.whiskerTrialNums); 
                            g.firstContactTimes = obj.detectFirstContacts(g.tid, obj.whiskerTrialNums);
                        end
                    case 'tid2'
                        if isempty(g.tid) || g.tid ~= 2
                            g.tid = 2;
                            [g.whiskingEpochs,g.nonWhiskingEpochs] = obj.detectWhiskingEpochs(g.tid, obj.whiskerTrialNums); 
                            g.firstContactTimes = obj.detectFirstContacts(g.tid, obj.whiskerTrialNums);
                        end
                end
            end
                
            msSpikes=5;
            switch g.displayType
                case 'behav'
                    numAxes=1;
                    subplot(1,1,1); cla
                    obj.trials{g.sweepNum}.behavTrial.plot_trial_events;
                    set(gca,'FontSize',fs); xlabel('Sec','FontSize',fs);
                    
                case 'spikeTimes'
                    numAxes=1;
                    subplot(1,1,1); cla
                    x = obj.trials{g.sweepNum}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{g.sweepNum}.shanksTrial.clustData{clustNum}.sampleRate;
                    y = ones(size(x));
                    plot(x,y,'ko','MarkerSize',msSpikes); ylim([.8 1.2]); set(gca,'YTickLabel','')
                    
                case 'behavSpikes'
                    numAxes=2;
                    subplot(2,1,1); cla
                    obj.trials{g.sweepNum}.behavTrial.plot_trial_events;
                    set(gca,'FontSize',fs); xlabel('Sec','FontSize',fs);
                    subplot(2,1,2); cla
                    x = obj.trials{g.sweepNum}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{g.sweepNum}.shanksTrial.clustData{clustNum}.sampleRate;
                    y = ones(size(x));
                    plot(x,y,'ko','MarkerSize',msSpikes); ylim([.8 1.2])
                    
                case 'behavSpikesWhisker'
                    numAxes=4;
                    subplot(4,1,1); cla
                    obj.trials{g.sweepNum}.behavTrial.plot_trial_events;
                    set(gca,'FontSize',fs); xlabel('Sec','FontSize',fs);
                    subplot(4,1,2); cla
                    x = obj.trials{g.sweepNum}.shanksTrial.clustData{clustNum}.spikeTimes / obj.trials{g.sweepNum}.shanksTrial.clustData{clustNum}.sampleRate;
                    y = ones(size(x));
                    plot(x,y,'ko','MarkerSize',msSpikes); ylim([.8 1.2])
                    
                    subplot(4,1,3); cla; hold on; 
                    title('Position')
                    subplot(4,1,4); cla; hold on; 
                    title('Curvature')
%                     title('CurvatureDot') 
%                     title('CurvatureDot / STD_{CurvatureDot on this trial}') 
                    if ~isempty(obj.trials{g.sweepNum}.whiskerTrial)
                        plotSymString = {'k-','m-','c-','g-','y-','r-','b-'};
                        tid = obj.trials{g.sweepNum}.whiskerTrial.trajectoryIDs;
                        numTid = length(tid);
                        yRangePos = zeros(numTid,2); % for setting display limits below 
                        yRangeCurv = zeros(numTid,2); % for setting display limits below 
                        xRangeCurv = zeros(numTid,2); % for setting display limits below
                        for j=1:numTid
                            s = plotSymString{mod(j,length(plotSymString))};
                            subplot(4,1,3)
                            [y,x] = obj.trials{g.sweepNum}.whiskerTrial.get_position(tid(j));
                            plot(x,y,s);
                            yRangePos(j,:) = [min(y) max(y)]; 
                            subplot(4,1,4)
                            [y,x] = obj.trials{g.sweepNum}.whiskerTrial.get_curvature(tid(j));
%                             [y,x] = obj.trials{g.sweepNum}.whiskerTrial.get_curvatureDot(tid(j));
%                             [y,x] = obj.trials{g.sweepNum}.whiskerTrial.get_curvatureDot(tid(j)); y = y ./std(y);
                            plot(x,y,s);
                            xRangeCurv(j,:) = [min(x) max(x)];
                            yRangeCurv(j,:) = [min(y) max(y)];
                        end
                    else
                        subplot(4,1,3); text(.1, .5, 'No whisker data this trial')
                        subplot(4,1,4); text(.1, .5, 'No whisker data this trial')
                    end
                    
                otherwise
                    error('Invalid string argument.')
            end
            
            switch g.displayTypeMinor
                case 'none'
                    % Do nothing
                case 'whiskingEpochsContactShading'
                    
                    trialNum = obj.trialNums(g.sweepNum);
                    ind = find(obj.whiskerTrialNums==trialNum);
                    if ~isempty(ind)
                        % Shade whisking epochs in position plot:
                        subplot(4,1,3);
                        x = g.whiskingEpochs{ind};
                        ymin = min(yRangePos(:,1)); ymax = max(yRangePos(:,2));
                        if ~isempty(x)
                            for j=1:size(x,1)
                                p = patch([x(j,1) x(j,1) x(j,2) x(j,2)], [ymin ymax ymax ymin],[1 0 0],'FaceAlpha',0.2,'EdgeColor','none');
                                uistack(p,'bottom')
                            end
                        end
                        % Shade non-whisking epochs in position plot:
                        x = g.nonWhiskingEpochs{ind};
                        if ~isempty(x)
                            for j=1:size(x,1)
                                p = patch([x(j,1) x(j,1) x(j,2) x(j,2)], [ymin ymax ymax ymin],[0 1 0],'FaceAlpha',0.2,'EdgeColor','none');
                                uistack(p,'bottom')
                            end
                        end
                        % Shade all post-first contact times in curvature plot:
                        subplot(4,1,4);
                        ymin = min(yRangeCurv(:,1)); ymax = max(yRangeCurv(:,2));
                        xmax = max(xRangeCurv(:,2));                        
                        x = g.firstContactTimes{ind};
                        if ~isempty(x)
                            p = patch([x x xmax xmax], [ymin ymax ymax ymin],[1 1 0],'FaceAlpha',0.2,'EdgeColor','none');
                            uistack(p,'bottom')
                        end
                    end

            end
                
            if ~isempty(obj.trials{g.sweepNum}.whiskerTrial)
                trackerFileName = obj.trials{g.sweepNum}.whiskerTrial.trackerFileName((end-2):end);
            else
                trackerFileName = 'NA';
            end
            
            subplot(numAxes,1,1);
            title([int2str(g.sweepNum) '/' int2str(obj.length) ', trialNum=' int2str(obj.trialNums(g.sweepNum))...
                ', trackerFileNum=' trackerFileName ...
                ', ' obj.trials{g.sweepNum}.trialOutcome '\newline'  obj.cellNum obj.cellCode ', ' strrep(obj.sessionName,'_','\_') ...
                '\newline displayType=' g.displayType '/' g.displayTypeMinor,', tid=' int2str(g.tid)],'FontSize',10)
            
            % Uncomment following for-loop to put all axes on [0 s,5 s]:
%             for k=1:numAxes
%                 subplot(numAxes,1,k)
%                 xlim([0 5])
%             end
            
            set(gcf,'UserData',g);
            

        end
        

    end % Methods



    methods % Dependent property methods; cannot have attributes.

        function value = get.cellNum(obj)
            if ~isempty(obj.trials)
                value = obj.trials{1}.cellNum;
            else
                value = [];
            end
        end

        function value = get.shankNum(obj)
            if ~isempty(obj.trials)
                value = obj.trials{1}.shankNum;
            else
                value = [];
            end
        end

        function value = get.mouseName(obj)
            if ~isempty(obj.trials)
                value = obj.trials{1}.mouseName;
            else
                value = [];
            end
        end

        function value = get.sessionName(obj)
            if ~isempty(obj.trials)
                value = obj.trials{1}.sessionName;
            else
                value = [];
            end
        end

        function value = get.trialNums(obj)
            if ~isempty(obj.trials)
                value = cellfun(@(x) x.trialNum, obj.trials);
            else
                value = [];
            end
        end

        function value = get.trialTypes(obj)
            if ~isempty(obj.trials)
                value = cellfun(@(x) x.trialType, obj.trials);
            else
                value = [];
            end
        end

        function value = get.trialCorrects(obj)
            if ~isempty(obj.trials)
                value = cellfun(@(x) x.trialCorrect, obj.trials);
            else
                value = [];
            end
        end

        function value = get.fractionCorrect(obj)
            if ~isempty(obj.trials)
                value = mean(obj.trialCorrects);
            else
                value = [];
            end
        end

        function value = get.hitTrialNums(obj)
            if ~isempty(obj.trials)
                ind = cellfun(@(x) x.trialType==1 && x.trialCorrect==1, obj.trials);
                value = obj.trialNums(ind);
            else
                value = [];
            end
        end

        function value = get.hitTrialInds(obj)
            if ~isempty(obj.trials)
                value = cellfun(@(x) x.trialType==1 && x.trialCorrect==1, obj.trials);
            else
                value = [];
            end
        end

        function value = get.missTrialNums(obj)
            if ~isempty(obj.trials)
                ind = cellfun(@(x) x.trialType==1 && x.trialCorrect==0, obj.trials);
                value = obj.trialNums(ind);
            else
                value = [];
            end
        end

        function value = get.missTrialInds(obj)
            if ~isempty(obj.trials)
                value = cellfun(@(x) x.trialType==1 && x.trialCorrect==0, obj.trials);
            else
                value = [];
            end
        end

        function value = get.falseAlarmTrialNums(obj)
            if ~isempty(obj.trials)
                ind = cellfun(@(x) x.trialType==0 && x.trialCorrect==0, obj.trials);
                value = obj.trialNums(ind);
            else
                value = [];
            end
        end

        function value = get.falseAlarmTrialInds(obj)
            if ~isempty(obj.trials)
                value = cellfun(@(x) x.trialType==0 && x.trialCorrect==0, obj.trials);
            else
                value = [];
            end
        end

        function value = get.correctRejectionTrialNums(obj)
            if ~isempty(obj.trials)
                ind = cellfun(@(x) x.trialType==0 && x.trialCorrect==1, obj.trials);
                value = obj.trialNums(ind);
            else
                value = [];
            end
        end

        function value = get.correctRejectionTrialInds(obj)
            if ~isempty(obj.trials)
                value = cellfun(@(x) x.trialType==0 && x.trialCorrect==1, obj.trials);
            else
                value = [];
            end
        end

        function value = get.whiskerTrialInds(obj)
            if ~isempty(obj.trials)
                value = cellfun(@(x) ~isempty(x.whiskerTrial), obj.trials);
            else
                value = [];
            end
        end

        function value = get.whiskerTrialNums(obj)
            if ~isempty(obj.trials)
                ind = cellfun(@(x) ~isempty(x.whiskerTrial), obj.trials);
                value = obj.trialNums(ind);
            else
                value = [];
            end
        end

%         function value = get.spikeRatesInHz(obj)
%             
%             length(obj.trials{1}.spikeRateInHz)
%             
%             tmp = cellfun(@(x) x.spikeRateInHz, obj.trials,'UniformOutput',0)
%             
%             for i=1:length(tmp)
%                 emptyrates(i,:) = cellfun(@(y)~isempty(y),tmp{i});
%                 zerorates(i,:)  = cellfun(@(y)y==0,tmp{i});
%             end
%             
%             if ~isempty(obj.trials)
%                 value = cellfun(@(x) x.spikeRateInHz, obj.trials,'UniformOutput',0);
%             else
%                 value = [];
%             end
%         end

%         function value = get.meanSpikeRateInHz(obj)
%             if ~isempty(obj.trials)
%                 value = mean(obj.spikeRatesInHz);
%             else
%                 value = [];
%             end
%         end

%         function value = get.stdDevSpikeRateInHz(obj)
%             if ~isempty(obj.trials)
%                 value = std(obj.spikeRatesInHz,1);
%             else
%                 value = [];
%             end
%         end


    end

end
