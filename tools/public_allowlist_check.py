from pathlib import Path
import csv, hashlib, json, re, sys
root=Path(__file__).resolve().parents[1]
allow_obj=json.loads((root/'PUBLIC_CONTENT_ALLOWLIST.json').read_text(encoding='utf-8'))
allow=allow_obj['allowed_paths']
actual=[]
for p in root.rglob('*'):
    if p.is_file() and '.git' not in p.parts and not any(x in p.parts for x in ('evidence','external','transport','smoke','__pycache__')):
        actual.append(p.relative_to(root).as_posix())
unknown=sorted(set(actual)-set(allow)); missing=sorted(set(allow)-set(actual))
if unknown or missing:
    print('ALLOWLIST FAIL', {'unknown':unknown,'missing':missing}); sys.exit(2)

register=json.loads((root/'action_dependency_register.json').read_text(encoding='utf-8'))
registered={(x['repository'],x['commit_sha']):x for x in register['dependencies']}
for dep in register['dependencies']:
    if not re.fullmatch(r'[0-9a-f]{40}', dep['commit_sha']): print('ACTION REGISTER FAIL invalid SHA',dep['repository']); sys.exit(3)
    if dep.get('runtime') != 'node24': print('ACTION RUNTIME FAIL expected node24',dep['repository'],dep.get('runtime')); sys.exit(3)
invoked=[]
for wf in (root/'.github/workflows').glob('*'):
    text=wf.read_text(encoding='utf-8')
    for ref in re.findall(r'uses:\s*([^\s#]+)',text):
        m=re.fullmatch(r'([^@]+)@([0-9a-f]{40})',ref)
        if not m: print('ACTION PIN FAIL', wf.name, ref); sys.exit(3)
        repo,sha=m.groups(); invoked.append((repo,sha))
        if (repo,sha) not in registered: print('ACTION REGISTER FAIL', wf.name, repo, sha); sys.exit(3)

rows=list(csv.DictReader((root/'config/reference_grid.csv').open(encoding='utf-8')))
if len(rows)!=18: print('GRID FAIL row_count',len(rows)); sys.exit(4)
if {r['Group'] for r in rows}!={'TAKEOFF','CLIMB','CRUISE','PART_POWER'}: print('GRID FAIL groups',sorted({r['Group'] for r in rows})); sys.exit(4)
for r in rows:
    if r['Execution_Action']!='EXECUTE': print('GRID FAIL non-execute',r['Point_ID']); sys.exit(4)
    alt=float(r['Altitude_ft']); mn=float(r['Mach']); dt=float(r['dT_degF']); pla=float(r['PLA'])
    if not (0<=mn<=0.8 and -30<=dt<=30 and 40<=pla<=80.5): print('GRID FAIL scalar envelope',r['Point_ID']); sys.exit(4)
    hi_m=[0,0.2,0.5,0.6,0.7,0.8]; hi_a=[10000,10000,25000,35000,40000,40000]
    lo_m=[0,0.5,0.6,0.7,0.8]; lo_a=[0,0,10000,20000,25000]
    def interp(x,xs,ys):
        if x<=xs[0]: return ys[0]
        if x>=xs[-1]: return ys[-1]
        for i in range(len(xs)-1):
            if xs[i]<=x<=xs[i+1]:
                f=(x-xs[i])/(xs[i+1]-xs[i]); return ys[i]+f*(ys[i+1]-ys[i])
        raise RuntimeError('interpolation domain error')
    if not (interp(mn,lo_m,lo_a)-1e-9 <= alt <= interp(mn,hi_m,hi_a)+1e-9): print('GRID FAIL altitude/Mach envelope',r['Point_ID'],alt,mn); sys.exit(4)

