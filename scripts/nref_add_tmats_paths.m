function nref_add_tmats_paths(tmatsTrunk)
% Controlled P1 uses the standard T-MATS execution path only.
% Cantera_Enabled is intentionally NOT added unless dependency assessment proves it is required
% and Oversight separately authorizes/provisions a controlled dependency.
paths = {
    fullfile(tmatsTrunk,'TMATS_Library'), ...
    fullfile(tmatsTrunk,'TMATS_Library','MEX'), ...
    fullfile(tmatsTrunk,'TMATS_Library','TMATS_Support'), ...
    fullfile(tmatsTrunk,'TMATS_Tools'), ...
    fullfile(tmatsTrunk,'TMATS_Library','MATLAB_Scripts')};
for k=1:numel(paths)
    if isfolder(paths{k}), addpath(paths{k}); end
end
fprintf('Controlled standard T-MATS paths added from %s\n',tmatsTrunk);
end
