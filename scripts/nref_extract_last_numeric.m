function v=nref_extract_last_numeric(x,fieldName)
v=NaN;
try
    if isstruct(x) && isfield(x,fieldName), y=x.(fieldName);
    elseif isobject(x) && isprop(x,fieldName), y=x.(fieldName);
    else, return; end
    if isa(y,'timeseries'), y=y.Data;
    elseif isobject(y) && isprop(y,'Data'), y=y.Data;
    end
    if isnumeric(y) || islogical(y)
        y=y(:); if ~isempty(y), v=double(y(end)); end
    end
catch
end
end
