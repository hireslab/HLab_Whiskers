function params = SC_combiner(params, cmb_cell, cmd_key)
%{
cmd_key = 'd'
cmb_cell = {'params.SC_keys.custom.add_contact', 'params.SC_keys.custom.next_trial'}
%}
for k = 1:length(cmb_cell)
    cmb_cell{k} = ['params.', cmb_cell{k}];
end
% setup 'compound' command struct for compount shortcuts
if ~isfield(params.SC_keys, 'compound')
    params.SC_keys.compound = struct;
end
% search for matching keyboard shortcuts to warn the user of duplicates.
F1 = fieldnames(params.SC_keys);
matchingCMDS = {};
for F1i = 1:length(F1)
    eval(['SC_tmp = params.SC_keys.', F1{F1i}, ';']);
    if isstruct(SC_tmp)
        F2 = fieldnames(SC_tmp);
        for F2i = 1:length(F2)
            eval(['tmp_cmd_key = SC_tmp.', F2{F2i}, '.SC;']);
            if tmp_cmd_key == cmd_key
                matchingCMDS{end+1} = ['params.SC_keys.',  F1{F1i}, '.',  F2{F2i}];
            end
        end
    end
end

cmbd_cmd = cell(length(cmb_cell), 1);
cmbd_name = cmbd_cmd;
for iii = 1:length(cmb_cell)
    cmbd_cmd{iii} = eval([cmb_cell{iii}, '.cmd']) ;% combine the function commands
    tmp1 = strfind(cmb_cell{iii}, '.');
    cmbd_name{iii} = cmb_cell{iii}(tmp1(end)+1:end);% combine the funciton names
end
cmbd_cmd = strjoin(cmbd_cmd, '     ');% join the cmd cell
cmbd_cmd = strrep(cmbd_cmd, '''', '''''');% set up the apostrophes for eval command
cmbd_name = strjoin(cmbd_name, '___');% join the names fo the combined function names
eval(['params.SC_keys.compound.', cmbd_name, '.cmd = ''', cmbd_cmd, ''';' ]);%set compound cmd
eval(['params.SC_keys.compound.', cmbd_name, '.SC = ''', cmd_key, ''';' ]);% set compount shortcut key

% remove the warning if the same shortcut key is already assigned to the compound shortcut that we selected
matchingCMDS = matchingCMDS(~strcmpi(['params.SC_keys.compound.', cmbd_name], matchingCMDS));
%  warning for if the shortcut key is the same as another shortcut key
if length(matchingCMDS) > 0
    warning('%s\n\n%s\n\n%s', ...
        'The following shortcuts have the same shortcut key as the one just specificed.', strjoin(matchingCMDS, '\n'),...
        'TO CLEAR ALL THE ABOVE SHORTCUTS set their ''.SD'' equal to an empty string OR leave and know that all the shortcuts will trigger including the one just created')
end
end