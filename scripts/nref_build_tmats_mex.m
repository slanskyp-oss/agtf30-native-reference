function nref_build_tmats_mex(repoRoot,tmatsTrunk)
outDir = fullfile(repoRoot,'evidence','environment');
if ~exist(outDir,'dir'), mkdir(outDir); end
fid = fopen(fullfile(outDir,'mex_build_record.txt'),'w');
if fid<0, error('NREF:EvidenceWrite','Cannot open MEX build record.'); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'MATLAB=%s\n',version);
fprintf(fid,'RELEASE=%s\n',version('-release'));
selected=nref_select_compiler(repoRoot);
fprintf(fid,'SELECTED_NAME=%s\n',selected.Name);
fprintf(fid,'SELECTED_MANUFACTURER=%s\n',selected.Manufacturer);
fprintf(fid,'SELECTED_VERSION=%s\n',selected.Version);
fprintf(fid,'SELECTED_LOCATION=%s\n',selected.Location);
fprintf(fid,'SELECTED_MEXOPT=%s\n',selected.MexOpt);

mexDir = fullfile(tmatsTrunk,'TMATS_Library','MEX');
assert(isfolder(mexDir),'T-MATS MEX directory missing');
old = pwd; cdCleanup = onCleanup(@() cd(old)); cd(mexDir);
fprintf('Building unmodified T-MATS v1.3.0 MEX sources using make_file_TMATS.m ...\n');
run('make_file_TMATS.m');
fprintf('T-MATS MEX build completed.\n');
end
