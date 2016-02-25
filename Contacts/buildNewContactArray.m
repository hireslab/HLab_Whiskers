function [contacts, params] = buildNewContactArray(array, params)

% Version 0.5.0 SAH 110827

if nargin == 1;
    disp('Build new contact array using default analysis parameters')
    
    % create default parameters
    contacts=cell(1,length(array.trials));
    params=struct;
    params.touchThresh = [.1 .1 .3 .3]; %Touch threshold for go (protraction, retraction), no-go (protraction,retraction). Check with Parameter Estimation cell
    params.goProThresh = 0; % Mean curvature above this value indicates probable go protraction, below it, a go retraction trial.
    params.nogoProThresh = 0; % Mean curvature above this value indicates probable nogo protraction, below it, a nogo retraction trial.
    params.poleOffset = .535; % Time where pole becomes accessible
    params.poleEndOffset = .13; % Time between start of pole exit and inaccessiblity
    params.spikeSynapticOffset = .02; % Estimated synaptic delay for assigning spikes to contact epochs
    params.tid=0; % Trajectory id
    params.framesUsed=1:length(array.trials{find(array.whiskerTrialInds,1)}.whiskerTrial.time{1});
    params.curveMultiplier=1.5;
    params.trialcolors = {'g','r','k','b'};
    params.baselineCurve = [0 .02]; % To subtract from the baseline curve for contact detection
    
    params.savedir = 'Z:\users\Andrew\Whisker Project\SingleUnit\'
    disp(params)
    
else
    
    disp('Using custom analysis parameters')
    
end

% Prefetch all relevant data to prevent numerous slow calls to the trial
% array classes

whiskerTIN                          = find(array.whiskerTrialInds);
goTrialNums                         = cat(1,array.missTrialNums(:),array.hitTrialNums(:));
trialNums                           = array.trialNums;

pinDescentOnsetTime(whiskerTIN)     = cellfun(@(x)x.behavTrial.pinDescentOnsetTime,array.trials(whiskerTIN),'UniformOutput',0);
pinAscentOnsetTime(whiskerTIN)      = cellfun(@(x)x.behavTrial.pinAscentOnsetTime,array.trials(whiskerTIN),'UniformOutput',0);

time(whiskerTIN)                    = cellfun(@(x)x.whiskerTrial.time{1},                   array.trials(whiskerTIN),'UniformOutput',0);
distanceToPoleCenter(whiskerTIN)    = cellfun(@(x)x.whiskerTrial.distanceToPoleCenter{1},   array.trials(whiskerTIN),'UniformOutput',0);
kappa(whiskerTIN)                   = cellfun(@(x)x.whiskerTrial.deltaKappa{1},             array.trials(whiskerTIN),'UniformOutput',0);
thetaAtBase(whiskerTIN)             = cellfun(@(x)x.whiskerTrial.thetaAtBase{1},            array.trials(whiskerTIN),'UniformOutput',0);
thetaAtContact(whiskerTIN)          = cellfun(@(x)x.whiskerTrial.thetaAtContact{1},         array.trials(whiskerTIN),'UniformOutput',0);

meanContactCurve = zeros(max(whiskerTIN),1);
trialContactType = zeros(max(whiskerTIN),1);

% Make initial guesses for contact periods
disp('Determining contact periods')
for k = whiskerTIN
    
    if max(goTrialNums==trialNums(k))  %determine trial type
        % Finds indexes of time periods of contacts by distance to pole - curvature
        
        touchThreshi=max(params.touchThresh(1:2));     % go trials
        contacts{k}.contactInds{1} = time{k}(distanceToPoleCenter{k} - params.curveMultiplier*abs(kappa{k}-params.baselineCurve(1)) - ...
            (params.curveMultiplier*5*(kappa{k}-params.baselineCurve(1))).^2 < touchThreshi);
    else
        % Finds indexes of time periods of contacts by distance to pole - curvature
        
        touchThreshi=max(params.touchThresh(3:4));     % nogo trials
        contacts{k}.contactInds{1} = time{k}(distanceToPoleCenter{k} - params.curveMultiplier*abs(kappa{k}-params.baselineCurve(2)) - ...
            (params.curveMultiplier*5*(kappa{k}-params.baselineCurve(2))).^2 < touchThreshi);

    end
    
    
    % Crops indexs to only pole available times
    contacts{k}.contactInds{1} = contacts{k}.contactInds{1}(contacts{k}.contactInds{1} >...
        params.poleOffset+pinDescentOnsetTime{k} & contacts{k}.contactInds{1} < params.poleEndOffset + pinAscentOnsetTime{k} );
    
    [~,~,contacts{k}.contactInds{1}]=intersect(contacts{k}.contactInds{1}, time{k});
    
    % Calculate the mean curvature during contact period
    meanContactCurve(k)=nanmean(kappa{k}(contacts{k}.contactInds{1}));
    
