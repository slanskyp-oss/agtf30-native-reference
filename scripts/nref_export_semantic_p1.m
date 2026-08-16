function result=nref_export_semantic_p1(repoRoot,raw,pointId,outFile)
% Reviewed fail-closed semantic export for the generic AGTF30/T-MATS P1 source deck.
% Raw native MAT remains authoritative. This output is derivative candidate evidence.

mappingFile=fullfile(repoRoot,'config','p1_semantic_mapping.json');
expectedHash='2d81fe446a7e969ca4e21a18c79dfa9ad8ab71c73a0d4e7e23cd28bb7261102a';

if ~isfile(mappingFile)
    error('NREF:SemanticParser','Reviewed semantic mapping contract is missing: %s',mappingFile);
end
actualHash=nref_sha256_file(mappingFile);
if ~strcmp(actualHash,expectedHash)
    error('NREF:SemanticParser','Semantic mapping contract hash mismatch: %s != %s',actualHash,expectedHash);
end

contract=jsondecode(fileread(mappingFile));
if ~isfield(contract,'schema') || ~strcmp(char(contract.schema),'NREF_P1_SEMANTIC_MAPPING_CONTRACT_v1.0-R1')
    error('NREF:SemanticParser','Unexpected semantic mapping schema.');
end
if ~isfield(raw,'out_SS')
    error('NREF:SemanticParser','Required raw.out_SS is missing.');
end

maps=contract.out_SS_mapping;
nMaps=nref_item_count(maps);
if nMaps~=68
    error('NREF:SemanticParser','Expected exactly 68 out_SS mappings; found %d.',nMaps);
end

records=cell(nMaps,1);
seenPaths=cell(nMaps,1);
seenNames=cell(nMaps,1);

for i=1:nMaps
    m=nref_item_at(maps,i);
    path=char(m.native_path);
    semanticName=char(m.semantic_name);
    expectedShape=char(m.required_shape);

    if any(strcmp(seenPaths(1:max(i-1,0)),path))
        error('NREF:SemanticParser','Duplicate native path in mapping contract: %s',path);
    end
    if any(strcmp(seenNames(1:max(i-1,0)),semanticName))
        error('NREF:SemanticParser','Duplicate semantic name in mapping contract: %s',semanticName);
    end

    value=nref_resolve_native_path(raw,path);
    if ~(isnumeric(value) || islogical(value))
        error('NREF:SemanticParser','Mapped path is not numeric/logical: %s (%s)',path,class(value));
    end
    if ~strcmp(mat2str(size(value)),expectedShape)
        error('NREF:SemanticParser','Shape mismatch for %s: actual %s expected %s',path,mat2str(size(value)),expectedShape);
    end
    if any(~isfinite(double(value(:))))
        error('NREF:SemanticParser','Non-finite required semantic value at %s',path);
    end
    if ~strcmp(char(m.allowed_transformation),'NONE')
        error('NREF:SemanticParser','P1 semantic mapping transformation is not NONE at %s',path);
    end

    rec=struct();
    rec.native_path=path;
    rec.semantic_name=semanticName;
    rec.unit=char(m.unit);
    rec.quality_class=char(m.quality_class);
    rec.authority=char(m.authority);
    rec.native_class=class(value);
    rec.value_shape=mat2str(size(value));
    rec.value=value;
    records{i}=rec;

    seenPaths{i}=path;
    seenNames{i}=semanticName;
end

runtimePaths=nref_collect_numeric_paths(raw.out_SS,'out_SS',0,{});
if numel(runtimePaths)~=68 || numel(unique(runtimePaths))~=68 || ~isequal(sort(runtimePaths(:)),sort(seenPaths(:)))
    missing=setdiff(seenPaths,runtimePaths);
    extra=setdiff(runtimePaths,seenPaths);
    error('NREF:SemanticParser','Runtime out_SS numeric schema mismatch. expected=68 actual=%d missing=%s extra=%s', ...
        numel(runtimePaths),strjoin(missing,';'),strjoin(extra,';'));
end

componentEvidence=nref_component_evidence(raw,contract);
executionBinding=nref_execution_binding();
[reviewedSourceIdentity,actualSourceIdentity,sourceIdentityBinding]=nref_source_identity_binding(repoRoot,contract);

rawNativeFile=fullfile(repoRoot,'evidence','raw',char(pointId),[char(pointId) '_native_authoritative.mat']);
if ~isfile(rawNativeFile)
    error('NREF:SemanticParser','Authoritative raw MAT is missing for %s: %s',char(pointId),rawNativeFile);
end
rawNativeSha256=nref_sha256_file(rawNativeFile);

