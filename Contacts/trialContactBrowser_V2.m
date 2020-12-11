% trialContactBrowser_V2 is a tool to determine and examine whisking and contacts
%
% trialContactBrowser_V2(array) will construct an first pass estimate of
% contacts using default parameters.
%
% trialContactBrowser_V2(array, contacts) will load the browser with the
% contact info specified in the contacts structure, but default detection
% parameters.
%
% trialContactBrowser_V2(array, contacts, params) will load the browser with
% the contact and parameter info specified in your saved structures. If you
% have built a contacts array from the trial array already, this is how you
% want to call the program.
%
% Version 1.0 SAH 140514

% Phillip Maire Aug 15 2020 -- 200815 made the following edits, edit 1)
% below and a small other edit made this program work with matlab 2020.
% tested on 2017-2020.
% 1) added function subplot_old_2013_position to allow for the new crappier
% subplot function to not break (see program description)
% 2) using a while loop I have made it so that the program doesn't get stuck
% on the missing trail error, it simply goes to the next availible trial.
% 3) keeping the same graphs I made all but the main graph of whisker
% position basically so small that they don't bother you. I did this (as
% opposed to removing them) in case they are desired in the future. They
% just have to use the prefered size coordinates in the 100X100 subplot
% grid.
% 4) ADDED SHORTCUT KEYS!!! I have show that in theory these shortcuts
% could have been imlemented in MATLAB 2013 as well but I did not edit this
% script to do that in the 2013 MATLAB b/c I don't see any point in that.
% ###################### below is a link to how I use undocumented matlab
% tools to make the shortcuts work. it might break in future releases and
% this link explains everything
% https://undocumentedmatlab.com/matlab/wp-content/cache/all/articles/enabling-user-callbacks-during-zoom-pan/index.html
% ######################
% see file "set_custom_shortcuts_TCB.m" for examples of the shortcuts and
% how to set them up yourself, it is pretty easy just read the that file.
%{
BASICS SHORTCUTS
-double click to zoomout and then back to where you last were zoomed in to
-b = brush toggle
-z = zom toggle
-1 and 2 are 'pan' left and right 1/3 of the current zoom level ( so if x
axis is 1 to 3 then -> 3-1 = 2, 2/3 = .666, --> new position is 1.666 to
3.666 if you hit the 2 key. used to pan across while maintaining a
certain zoom level the entire time.
-double clicking the right mouse will pan to the right as well!!!
-a or left arraow goas back a trial
-d of rightarrow or 3 key goes forward a trial
** thes ekeep the same zoom level and start you off at the beginning of the
trial so you can just keep on curating!!!!! should never need the zoom tool
except at the beginning of the session.
-scroll up and down to add or remove highlighted points
-right click once to bring up videos (NOTE some matlabs you have to click
**the video button to set up the viddeo directory first!!!, then this will
work)
-alt is save (the old way)
-s key or clicking the scroll button (on the mouse clicking it down) activates quick
save which has "QUICK SAVE" appended to the beginning of the the contacts
that is saved. it will auto save in the directory matlab is in. it will
overwrite other quicksaves that are that same session.
ALL SHORTCUTS WORK WHILE THE BRUSH TOOL IS SELECTED SO DONT WORRY ABOUT
EVER CHANGING IT.


%}
function trialContactBrowser_V2(array, contacts, params, varargin)
% version_test = version('-release');
% v_test = str2num(version_test(1:4))>2013;% is greater than the 2013 version this software is meant for

if nargin <4
    if nargin==1
        disp('Contacts data missing, building and assigning to workspace as "contacts"')
        [contacts, params]=autoContactAnalyzerSi(array);
        contactsname = 'contacts';
        %        assignin('base','contacts',contacts);
    end
    
    if nargin<=2
        % Populate parameters with defaults
        params.sweepNum = find(array.whiskerTrialInds,1);
        params.displayType = 'all';
        params.displayTypeMinor = 'none';
        params.arbTimes = [];
        params.trialList = '';
        params.trialRange =  [array.trialNums(1) array.trialNums(end)];
        params.colors = prism(length(array.cellNum));
        params.trialcolors = {'g','r','k','b'};
        params.summarize = 'off';
        params.touchThresh = [.1 .1 .1 .1]; %Touch threshold for go (protraction, retraction), no-go (protraction,retraction). Check with Parameter Estimation cell
        params.goProThresh = 0; % Mean curvature above this value indicates probable go protraction, below it, a go retraction trial.
        params.nogoProThresh = 0; % Mean curvature above this value indicates probable nogo protraction, below it, a nogo retraction trial.
        params.poleOffset = .50; % Time where pole becomes accessible
        params.poleEndOffset = .195; % Time between start of pole exit and inaccessiblity
        params.tid=0; % Trajectory id
        params.framesUsed=1:length(array.trials{find(array.whiskerTrialInds,1)}.whiskerTrial.time{1});
        params.curveMultiplier=1.5;
        params.noiseMultiplier=1.5;
        params.baselineCurve = [0 .02]; % To subtract from the baseline curve for contact detection
        params.videoDirectory = {};
        
        %             'maxBins', 51, 'spikeRateWindow', .05, 'spikeSynapticOffset',0,...
        %             'colors',prism(length(array.cellNum)), 'trialcolors', {{'g','r','k','b'}}, 'summarize', 'off');
        %
        
        % Get mean answer time
        tmp=[];
        for i=1:array.length
            if isempty(array.trials{i}.answerLickTime)==0
                tmp(i)=array.trials{i}.answerLickTime;
            else
                tmp(i)=NaN;
            end
        end
        
        params.meanAnswerTime=nanmean(tmp);
        params.cellNum   = array.cellNum;
        params.trialNums = array.trialNums;
        params.arrayname = inputname(1);
        
        % Define the type of spike data present
        if sum(ismember(fieldnames(array.trials{params.sweepNum}),'shanksTrial'))
            params.spikeDataType = 'silicon';
            params.shankNum  = array.shankNum;
        elseif sum(ismember(fieldnames(array.trials{params.sweepNum}),'spikesTrial'))
            params.spikeDataType = 'singleUnit';
        else
            params.spikeDataType = 'none';
        end
        
    end
    
    if  nargin == 1
        params.contactsname = 'contacts';
    else
        params.contactsname = inputname(2);
        params.arrayname = inputname(1); % Command-line name of this instance of a TrialArray.
        
    end
    params = define_shortcut_keys(params);
    
    
    % Setup Figure and handles
    hParamBrowserGui = figure('Color','white'); ht = uitoolbar(hParamBrowserGui);
    
    
    
    
    
    setappdata(0,'hParamBrowserGui',gcf);
    hParamBrowserGui = getappdata(0,'hParamBrowserGui');
    h_b=brush(hParamBrowserGui);
    try
        set(h_b,'Color',[1 0 1]);
    catch
        h_b.Color = [1 0 1];
    end
    
    % Setup pushbuttons
    icon_cell         = {...
        'icon_del'             , 'delete.tif', '' ;...
        'icon_add'             , 'add.png', '' ;...
        'icon_right'             , 'arrow-right.png', '' ;...
        'icon_left'             , 'arrow-left.png', '' ;...
        'icon_recalc'             , 'refresh.png', '' ;...
        'icon_save'             , 'save.png', '' ;...
        'icon_float'             , 'floatingBaseline.tif', '' ;...
        'icon_floatOff'             , 'floatingBaselineOff.tif', '' ;...
        'icon_zoomIn'             , 'arrow-down.png', '' ;...
        'icon_zoomOut'             , 'arrow-up.png', '' ;...
        'icon_exclude'             , 'red_flag_16.png', '' ;...
        'icon_video'             , 'video_camera.png', '' ;...
        };
    % renamed the icons with a specific label ' - TCB.' (trial contact browser)
    % so that it will find the right ones. new matlab has some icons with the
    % same names on path.
    for icon_iter = 1:length(icon_cell(:, 1))
        t = icon_cell{icon_iter, 2};
        icon_cell{icon_iter, 3} = [extractBefore(t, '.'), ' - TCB.', extractAfter(t, '.')];
    end
    % try to load teh news first then load the old ons if
    % it doesnt work
    trig_warning = 0;
    for icon_iter = 1:length(icon_cell(:, 1))
        try
            eval([icon_cell{icon_iter, 1}, '= imread(''', icon_cell{icon_iter, 3}, ''');']);
        catch
            trig_warning = 1;
            eval([icon_cell{icon_iter, 1}, '= imread(''', icon_cell{icon_iter, 2}, ''');']);
        end
    end
    
    icon_quick_save = icon_save;% make a grean version of save for quick_save function
    icon_quick_save(:, :, 3) = icon_quick_save(:, :, 3)/5;
    
    if trig_warning
        warning('Icons need to be updated make sure to use the new icons from github with the '' - TCB.'' in the name. You can keep both copies of the icons.')
    end
    
    if size(icon_add, 3)==1%issues with reading matlab add png this way it still works
        % but to be clear this shit is wrong need to add the new icon files
        icon_add = repmat(icon_add, 1, 1, 3);
    end
    
    bbutton = uipushtool(ht,'CData',icon_left,'TooltipString','Back');
    fbutton = uipushtool(ht,'CData',icon_right,'TooltipString','Forward');
    abutton = uipushtool(ht,'CData',icon_add,'TooltipString','Add Contact','Separator','on');
    dbutton = uipushtool(ht,'CData',icon_del,'TooltipString','Delete Contact');
    rbutton = uipushtool(ht,'CData',icon_recalc,'TooltipString','Recalculate Contact Dependents');
    flagToggle = uitoggletool(ht,'CData',icon_exclude,'TooltipString','Flag trial for exclusion');
    
    sbutton = uipushtool(ht,'CData',icon_save,'TooltipString','Save Contacts and Parameters','Separator','on');
    qsbutton = uipushtool(ht,'CData',icon_quick_save,'TooltipString','quick Save Contacts and Parameters','Separator','on');
    
    floatToggle = uitoggletool(ht,'CData',icon_floatOff, 'TooltipString', 'Toggle PreContact Baseline Correction');
    zoomToggle  = uitoggletool(ht, 'CData',icon_zoomOut,   'TooltipString', 'Toggle Zoom Level');
    vbutton = uipushtool(ht, 'CData',icon_video,   'TooltipString', 'Go to Video Frames');
    
    
    
    % Setup pushbutton callbacks
    set(fbutton,'ClickedCallback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''next'')'])
    set(bbutton,'ClickedCallback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''last'')'])
    set(abutton,'ClickedCallback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''add'')'])
    set(dbutton,'ClickedCallback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''del'')'])
    set(rbutton,'ClickedCallback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''recalc'')'])
    set(sbutton,'ClickedCallback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''save'')'])
    set(qsbutton,'ClickedCallback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''quick_save'')'])
    set(vbutton,'ClickedCallback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''videoOn'')'])
    
    set(flagToggle,'OnCallback',   ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''flagOn'')'])
    set(flagToggle,'OffCallback',  ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''flagOff'')'])
    set(floatToggle,'OnCallback',  ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''floatOn'')'])
    set(floatToggle,'OffCallback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''floatOff'')'])
    set(zoomToggle,'OnCallback',   ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''zoomOut'')'])
    set(zoomToggle,'OffCallback',  ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''zoomIn'')'])
    
    % Setup menus
    m1=uimenu(hParamBrowserGui,'Label','Time Period','Separator','on');
    uimenu(m1,'Label','All'                          ,'Callback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''all'')']);
    uimenu(m1,'Label','Contacts Only'                ,'Callback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''contactsOnly'')']);
    uimenu(m1,'Label','Exclude Contacts'             ,'Callback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''excludeContacts'')']);
    uimenu(m1,'Label','Pole Presentation to Decision','Callback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''poleToDecision'')']);
    uimenu(m1,'Label','First Contact to Decision'    ,'Callback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''contactToDecision'')']);
    uimenu(m1,'Label','Post Decision'                ,'Callback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''postDecision'')']);
    uimenu(m1,'Label','Post Pole'                    ,'Callback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''postPole'')']);
    uimenu(m1,'Label','Abritrary Range'              ,'Callback', ['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''arbitrary'')']);
    
    m2=uimenu(hParamBrowserGui,'Label','Adjust parameters','Separator','on');
    uimenu(m2,'Label','Plots'   ,'Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''adjPlots'')']);
    uimenu(m2,'Label','Spikes'  ,'Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''adjSpikes'')']);
    uimenu(m2,'Label','Contacts','Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''adjContacts'')']);
    uimenu(m2,'Label','Trial Range','Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''adjTrials'')']);
    
    uimenu(hParamBrowserGui,'Label','Jump to sweep','Separator','on','Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''jumpToSweep'')']);
    
    % Old code to call external contact summary routines, may reimplement in
    % future versions -SAH
    %
    %     m3=uimenu(hParamBrowserGui,'Label','Summarize','Separator','on');
    %     uimenu(m3,'Label','STA'     ,'Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''STA'')']);
    %     uimenu(m3,'Label','Clusts'  ,'Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''clusts'')']);
    %     uimenu(m3,'Label','Tuning'  ,'Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''tuning'')']);
    %     uimenu(m3,'Label','Contacts','Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''contacts'')']);
    %     uimenu(m3,'Label','Fit'     ,'Callback',['trialContactBrowser_V2(' params.arrayname ',' params.contactsname ', params,''fit'')']);
    %
    %
    setappdata(hParamBrowserGui, 'params',params);
    setappdata(hParamBrowserGui, 'contacts', contacts);
    setappdata(hParamBrowserGui, 'array', array);
else
    hParamBrowserGui = getappdata(0,'hParamBrowserGui');
    params = getappdata(hParamBrowserGui,'params');
    
    if isempty(params) % Initial call to this method has argument
        params = struct('sweepNum',find(cellfun(@(x) ~isempty(x.whiskerTrial),array.trials),1),'trialList',params.trialNums(cellfun(@(x) ~isempty(x.whiskerTrial),T.trials)),'displayType','all');
    end
    SPinds = 1:100*100;
    SPinds = reshape(SPinds, 100, 100)';
    tmpIND = SPinds(1:90, 1:99);
    position = subplot_old_2013_position(100,100,tmpIND(:));
    hs_1 = subplot('Position', position);
    
    for j = 1:length(varargin);
        argString = varargin{j};
        switch argString
            case 'toggle_axes'
                toggle_axes(hParamBrowserGui)
%                 pause(0.25)
                params = getappdata(hParamBrowserGui,'params');
                return
            case 'next'
                if params.sweepNum < length(array.trials)
                    params.sweepNum = params.sweepNum + 1;
                    while isempty(array.trials{params.sweepNum}.whiskerTrial) && params.sweepNum < length(array.trials)
                        params.sweepNum = params.sweepNum + 1;
                    end
                end
                if params.sweepNum == length(array.trials)
                    warning('You have reached the end of the available contact arrays') ;
                    return
                end
                
                %                 reset_axes(params);
                reset_axes_for_curating_next_trial(array)
                %                 hParamBrowserGui.Children(8).Children(2).YData
            case 'last'
                
                
                if params.sweepNum > 1
                    params.sweepNum = params.sweepNum - 1;
                    while isempty(array.trials{params.sweepNum}.whiskerTrial) && params.sweepNum > 1
                        params.sweepNum = params.sweepNum - 1;
                    end
                end
                
                %                 reset_axes(params);
                reset_axes_for_curating_next_trial(array)
                
            case 'add'
                
                toAdd = [];
                try
                    toAdd = find(get(findobj('Tag','t_d'),'BrushData'));
                    display ('Distance Brushing')
                catch
                    keyboard
                end
                
                
                if ~isempty(toAdd);
                    
                    addContact(toAdd);
                end
                contacts = getappdata(getappdata(0,'hParamBrowserGui'),'contacts');
                SPinds = 1:100*100;
                SPinds = reshape(SPinds, 100, 100)';
                tmpIND = SPinds(1:90, 1:99);
                position = subplot_old_2013_position(100,100,tmpIND(:));
                hs_1  = subplot('Position', position);
                params.xlim =  get(hs_1,'xlim');
                params.ylim =  get(hs_1,'ylim');
                
                time=array.trials{params.sweepNum}.whiskerTrial.time{1}; % All times in current trial
                cW=array.trials{params.sweepNum}.whiskerTrial;
                set(findobj('Tag','t_d'),'BrushData', []) %clear selection 
                try
                    [~, keep_inds, ~] = intersect(time, params.red_dots{2}.XData);
                    keep_inds = unique([keep_inds(:); toAdd(:)]);
                    set(params.red_dots{2}, 'XData', cW.time{1}(keep_inds), 'YData', cW.distanceToPoleCenter{1}(keep_inds))
                    set(params.red_dots{3}, 'XData', cW.time{1}(keep_inds), 'YData', cW.deltaKappa{1}(keep_inds))
                    set(params.red_dots{4}, 'XData', cW.time{1}(keep_inds), 'YData',cW.M0{1}(keep_inds))
                    return
                catch 
                end
            case 'del'
                
                toDel = [];
                try
                    toDel = find(get(findobj('Tag','t_d'),'BrushData'));
                    display ('Distance Brushing')
                catch
                    keyboard
                end
                
                
                if ~isempty(toDel);
                    delContact(toDel);
                end
                
                contacts = getappdata(getappdata(0,'hParamBrowserGui'),'contacts');
                SPinds = 1:100*100;
                SPinds = reshape(SPinds, 100, 100)';
                tmpIND = SPinds(1:90, 1:99);
                position = subplot_old_2013_position(100,100,tmpIND(:));
                hs_1 = subplot('Position', position);
                
                params.xlim =  get(hs_1,'xlim');
                params.ylim =  get(hs_1,'ylim');
                
                time=array.trials{params.sweepNum}.whiskerTrial.time{1}; % All times in current trial
                cW=array.trials{params.sweepNum}.whiskerTrial;
                set(findobj('Tag','t_d'),'BrushData', []) %clear selection 
                try                    
                    [~, keep_inds] = setdiff(params.red_dots{2}.XData, time(toDel));
                    set(params.red_dots{2}, 'XData', cW.time{1}(keep_inds), 'YData', cW.distanceToPoleCenter{1}(keep_inds))
                    set(params.red_dots{3}, 'XData', cW.time{1}(keep_inds), 'YData', cW.deltaKappa{1}(keep_inds))
                    set(params.red_dots{4}, 'XData', cW.time{1}(keep_inds), 'YData',cW.M0{1}(keep_inds))
                    return
                catch 
                end
            case 'recalc'
                [contacts params] = autoContactAnalyzerSi(array, params, contacts, 'recalc');
                set(0,'CurrentFigure',hParamBrowserGui);
                
            case 'flagOn'
                contacts{params.sweepNum}.passiveTouch = 1;
                setappdata(hParamBrowserGui,'contacts', contacts);
                
            case 'flagOff'
                contacts{params.sweepNum}.passiveTouch = 0;
                setappdata(hParamBrowserGui,'contacts', contacts);
                
            case 'floatOn'
                
                if ~isfield(params,'floatingBaseline');
                    [contacts params] = autoContactAnalyzerSi(array, params, contacts, 'recalc');
                end
                
                params.floatingBaseline = 1;
                set(0,'CurrentFigure',hParamBrowserGui);
                
            case 'floatOff'
                params.floatingBaseline = 0;
                
            case 'zoomOut'
                
                params.zoomOut = 1;
                set(hs_1,'Xlim',[0 4.5],'YLim',[-.5 5])
                
            case 'zoomIn'
                params.zoomOut = 0;
                set(hs_1,'Xlim',[0 4.5],'YLim',[-.3 1])
                
            case 'save'
                assignin('base','contacts',contacts);
                assignin('base','params',params);
                uisave( {'contacts', 'params'},['ConTA_' array.mouseName '_' array.sessionName '_' array.cellNum '_' array.cellCode])
                display('Saved Contacts and Parameters')
                
            case 'quick_save'
                assignin('base','contacts',contacts);
                assignin('base','params',params);
                quick_save_name = ['QUICK SAVED ConTA_' array.mouseName '_' array.sessionName '_' array.cellNum '_' array.cellCode];
                save(quick_save_name,  'contacts', 'params')
                fprintf(['QUICK SAVED Contacts and Parameters - REMEMBER, THIS OVERWRITES THE EXISTING FILE. \nThis file is saved with the words',...
                    '''QUICK SAVED'' appended to the beginning. \nOnce finished curating rename this file to be sure that it is not saved over next time.\n'])
                disp(['File was saved here aved here-> ',pwd, filesep, quick_save_name])
                return
            case 'jumpToSweep'
                if isempty(params.trialList)
                    nsweeps = array.length;
                    params.trialList = cell(1,nsweeps);
                    for k=1:nsweeps
                        params.trialList{k} = [int2str(k) ': trialNum=' int2str(params.trialNums(k))];
                        
                    end
                end
                [selection,ok]=listdlg('PromptString','Select a sweep:','ListString',...
                    params.trialList,'SelectionMode','single');
                if ~isempty(selection) && ok==1
                    params.sweepNum = selection;
                end
                 if params.sweepNum < length(array.trials)
                    trig_on = 0;
                    while isempty(array.trials{params.sweepNum}.whiskerTrial) && params.sweepNum < length(array.trials)
                        trig_on = 1;
                        params.sweepNum = params.sweepNum + 1;
                    end
                    if trig_on
                       warning('select trial nor earlier trials exist, reverting back to earliest trial') 
                    end
                end
                if params.sweepNum == length(array.trials)
                    trig_on = 0;
                    while isempty(array.trials{params.sweepNum}.whiskerTrial) && params.sweepNum > 0
                        trig_on = 1;
                        params.sweepNum = params.sweepNum - 1;
                    end
                    if trig_on
                    warning(['reverting back to the last trial which is trial ', num2str(params.sweepNum)])
                    end
                    warning('You have reached the end of the available contact arrays') ;
                end
                
            case 'adjPlots'
                prompt = {'Maximum bins for plots'};
                dlg_title = 'Plotting Parameters';
                num_lines = 1;
                def = {num2str(params.maxBins)};
                plotParams = inputdlg(prompt,dlg_title,num_lines,def);
                
                params.maxBins=str2num(plotParams{1});
                
            case 'adjSpikes'
                prompt = {'Window size of spike integration (s)', 'Estimated synaptic delay between spikes and whiskers (s)'};
                dlg_title = 'Spike Rate Parameters';
                num_lines = 1;
                def = {num2str(params.spikeRateWindow), num2str(params.spikeSynapticOffset)};
                spikeParams = inputdlg(prompt,dlg_title,num_lines,def);
                params.spikeRateWindow=str2num(spikeParams{1});
                params.spikeSynapticOffset=str2num(spikeParams{2});
                
            case 'adjContacts'
                prompt = {'Trajectory ID :','Pole delay from onset till in range (s)','Pole delay from offset till out of range (s)',...
                    'Contact distance thresholds (go/pro, go/ret, nogo/pro, nogo/ret)', 'Go pro/ret curvature threshold',...
                    'Nogo pro/ret curvature threshold','Curve Multiplier','Noise Multiplier','Baseline Curve go/nogo'};
                dlg_title = 'Contact Parameters';
                num_lines = 1;
                def = {num2str(params.tid), num2str(params.poleOffset), num2str(params.poleEndOffset),...
                    num2str(params.touchThresh), num2str(params.goProThresh),num2str(params.nogoProThresh),...
                    num2str(params.curveMultiplier), num2str(params.noiseMultiplier), num2str(params.baselineCurve)};
                dlgout = inputdlg(prompt,dlg_title,num_lines,def);
                
                if ~isempty(dlgout)
                    params.tid= str2num(dlgout{1});
                    params.poleOffset=str2num(dlgout{2});
                    params.poleEndOffset=str2num(dlgout{3});
                    params.touchThresh = str2num(dlgout{4}); %Touch threshold for go (protraction, retraction), no-go (protraction,retraction). Check with Parameter Estimation cell
                    params.goProThresh = str2num(dlgout{5}); % Mean curvature above this value indicates probable go protraction, below it, a go retraction trial.
                    params.nogoProThresh = str2num(dlgout{6});
                    params.curveMultiplier = str2num(dlgout{7});
                    params.noiseMultiplier = str2num(dlgout{8});
                    params.baselineCurve = str2num(dlgout{9});
                    
                    disp('Recalculating session contact data')
                    [contacts, params]=autoContactAnalyzerSi(array, params, contacts);
                    setappdata(hParamBrowserGui,'contacts',contacts);
                    setappdata(hParamBrowserGui,'params',params);
                    
                    assignin('base','contacts',contacts);
                    figure(hParamBrowserGui);
                else
                    disp('Contact Parameter Adjustment Cancelled')
                end
                
                
            case 'adjTrials'
                prompt = {'Trial Range'};
                dlg_title = 'Trial Range';
                num_lines = 1;
                def = {num2str(params.trialRange)};
                trialParams = inputdlg(prompt,dlg_title,num_lines,def);
                
                params.trialRange=str2num(trialParams{1});
                
            case 'all'
                params.displayType = 'all'
                
            case 'contactsOnly'
                params.displayType = 'contactsOnly'
                disp('Updating Time Period, please wait')
                
            case 'excludeContacts'
                params.displayType = 'excludeContacts'
                disp('Updating Time Period, please wait')
                
            case 'poleToDecision'
                params.displayType = 'poleToDecision'
                disp('Updating Time Period, please wait')
                
            case 'contactToDecision'
                params.displayType = 'contactToDecision'
                disp('Updating Time Period, please wait')
                
            case 'postDecision'
                params.displayType = 'postDecision'
                disp('Updating Time Period, please wait')
                
            case 'postPole'
                params.displayType = 'postPole'
                disp('Updating Time Period, please wait')
                
            case 'arbitrary'
                params.displayType = 'arbitrary'
                prompt = {'Enter starting time (in ms):','Enter ending time (in sec)'};
                dlg_title = 'Select a timeperiod for analysis';
                num_lines = 1;
                def = {'0','4.500'};
                disp('Updating Time Period, please wait')
                params.arbTimes = inputdlg(prompt,dlg_title,num_lines,def);
                
            case 'STA'
                params.summarize = 'STA'
                
            case 'clusts'
                params.summarize = 'clusts'
                
            case 'tuning'
                params.summarize = 'tuning'
                
            case 'contacts'
                params.summarize = 'contacts'
                
            case 'fit'
                params.summarize = 'fit'
                
            case 'videoOn'
                if isempty(getappdata(hParamBrowserGui,'videoDir'))
                    videoDir = uigetdir;
                    setappdata(hParamBrowserGui,'videoDir', videoDir);
                else
                    videoDir = getappdata(hParamBrowserGui,'videoDir');
                    
                end
                if  isfield(get(findobj('Tag','t_d')),'BrushData') || ~isempty(find(get(findobj('Tag','t_d'),'BrushData')))
                    brushedData = find(get(findobj('Tag','t_d'),'BrushData'));
                    fr = round(1/array.trials{params.sweepNum}.whiskerTrial.framePeriodInSec);
                    toPlay = round(array.trials{params.sweepNum}.whiskerTrial.time{1}(brushedData)*fr)+1;
                    loadWhiskerVideo(array.trialNums(params.sweepNum), toPlay, videoDir);
                    params = getappdata(hParamBrowserGui,'params');
                    contacts = getappdata(hParamBrowserGui,'contacts');
                else
                    display('No datapoints found, please brush points before calling video')
                end
                set(findobj('Tag','t_d'),'BrushData', []) %clear selection 
            case 'pass' % pass so I can have my own function without going through this like move left or right
                test1 = 1
                return
            otherwise
                error('Invalid string argument.')
        end
    end
end
tmp_h = keep_my_selection_of_figure_tools_please(hParamBrowserGui);

hParamBrowserGui = getappdata(0,'hParamBrowserGui');
keep_my_selection_of_figure_tools_please(hParamBrowserGui, tmp_h, array);

if isfield(params,'showVideo')
    if params.showVideo == 1
        videoDir = getappdata(hParamBrowserGui,'videoDir');
        loadWhiskerVideo(array.trialNums(params.sweepNum), toPlay, videoDir);
    end
end


if ~isfield(params,'spikeDataType')
    
    if sum(ismember(fieldnames(array.trials{params.sweepNum}),'shanksTrial'))
        params.spikeDataType = 'silicon';
        params.shankNum  = array.shankNum;
    elseif sum(ismember(fieldnames(array.trials{params.sweepNum}),'spikesTrial'))
        params.spikeDataType = 'singleUnit';
    else
        params.spikeDataType = 'none';
    end
end

% properly populate flag exclusion toggle state from contacts
% h_flag = findobj(1,'TooltipString','Flag trial for exclusion'); % Get handle for the exclusion flag toggle
%
% if isfield(contacts{params.sweepNum},'passiveTouch')
%     if contacts{params.sweepNum}.passiveTouch == 0
%         set(h_flag,'State','off');
%     else
%         set(h_flag,'State','on');
%     end
% else
%     contacts{params.sweepNum}.passiveTouch = 0;
%     set(h_flag,'State','off');
% end
% setappdata(hParamBrowserGui,'contacts', contacts);
% setappdata(hParamBrowserGui,'params', params);


% Shorthand notation
%#here

time=array.trials{params.sweepNum}.whiskerTrial.time{1}; % All times in current trial
cT=array.trials{params.sweepNum};
cW=array.trials{params.sweepNum}.whiskerTrial;
cB=array.trials{params.sweepNum}.behavTrial;

if strcmp(params.spikeDataType,'silicon')
    
    cS=array.trials{params.sweepNum}.shanksTrial;
    % Calculate the spike rate across trials
    sampleRate=cS.sampleRate;
    
end

if strcmp(params.spikeDataType,'singleUnit')
    
    cS=array.trials{params.sweepNum}.spikesTrial;
    % Calculate the spike rate across trials
    sampleRate=cS.sampleRate;
    
end

if strcmp(params.spikeDataType,'Vm')
    
    cS=array.trials{params.sweepNum}.spikesTrial;
    % Calculate the spike rate across trials
    sampleRate=cS.sampleRate;
    
end
% Select relevant frame periods

switch params.displayType
    
    case 'all'
        params.framesUsed = 1:length(time);
        
    case 'contactsOnly'
        params.framesUsed = contacts{params.sweepNum}.contactInds{1};
        
    case 'excludeContacts'
        params.framesUsed = ones(size(time));
        params.framesUsed(contacts{params.sweepNum}.contactInds{1})=0;
        params.framesUsed= find(params.framesUsed);
        
    case 'poleToDecision'
        if isempty(cB.answerLickTime)==0
            params.framesUsed = find(time > cT.pinDescentOnsetTime+params.poleOffset &...
                time < cB.answerLickTime);
        else
            params.framesUsed = find(time > cT.pinDescentOnsetTime+params.poleOffset &...
                time < params.meanAnswerTime);
        end
        
    case 'contactToDecision'
        if isempty(contacts{params.sweepNum}.contactInds{1})==0
            params.framesUsed = find(time > time(contacts{params.sweepNum}.contactInds{1}(1)) &...
                time < params.meanAnswerTime);
        else
            params.framesUsed=[];
        end
        
    case 'postDecision'
        
        if isempty(cB.answerLickTime)==0;
            params.framesUsed = find(time > cB.answerLickTime);
        else
            params.framesUsed = find(time> params.meanAnswerTime);
        end
        
    case 'postPole'
        params.framesUsed = find(time > cT.pinAscentOnsetTime);
        
    case 'arbitrary'
        params.framesUsed = find(time > str2num(params.arbTimes{1}) & time < str2num(params.arbTimes{2}));
        
    otherwise
        error('Invalid string argument.')
end

% Contact discrimination parameters

% spikeIndex=zeros(100000,1);
if isempty(cW)==1
    position = subplot_old_2013_position(4,3,1)
    subplot('Position', position);
    text(0,0,'Whisker Data Missing for Trial');
else

    params.cropind=[];   cind=[];   y1=[];   x1=[];    y2=[];   x2=[];
    params.cropind=find(cW.time{1} > params.poleOffset+cB.pinDescentOnsetTime & cW.time{1} < params.poleEndOffset+cB.pinAscentOnsetTime);
    cind=contacts{params.sweepNum}.contactInds{1};%set inds to plot red dots for touch times
    y1=cW.distanceToPoleCenter{1}(params.cropind);
    x1=cW.kappa{1}(params.cropind);
    y2=cW.distanceToPoleCenter{1}(cind);
    x2=cW.kappa{1}(cind);
    tmax=max(cW.time{1});
    
    SPinds = 1:100*100;
    SPinds = reshape(SPinds, 100, 100)';
    % Plot contact detection parameters
    tmpIND = SPinds(1, 100);
    
    position = subplot_old_2013_position(100,100,tmpIND(:));
    hold off;
    hs_2 = subplot('Position', position);
    plot(x1,y1,'.k','Tag','t_cvd'); hold on
    axis([min(x1)-.02 max(x1)+.02 min(y1)-.3 max(y1)+1])
    
    params.red_dots{1} = plot(x2,y2,'.r');
    %     title('Contact Parameters')
    axis tight
    %     xlabel('Curvature (\kappa)')
    %     ylabel('Dist to pole (mm)')
    
    % Plot Trial info
    tmpIND = SPinds(1:6, end:end);
    
    position = subplot_old_2013_position(100,100,tmpIND(:));
    subplot('Position', position);
    hold off;
    
    plot([0 1],[0 1],'.');
    set(gca,'Visible','off');
    
    text(0,1.2,[int2str(params.sweepNum) '/' int2str(array.length) ...
        ', Trial=' int2str(params.trialNums(params.sweepNum))]);
    
    text(0,.95, ['\fontsize{10}' array.trials{params.sweepNum}.trialOutcome]);
    text(0,.7, ['\fontsize{10}' 'Mean Answer Time : ' num2str(params.meanAnswerTime) ' (s)']);
    text(0,.4, ['\fontsize{10}' 'Mouse : ' array.mouseName]);
    text(0,.1, ['\fontsize{10}' 'Cell : ' params.cellNum ' ' array.cellCode]) ;
    
    % Distance to pole center
    tmpIND = SPinds(1:90, 1:99);
    position = subplot_old_2013_position(100,100,tmpIND(:));
    hs_1 = subplot('Position', position);
    current_x = get(hs_1,'xlim');
    current_y = get(hs_1,'ylim');
    hParamBrowserGui = getappdata(0,'hParamBrowserGui');
    setappdata(hParamBrowserGui,'current_x',current_x)
    setappdata(hParamBrowserGui,'current_y',current_y)
    %%%%%%%%%
    ca_tmp = gca;
    % set axis back to the pole trigger time (that way we can see just
    % before the pole is in reach and we dont have to scroll
    %     X_ax_set = [ca_tmp.XLim+(cT.pinDescentOnsetTime - ca_tmp.XLim(1))];
    X_ax_set = ca_tmp.XLim;
    Y_ax_set = ca_tmp.YLim;
    hold off;
% %     tmp1 = gca;
%     hold(gca,'on');
%     
%     hold(handles.axes1,'on');
    axis('manual')
    plot(cW.time{1},cW.distanceToPoleCenter{1},'.-k','Tag','t_d')
    hold on
    
    ylim(Y_ax_set)
    params.red_dots{2} = plot(cW.time{1}(cind),cW.distanceToPoleCenter{1}(cind),'.r');
    
    title(strcat('Distance to pole center #',...
        num2str(params.trialNums(params.sweepNum))),'FontSize',10)
    ylabel('Distance (mm)');
    
    
    tmp1 = (mode(diff(cW.time{1}))*10);
    params.resetAxesTo_BIG = [min(cW.time{1})-tmp1 , max(cW.time{1})+tmp1, -.5, 4.5];
    
    
    warning('off','MATLAB:modes:mode:InvalidPropertySet')
    hParamBrowserGui.KeyPressFcn = {@key_shortcuts,array, hParamBrowserGui};
    
    hManager = set_mode_manager_free(hParamBrowserGui);
    
    fcnList = {{@(es,ed)datamanager.brushdown(es,ed)}, {@clickcallback, array,hParamBrowserGui}};
    hParamBrowserGui.WindowButtonDownFcn = {@testwrapper, fcnList};
    
    warning('on','MATLAB:modes:mode:InvalidPropertySet')
    %%%%%%%%%%
    tmpIND = SPinds(91:95, 1:99);
    position = subplot_old_2013_position(100,100, tmpIND(:));
    hs_3 = subplot('Position', position);
    
    hold off;
    
    plot(cW.time{1},cW.deltaKappa{1},'.-k')
    hold on
    
    params.red_dots{3} = plot(cW.time{1}(cind),cW.deltaKappa{1}(cind),'.r');
    title(strcat('Change in curvature #',num2str(params.trialNums(params.sweepNum))))
    ylabel('Curvature (K)');
    hold on;
    
    % Plot M0 with contacts scored
    
    M0combo=cW.M0I{1};
    M0combo(abs(M0combo)>1e-7)=NaN;
    M0combo(cind)=cW.M0{1}(cind);
    tmpIND = SPinds(96:100, 1:99);
    position = subplot_old_2013_position(100,100,tmpIND(:));
    hs_4 =subplot('Position', position);
    cla;hold on
    set(gca,'XLim',[0 tmax],'YLim', [-5 5]*1e-7,'Color','k');
    %     set(gca,'YLim', [-5 5]*1e-7,'Color','k');
    title(strcat('Forces associated with trial #',num2str(params.trialNums(params.sweepNum))))
    
    %     linkaxes([hs_1 hs_3 hs_4],'x');
    allAxes = findobj(gcf,'Type','axes','Visible','on');
    try
        linkaxes(allAxes,'x')
    catch
    end
    %     set(hs_1,'XLim',current_x,'YLim',current_y);
    xlim(X_ax_set)
    if ~isfield(params,'floatingBaseline')
        plot(array.trials{params.sweepNum}.whiskerTrial.time{1},contacts{params.sweepNum}.M0combo{1},'-w.','MarkerSize',6)
        params.red_dots{4} = plot(array.trials{params.sweepNum}.whiskerTrial.time{1}(cind),cW.M0{1}(cind),'r.','MarkerSize',8);
    elseif ~params.floatingBaseline
        plot(array.trials{params.sweepNum}.whiskerTrial.time{1},contacts{params.sweepNum}.M0combo{1},'-w.','MarkerSize',6)
        params.red_dots{4} = plot(array.trials{params.sweepNum}.whiskerTrial.time{1}(cind),cW.M0{1}(cind),'r.','MarkerSize',8);
    elseif params.floatingBaseline
        plot(array.trials{params.sweepNum}.whiskerTrial.time{1},contacts{params.sweepNum}.M0comboAdj{1},'-w.','MarkerSize',6)
        params.red_dots{4} = plot(array.trials{params.sweepNum}.whiskerTrial.time{1}(cind),contacts{params.sweepNum}.M0comboAdj{1}(cind),'r.','MarkerSize',8);
    else
    end
    % Plot silicon probe spikes if present
    if strcmp(params.spikeDataType,'silicon')
        for i = 1:length(cS.clustData)
            if length(array.whiskerTrialTimeOffset)>1;
                try
                    plot(double(cS.clustData{i}.spikeTimes)/cS.sampleRate-array.whiskerTrialTimeOffset(params.sweepNum),.5e-7+5e-8*i,'.','color',params.colors(i,:))
                end
            else
                try
                    plot(double(cS.clustData{i}.spikeTimes)/cS.sampleRate-array.whiskerTrialTimeOffset,.5e-7+5e-8*i,'.','color',params.colors(i,:))
                end
            end
            text(tmax*.95,.5e-7+5e-8*i,[num2str(params.shankNum(i)) num2str(params.cellNum(i))],...
                'FontSize',6,'color',params.colors(i,:))
        end
    end
    % Plot cell attached spikes if present
    if strcmp(params.spikeDataType,'singleUnit')
        try
            plot(double(cS.spikeTimes)/cS.sampleRate-array.whiskerTrialTimeOffset,.5e-7+5e-8,'c.')
        end
    end
    % Plot Vm attached spikes if present
    if strcmp(params.spikeDataType,'Vm')
        try
            plot(double(cS.spikeTimes)/cS.sampleRate-array.whiskerTrialTimeOffset,.5e-7+5e-8,'c.')
        end
    end
    try
        plot(array.trials{params.sweepNum}.behavTrial.beamBreakTimes,.5e-7,'m*')
    end
    text(tmax*.95,.5e-7,'Lick','FontSize',6,'color','m')
    ylabel('M0 (N*m) red=contact');
end
assignin('base','params', params);
setappdata(hParamBrowserGui,'params', params);
end

%%
function scroll_function(hObj, evt,array)
contacts = getappdata(getappdata(0,'hParamBrowserGui'),'contacts');% maybe change to hObj
%# MAKE SURE THAT THE ARRAY IS UPDATEED OR WERE FUCKED
params = getappdata(hObj,'params');
if evt.EventName== 'WindowScrollWheel'
    if  evt.VerticalScrollCount>0 % scroll down
        e.Key = 'scroll_down';
    elseif evt.VerticalScrollCount<0 % scroll up
        e.Key = 'scroll_up';
    end
    key_shortcuts(hObj, e, array, hObj)
    brush('on')
    hManager = set_mode_manager_free(hObj);%allow us to set our own callbacks
    fcnList = {{@(es,ed)datamanager.brushdown(es,ed)}, {@clickcallback, array, hObj}};
    hObj.WindowButtonDownFcn = {@testwrapper, fcnList};
    set_scroll_callbacks(hObj, array, contacts, params)
    
end
end
%%
function testwrapper(ObjH, EventData, fcnList)
for iFcn = 1:length(fcnList)
    f =fcnList{iFcn};
    eval_str = 'feval(f{1}, ObjH, EventData';
    for k = 2:length(fcnList{iFcn})
        eval_str = [eval_str, ', f{',num2str(k) '}'];
    end
    eval_str = [eval_str, ');'];
    eval(eval_str)
end
hManager = set_mode_manager_free(ObjH);%allow us to set our own callbacks
params = getappdata(ObjH,'params');
% % % % fcnList = {{@(es,ed)datamanager.brushdown(es,ed)}, {@clickcallback, array, ObjH}};
% % % % hManager.CurrentMode.WindowButtonDownFcn = {@testwrapper, fcnList};
ObjH.WindowButtonDownFcn = {@testwrapper, fcnList};
contacts = getappdata(getappdata(0,'hParamBrowserGui'),'contacts');% maybe change to hObj
array = fcnList{2}{2};
set_scroll_callbacks(ObjH, array, contacts, params)
end

%%
function hManager = set_mode_manager_free(h_fig)
%allow us to set our own callbacks over defaults
hManager = uigetmodemanager(h_fig);
try
    set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
catch
    [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
end
end

%%
function key_shortcuts(src, e, array, h)
trig_cmd_list = {};

warning('off','MATLAB:modes:mode:InvalidPropertySet')
contacts = getappdata(getappdata(0,'hParamBrowserGui'),'contacts');
params = getappdata(gcf,'params');

if params.SC_keys.disply_key_string
    disp(['You just pressed a key identified as ''', e.Key, ...
        ''', use this identifier to set a shortcut using this key!']);
end

%%%%%
F = fieldnames(params.SC_keys.custom);
for FNi = 1:length(F)
    P = eval(['params.SC_keys.custom.', F{FNi}, ';']);
    if ~iscell(P.SC)
        trigON = strcmp(e.Key, P.SC);
    else % allows cell input to map same command onto multiple keys in the same category
        trigON = any(cellfun(@(x) strcmp(e.Key, x), P.SC));
    end
    if trigON
        eval(P.cmd);
        trig_cmd_list{end+1} = F{FNi};
        %was going to put a break here but this could actually be useful
        %like for example if you want to combine the next trial with brush
        %on command in one this could be useful. or close video combined
        %with selecting brush and moving over by some degree. 3 commands in
        %one that will help the user curate.
    end
end
%%%%%
F = fieldnames(params.SC_keys.built_in);
for FNi = 1:length(F)
    P = eval(['params.SC_keys.built_in.', F{FNi}, ';']);
    if ~iscell(P.SC)
        trigON = strcmp(e.Key, P.SC);
    else % allows cell input to map same command onto multiple keys in the same category
        trigON = any(cellfun(@(x) strcmp(e.Key, x), P.SC));
    end
    if trigON
        eval(P.cmd);
        trig_cmd_list{end+1} = F{FNi};
    end
end
%%%%%
ha = gca(h);

F = fieldnames(params.SC_keys.compound);
for FNi = 1:length(F)
    P = eval(['params.SC_keys.compound.', F{FNi}, ';']);
    if ~iscell(P.SC)
        trigON = strcmp(e.Key, P.SC);
    else % allows cell input to map same command onto multiple keys in the same category
        trigON = any(cellfun(@(x) strcmp(e.Key, x), P.SC));
    end
    if trigON
        eval(P.cmd);
        trig_cmd_list{end+1} = F{FNi};
    end
end
%%%%%
switch e.Key
    case params.SC_keys.custom.move_right.SC
        ha.XLim = ha.XLim + diff(ha.XLim)./3;
    case params.SC_keys.custom.move_left.SC
        ha.XLim = ha.XLim - diff(ha.XLim)./3;
end
allAxes = findobj(gcf,'Type','axes','Visible','on');
try
    linkaxes(allAxes,'x')
catch
end
% setappdata(h, 'params', params);
keep_focus(array, h)
set_scroll_callbacks(h, array, contacts, params)
% set up scroll wheel while brush (or anything) is selected. If user uses
% mouse and clicks on brush or zoom etc. This will NOT WORK. must use
% shortcuts instead.

hManager = set_mode_manager_free(h);%allow us to set our own callbacks
set_click_test = [];
for testturn = 1:length(trig_cmd_list)%dont set for these keys 
    set_click_test(end+1) = any(strcmp(trig_cmd_list{testturn}, {'zoom_on';'zoom_off';'zoom_toggle';'pan_on';'pan_off';'pan_toggle'}));
end
if ~any(set_click_test)
    fcnList = {{@(es,ed)datamanager.brushdown(es,ed)}, {@clickcallback, array, h}};
    h.WindowButtonDownFcn = {@testwrapper, fcnList};
end
end
%%
function keep_focus(array, h2)
% below is needed so when selecting inherant matlab tools (eg zoom etc) the 'focus' on the figure isn't lost
try
    hManager2 = uigetmodemanager(h2);
    hManager2.CurrentMode.KeyPressFcn =  {@key_shortcuts,array, h2};
catch
end
end
%%
function set_scroll_callbacks(hfighand, array, contacts, params)
try
    hManager = set_mode_manager_free(hfighand);
    set(hfighand, 'WindowScrollWheelFcn', {@scroll_function, array});
    % % %     set(hfighand, 'WindowScrollWheelFcn', {@scroll_function, array, contacts, params, hfighand});
catch
end
end

%%
function clickcallback(obj,evt, array, h)
persistent chk sel_type cmd_str
d_click_time = 0.25;
if isempty(chk)
    chk = 1;
    sel_type = get(gcf,'SelectionType');
    pause(d_click_time); %Add a delay to distinguish single click from a double click
    if chk == 1 % SET SINGLE CLICK
        cmd_str = ['mouse_',sel_type, '_', num2str(chk)];
        chk = [];
    else %if wasnt a single click dont procede
        return
    end
else % SET DOUBLE CLICK
    chk = 2;
    
%     pause(d_click_time)% needed for focus to be correctb
    cmd_str = ['mouse_',sel_type, '_', num2str(chk)];
    chk = [];
end
e.Key = cmd_str;
key_shortcuts(obj, e, array, h)
end
%%
function toggle_axes(h)
params = getappdata(h, 'params');
if ~isfield(params, 'resetAxesTo_LAST')
    params.resetAxesTo_LAST =  [-0.0100    2.0090   -0.5000    1.5000];
end
if ~isfield(params, 'resetAxesTo_BIG')
    params.resetAxesTo_BIG = [-0.0100    4.0090   -0.5000    4.5000];
end

hax = gca;
currentAX = [hax.XLim, hax.YLim];
%reset to last setting
if all(abs(sum((currentAX - params.resetAxesTo_BIG)))<.01)
    axis(params.resetAxesTo_LAST)
else %reset to defined big axis and save the most recent axis
    params.resetAxesTo_LAST = currentAX;
    
    axis(params.resetAxesTo_BIG)
    setappdata(h, 'params', params);
end
end

%%
function r = keep_my_selection_of_figure_tools_please(fig_hand, varargin)
% takes in one input, if it is a figure handle it copies the infor from
% brush zoom pann tool etc. if not figure it apples thoese settings to the current figure
% if isgraphics(fig_hand_or_struct_to_set,'figure')

r2.brush = brush(fig_hand);
r2.zoom = zoom(fig_hand);
r2.pan = zoom(fig_hand);

if nargin == 1
    r.brush.Enable = r2.brush.Enable;
    
    r.zoom.Enable = r2.zoom.Enable;
    r.zoom.Direction =r2.zoom.Direction;
    r.zoom.Motion = r2.zoom.Motion;
    
    r.pan.Enable = r2.pan.Enable;
    r.pan.Direction =r2.pan.Direction;
    r.pan.Motion = r2.pan.Motion;
elseif nargin >= 2
    r = varargin{1};
    if strcmp(r.brush.Enable, 'on')
        r2.brush.Enable = 'on';r2.brush.Enable = 'off';r2.brush.Enable = r.brush.Enable;
    elseif strcmp(r.zoom.Enable, 'on')
        r2.zoom.Enable = 'on';r2.zoom.Enable = 'off';r2.zoom.Enable = r.zoom.Enable;
        r2.zoom.Direction = 'in';r2.zoom.Direction = 'out';r2.zoom.Direction = r.zoom.Direction;
        r2.zoom.Motion = 'vertical';r2.zoom.Motion = 'horizontal';r2.zoom.Motion = r.zoom.Motion;
    elseif strcmp(r.pan.Enable, 'on')
        r2.pan.Enable = 'on';r2.pan.Enable = 'off';r2.pan.Enable = r.pan.Enable;
        r2.pan.Direction = 'in';r2.pan.Direction = 'out';r2.pan.Direction = r.pan.Direction;
        r2.pan.Motion = 'vertical';r2.pan.Motion = 'horizontal';r2.pan.Motion = r.pan.Motion;
    end
    if nargin>=3
        array = varargin{2};
        keep_focus(array, fig_hand)
        
        %         fig_hand.WindowButtonDownFcn = {@clickcallback, fig_hand, params};
    end
    %     fig_hand.KeyPressFcn = {@key_shortcuts,array, fig_hand};
    %     %     hParamBrowserGui.WindowButtonDownFcn = {@localModeWindowButtonDownFcn}
    
end
end


%%
function  r = loadWhiskerVideo(videoNum,toPlay,videoDir)
% Display rasters of video frames from brushed data
hParamBrowserGui = getappdata(0,'hParamBrowserGui');
obj = getappdata(hParamBrowserGui);
contactTimes = obj.array.trials{obj.params.sweepNum}.whiskerTrial.time{1}(obj.contacts{obj.params.sweepNum}.contactInds{1});
fr = round(1/obj.array.trials{obj.params.sweepNum}.whiskerTrial.framePeriodInSec);
bar = load([videoDir filesep  obj.array.trials{obj.params.sweepNum}.whiskerTrial.trackerFileName '.bar']);
if size(bar, 1) == 3999;
    bar = [bar; [4000, bar(1, 2), bar(1, 3)]] ;
end
if isempty(toPlay)
    video = mmread([videoDir filesepobj.array.trials{obj.params.sweepNum}.whiskerTrial.trackerFileName '.mp4']);
    barSelected = bar(:,2:3,:)
else
    video = mmread([videoDir filesep obj.array.trials{obj.params.sweepNum}.whiskerTrial.trackerFileName '.mp4'],toPlay);
    barSelected = bar(toPlay,2:3,:);
end
poleWindow = [-50:50];
video.isContact = zeros(length(toPlay),1)
[~,brushedContactIdx,~] = intersect(toPlay, round(contactTimes*fr)+1);
video.isContact(brushedContactIdx) = 1;
[poleCropVideoCat poleCropVideoSub] = buildPoleCropVideos(video,barSelected,poleWindow);
h_videofig = figure(5);
clf
position = subplot_old_2013_position(2,1,1);
subplot('Position', position);
colormap(gray(256));
h_cropimg = image(poleCropVideoCat);
axis off
for i = 1:length(toPlay)
    text(length(poleWindow)*(i-1),5,num2str((toPlay(i)-1)/fr),'color','y','fontsize',8)
end
text(0,-2,'Left click to add contact, Right click delete, Enter to save','color','y')

position = subplot_old_2013_position(2,1,2)
subplot('Position', position);
h_diffimg = imagesc(poleCropVideoSub);
axis off
for i = 1:length(toPlay)
    text(length(poleWindow)*(i-1),5,num2str((toPlay(i)-1)/fr),'color','y','fontsize',8)
end
text(0,-10,'Contact','color','k')
text(0,-5,'No Contact','color','w')

% figure(hParamBrowserGui);
%video = mmread(sweepNum,videoDir)
[x,y,button] = ginput

toAddSubIdx = unique(ceil(x(button == 1)/length(poleWindow)));
toDelSubIdx = setdiff(unique(ceil(x(button == 3)/length(poleWindow))),toAddSubIdx);

toAddSubIdx = toAddSubIdx(toAddSubIdx > 0 & toAddSubIdx <= length(toPlay));
toDelSubIdx = toDelSubIdx(toDelSubIdx > 0 & toDelSubIdx <= length(toPlay));

toAddTimes = toPlay(toAddSubIdx);
toDelTimes = toPlay(toDelSubIdx);

[~, toAddIdx,~] = intersect(round(obj.array.trials{obj.params.sweepNum}.whiskerTrial.time{1}*fr)+1,toAddTimes);
[~, toDelIdx,~] = intersect(round(obj.array.trials{obj.params.sweepNum}.whiskerTrial.time{1}*fr)+1,toDelTimes);

toAddIdx = toAddIdx';
toDelIdx = toDelIdx';

if ~isempty(toAddIdx);
    addContact(toAddIdx);
    for i = toAddSubIdx
        video.isContact(i) = 1;
    end
end
if ~isempty(toDelIdx);
    
    delContact(toDelIdx);
    for i = toDelSubIdx
        video.isContact(i)= 0;
    end
end

[poleCropVideoCat, poleCropVideoSub] = buildPoleCropVideos(video,barSelected,poleWindow);

figure(h_videofig);
position = subplot_old_2013_position(2,1,1)
subplot('Position', position);
h_cropimg = image(poleCropVideoCat);
axis off
for i = 1:length(toPlay)
    text(length(poleWindow)*(i-1),5,num2str((toPlay(i)-1)/fr),'color','y','fontsize',8)
end
setappdata(h_videofig,'h_cropimg',h_cropimg)
setappdata(h_videofig,'h_diffimg',h_diffimg)

ap5 = getappdata(h_videofig);

figure(hParamBrowserGui);
end

%%
function [poleCropVideoCat poleCropVideoSub] = buildPoleCropVideos(video,barSelected, poleWindow)
poleCropVideo = zeros(length(poleWindow),length(poleWindow),length(barSelected));
poleCropVideoCat = [];
poleCropVideoSub = [];
if size(video.frames(1).cdata,2) <  max(barSelected(1,1)+poleWindow) || size(video.frames(1).cdata,1) < max(barSelected(1,2)+poleWindow);
    poleWindow = poleWindow - max([max(barSelected(1,1)+poleWindow)-size(video.frames(1).cdata,2)  max(barSelected(1,2)+poleWindow)-size(video.frames(1).cdata,1)]);
end
for i = 1:length(barSelected)
    vidINDS1 = barSelected(i,2)+poleWindow;
    vidINDS2 = barSelected(i,1)+poleWindow;
    badInds = find(((vidINDS1<=0) + (vidINDS2<=0)));
    vidINDS1(badInds) = 1;
    vidINDS2(badInds) = 1;
    poleCropVideo(:,:,i) = video.frames(i).cdata(vidINDS1, vidINDS2, 1);
end
for i = 1:length(barSelected)
    vidINDS1 = barSelected(i,2)+poleWindow;
    vidINDS2 = barSelected(i,1)+poleWindow;
    badInds = find(((vidINDS1<=0) + (vidINDS2<=0)));
    vidINDS1(badInds) = 1;
    vidINDS2(badInds) = 1;
    if video.isContact(i) == 0;
        poleCropVideoCat = cat(2,poleCropVideoCat,cat(1,video.frames(i).cdata(vidINDS1, vidINDS2, 1),repmat(255,10,length(poleWindow))));
    else
        poleCropVideoCat = cat(2,poleCropVideoCat,cat(1,video.frames(i).cdata(vidINDS1, vidINDS2, 1),repmat(0,10,length(poleWindow))));
    end
    poleCropVideoSub = cat(2,poleCropVideoSub, mean(poleCropVideo,3)-poleCropVideo(:,:,i));
end
end
%%
function reset_axes_for_curating_next_trial(array)
% set axis back to the pole trigger time (that way we can see just
% before the pole is in reach and we dont have to scroll

hParamBrowserGui = getappdata(0,'hParamBrowserGui');
params = getappdata(hParamBrowserGui,'params');
figure(hParamBrowserGui)
ca_tmp = gca;
cT=array.trials{params.sweepNum};
params.xlim = [ca_tmp.XLim+((.95*cT.pinDescentOnsetTime) - ca_tmp.XLim(1))];
params.ylim = ca_tmp.YLim;
xlim(params.xlim);
ylim(params.ylim);
end
%%
function params = reset_axes(params)

hParamBrowserGui = getappdata(0,'hParamBrowserGui');
params = getappdata(hParamBrowserGui,'params');
figure(hParamBrowserGui)
SPinds = 1:100*100;
SPinds = reshape(SPinds, 100, 100)';
tmpIND = SPinds(1:90, 1:99);
position = subplot_old_2013_position(100,100,tmpIND(:));
hs_1 = subplot('Position', position);

params.xlim =  get(hs_1,'xlim');
params.ylim =  get(hs_1,'ylim');
end

%%
function position = subplot_old_2013_position(nRows, nCols, plotId, varargin)
% cut directly from the 2013b matlab subplot function. 2013 subplot handles
% a certain input much faster (100 x 100 grid input for newer matlabs fails
% to load completly). this cuts down a lot of the stuff that isnt needed
% for this specific input type and just outputs the position coordinates.
% Vuala - Phillip Maire Aug 15 2020 -- 200815
narg = nargin;
killSiblings = 0;
createAxis = true;
moveAxis = false;
delayDestroy = false;
useAutoLayout = true;
tol = sqrt(eps);
parent = get(0, 'CurrentFigure');
ancestorFigure = parent;
if ~isempty(parent) && ~isempty(get(parent, 'CurrentAxes'))
    parent = get(get(parent, 'CurrentAxes'), 'Parent');
    ancestorFigure = parent;
    if ~strcmp(get(ancestorFigure, 'Type'), 'figure')
        ancestorFigure = ancestor(parent, 'figure');
    end
end
pvpairs = {};
preventMove = false;
% This is the percent offset from the subplot grid of the plotbox.
inset = [.2, .18, .04, .1]; % [left bottom right top]

%check for encoded format
h = [];
position = [];
explicitParent = false;
explicitPosition = false;

if narg == 0 % make compatible with 3.5, i.e. subplot == subplot(111)
    nRows = 111;
    narg = 1;
end

if narg == 1
    % The argument could be one of 3 things:
    % 1) a 3-digit number 100 < num < 1000, of the format mnp
    % 2) a 3-character string containing a number as above
    % 3) an axes handle
    arg = nRows;
    
    % turn string into a number:
    if(ischar(arg))
        arg = str2double(arg);
    end
    
    % Check for NaN and Inf.
    if (~isfinite(arg))
        error(message('MATLAB:subplot:SubplotIndexNonFinite'))
    end
    
    % number with a fractional part can only be an identifier:
    if(rem(arg, 1) > 0)
        h = arg;
        if ~ishghandle(h, 'axes')
            error(message('MATLAB:subplot:InvalidAxesHandle'))
        end
        createAxis = false;
        % all other numbers will be converted to mnp format:
    else
        % Check for input out of range
        if (arg <= 100 || arg >= 1000)
            error(message('MATLAB:subplot:SubplotIndexOutOfRange'))
        end
        
        plotId = rem(arg, 10);
        nCols = rem(fix(arg - plotId) / 10, 10);
        nRows = fix(arg / 100);
        if nRows * nCols < plotId
            error(message('MATLAB:subplot:SubplotIndexTooLarge'));
        end
        killSiblings = 1;
        if (arg == 111)
            createAxis = false;
            delayDestroy = true;
        else
            createAxis = true;
            delayDestroy = false;
        end
    end
    
elseif narg == 2
    % The arguments MUST be the string 'position' and a 4-element vector:
    if (strcmpi(nRows, 'position'))
        pos_size = size(nCols);
        if (pos_size(1) * pos_size(2) == 4)
            position = nCols;
            explicitPosition = true;
        else
            error(message('MATLAB:subplot:InvalidPositionParameter'))
        end
    else
        error(message('MATLAB:subplot:UnknownOption'))
    end
    killSiblings = 1; % Kill overlaps here also.
    useAutoLayout = false;
    
elseif narg == 3
    % passed in subplot(m,n,p) -- we should kill overlaps
    % here too:
    killSiblings = 1;
    
elseif narg >= 4
    if ~ischar(nRows)
        arg = varargin{1};
        if ~ischar(arg)
            % passed in subplot(m,n,p,H,...)
            h = arg;
            if ~ishghandle(h, 'axes') || ...
                    isa(handle(h), 'scribe.colorbar') || ...
                    isa(handle(h), 'scribe.legend')
                error(message('MATLAB:subplot:InvalidAxesHandle'))
            end
            parent = get(h, 'Parent');
            ancestorFigure = ancestor(h, 'figure');
            % If the parent is passed in explicitly, don't create a new figure
            % when the "NextPlot" property is set to "new" in the figure.
            explicitParent = true;
            set(ancestorFigure, 'CurrentAxes', h);
            moveAxis = true;
            createAxis = false;
            if narg >= 5 && strcmpi(varargin{2}, 'PreventMove')
                preventMove = true;
                pvpairs = varargin(3 : end);
            else
                pvpairs = varargin(2 : end);
            end
        elseif strncmpi(arg, 'replace', 1)
            % passed in subplot(m,n,p,'replace')
            killSiblings = 2; % kill nomatter what
        elseif strcmpi(arg, 'align')
            % passed in subplot(m,n,p,'align')
            % since obeying position will remove the axes from the grid just set
            % useAutoLayout to false to skip adding it to the grid to start with
            useAutoLayout = false;
            killSiblings = 1; % kill if it overlaps stuff
        elseif strcmpi(arg, 'v6')
            % passed in subplot(m,n,p,'v6')
            % since obeying position will remove the axes from the grid just set
            % useAutoLayout to false to skip adding it to the grid to start with
            warning(['MATLAB:', mfilename, ':DeprecatedV6Argument'],...
                getString(message('MATLAB:usev6plotapi:DeprecatedV6ArgumentForFilename', upper(mfilename))));
            useAutoLayout = false;
            killSiblings = 1; % kill if it overlaps stuff
        else
            % passed in prop-value pairs
            killSiblings = 1;
            pvpairs = varargin;
            par = find(strncmpi('Parent', pvpairs(1 : 2 : end), 6));
            if any(par)
                % If the parent is passed in explicitly, don't create a new figure
                % when the "NextPlot" property is set to "new" in the figure.
                explicitParent = true;
                parent = varargin{2 * par(1)};
                ancestorFigure = ancestor(parent, 'figure');
            end
        end
    else
        % Passed in "Position" syntax with P/V pairs
        % The arguments MUST be the string 'position' and a 4-element vector:
        if (strcmpi(nRows, 'position'))
            pos_size = size(nCols);
            if (pos_size(1) * pos_size(2) == 4)
                position = nCols;
                explicitPosition = true;
            else
                error(message('MATLAB:subplot:InvalidPositionParameter'))
            end
        else
            error(message('MATLAB:subplot:UnknownOption'))
        end
        killSiblings = 1; % Kill overlaps here also.
        useAutoLayout = false;
        pvpairs = [{plotId}, varargin];
        par = find(strncmpi('Parent', pvpairs(1 : 2 : end), 6));
        if any(par)
            % If the parent is passed in explicitly, don't create a new figure
            % when the "NextPlot" property is set to "new" in the figure.
            explicitParent = true;
            parent = pvpairs{2 * par(1)};
            ancestorFigure = ancestor(parent, 'figure');
        end
    end
end

% if we recovered an identifier earlier, use it:
if ~isempty(h) && ~moveAxis
    parent = get(h, 'Parent');
    ancestorFigure = ancestor(h, 'figure');
    set(ancestorFigure, 'CurrentAxes', h);
else  % if we haven't recovered position yet, generate it from mnp info:
    if isempty(parent)
        parent = gcf;
        ancestorFigure = parent;
    end
    if isempty(position)
        if min(plotId) < 1
            error(message('MATLAB:subplot:SubplotIndexTooSmall'))
        elseif max(plotId) > nCols * nRows
            error(message('MATLAB:subplot:SubplotIndexTooLarge'));
        else
            
            row = (nRows - 1) - fix((plotId - 1) / nCols);
            col = rem(plotId - 1, nCols);
            
            % get default axes position in normalized units
            % If we have checked this quanitity once, cache it.
            if ~isappdata(ancestorFigure, 'SubplotDefaultAxesLocation')
                if ~strcmp(get(ancestorFigure, 'DefaultAxesUnits'), 'normalized')
                    tmp = axes;
                    set(tmp, 'Units', 'normalized')
                    def_pos = get(tmp, 'Position');
                    delete(tmp)
                else
                    def_pos = get(ancestorFigure, 'DefaultAxesPosition');
                end
                setappdata(ancestorFigure, 'SubplotDefaultAxesLocation', def_pos);
            else
                def_pos = getappdata(ancestorFigure, 'SubplotDefaultAxesLocation');
            end
            
            % compute outerposition and insets relative to figure bounds
            rw = max(row) - min(row) + 1;
            cw = max(col) - min(col) + 1;
            width = def_pos(3) / (nCols - inset(1) - inset(3));
            height = def_pos(4) / (nRows - inset(2) - inset(4));
            inset = inset .* [width, height, width, height];
            outerpos = [def_pos(1) + min(col) * width - inset(1), ...
                def_pos(2) + min(row) * height - inset(2), ...
                width * cw, height * rw];
            
            % adjust outerpos and insets for axes around the outside edges
            if min(col) == 0
                inset(1) = def_pos(1);
                outerpos(3) = outerpos(1) + outerpos(3);
                outerpos(1) = 0;
            end
            if min(row) == 0
                inset(2) = def_pos(2);
                outerpos(4) = outerpos(2) + outerpos(4);
                outerpos(2) = 0;
            end
            if max(col) == nCols - 1
                inset(3) = max(0, 1 - def_pos(1) - def_pos(3));
                outerpos(3) = 1 - outerpos(1);
            end
            if max(row) == nRows - 1
                inset(4) = max(0, 1 - def_pos(2) - def_pos(4));
                outerpos(4) = 1 - outerpos(2);
            end
            
            % compute inner position
            position = [outerpos(1 : 2) + inset(1 : 2), ...
                outerpos(3 : 4) - inset(1 : 2) - inset(3 : 4)];
            
        end
    end
end
end

%%
function params = define_shortcut_keys(params)
if ~isfield(params, 'SC_keys')
    params.SC_keys = struct;
end
if ~isfield(params.SC_keys, 'custom')
    params.SC_keys.custom = struct;
end
if ~isfield(params.SC_keys, 'built_in')
    params.SC_keys.built_in = struct;
end
if ~isfield(params.SC_keys, 'disply_key_string')
    params.SC_keys.disply_key_string = 0;
end
if ~isfield(params.SC_keys, 'compound')
    params.SC_keys.compound = struct;
end


built_in          = {...
    'zoom_on'              , 'zoom(h,  ''''on'''')'    ,           'I___I';...
    'zoom_off'             , 'zoom(h,  ''''off'''')'   ,           'I___I';...
    'zoom_toggle'          , 'zoom(h)'             ,           'z';...
    'pan_on'               , 'pan(h,   ''''on'''')'    ,           'I___I';...
    'pan_off'              , 'pan(h,   ''''off'''')'   ,           'I___I';...
    'pan_toggle'           , 'pan(h)'              ,           'p';...
    'brush_on'             , 'brush(h,   ''''on'''')'  ,           'I___I';...
    'brush_off'            , 'brush(h,   ''''off'''')' ,           'I___I';...
    'brush_toggle'         , 'brush(h)'            ,           'b';...
    };
f = fieldnames(params.SC_keys.built_in);
for ksc = 1:length(built_in)
    b = ['params.SC_keys.built_in.', built_in{ksc, 1}];
    % set shorcut if user didnt already set it
    if ~contains(built_in{ksc, 1}, f)
        eval_str = [ b, '.cmd = ''',built_in{ksc, 2} , ''';'];
        eval(eval_str);
        eval_str = [ b, '.SC = ''',built_in{ksc, 3} , ''';'];
        eval(eval_str);
    end
end

%{
these are the mouse command keys, numer at the end is number of clicks
(single vs double) and nor is left alt is right and extend is the scroll
wheel press button and obviously scroll_up and scroll_down
mouse_normal_1
mouse_normal_2
mouse_alt_1
mouse_alt_2
mouse_extend_1
mouse_extend_2
scroll_up
scroll_down
%}

%structFieldName,   set command string,    shortcut key}
custom_cell         = {...
    'next_trial'        , 'next'              , 'set_double_key_below';...
    'last_trial'        , 'last'              , 'set_double_key_below';...
    'add_contact'       , 'add'               , 'scroll_up';...
    'del_contact'       , 'del'               , 'scroll_down';...
    'recalculate_shit'  , 'recalc'            , 'I___I';...
    'save'              , 'save'              , 'alt';...
    'quick_save'        , 'quick_save'         , 'set_double_key_below';...
    'all'               , 'all'               , 'I___I';...
    'contactsOnly'      , 'contactsOnly'      , 'I___I';...
    'excludeContacts'   , 'excludeContacts'   , 'I___I';...
    'poleToDecision'    , 'poleToDecision'    , 'I___I';...
    'contactToDecision' , 'contactToDecision' , 'I___I';...
    'postDecision'      , 'postDecision'      , 'I___I';...
    'postPole'          , 'postPole'          , 'I___I';...
    'arbitrary'         , 'arbitrary'         , 'I___I';...
    'adjPlots'          , 'adjPlots'          , 'I___I';...
    'adjSpikes'         , 'adjSpikes'         , 'I___I';...
    'adjContacts'       , 'adjContacts'       , 'I___I';...
    'adjTrials'         , 'adjTrials'         , 'I___I';...
    'jumpToSweep'       , 'jumpToSweep'       , 'I___I';...
    'videoOn'           , 'videoOn'           , 'mouse_alt_1';...
    'move_right'        , 'pass'        , 'set_double_key_below';...
    'move_left'         , 'pass'         , '1';...
    'toggle_axes'             , 'toggle_axes'             , 'mouse_normal_2';...
    'I___I'             , 'I___I'             , 'I___I';...
    'I___I'             , 'I___I'             , 'I___I';...
    'I___I'             , 'I___I'             , 'I___I'...
    };
% insert the command around the command string
custom_cell(:, 2) = cellfun(@(x) ['trialContactBrowser_V2(array,contacts, params,''''', ...
    x, ''''');'],custom_cell(:, 2), 'UniformOutput', false);% add callback to eval

f = fieldnames(params.SC_keys.custom);
for ksc = 1:length(custom_cell)
    b = ['params.SC_keys.custom.', custom_cell{ksc, 1}];
    % set shorcut if user didnt already set it
    if ~contains(custom_cell{ksc, 1}, f)
        eval_str = [ b, '.cmd = ''',custom_cell{ksc, 2} , ''';'];
        eval(eval_str);
        eval_str = [ b, '.SC = ''',custom_cell{ksc, 3} , ''';'];
        eval(eval_str);
    end
end
% add double keys
params.SC_keys.custom.next_trial.SC = {'d', 'rightarrow', '3'};
params.SC_keys.custom.last_trial.SC = {'a', 'leftarrow'};
params.SC_keys.custom.quick_save.SC = {'s', 'mouse_extend_1'};%click middle button
params.SC_keys.custom.move_right.SC = {'2', 'mouse_alt_2'};%click middle button

end

%%
function super_struct = auto_gen_eval_commands_buttons(varargin)
% THIS FUNCTION IS NOT USED
% this is a fun little program I wrote that I decided not to use but
% someone might find it useful. it goes through all of the figure and finds
% the function handles so you can evaluate it and attach a shortcut. In theory
% you can do this for inherent functions like zoom, without using the
% 'zoom.m' command, by accessing the inherant zoom handles commands but
% this was too complicated than it was worth for my purposes.
% Phillip Maire Aug 17th 2020
%{
thing that might help figure this out
import matlab.graphics.interaction.internal.*
used in the zoom function.
%}
if nargin ==1
    tmp1 = findall(varargin{1});
else
    tmp1 = findall(gcf);
end

hhhh = {};
for k = 1:length(tmp1)
    try
        hhhh{k, 1} = tmp1(k).Type;
    catch
        hhhh{k, 1} = '';
    end
end

hh = unique(hhhh);

super_struct = struct;
all_types = cell(length(hh), 1);
for k = 1:length(hh)
    all_types{k} = findall(gcf, 'Type', hh{k});
    C = class(all_types{k});
    tmp1 = find(C=='.', 1, 'last')+1;
    C = C(tmp1:end) ;
    disp(C)
    for kk = 1:length(all_types{k})
        E = all_types{k}(kk);
        f = fieldnames(E);
        switch C
            case 'AnnotationPane'
            case 'Axes'
            case 'axestoolbar'
            case 'Figure'
            case 'Line'
            case 'Text'
            case 'ToolbarPushButton'
            case 'ToolbarStateButton'
            case 'ContextMenu'
            case 'toolbarpushbutton'
            case 'toolbarstatebutton'
            case 'uicontextmenu'
            case 'uimenu'
            case 'uipushtool'
            case 'uitoggletool'
            case 'uitoolbar'
            case 'Menu'
            case 'PushTool'
                tmp1 = E.Tooltip;
                tmp1 = strrep(tmp1, ' ', '_');
                eval(['super_struct.', C, '.', tmp1, ' = eval(''E.ClickedCallback'');']);
            case 'ToggleTool'
                tmp1 = E.Tooltip;
                tmp1 = strrep(tmp1, ' ', '_');
                eval(['super_struct.', C, '.', tmp1, ' = eval(''E.ClickedCallback'');']);
            case 'Toolbar'
                for k3 = 1:length(E.Children)
                    EE = E.Children(k3);
                    tmp1 = EE.Tooltip;
                    tmp1 = strrep(tmp1, ' ', '_');
                    eval(['super_struct.', C, '.', tmp1, ' = eval(''EE.ClickedCallback'');']);
                end
        end
    end
end
end