timeout=json.loads((root/'config/timeout_policy.json').read_text(encoding='utf-8'))
whole=timeout['whole_controlled_job_timeout_minutes']; native=timeout['native_matlab_action_step_timeout_minutes']; margin=timeout['reserved_post_native_margin_minutes']
if not (native < whole and margin == whole-native and margin>0): print('TIMEOUT POLICY FAIL',timeout); sys.exit(5)
controlled=(root/'.github/workflows/native-agtf30-v130-controlled.yml').read_text(encoding='utf-8')
if 'expected_harness_sha:' not in controlled or 'EXPECTED_HARNESS_SHA: ${{ inputs.expected_harness_sha }}' not in controlled: print('HARNESS SHA GATE FAIL missing dispatch binding'); sys.exit(6)
if 'workflow_dispatch:' not in controlled or re.search(r'\n\s+push:', controlled) or re.search(r'\n\s+pull_request:', controlled): print('CONTROLLED TRIGGER FAIL'); sys.exit(6)
if f'timeout-minutes: {whole}' not in controlled: print('WHOLE JOB TIMEOUT BINDING FAIL'); sys.exit(6)
native_block=controlled[controlled.index('id: native_run'):controlled.index('Verify tracked NASA source cleanliness after run')]
run_sha='75644028e1e2aa374bbfdc968a65718a178cc264'
if f'uses: matlab-actions/run-command@{run_sha}' not in native_block or f'timeout-minutes: {native}' not in native_block: print('AUTHORITATIVE MATLAB ACTION/TIMEOUT FAIL'); sys.exit(6)
if "command: addpath('scripts'); nref_native_bootstrap" not in native_block or 'generate-summary: false' not in native_block: print('AUTHORITATIVE MATLAB COMMAND INPUT FAIL'); sys.exit(6)
all_public_text='\n'.join(p.read_text(encoding='utf-8',errors='ignore') for p in root.rglob('*') if p.is_file())
if re.search(r'Start-Process\s+.*matlab|Start-Process\s+-FilePath\s+\$matlab',all_public_text,re.I): print('DIRECT MATLAB LAUNCH FAIL'); sys.exit(6)
if (root/'scripts/run_native_with_timeout.ps1').exists(): print('DIRECT MATLAB WATCHDOG RETIREMENT FAIL'); sys.exit(6)
if 'MATLAB_ACTION_EXECUTION_FAIL' not in (root/'scripts/finalize_controlled_status.ps1').read_text(encoding='utf-8'): print('MATLAB ACTION FAILURE CLASSIFICATION FAIL'); sys.exit(6)
gate=(root/'scripts/capture_harness_identity.ps1').read_text(encoding='utf-8')
if '^[0-9a-fA-F]{40}$' not in gate or 'UNREVIEWED_HARNESS_SHA_FAIL' not in gate: print('HARNESS SHA IMPLEMENTATION FAIL'); sys.exit(6)

manifest_path=root/'TEMPLATE_SHA256SUMS.txt'; manifest={}
for line in manifest_path.read_text(encoding='ascii').splitlines():
    if not line.strip(): continue
    m=re.fullmatch(r'([0-9a-f]{64})  (.+)',line)
    if not m: print('MANIFEST FORMAT FAIL',line); sys.exit(7)
    manifest[m.group(2)]=m.group(1)
expected_manifest=set(allow)-{'TEMPLATE_SHA256SUMS.txt'}
if set(manifest)!=expected_manifest: print('MANIFEST COVERAGE FAIL', {'missing':sorted(expected_manifest-set(manifest)),'extra':sorted(set(manifest)-expected_manifest)}); sys.exit(7)
for rel,expected in manifest.items():
    actual_hash=hashlib.sha256((root/rel).read_bytes()).hexdigest()
    if actual_hash != expected: print('MANIFEST HASH FAIL',rel); sys.exit(7)
print(f'PUBLIC ALLOWLIST PASS paths={len(allow)} grid_rows={len(rows)} action_invocations={len(invoked)} manifest_entries={len(manifest)} licensing_path=PINNED_RUN_COMMAND')
