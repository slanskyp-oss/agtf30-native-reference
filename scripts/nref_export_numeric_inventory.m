function nref_export_numeric_inventory(rootObj,fn)
% Conservative numeric-leaf inventory for native output discovery.
% Raw MAT remains authoritative; this CSV is a parsed aid, never a replacement.
rows = {};
rows = walk(rootObj,'out_SS',0,rows);
if isempty(rows)
    T=cell2table(cell(0,5),'VariableNames',{'Path','Class','Size','LastNumeric','Status'});
else
    T=cell2table(rows,'VariableNames',{'Path','Class','Size','LastNumeric','Status'});
end
writetable(T,fn);
end

function rows=walk(x,path,depth,rows)
if depth>5, rows(end+1,:)={path,class(x),mat2str(size(x)),NaN,'DEPTH_LIMIT'}; return; end
if isnumeric(x) || islogical(x)
    y=x(:); last=NaN; if ~isempty(y), last=double(y(end)); end
    rows(end+1,:)={path,class(x),mat2str(size(x)),last,'NUMERIC'}; return
end
if isa(x,'timeseries')
    rows=walk(x.Data,[path '.Data'],depth+1,rows); return
end
if isstruct(x)
    if numel(x)~=1, rows(end+1,:)={path,class(x),mat2str(size(x)),NaN,'STRUCT_ARRAY_RAW_ONLY'}; return; end
    f=fieldnames(x); for i=1:numel(f), rows=walk(x.(f{i}),[path '.' f{i}],depth+1,rows); end; return
end
if isa(x,'Simulink.SimulationData.Signal')
    rows=walk(x.Values,[path '.Values'],depth+1,rows); return
end
if isa(x,'Simulink.SimulationData.Dataset')
    for i=1:x.numElements
        e=x.getElement(i); nm=e.Name; if isempty(nm), nm=sprintf('Element%d',i); end
        rows=walk(e,[path '.' matlab.lang.makeValidName(nm)],depth+1,rows);
    end; return
end
if isobject(x) && isprop(x,'Data')
    try, rows=walk(x.Data,[path '.Data'],depth+1,rows); return; catch, end
end
rows(end+1,:)={path,class(x),mat2str(size(x)),NaN,'RAW_ONLY'};
end