warningReference=struct();
warningReference.reviewed_assignment_applies=false;
warningReference.current_run_diary_observation='POST_RUN_DIARY_REVIEW_REQUIRED';
warningReference.disposition='NOT_APPLICABLE_TO_THIS_POINT';

if isfield(contract,'warning_policy') && isfield(contract.warning_policy,'assignment') && ...
        strcmp(char(contract.warning_policy.assignment),char(pointId))
    warningReference.reviewed_assignment_applies=true;
    warningReference.assignment_method=char(contract.warning_policy.assignment_method);
    warningReference.assignment_evidence_strength=char(contract.warning_policy.assignment_evidence_strength);
    warningReference.disposition=char(contract.warning_policy.disposition);
    warningReference.source_warning=char(contract.warning_policy.source_warning);

    s7pt=nref_resolve_native_path(raw,'out_SS.S7.Pt.Data');
    pa=nref_resolve_native_path(raw,'out_SS.Pa.Data');
    warningReference.final_state_S7_Pt_psia=s7pt;
    warningReference.final_state_Pa_psia=pa;
    warningReference.final_state_Pt_minus_Pa_psia=s7pt-pa;
    warningReference.final_state_condition='S7.Pt > Pa';
    warningReference.final_state_condition_pass=logical(s7pt>pa);
    if ~(isscalar(s7pt) && isscalar(pa) && isfinite(double(s7pt)) && isfinite(double(pa)) && s7pt>pa)
        error('NREF:SemanticParser','Reviewed warning disposition final-state cross-check failed for %s.',char(pointId));
    end
end

result=struct();
result.schema='NREF_P1_SEMANTIC_POINT_EVIDENCE_v1.0';
result.status='SEMANTIC_EXTRACTION_PASS_CANDIDATE';
result.point_id=char(pointId);
result.mapping_contract_schema=char(contract.schema);
result.mapping_contract_sha256=actualHash;
result.raw_native_authority='AUTHORITATIVE_NATIVE_MAT';
result.raw_native_relative_path=['raw/' char(pointId) '/' char(pointId) '_native_authoritative.mat'];
result.raw_native_sha256=rawNativeSha256;
result.reviewed_source_identity=reviewedSourceIdentity;
result.actual_source_identity=actualSourceIdentity;
result.source_identity_binding=sourceIdentityBinding;
result.execution_binding=executionBinding;
result.semantic_authority='DERIVATIVE_SEMANTIC_DECK_CANDIDATE_REQUIRES_OVERSIGHT_ACCEPTANCE';
result.native_unit_policy='PRESERVE_SOURCE_NATIVE_UNITS_NO_CONVERSION';
result.out_SS_mapping_count=nMaps;
result.runtime_out_SS_numeric_path_count=numel(runtimePaths);
result.runtime_out_SS_numeric_schema='EXACT_MATCH_TO_REVIEWED_68_PATH_CONTRACT';
result.out_SS_records=records;
result.record_order_authority='MAPPING_CONTRACT_ORDER';
result.json_array_shape_authority='USE_EACH_RECORD_VALUE_SHAPE; DO_NOT INFER MATLAB ROW/COLUMN ORIENTATION FROM DECODED JSON ARRAY SHAPE';
result.component_diagnostics=componentEvidence;
result.warning_policy_reference=warningReference;
result.utc=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));

nref_write_json(outFile,result);
end


function b=nref_execution_binding()
actualSha=strtrim(getenv('GITHUB_SHA'));
expectedSha=strtrim(getenv('EXPECTED_HARNESS_SHA'));
repo=strtrim(getenv('GITHUB_REPOSITORY'));
ref=strtrim(getenv('GITHUB_REF'));
workflow=strtrim(getenv('GITHUB_WORKFLOW'));
runId=strtrim(getenv('GITHUB_RUN_ID'));
runAttempt=strtrim(getenv('GITHUB_RUN_ATTEMPT'));

if isempty(regexp(actualSha,'^[0-9a-fA-F]{40}$','once'))
    error('NREF:SemanticParser','GITHUB_SHA is missing or malformed for semantic evidence binding.');
end
if isempty(regexp(expectedSha,'^[0-9a-fA-F]{40}$','once'))
    error('NREF:SemanticParser','EXPECTED_HARNESS_SHA is missing or malformed for semantic evidence binding.');
end
if ~strcmpi(actualSha,expectedSha)
    error('NREF:SemanticParser','Semantic evidence harness binding mismatch: actual %s expected %s.',actualSha,expectedSha);
end
if isempty(repo) || isempty(ref) || isempty(workflow) || isempty(runId) || isempty(runAttempt)
    error('NREF:SemanticParser','Required GitHub run-binding environment metadata is incomplete.');
