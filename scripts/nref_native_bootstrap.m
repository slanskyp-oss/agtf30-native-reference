function nref_native_bootstrap
repoRoot = fileparts(fileparts(mfilename('fullpath')));
evidenceRoot = fullfile(repoRoot,'evidence');
if ~exist(fullfile(evidenceRoot,'logs'),'dir'), mkdir(fullfile(evidenceRoot,'logs')); end
logFile = fullfile(evidenceRoot,'logs','matlab_execution_diary.txt');
diary(logFile); diary on; cleanupDiary = onCleanup(@() diary('off'));
nref_write_native_stage_status(repoRoot,'RUNNING','MATLAB_BOOTSTRAP','Native compatibility acquisition started.');
fprintf('Native source acquisition start UTC: %s\n', char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX')));

agtfRepo = fullfile(repoRoot,'external','AGTF30');
tmatsRepo = fullfile(repoRoot,'external','T-MATS');
agtfModelRoot = fullfile(agtfRepo,'AGTF30');
tmatsTrunk = fullfile(tmatsRepo,'Trunk');
assert(isfolder(agtfModelRoot),'AGTF30 source folder missing');
assert(isfolder(tmatsTrunk),'T-MATS source folder missing');

try
    nref_record_environment(repoRoot,'PRE_BUILD');
    nref_add_tmats_paths(tmatsTrunk);
    nref_write_native_stage_status(repoRoot,'RUNNING','COMPILER_SELECTION_AND_BUILD','Selecting controlled compiler and building unmodified T-MATS MEX.');
    nref_build_tmats_mex(repoRoot,tmatsTrunk);
    nref_record_environment(repoRoot,'POST_BUILD');
catch ME
    if strcmp(ME.identifier,'NREF:CompilerSelection')
        nref_write_native_stage_status(repoRoot,'COMPILER_SELECTION_FAIL','COMPILER_SELECTION',getReport(ME,'extended','hyperlinks','off'));
    else
        nref_write_native_stage_status(repoRoot,'BUILD_FAIL','T_MATS_MEX_BUILD',getReport(ME,'extended','hyperlinks','off'));
    end
    rethrow(ME)
end

addpath(agtfModelRoot); addpath(fullfile(agtfModelRoot,'SimSetup'));
gridFile = fullfile(repoRoot,'config','reference_grid.csv');
try
    nref_write_native_stage_status(repoRoot,'RUNNING','NATIVE_REFERENCE_GRID','Executing all independent mandatory native points; no early abort.');
    nref_run_reference_grid(repoRoot,agtfModelRoot,gridFile);
catch ME
    nref_write_native_stage_status(repoRoot,'GRID_QUALIFICATION_FAIL','NATIVE_REFERENCE_GRID',getReport(ME,'extended','hyperlinks','off'));
    rethrow(ME)
end
nref_write_native_stage_status(repoRoot,'P1_NATIVE_GENERIC_SOURCE_REFERENCE_CANDIDATE_PASS_SEMANTIC_DECK','COMPLETE','All mandatory native points passed execution, convergence, input binding, schema inventory and reviewed semantic extraction. This is a semantic-deck candidate requiring Oversight artifact acceptance.');
fprintf('Native source acquisition completed UTC: %s\n', char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX')));
end
