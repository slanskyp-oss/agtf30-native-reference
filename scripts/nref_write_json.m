function nref_write_json(fn,s)
fid=fopen(fn,'w');
if fid<0, error('NREF:EvidenceWrite','Cannot open %s for writing.',fn); end
c=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(s,'PrettyPrint',true));
end
