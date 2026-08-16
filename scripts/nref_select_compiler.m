function selected=nref_select_compiler(repoRoot)
outDir=fullfile(repoRoot,'evidence','environment');
if ~exist(outDir,'dir'), mkdir(outDir); end
assessmentFile=fullfile(outDir,'compiler_selection_assessment.json');
policy=jsondecode(fileread(fullfile(repoRoot,'config','toolchain_policy.json')));

installed=mex.getCompilerConfigurations('C','Installed');
rows=cell(numel(installed),8);
isC=false(1,numel(installed));
match=false(1,numel(installed));

for k=1:numel(installed)
    rows{k,1}=installed(k).Name;
    rows{k,2}=installed(k).Manufacturer;
    rows{k,3}=installed(k).Language;
    rows{k,4}=installed(k).Version;
    rows{k,5}=installed(k).Location;
    rows{k,6}=installed(k).ShortName;
    rows{k,7}=installed(k).MexOpt;
    rows{k,8}=installed(k).Priority;

    isC(k)=strcmpi(installed(k).Language,'C');

    match(k)=isC(k) && ...
        strcmpi(installed(k).Manufacturer,policy.expected_c_mex_compiler.manufacturer) && ...
        ~isempty(regexp(installed(k).Name, ...
            policy.expected_c_mex_compiler.name_regex,'once'));
end

T=cell2table(rows,'VariableNames', ...
    {'Name','Manufacturer','Language','Version','Location','ShortName','MexOpt','Priority'});
writetable(T,fullfile(outDir,'installed_c_mex_compilers.csv'));

idxC=find(isC);
idxMatch=find(match);

assessment=struct();
assessment.schema='NREF_C_MEX_COMPILER_SELECTION_ASSESSMENT_v1.0';
assessment.utc=char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
assessment.policy_schema=policy.schema;
assessment.expected_family=policy.expected_c_mex_compiler.family;
assessment.semantic_identity_fields= ...
    policy.expected_c_mex_compiler.semantic_identity_fields;
assessment.configuration_descriptor_fields= ...
    policy.expected_c_mex_compiler.configuration_descriptor_fields;
assessment.configuration_provenance_fields= ...
    policy.expected_c_mex_compiler.configuration_provenance_fields;
assessment.installed_c_configuration_count=numel(idxC);
assessment.installed_family_match_count=numel(idxMatch);
assessment.installed_c_configurations=nref_config_array_to_struct(installed(idxC));
assessment.candidate=[];
assessment.selected_before_count=0;
assessment.selected_before=[];
assessment.comparison_before=[];
assessment.selection_action='NOT_ATTEMPTED';
assessment.selected_after_count=0;
assessment.selected_after=[];
assessment.comparison_after=[];
assessment.semantic_identity_match=false;
assessment.result='PENDING';
assessment.failure_reason='';

if numel(idxC)~=1
    assessment.result='FAIL';
    assessment.failure_reason=sprintf( ...
        'Deterministic policy requires exactly one installed supported C configuration; found %d.', ...
        numel(idxC));
    nref_write_json(assessmentFile,assessment);
    error('NREF:CompilerSelection','%s',assessment.failure_reason);
end

candidate=installed(idxC);
assessment.candidate=nref_config_to_struct(candidate);

if numel(idxMatch)~=1 || idxMatch~=idxC
    assessment.result='FAIL';
    assessment.failure_reason= ...
        'The sole installed C configuration is not the required Microsoft Visual C++ 2022 family.';
    nref_write_json(assessmentFile,assessment);
    error('NREF:CompilerSelection','%s',assessment.failure_reason);
end

selectedBefore=mex.getCompilerConfigurations('C','Selected');
beforeMask=false(1,numel(selectedBefore));
for k=1:numel(selectedBefore)
    beforeMask(k)=strcmpi(selectedBefore(k).Language,'C');
end
selectedBeforeC=selectedBefore(beforeMask);

assessment.selected_before_count=numel(selectedBeforeC);
assessment.selected_before=nref_config_array_to_struct(selectedBeforeC);

if numel(selectedBeforeC)>1
    assessment.selection_action='AMBIGUOUS_SELECTED_STATE_FAIL';
    assessment.result='FAIL';
    assessment.failure_reason=sprintf( ...
        'Expected at most one selected C configuration; found %d.', ...
        numel(selectedBeforeC));
    nref_write_json(assessmentFile,assessment);
    error('NREF:CompilerSelection','%s',assessment.failure_reason);
