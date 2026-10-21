import pathlib,json,re,hashlib,datetime,subprocess,ast
r=pathlib.Path(r'D:\FPGA\EG4S20-Multimedia-Signage');a=r/'output/html_fidelity/audit';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
ledger=json.loads((a/'build_budget.json').read_text());statuses=[json.loads(pathlib.Path(x['status']).read_text()) for x in ledger['attempts'] if pathlib.Path(x['status']).exists()]
summary={'utc':now,'attempts':len(statuses),'full_flows':len([x for x in statuses if x['run_id'].startswith('html_full_')]),'completed_seconds':round(sum(x.get('elapsed_seconds',0) for x in statuses if x['state'] not in ['STARTING','RUNNING']),3),'active':[x['run_id'] for x in statuses if x['state'] in ['STARTING','RUNNING']]}
(a/'build_budget_summary.json').write_text(json.dumps(summary,indent=2))
b=r/'output/html_fidelity/builds/html_top_area_probe_20261015_03';log=(b/'runs/html_top_area_probe_20261015_03/stdout.log').read_text(errors='replace');area=(b/'runs/html_top_area_probe_20261015_03/probe_gate.area').read_bytes();init=re.findall(r'Reading BRAM .*?init file "([^"]+)"',log)
proof={'run_id':b.name,'status':statuses[-1],'utilization':{'LUT':18779,'REG':10866,'BRAM9K':64,'BRAM32K':16,'DSP':18},'area_sha256':hashlib.sha256(area).hexdigest(),'init_files_read':init,'critical_messages':[l for l in log.splitlines() if 'CRITICAL' in l or 'implicitly declared' in l],'scope':'Synthesis area only; probe clock is not timing sign-off; final packing/routing pending'}
(a/'top_area_probe03.json').write_text(json.dumps(proof,indent=2))
p=r/'docs/harness/STATUS.md';s=p.read_text();s=s.replace('2026-10-15T19:07:15.232560+00:00',now);start=s.index('最终整机首次面积诊断');end=s.index('## 当前验证',start)
s=s[:start]+'''最新整机面积诊断 html_top_area_probe_20261015_03 综合通过：18779/19600 LUT（95.81%）、10866寄存器、64/64 BRAM9K、16/16 BRAM32K、18/29 DSP，187.812秒。源快照86649724cebc3ec1f379905438fec48d950819efddb331bb6f83a0330c05ff7a。此结果包含8槽缓存、4-span几何、返回标签FF队列、眼睛半径ROM和BMP同步扇区RAM；尚未证明器件packing和布线可行。原21399、19303 LUT诊断及无效385 LUT前向声明候选均保留；不混作最终结果。

本次优化未改变六页资源或色深。眼睛与alpha端点等价优化六帧逐字节一致；完整页面分为两个1024色bank的只读穷举无解（最佳1060/1059色），未修改素材。BG共享候选连续显示欠流，已停止此路线，失败记录保留。

累计29次TD尝试，含2次完整流程，已完成工具耗时2323.909秒；台账output/html_fidelity/audit/build_budget.json。没有并行重型TD。准备对当前候选运行完整流程，依据实际packing和时序结果继续处理。

'''+s[end:]
s=s.replace('当前候选资源优化尚未冻结，最终18帧套件等待匹配源码。','当前资源候选已完成面积综合，最终18帧套件等待布局资源和长写占用验证。')
s+='''
补充验证：eyeROM生产版本六帧307200像素全部与优化前逐字节相同（bot_osd/verify_20261016_032406）；overlay_target/run_20261016_032406的720事件、alpha、48缩放配置及1113600字模像素通过。BMP同步扇区RAM的scan/reject、两次614400像素加载和原生307200像素case3通过，其余缩放/正式HFXL兼容测试继续。旧40项快照control_storage因替身缺ENABLE_HFXL参数编译失败；仅补齐测试接口后20261015T193237292810Z单独复测PASS，所有原断言保留，原FAIL未覆盖。
''';p.write_bytes(s.encode())
p=r/'docs/harness/EVIDENCE.md';s=p.read_text();s+='''
## 资源候选冻结前检查（19:34 UTC）

- 整机SYN03：18779 LUT/10866 REG/64×9K/16×32K/18DSP；187.812秒，exit0，supervisor4348/TD17040；快照86649724cebc3ec1f379905438fec48d950819efddb331bb6f83a0330c05ff7a，源包a4e1d8175d0d106063d3cec90e777b0101cbd265a1913fdbe85d7f2ed9d3a87c。独立probe时钟不用于时序结论。完整报告、初始化输入和警告见audit/top_area_probe03.json及builds/html_top_area_probe_20261015_03。
- 眼睛ROM独立SYN为4018 LUT，较原4364节省346 LUT和2 DSP，使用新增1×9K。生产六帧与原实现逐字节相同；verification.json SHA77209fee3c44855fa5d046a215657c387953f07d47a055193b0795bc884ed459。数值ROM14份均完成HEX/BIN roundtrip（audit/rom_init_eye_v1.json）。
- returnFF版本cache SHA8aa97cab14d8cd958d3d5d4b26988428cb6cbc8a873d765869006b6e458385c5；8192单元事务、home/eagle连续25/40MHz全帧通过；其他页和266周期后台写占用继续。
- BMP sector同步RAM候选独立SYN1737 LUT、3×9K/1×32K/1DSP；原生case3及scan/load/reject已过，其余兼容回归继续。最小diff/before/provenance在verification/bmp_sector_sync_v1。
- control_storage旧替身参数遗漏导致原快照编译FAIL，补齐ENABLE_HFXL声明后regression/20261015T193237292810Z PASS，未改DUT或放宽断言。
- 受保护依赖审计audit/protected_dependencies_20261015T1914.json：59项中53项与基线相同，6项为授权的最小可重放补丁。引脚、时钟/复位架构和vendor IP未更改。
- 两bank调色板只读穷举31种分组，最优UI01/04/05=1060色、UI02/03/06=1059色，各超1024；因此不采用，SET_ID仍003adc1b。总色并集1994，不以总数误判分组可行。
''';p.write_bytes(s.encode())
# Explicit previously audited candidate allowlist; pending write-stress bench excluded.
paths=json.loads((a/'precommit_integration_candidates.json').read_text())['files'];paths=[x for x in paths if x!='tests/html_layer_bridge_write_tb.v']
for name in paths:
 p=r/name
 assert p.is_file(),name
 if p.suffix=='.py':ast.parse(p.read_text(encoding='utf8'),filename=name)
res=subprocess.run(['git','add','--',*paths],cwd=r,capture_output=True,text=True);assert res.returncode==0,res.stderr
res=subprocess.run(['git','-c','core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol','diff','--cached','--check'],cwd=r,capture_output=True,text=True);print('DIFFCHECK',res.returncode,res.stdout,res.stderr)
print('STAGED',subprocess.run(['git','diff','--cached','--stat'],cwd=r,capture_output=True,text=True).stdout)
print('BUDGET',summary);print('INIT_READ_COUNT',len(init));print('CRITICAL',proof['critical_messages'])
