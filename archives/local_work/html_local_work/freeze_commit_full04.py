from pathlib import Path
import json,hashlib,subprocess,datetime,runpy,re,ast
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');o=r/'output/html_fidelity';audit=o/'audit'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def git(*args):return subprocess.check_output(['git',*args],cwd=r,text=True).strip()
assert git('rev-parse','HEAD')=='5aa8501e721045787917d474800f33d7c9fc6d09'
pre_staged=git('diff','--cached','--name-only').splitlines()
expected={
'rtl/ext/html_layer_pixel_engine.v':'813045190203c34d0204bf239a2d0ddb7fb00893eabcd34e3d27dcaad11b9bc2',
'rtl/ext/html_layer_cache.v':'ce8ea985b7c4d3df9fb1fe26e4475f175887e0e599bdc385ef387e9c054d77d2',
'rtl/ext/html_layer_memory_bridge.v':'cb4c0508417db2d4d9517f65bead8fbaa485118843c80339ceb45fd2ee1c1b93',
'rtl/ext/html_osd_overlay.v':'ee0176823765ad761d01e15351e58216c38dfe0546199aa5fc93a222cbe0d06f',
'rtl/ext/html_bot_overlay.v':'eaf861cec66491af985b4cb3e6d9b508c76b55c68b4ff17766a9dcaff034dd87',
'rtl/ext/html_osd_swap_rom.v':'a18f25119ac50532263818472afeead32dd90814f221774375c9260cbeaae4c2',
'rtl/ext/bmp_scale.v':'2f3080006bf3b05c4e560b8d2865a30332fb3393c73900e1294402e8c9ac9f6d',
'rtl/ext/html_resource_locator.v':'f9ca5199ca014c5de1717065e48fc5818cfefd5c0f99906e79d21119b410aa41',
'rtl/ext/html_scene_loader.v':'ecbf9b04b8854370b7322f2c1d2c0639a1a1052825c025f774d512e04859c813',
'rtl/SD/frame_read_write.v':'7c9eceabec73f990904ea3e08fa0eaf1caca394cc3ba269364597baafb8201da',
'rtl/top_tf_hdmi_audio.v':'b01132128041c7917946e854f1f3826358e79428769a9f2738de8ac88f07079f',
'rtl/ext/html_assets/html_osd_swap_font.hex':'5feb7b3dd891be5d1079b9beb06e2e412664a3d515274ffd531157ca7d58ae31',
'rtl/ext/html_assets/html_osd_swap_font.hex.bin':'3e3c4e37d1b625be61bd355d49d82e3dbc65ce5bfce17df49dab81d5b0418126'}
for name,value in expected.items():assert sha(r/name)==value,(name,sha(r/name),value)
assert 'BG_SLOT_BITS=4' in (r/'rtl/ext/html_layer_memory_bridge.v').read_text()
proofs={}
for run in ['layer_final_bg16_mixed_v1','layer_final_bg16_writer128_home_eagle_v1','layer_final_bg16_writer128_phoenix_v1','layer_final_bg16_writer128_remaining_v1']:
    p=o/'page_control'/run/'result.json';j=json.loads(p.read_text());assert j['UNIT_SIM']=='PASS',run
    proofs[str(p.relative_to(r))]={'sha256':sha(p),'state':j['UNIT_SIM'],'cases':[{'case':x['case'],'exit':x['exit'],'wall_seconds':x['wall_seconds']} for x in j['cases']]}
p=o/'regression/20261015T201246394876Z/results/regression_summary.json';j=json.loads(p.read_text());assert j['status']=='PASS' and j['source_unchanged_after'] and j['fresh_tests']==5
assert j['source_sha256']['rtl/ext/bmp_scale.v']==expected['rtl/ext/bmp_scale.v']
proofs[str(p.relative_to(r))]={'sha256':sha(p),'state':'PASS','tests':[x['id'] for x in j['tests']]}
for name in ['verification/locator_scene_stream_v1/verification.json','verification/20261015T194733755081Z/result.json','audit/rom_init_font8_v1.json','bot_osd/final_source_proofs_v5.json']:
    p=o/name;proofs[str(p.relative_to(r))]={'sha256':sha(p)}
replay={}
for name in ['apply_html_integration.py','apply_html_memory_controller.py','apply_html_sd_controller.py']:
    api=runpy.run_path(str(r/'scripts'/name))
    if 'FILES' in api:replay.update(api['FILES'])
    else:replay['rtl/SD/sd_card_bmp.v']={'result_text_sha256':api['RESULT_TEXT_SHA256']}