end



for j=1:2
    % Determine if contacts are protraction or retraction and refine contact
    % periods
    disp('Determining contact directions and refining contact periods')
    for k = whiskerTIN
        if max(goTrialNums==trialNums(k))  %determine trial type
            if meanContactCurve(k) < params.goProThresh
                touchThreshi=params.touchThresh(1); % use go / protraction threshold
                trialContactType(k)=1;
                                        % Finds indexes of time periods of contacts by distance to pole - curvature

                             contacts{k}.contactInds{1} = time{k}(distanceToPoleCenter{k}...
                    - params.curveMultiplier*abs(kappa{k}-params.baselineCurve(1))...
                    - (params.curveMultiplier*5*(kappa{k}-params.baselineCurve(1))).^2 <touchThreshi);
                
            elseif meanContactCurve(k) > params.goProThresh
                touchThreshi=params.touchThresh(2); % use go / retraction threshold
                trialContactType(k)=2;
                                        % Finds indexes of time periods of contacts by distance to pole - curvature

                             contacts{k}.contactInds{1} = time{k}(distanceToPoleCenter{k}...
                    - params.curveMultiplier*abs(kappa{k}-params.baselineCurve(1))...
                    - (params.curveMultiplier*5*(kappa{k}-params.baselineCurve(1))).^2 <touchThreshi);
                
            else
                trialContactType(k)=0;
                
            end
            
        else
            if meanContactCurve(k) < params.nogoProThresh
                touchThreshi=params.touchThresh(3); % use no-go / protraction threshold
                trialContactType(k)=3;
                        % Finds indexes of time periods of contacts by distance to pole - curvature
             contacts{k}.contactInds{1} = time{k}(distanceToPoleCenter{k}...
                    - params.curveMultiplier*abs(kappa{k}-params.baselineCurve(2))...
                    - (params.curveMultiplier*5*(kappa{k}-params.baselineCurve(2))).^2 <touchThreshi);
                
   
            elseif meanContactCurve(k) > params.nogoProThresh
                touchThreshi=params.touchThresh(4); % use no-go / retraction threshold
                trialContactType(k)=4;
                        % Finds indexes of time periods of contacts by distance to pole - curvature

                contacts{k}.contactInds{1} = time{k}(distanceToPoleCenter{k}...
                    - params.curveMultiplier*abs(kappa{k}-params.baselineCurve(2))...
                    - (params.curveMultiplier*5*(kappa{k}-params.baselineCurve(2))).^2 <touchThreshi);
                
            else
                trialContactType(k)=0;
            end
            
        end
        

        % Crops contact indexes to only pole available times
        contacts{k}.contactInds{1} = ...
            contacts{k}.contactInds{1}(contacts{k}.contactInds{1} > params.poleOffset + pinDescentOnsetTime{k} ...
            & contacts{k}.contactInds{1} < params.poleEndOffset+ pinAscentOnsetTime{k} );
        
        [~,~,contacts{k}.contactInds{1}]=intersect(contacts{k}.contactInds{1},time{k}); % c, ia are unused
        
        % Recalculate mean contact curvature with refined contacts
        meanContactCurve(k)=nanmean(kappa{k}(contacts{k}.contactInds{1}));
        contacts{k}.trialContactType=trialContactType(k);
        contacts{k}.contactInds{1}=contacts{k}.contactInds{1}(:)';
    end
end