end

b=struct();
b.GITHUB_REPOSITORY=repo;
b.GITHUB_REF=ref;
b.GITHUB_WORKFLOW=workflow;
b.GITHUB_SHA=lower(actualSha);
b.EXPECTED_HARNESS_SHA=lower(expectedSha);
b.GITHUB_RUN_ID=runId;
b.GITHUB_RUN_ATTEMPT=runAttempt;
end

function [reviewed,actual,binding]=nref_source_identity_binding(repoRoot,contract)
if ~isfield(contract,'source_identity') || ~isstruct(contract.source_identity)
    error('NREF:SemanticParser','Reviewed source_identity is missing from mapping contract.');
end
reviewed=contract.source_identity;
sourceFile=fullfile(repoRoot,'evidence','source','source_identity_actual.json');
if ~isfile(sourceFile)
    error('NREF:SemanticParser','Current-run source identity evidence is missing: %s',sourceFile);
end
actual=jsondecode(fileread(sourceFile));

hardFields={'AGTF30_repository','AGTF30_commit','TMATS_repository','TMATS_commit','TMATS_declared_tag'};
for i=1:numel(hardFields)
    f=hardFields{i};
    if ~isfield(reviewed,f) || ~isfield(actual,f)
        error('NREF:SemanticParser','Source identity field missing: %s',f);
    end
    if endsWith(f,'_commit')
        match=strcmpi(char(reviewed.(f)),char(actual.(f)));
    else
        match=strcmp(char(reviewed.(f)),char(actual.(f)));
    end
    if ~match
        error('NREF:SemanticParser','Current-run source identity mismatch at %s: reviewed=%s actual=%s', ...
            f,char(reviewed.(f)),char(actual.(f)));
    end
end
if ~isfield(actual,'source_modifications') || ~strcmp(char(actual.source_modifications),'NONE')
    error('NREF:SemanticParser','Current-run source identity does not establish source_modifications=NONE.');
end

binding=struct();
binding.hard_identity_fields=hardFields;
binding.hard_identity_match=true;
binding.source_modifications=char(actual.source_modifications);
binding.archive_hashes_are_provenance_not_hard_identity=true;
binding.AGTF30_archive_sha256_match_to_reviewed=nref_optional_hash_match(reviewed,actual,'AGTF30_source_archive_sha256');
binding.TMATS_archive_sha256_match_to_reviewed=nref_optional_hash_match(reviewed,actual,'TMATS_source_archive_sha256');
end

function tf=nref_optional_hash_match(reviewed,actual,fieldName)
tf=false;
if isfield(reviewed,fieldName) && isfield(actual,fieldName)
    tf=strcmpi(char(reviewed.(fieldName)),char(actual.(fieldName)));
end
end

function paths=nref_collect_numeric_paths(x,path,depth,paths)
if depth>5
    error('NREF:SemanticParser','Runtime out_SS schema traversal exceeded reviewed depth at %s.',path);
end
if isnumeric(x) || islogical(x)
    paths{end+1,1}=path;
    return
end
if isa(x,'timeseries')
    paths=nref_collect_numeric_paths(x.Data,[path '.Data'],depth+1,paths);
    return
end
if isstruct(x)
    if numel(x)~=1
        error('NREF:SemanticParser','Runtime out_SS contains unexpected struct array at %s.',path);
    end
    f=fieldnames(x);
    for i=1:numel(f)
        paths=nref_collect_numeric_paths(x.(f{i}),[path '.' f{i}],depth+1,paths);
    end
    return
end
if isa(x,'Simulink.SimulationData.Signal')
    paths=nref_collect_numeric_paths(x.Values,[path '.Values'],depth+1,paths);
    return
end
if isa(x,'Simulink.SimulationData.Dataset')
    for i=1:x.numElements
        e=x.getElement(i);
        nm=e.Name;
        if isempty(nm), nm=sprintf('Element%d',i); end
        paths=nref_collect_numeric_paths(e,[path '.' matlab.lang.makeValidName(nm)],depth+1,paths);
    end
    return
end
if isobject(x) && isprop(x,'Data')
    paths=nref_collect_numeric_paths(x.Data,[path '.Data'],depth+1,paths);
    return
end
% Non-numeric metadata is not part of the reviewed numeric-path schema.
end

function evidence=nref_component_evidence(raw,contract)
families={'compressors','turbines'};
evidence=struct();