end

if numel(selectedBeforeC)==1
    cmpBefore=nref_compare_compiler_identity(selectedBeforeC(1),candidate);
    assessment.comparison_before=cmpBefore;

    if cmpBefore.overall
        selected=selectedBeforeC(1);
        assessment.selection_action='PRESELECTED_ACCEPTED';
        assessment.selected_after_count=1;
        assessment.selected_after=nref_config_to_struct(selected);
        assessment.comparison_after=cmpBefore;
        assessment.semantic_identity_match=true;
        assessment.result='PASS';
        assessment.failure_reason='';
        nref_write_json(assessmentFile,assessment);
        nref_write_selected_record(outDir,selected,policy,assessment.selection_action);
        fprintf('Compiler semantic identity PASS; action=%s; compiler=%s\n', ...
            assessment.selection_action,selected.Name);
        return
    end
end

assessment.selection_action='MEX_SETUP_C_RECOVERY_ATTEMPTED';
nref_write_json(assessmentFile,assessment);

try
    mex -setup C
catch ME
    assessment.result='FAIL';
    assessment.failure_reason=sprintf( ...
        'mex -setup C recovery selection failed: %s',ME.message);
    nref_write_json(assessmentFile,assessment);
    error('NREF:CompilerSelection','%s',assessment.failure_reason);
end

selectedAfter=mex.getCompilerConfigurations('C','Selected');
afterMask=false(1,numel(selectedAfter));
for k=1:numel(selectedAfter)
    afterMask(k)=strcmpi(selectedAfter(k).Language,'C');
end
selectedAfterC=selectedAfter(afterMask);

assessment.selected_after_count=numel(selectedAfterC);
assessment.selected_after=nref_config_array_to_struct(selectedAfterC);

if numel(selectedAfterC)~=1
    assessment.result='FAIL';
    assessment.failure_reason=sprintf( ...
        'Expected exactly one selected C configuration after mex -setup C; found %d.', ...
        numel(selectedAfterC));
    nref_write_json(assessmentFile,assessment);
    error('NREF:CompilerSelection','%s',assessment.failure_reason);
end

cmpAfter=nref_compare_compiler_identity(selectedAfterC(1),candidate);
assessment.comparison_after=cmpAfter;

if ~cmpAfter.overall
    failed=nref_failed_identity_fields(cmpAfter);
    assessment.result='FAIL';
    assessment.failure_reason=sprintf( ...
        'Selected compiler semantic identity mismatch after mex -setup C in field(s): %s.', ...
        strjoin(failed,', '));
    nref_write_json(assessmentFile,assessment);
    error('NREF:CompilerSelection','%s',assessment.failure_reason);
end

selected=selectedAfterC(1);
assessment.selection_action='MEX_SETUP_C_SELECTED';
assessment.semantic_identity_match=true;
assessment.result='PASS';
assessment.failure_reason='';

nref_write_json(assessmentFile,assessment);
nref_write_selected_record(outDir,selected,policy,assessment.selection_action);

fprintf('Compiler semantic identity PASS; action=%s; compiler=%s\n', ...
    assessment.selection_action,selected.Name);
end

function cmp=nref_compare_compiler_identity(actual,candidate)
cmp=struct();

cmp.Name=strcmpi(nref_text(actual.Name),nref_text(candidate.Name));
cmp.Manufacturer=strcmpi( ...
    nref_text(actual.Manufacturer),nref_text(candidate.Manufacturer));
cmp.Language=strcmpi( ...
    nref_text(actual.Language),nref_text(candidate.Language));
cmp.Version=strcmp( ...
    nref_text(actual.Version),nref_text(candidate.Version));
cmp.ShortName_equal_descriptor=strcmpi( ...
    nref_text(actual.ShortName),nref_text(candidate.ShortName));

cmp.Location_actual_normalized= ...
    nref_normalize_windows_path(actual.Location);
cmp.Location_candidate_normalized= ...
    nref_normalize_windows_path(candidate.Location);
cmp.Location=strcmp( ...
    cmp.Location_actual_normalized,cmp.Location_candidate_normalized);

