function selected=nref_select_compiler(repoRoot)
outDir=fullfile(repoRoot,'evidence','environment');
if ~exist(outDir,'dir'), mkdir(outDir); end
policy=jsondecode(fileread(fullfile(repoRoot,'config','toolchain_policy.json')));
installed=mex.getCompilerConfigurations('C','Installed');
rows=cell(numel(installed),8);
isC=false(1,numel(installed)); match=false(1,numel(installed));
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
    match(k)=isC(k) && contains(installed(k).Manufacturer,'Microsoft','IgnoreCase',true) && ...
        ~isempty(regexp(installed(k).Name,policy.expected_c_mex_compiler.name_regex,'once'));
end
T=cell2table(rows,'VariableNames',{'Name','Manufacturer','Language','Version','Location','ShortName','MexOpt','Priority'});
writetable(T,fullfile(outDir,'installed_c_mex_compilers.csv'));
idxC=find(isC); idxMatch=find(match);
if numel(idxC)~=1
    error('NREF:CompilerSelection','Deterministic policy requires exactly one installed supported C configuration; found %d.',numel(idxC));
end
if numel(idxMatch)~=1 || idxMatch~=idxC
    error('NREF:CompilerSelection','The sole installed C configuration is not the required Microsoft Visual C++ 2022 family.');
end
candidate=installed(idxC);
% Documented MATLAB selection path. Because exactly one supported C configuration exists,
% mex -setup C is non-ambiguous; any environment with multiple C configurations fails above.
mex -setup C
post=mex.getCompilerConfigurations('C','Selected');
if isempty(post)
    error('NREF:CompilerSelection','No selected C MEX compiler after mex -setup C.');
end
selected=post(1);
if ~strcmpi(selected.Language,'C') || ~strcmp(selected.Name,candidate.Name) || ...
        ~strcmp(selected.Manufacturer,candidate.Manufacturer) || ~strcmp(selected.Version,candidate.Version) || ...
        ~strcmp(selected.Location,candidate.Location) || ~strcmp(selected.MexOpt,candidate.MexOpt)
    error('NREF:CompilerSelection','Selected compiler identity differs from the sole intended C candidate.');
end
r=struct();
r.schema='NREF_DETERMINISTIC_C_MEX_COMPILER_SELECTION_v1.1';
r.utc=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
r.expected_family=policy.expected_c_mex_compiler.family;
r.Name=selected.Name; r.Manufacturer=selected.Manufacturer; r.Language=selected.Language; r.Version=selected.Version;
r.Location=selected.Location; r.ShortName=selected.ShortName; r.MexOpt=selected.MexOpt;
r.selection='SOLE_SUPPORTED_C_CONFIGURATION_PLUS_DOCUMENTED_MEX_SETUP_C';
nref_write_json(fullfile(outDir,'selected_c_mex_compiler.json'),r);
end
