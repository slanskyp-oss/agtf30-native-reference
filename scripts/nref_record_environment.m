function nref_record_environment(repoRoot,phase)
outDir = fullfile(repoRoot,'evidence','environment');
if ~exist(outDir,'dir'), mkdir(outDir); end
r = struct();
r.phase = phase;
r.utc = char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
r.matlab_version = version;
r.matlab_release = version('-release');
r.computer = computer;
try, r.os = system_dependent('getos'); catch, r.os = 'UNKNOWN'; end
v=ver; r.products=struct('Name',{v.Name},'Version',{v.Version},'Release',{v.Release},'Date',{v.Date});
try
    c=mex.getCompilerConfigurations('C','Selected');
    if isempty(c), r.selected_c_mex_compiler = []; else
        r.selected_c_mex_compiler = struct('Name',c(1).Name,'Manufacturer',c(1).Manufacturer,'Version',c(1).Version,'Location',c(1).Location,'ShortName',c(1).ShortName,'MexOpt',c(1).MexOpt);
    end
catch ME
    r.selected_c_mex_compiler_error = ME.message;
end
nref_write_json(fullfile(outDir,['matlab_environment_' lower(phase) '.json']),r);
end
