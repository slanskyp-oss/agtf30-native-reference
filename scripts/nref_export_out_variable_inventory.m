function nref_export_out_variable_inventory(raw,fn)
names=fieldnames(raw); rows=cell(numel(names),4);
for k=1:numel(names)
    x=raw.(names{k}); rows{k,1}=names{k}; rows{k,2}=class(x); rows{k,3}=mat2str(size(x)); rows{k,4}='RAW_MAT_PRESERVED';
end
T=cell2table(rows,'VariableNames',{'Variable','Class','Size','Preservation'}); writetable(T,fn);
end