deps=json.loads((r/'docs/local_dependencies.json').read_text())['dependencies'];dep_records=[]
for d in deps:
    p=r/d['path'];digest=sha(p)
    if digest==d['sha256']:state='BASELINE_IDENTICAL'
    elif d['path'] in replay:
        normalized=p.read_bytes().decode('utf-8').replace('\r\n','\n')
        assert hashlib.sha256(normalized.encode()).hexdigest()==replay[d['path']]['result_text_sha256'],d['path']
        state='VERIFIED_AUTHORED_REPLAY'
    else:raise AssertionError('Unexpected protected dependency change: '+d['path'])
    dep_records.append({'path':d['path'],'sha256':digest,'state':state})
assert len(dep_records)==59 and sum(x['state']=='BASELINE_IDENTICAL' for x in dep_records)==53
(audit/'protected_dependencies_full04.json').write_bytes(json.dumps({'utc':now,'dependencies':dep_records},indent=2).encode())
ledger=json.loads((audit/'build_budget.json').read_text());statuses=[json.loads(Path(x['status']).read_text()) for x in ledger['attempts'] if Path(x['status']).exists()]
budget={'utc':now,'attempts':len(statuses),'full_flows':sum(x['run_id'].startswith('html_full_') for x in statuses),'completed_seconds':round(sum(x.get('elapsed_seconds',0) for x in statuses if x['state'] not in ['STARTING','RUNNING']),3),'active':[x['run_id'] for x in statuses if x['state'] in ['STARTING','RUNNING']]}
assert not budget['active'];(audit/'build_budget_summary.json').write_bytes(json.dumps(budget,indent=2).encode())
p=r/'docs/harness/STATUS.md';s=p.read_text()
if '## 恢复连接后的最终候选冻结' not in s:s+=f'''

## 恢复连接后的最终候选冻结

Windows主仓库源码与暂停前冻结SHA一致；未启动过full04或最终18帧。当前冻结保留16槽BG、8槽纹理缓存、8计算上下文，使用32项分布式任务队列、分开的单写RGB存储和16位结果RAM。8槽BG候选在凤凰/飞龙后台写入测试中发生写FIFO溢出，保留失败并撤销该候选；没有降低显示规格或更换素材。

当前16槽BG候选实际读128/写256的六页均PASS：每页307200精确像素，真实读/写控制器、连续合法SPI速率及512字初始写积压，无读欠流或写溢出。写FIFO占用在此压力台为行为模型；最终18帧使用真实未加密vendor FIFO/CDC RTL。它们都不是加密SDRAM/HDMI IP全系统仿真。

Bot/OSD采用font8共享ROM、等价颜色编码、可达弹簧位宽与数据流水复位填充。六帧与优化前逐字节相同，1221490真实RTL弹簧转移、720事件、alpha/缩放/字模和迟到ACK检查PASS。独立面积3729LUT898REG，不能当整机面积。十进制ROM和常量字形候选没有资源收益，均未推广。

读突发独立参数已实际接入：READ_BURST_SIZE默认等于原BURST_SIZE；展陈顶层明确128，写突发仍256，读排空13周期。两个公开replay脚本从核实原件重建、幂等、拒绝未知修改均通过。引脚、时钟/复位架构和vendor IP保持原件；53项依赖逐字节相同，另6项为可重放授权集成差异。

BMP21位文件位置/11位行位置的范围证明覆盖616320行计数转移；当前源码五项原生/缩放/真实HFXL接收拒绝回归全部PASS，1247.062秒。先前同步扇区RAM15项专项PASS；40项兼容快照39PASS，唯一旧替身接口编译失败已单独修复复测PASS，原失败保留。

TD台账当前{budget['attempts']}次尝试、{budget['full_flows']}次完整流程、{budget['completed_seconds']}秒。最后完整full03仍是packing FAIL；full02只证明第一阶段。下一步对本冻结提交运行full04，并同时完成匹配源码18帧实际显示链、视觉并排与动作预览。正式媒体仍SET_ID003adc1b，HARDWARE=NOT_TESTED_THIS_RUN。
''';p.write_bytes(s.encode())
p=r/'docs/harness/EVIDENCE.md';s=p.read_text()
if '### Final candidate freeze after resume' not in s:s+='''

### Final candidate freeze after resume

Current source binding and protected dependency evidence: `audit/full04_freeze.json` and `audit/protected_dependencies_full04.json`. The active BG16/task32/group-return candidate passes all6native writer128 tests in `page_control/layer_final_bg16_writer128_{home_eagle,phoenix,remaining}_v1`. Eachframe307200RGBexact; legalcontinuousSPIinput and actualread/writecontrollers. BG8phoenix/dragon writerFIFO failures remain separate and are not promoted.

`regression/20261015T201246394876Z/results/regression_summary.json`: current narrowed BMP source2f308000... passes5cases,1247.062s; previous15case syncRAM suite alsoPASS. `bot_osd/final_source_proofs_v5.json` binds approvedfont8/spring/reset3RTLfiles,6byteidenticalDUTframes,fulltargetchecks and1221490actualRTLspring transitions. `audit/rom_init_font8_v1.json` proves15active/source numeric HEX/BIN roundtrips including1024×8utilityROM. Decimal andconstantforeground variants are rejectedbymeasuredarea, notclaimedproduction.

Top usesREAD_BURST_SIZE128/READ_DRAIN_CYCLES13; writerBURST_SIZE256 and legacydefaults remain. `verification/read_burst128_v1/{audit,memory_replay_v2,integration_replay_v5}.json` records exactdiffs and reproducibility. The final18displaybench uses the actual vendorFIFO/GrayCDC RTL and PCM-derived peakROM; WAVparser/player/SDaudioRTL are covered separately, not instantiated by this displaychain suite.
''';p.write_bytes(s.encode())
paths=['docs/harness/EVIDENCE.md','docs/harness/STATUS.md','rtl/ext/bmp_scale.v','rtl/ext/html_bot_overlay.v','rtl/ext/html_layer_cache.v','rtl/ext/html_layer_pixel_engine.v','rtl/ext/html_osd_overlay.v','rtl/ext/html_osd_swap_rom.v','rtl/ext/html_panel_loader.v','rtl/ext/html_resource_locator.v','rtl/ext/html_scene_loader.v','scripts/apply_html_integration.py','scripts/apply_html_memory_controller.py','scripts/html_display_chain_verify.py','scripts/html_layer_render_verify.py','scripts/html_rom_init.py','tests/html_display_chain_tb.v','tests/html_layer_pixel_engine_tb.v','tests/html_panel_loader_tb.v','tests/html_scene_loader_tb.v','scripts/html_bot_spring_bounds.py','scripts/html_osd_utility_rom.py','tests/html_layer_bridge_write_tb.v','tests/html_layer_cache_boundary_tb.v']
extra=['rtl/ext/html_assets/html_osd_swap_font.hex','rtl/ext/html_assets/html_osd_swap_font.hex.bin']
assert set(pre_staged)<=set(paths+extra)
patterns=[rb'-----BEGIN [A-Z ]*PRIVATE KEY-----',rb'\bgh[pousr]_[A-Za-z0-9]{30,}',rb'\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}',rb'local-agent-mode-sessions/[0-9a-f]']
for name in paths+extra:
    p=r/name;raw=p.read_bytes();assert not any(re.search(x,raw) for x in patterns),'Sensitive pattern in '+name
    if p.suffix=='.py':ast.parse(raw.decode('utf8'),filename=name)
