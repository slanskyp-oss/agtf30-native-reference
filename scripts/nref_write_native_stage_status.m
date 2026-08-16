function nref_write_native_stage_status(repoRoot,status,stage,message)
out=fullfile(repoRoot,'evidence','status'); if ~exist(out,'dir'), mkdir(out); end
r=struct('schema','NREF_NATIVE_STAGE_STATUS_v1.2.1','status',status,'stage',stage,'message',message, ...
    'utc',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX')));
nref_write_json(fullfile(out,'native_stage_status.json'),r);
end