cmp.MexOpt_actual_normalized= ...
    nref_normalize_windows_path(actual.MexOpt);
cmp.MexOpt_candidate_normalized= ...
    nref_normalize_windows_path(candidate.MexOpt);
cmp.MexOpt_equal_provenance=strcmp( ...
    cmp.MexOpt_actual_normalized,cmp.MexOpt_candidate_normalized);

cmp.overall=cmp.Name && cmp.Manufacturer && cmp.Language && ...
    cmp.Version && cmp.Location;
end

function failed=nref_failed_identity_fields(cmp)
failed={};
if ~cmp.Name, failed{end+1}='Name'; end
if ~cmp.Manufacturer, failed{end+1}='Manufacturer'; end
if ~cmp.Language, failed{end+1}='Language'; end
if ~cmp.Version, failed{end+1}='Version'; end
if ~cmp.Location, failed{end+1}='Location'; end
if isempty(failed), failed={'UNKNOWN'}; end
end

function out=nref_config_array_to_struct(configs)
if isempty(configs)
    out=[];
    return
end

out=repmat(nref_config_to_struct(configs(1)),1,numel(configs));
for k=1:numel(configs)
    out(k)=nref_config_to_struct(configs(k));
end
end

function s=nref_config_to_struct(c)
s=struct();
s.Name=nref_text(c.Name);
s.Manufacturer=nref_text(c.Manufacturer);
s.Language=nref_text(c.Language);
s.Version=nref_text(c.Version);
s.Location=nref_text(c.Location);
s.Location_normalized=nref_normalize_windows_path(c.Location);
s.ShortName=nref_text(c.ShortName);
s.MexOpt=nref_text(c.MexOpt);
s.MexOpt_normalized=nref_normalize_windows_path(c.MexOpt);
s.MexOpt_exists=isfile(s.MexOpt);

if s.MexOpt_exists
    d=dir(s.MexOpt);
    if isempty(d)
        s.MexOpt_bytes=[];
    else
        s.MexOpt_bytes=d(1).bytes;
    end
else
    s.MexOpt_bytes=[];
end

s.Priority=nref_text(c.Priority);
s.LinkerName=nref_text(c.LinkerName);
s.LinkerVersion=nref_text(c.LinkerVersion);
end

function s=nref_normalize_windows_path(x)
s=nref_text(x);
s=strrep(s,'/','\');

while numel(s)>3 && endsWith(s,'\')
    s=s(1:end-1);
end

s=lower(s);
end

function s=nref_text(x)
if ischar(x)
    s=x;
elseif isstring(x)
    s=char(x);
else
    s=char(string(x));
end
end

function nref_write_selected_record(outDir,selected,policy,selectionAction)
r=struct();
r.schema='NREF_DETERMINISTIC_C_MEX_COMPILER_SELECTION_v1.2';
r.utc=char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
r.policy_schema=policy.schema;
r.expected_family=policy.expected_c_mex_compiler.family;
r.semantic_identity_fields= ...
    policy.expected_c_mex_compiler.semantic_identity_fields;
r.configuration_descriptor_fields= ...
    policy.expected_c_mex_compiler.configuration_descriptor_fields;
r.configuration_provenance_fields= ...
    policy.expected_c_mex_compiler.configuration_provenance_fields;
r.Name=nref_text(selected.Name);
r.Manufacturer=nref_text(selected.Manufacturer);
r.Language=nref_text(selected.Language);
r.Version=nref_text(selected.Version);
r.Location=nref_text(selected.Location);
r.Location_normalized=nref_normalize_windows_path(selected.Location);
r.ShortName=nref_text(selected.ShortName);
r.MexOpt=nref_text(selected.MexOpt);
r.MexOpt_normalized=nref_normalize_windows_path(selected.MexOpt);
r.MexOpt_exists=isfile(r.MexOpt);

if r.MexOpt_exists
    d=dir(r.MexOpt);
    if isempty(d)
        r.MexOpt_bytes=[];
    else
        r.MexOpt_bytes=d(1).bytes;
    end
else
    r.MexOpt_bytes=[];
end

r.selection_action=selectionAction;
r.semantic_identity_match=true;

nref_write_json( ...
    fullfile(outDir,'selected_c_mex_compiler.json'),r);
end
