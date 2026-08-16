function nref_run_reference_grid(repoRoot,agtfModelRoot,gridFile)
T=readtable(gridFile,'TextType','string');
tol=jsondecode(fileread(fullfile(repoRoot,'config','input_match_tolerances.json')));
rawRoot=fullfile(repoRoot,'evidence','raw'); parsedRoot=fullfile(repoRoot,'evidence','parsed');
if ~exist(rawRoot,'dir'), mkdir(rawRoot); end
if ~exist(parsedRoot,'dir'), mkdir(parsedRoot); end
fid=fopen(fullfile(parsedRoot,'SCHEMA_DISCOVERY_ONLY.txt'),'w'); fprintf(fid,'Parsed inventories are derivative schema-discovery evidence only. Raw MAT is authoritative.\n'); fclose(fid);

vars={'Point_ID','Execution_Action','Requested_Altitude_ft','Requested_Mach','Requested_dT_degF','Requested_PLA', ...
      'Actual_Altitude_ft','Actual_Mach','Actual_dT_degF','Actual_PLA','Run_Status','Native_Converged','Out_Variables','Notes'};
summaryRows=cell(height(T),numel(vars));
mandatoryFail=false;

for i=1:height(T)
    pid=char(T.Point_ID(i)); action=char(T.Execution_Action(i));
    reqAlt=T.Altitude_ft(i); reqMach=T.Mach(i); reqdT=T.dT_degF(i); reqPLA=T.PLA(i);
    summaryRows(i,1:6)={pid,action,reqAlt,reqMach,reqdT,reqPLA};
    summaryRows(i,7:10)={NaN,NaN,NaN,NaN}; summaryRows{i,12}=NaN; summaryRows{i,13}=''; summaryRows{i,14}='';
    if ~strcmp(action,'EXECUTE')
        summaryRows{i,11}='NOT_EXECUTED_BY_GRID_POLICY'; summaryRows{i,14}=char(T.Rationale(i));
        continue
    end

    pointDir=fullfile(rawRoot,pid); if ~exist(pointDir,'dir'), mkdir(pointDir); end
    pointParsed=fullfile(parsedRoot,pid); if ~exist(pointParsed,'dir'), mkdir(pointParsed); end
    Input=struct('UseExcel',0,'LoadBus',1,'Alt',reqAlt,'MN',reqMach,'dT',reqdT,'PLA',reqPLA,'ICPoint','auto');
    MWS=[]; names={};
    try
        evalin('base',"clear('out_*')");
        old=pwd; c=onCleanup(@() cd(old)); cd(agtfModelRoot);
        MWS=AGTF30.setup_simulation(Input);

        actAlt=MWS.In.AltIC; actMach=MWS.In.MNIC; actdT=MWS.In.dTambIC; actPLA=MWS.In.PLA(1,1);
        summaryRows(i,7:10)={actAlt,actMach,actdT,actPLA};
        chk=struct('requested',struct('Altitude_ft',reqAlt,'Mach',reqMach,'dT_degF',reqdT,'PLA',reqPLA), ...
            'source_actual',struct('Altitude_ft',actAlt,'Mach',actMach,'dT_degF',actdT,'PLA',actPLA), ...
            'tolerances',tol,'accepted',true);
        mismatch = abs(actAlt-reqAlt)>tol.altitude_ft_abs || abs(actMach-reqMach)>tol.mach_abs || ...
            abs(actdT-reqdT)>tol.dT_degF_abs || abs(actPLA-reqPLA)>tol.PLA_abs;
        if mismatch
            chk.accepted=false; chk.status='SOURCE_CLAMPED_INPUT_REJECTED';
            nref_write_json(fullfile(pointParsed,[pid '_requested_vs_source_actual.json']),chk);
            save(fullfile(pointDir,[pid '_source_setup_rejected.mat']),'MWS','Input','chk','-v7.3');
            summaryRows{i,11}='SOURCE_CLAMPED_INPUT_REJECTED'; summaryRows{i,14}='Source-native setup changed requested flight/control state beyond predeclared tolerance.';
            mandatoryFail=true; clear c; continue
        end
        chk.status='INPUT_MATCH_PASS'; nref_write_json(fullfile(pointParsed,[pid '_requested_vs_source_actual.json']),chk);

        assignin('base','MWS',MWS); assignin('base','NREF_Input_Request',Input); assignin('base','NREF_MWS_After_Setup',MWS);
        evalin('base',"sim('AGTF30SysSS.mdl');");
        names=evalin('base',"who('out_*')");
        authMat=fullfile(pointDir,[pid '_native_authoritative.mat']);
        authEsc=strrep(authMat,"'","''");
        evalin('base',sprintf("save('%s','out_*','MWS','NREF_Input_Request','NREF_MWS_After_Setup','-v7.3');",authEsc));

        raw=struct(); for k=1:numel(names), raw.(names{k})=evalin('base',names{k}); end
        if ~isfield(raw,'out_SS')
            summaryRows{i,11}='PARSER_FAIL'; summaryRows{i,14}='Required native out_SS variable not discovered after simulation.'; mandatoryFail=true; clear c; continue
        end
        converged=nref_extract_last_numeric(raw.out_SS,'converged'); summaryRows{i,12}=converged; summaryRows{i,13}=strjoin(names,';');
        try
            nref_export_numeric_inventory(raw.out_SS,fullfile(pointParsed,[pid '_out_SS_numeric_inventory.csv']));
            nref_export_out_variable_inventory(raw,fullfile(pointParsed,[pid '_out_variable_inventory.csv']));
        catch PME
            summaryRows{i,11}='PARSER_FAIL'; summaryRows{i,14}=getReport(PME,'extended','hyperlinks','off'); mandatoryFail=true; clear c; continue
        end
        if isequal(converged,1)
            summaryRows{i,11}='PASS_NATIVE_CONVERGED';
        else
            summaryRows{i,11}='SOURCE_NONCONVERGED'; summaryRows{i,14}=sprintf('Native out_SS.converged final value = %g',converged); mandatoryFail=true;
        end
        clear c
    catch ME
        mandatoryFail=true; summaryRows{i,11}='SOURCE_EXECUTION_ERROR'; summaryRows{i,14}=getReport(ME,'extended','hyperlinks','off');
        fid=fopen(fullfile(pointDir,[pid '_SOURCE_EXECUTION_ERROR.txt']),'w'); if fid>=0, fprintf(fid,'%s\n',summaryRows{i,14}); fclose(fid); end
        % Preserve any native out_* variables that exist at the failure point, plus requested/setup state.
        try
            errNames=evalin('base',"who('out_*')");
            assignin('base','NREF_Input_Request',Input); assignin('base','NREF_MWS_Partial',MWS);
            errMat=fullfile(pointDir,[pid '_native_error_authoritative_partial.mat']); errEsc=strrep(errMat,"'","''");
            evalin('base',sprintf("save('%s','out_*','NREF_Input_Request','NREF_MWS_Partial','-v7.3');",errEsc));
            summaryRows{i,13}=strjoin(errNames,';');
        catch
            try, save(fullfile(pointDir,[pid '_partial_error_state.mat']),'MWS','Input','-v7.3'); catch, end
        end
        % Continue to the next independent mandatory point. Do not tune source between points.
    end
    % Durable point-by-point checkpoint inside the runner workspace. The final summary is rewritten after every row.
    Scheckpoint=cell2table(summaryRows,'VariableNames',vars);
    writetable(Scheckpoint,fullfile(parsedRoot,'native_reference_execution_summary_checkpoint.csv'));
end

S=cell2table(summaryRows,'VariableNames',vars); writetable(S,fullfile(parsedRoot,'native_reference_execution_summary.csv'));
counts=groupsummary(S,'Run_Status'); writetable(counts,fullfile(parsedRoot,'native_reference_status_counts.csv'));
if mandatoryFail
    error('NREF:GridQualificationFail','One or more mandatory native reference points failed. Complete summary/evidence has been preserved.');
end
end
