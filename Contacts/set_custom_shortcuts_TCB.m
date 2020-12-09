%% set custom shortcuts for trial contact browser

%% first load an example trials array

load('C:\Users\maire\Dropbox\HIRES_LAB\PHIL\Data\Characterization\FINAL TRIAL ARRAYS\trial_array_1.mat')
clipboard('copy', 'D:\Data\Video\PHILLIP\AH0698\170601')
%%
clear all
trialContactBrowser_V2(T)
%%
h = gcf;
params2 = getappdata(h,'params')
%%
% eval('params = getappdata(gcf,''params''); setappdata(gcf, ''params'', params);')
%{
- get app data inside the function 
- set that data to the new command 
- set the clear button 
- set the eval statement
%}
%% look at all the shortcuts 
f2 = fieldnames(params2.SC_keys);
f2 = setdiff(f2, {'disply_key_string'});
for kk = 1:length(f2)
    xxxx = ['params2.SC_keys.',f2{kk}];
    f = eval(['fieldnames(',xxxx ,');']);
    for k = 1:length(f)
        evl_str = ['disp(', xxxx, '.',f{k}, '.SC)'];
        disp(['shortcut ''', f{k}, ''', is mapped to key(s) and/or mouse operations below...'])
        eval(evl_str)
    end
end

%% disply_key_string
% set to 1 or zeros, this just displays the string associated with each
% button when the user presses the button on the screen. useful for getting
% the key identifier if it is not known (i.e. hitting right arrow displays
% the following...
% "You just pressed a key identified as 'rightarrow', use this identifier
% to set a shortcut using this key!"
params2 = getappdata(gcf,'params')% get current params to add to 
params2.SC_keys.disply_key_string = true;
setappdata(gcf, 'params', params2)% saves your settings
% click on the figure, first hit a key that is already a shortcut to
% activate it.
% test it out ... hit some keys now you can use this figure out what the
% string names should be called for setting your own shortcut keys, change
% it back to false and run this section to stop displaying this 
%{
these are the mouse command keys, numer at the end is number of clicks
(single vs double) and normal is left alt is right and extend is the scroll
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
%% built_in
% built in buttons like zoom and pan -- these have 3 settings that the
% button can do -- on, off and toggle-- lets say you set the shortcut to
% the key 'd' for the zoom tool  -- the on version (no matter how many 
% times presses) will result in the zoom on. same with the off, it will
% always be off. toggle will witch it from on to off or off to on. 

f = fieldnames(params2.SC_keys.built_in)


%% custom 
params2 = getappdata(gcf,'params')% get current params to add to 
% these have only one mode and will react as if you just click on them.
% they toggle if they are toggilible. 
fieldnames(params2.SC_keys.custom)
% example on how to change it
params2.SC_keys.custom

params2.SC_keys.custom.next_trial.SC = 'rightarrow'
params2.SC_keys.custom.save.SC = 's'

setappdata(gcf, 'params', params2)% saves your settings

%% compound 
% allows the combination of mutliplte buttons into one shortcut. wow such
% efficient. like next trial and select brush tool in one button.  

cmd_key = 'i'; % key to set 
cmb_cell = {'SC_keys.custom.next_trial', 'SC_keys.built_in.brush_on'}; % actions to set 
params2 = SC_combiner(params2, cmb_cell, cmd_key);% use custom SC combiner to combine these actions into one key

% display the compound keys
params2.SC_keys.compound
setappdata(gcf, 'params', params2)% saves your settings

% % % % % % % % NOTE: you can use params2.SC_keys.clearDoubles 
%% map one command to multiple outputs in the same category
params2 = getappdata(gcf,'params')% get current params to add to 

fieldnames(params2.SC_keys.custom)
% example on how to change it

params2.SC_keys.custom.next_trial.SC = {'d', 'rightarrow'}
% now d and right arrow both go to the next trial

setappdata(gcf, 'params', params2)% saves your settings
%% clearDoubles
% only applies to the compound tool -- automatic command you can eval to
% clear duplicate shortcut keys IF they exist. this autogenerates when a
% user generates a COMPOUND button. 