subprocess.run(['git','add','--',*paths],cwd=r,check=True)
subprocess.run(['git','add','-f','--',*extra],cwd=r,check=True)
subprocess.run(['git','-c','core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol','diff','--cached','--check'],cwd=r,check=True)
staged=git('diff','--cached','--name-only').splitlines();assert set(staged)<=set(paths+extra)
freeze={'utc':now,'prior_head':git('rev-parse','HEAD'),'source_sha256':expected,'proofs':proofs,'budget_before_full04':budget,'staged_paths':staged,'staged_source_sha256':{n:sha(r/n) for n in staged},'public_scan':'No selected secret/session-metadata patterns','FULL_SYSTEM_SIM':'NOT_VERIFIED','HARDWARE':'NOT_TESTED_THIS_RUN'}
(audit/'full04_freeze.json').write_bytes(json.dumps(freeze,indent=2).encode())
print(git('diff','--cached','--stat'))
subprocess.run(['git','commit','-m','Reduce renderer storage cost and preserve display reserve during loading'],cwd=r,check=True)
freeze['source_commit']=git('rev-parse','HEAD');(audit/'full04_freeze.json').write_bytes(json.dumps(freeze,indent=2).encode())
print(json.dumps({'source_commit':freeze['source_commit'],'staged_files':len(staged),'budget':budget,'freeze_sha256':sha(audit/'full04_freeze.json'),'protected_dependencies':len(dep_records)},indent=2))