for fi=1:numel(families)
    family=families{fi};
    spec=contract.component_diagnostics.(family);
    variables=nref_text_list(spec.variables);
    fieldContract=spec.field_contract;
    expectedFields=sort(fieldnames(fieldContract));

    familyRecords={};
    quarantined={};
    rix=0;
    qix=0;

    for vi=1:numel(variables)
        variableName=variables{vi};
        if ~isfield(raw,variableName)
            error('NREF:SemanticParser','Required component diagnostic variable missing: %s',variableName);
        end
        component=raw.(variableName);
        if ~isstruct(component) || numel(component)~=1
            error('NREF:SemanticParser','Component diagnostic %s is not a scalar struct.',variableName);
        end

        actualFields=sort(fieldnames(component));
        if ~isequal(actualFields,expectedFields)
            error('NREF:SemanticParser','Component field schema mismatch for %s.',variableName);
        end

        for fj=1:numel(expectedFields)
            fieldName=expectedFields{fj};
            fspec=fieldContract.(fieldName);
            qclass=char(fspec.class);

            if startsWith(qclass,'NOT_PROMOTED_')
                qix=qix+1;
                q=struct();
                q.variable=variableName;
                q.field=fieldName;
                q.disposition=qclass;
                q.unit=char(fspec.unit);
                quarantined{qix,1}=q;
                continue
            end

            value=nref_terminal_numeric(component.(fieldName),[variableName '.' fieldName]);
            if isempty(value) || ~(isnumeric(value) || islogical(value))
                error('NREF:SemanticParser','Promoted component field is not numeric/logical: %s.%s',variableName,fieldName);
            end
            if any(~isfinite(double(value(:))))
                error('NREF:SemanticParser','Non-finite promoted component diagnostic: %s.%s',variableName,fieldName);
            end

            rix=rix+1;
            rec=struct();
            rec.variable=variableName;
            rec.field=fieldName;
            rec.unit=char(fspec.unit);
            rec.quality_class=qclass;
            rec.native_class=class(value);
            rec.value_shape=mat2str(size(value));
            rec.value=value;
            familyRecords{rix,1}=rec;
        end
    end

    f=struct();
    f.promoted_records=familyRecords;
    f.quarantined_fields=quarantined;
    f.variable_count=numel(variables);
    f.promoted_record_count=numel(familyRecords);
    f.quarantined_record_count=numel(quarantined);
    evidence.(family)=f;
end
end

function value=nref_resolve_native_path(raw,path)
tokens=strsplit(path,'.');
value=raw;
for i=1:numel(tokens)
    token=tokens{i};
    if isstruct(value)
        if numel(value)~=1 || ~isfield(value,token)
            error('NREF:SemanticParser','Native path resolution failed at %s in %s',token,path);
        end
        value=value.(token);
    elseif isa(value,'timeseries')
        if ~strcmp(token,'Data')
            error('NREF:SemanticParser','Expected timeseries.Data while resolving %s',path);
        end
        value=value.Data;
    elseif isobject(value) && isprop(value,token)
        value=value.(token);
    else
        error('NREF:SemanticParser','Native path resolution failed at %s in %s (%s)',token,path,class(value));
    end
end
end

function value=nref_terminal_numeric(x,label)
if isnumeric(x) || islogical(x)
    value=x;
    return
end
if isa(x,'timeseries')
    value=x.Data;
    return
end
if isobject(x) && isprop(x,'Data')
    value=x.Data;
    return
end
error('NREF:SemanticParser','Unsupported component terminal type at %s: %s',label,class(x));
end

function n=nref_item_count(x)
if iscell(x)
    n=numel(x);
elseif isstruct(x)
    n=numel(x);
else
    error('NREF:SemanticParser','Expected JSON object array/cell for mapping entries.');
end
end

function item=nref_item_at(x,i)
if iscell(x)
    item=x{i};
else
    item=x(i);
end
if ~isstruct(item) || numel(item)~=1
    error('NREF:SemanticParser','Mapping entry %d is not a scalar object.',i);
end
end

function out=nref_text_list(x)
if iscell(x)
    out=cellfun(@char,x,'UniformOutput',false);
elseif isstring(x)
    out=cellstr(x(:));
elseif ischar(x)
    out={x};
else
    error('NREF:SemanticParser','Expected text list in mapping contract.');
end
out=out(:).';
end

function hex=nref_sha256_file(fn)
fid=fopen(fn,'rb');
if fid<0
    error('NREF:SemanticParser','Cannot open mapping contract for hashing: %s',fn);
end
c=onCleanup(@() fclose(fid));
bytes=fread(fid,Inf,'*uint8');
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest=typecast(md.digest(),'uint8');
hex=lower(reshape(dec2hex(digest,2).',1,[]));
end
