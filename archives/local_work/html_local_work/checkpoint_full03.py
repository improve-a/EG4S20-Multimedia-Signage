from pathlib import Path
import hashlib,json,datetime,subprocess,re
r=Path(r'D:\FPGA\EG4S20-Multimedia-Signage');o=r/'output/html_fidelity';a=o/'audit'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
run='html_full_20261015_03';b=o/'builds'/run;status=b/'runs'/run/'status.json'
j=json.loads(status.read_text());stdout=b/'runs'/run/'stdout.log'
area=b/'work/design/td_project/hx4s20_basic_Runs/syn_1/hx4s20_basic_gate.area'
if not area.exists():area=next(b.rglob('hx4s20_basic_gate.area'))
assert j['exit_code']==2 and '5494' in stdout.read_text(errors='replace')
report={'utc':now,'run_id':run,'source_commit':'5aa8501e721045787917d474800f33d7c9fc6d09','status':j,
 'SYN':'PASS','PNR':'FAIL_PACKING','STA':'NOT_COMPLETED','BITGEN':'NOT_RUN','BUILD':'FAIL','HARDWARE':'NOT_TESTED_THIS_RUN',
 'area':{'lut':19051,'registers':10866,'bram9k':64,'bram32k':16,'dsp':18,'packing_mslices':5494,'device_mslices':4900},
 'failure':'PHY-9009: required 5494 MSlices exceeds device limit 4900. No routed timing or fresh bitstream.',
 'reports':{str(p):sha(p) for p in [status,stdout,area]}}
(a/'full03_result.json').write_bytes(json.dumps(report,indent=2).encode())
ledger=json.loads((a/'build_budget.json').read_text());entries=[]
for item in ledger['attempts']:
    p=Path(item['status'])
    if p.exists():
        st=json.loads(p.read_text());entries.append({k:st.get(k) for k in ['run_id','state','exit_code','elapsed_seconds','snapshot_sha256','supervisor_pid','td_pid']})
summary={'utc':now,'attempts':len(entries),'full_flows':sum(x['run_id'].startswith('html_full_') for x in entries),'cumulative_completed_seconds':round(sum(x.get('elapsed_seconds') or 0 for x in entries),3),'runs':entries,'policy':'HX4S20C user overnight scope; serial TD only; no automatic full-build loop. Separate earlier PH1P35 task limit not treated as this target authorization.'}
(a/'build_budget_summary.json').write_bytes(json.dumps(summary,indent=2).encode())
p=r/'docs/harness/STATUS.md';s=p.read_text()
s=re.sub(r'更新 UTC .*?。主工作区',f'更新 UTC {now}。主工作区',s, count=1)
s=s.replace('已提交 HEAD a80b0facc90c4240d210f05613c04abd6da18045','已提交 HEAD 5aa8501e721045787917d474800f33d7c9fc6d09')
s=re.sub(r'累计29次TD尝试.*?继续处理。',f"累计{summary['attempts']}次TD尝试，含{summary['full_flows']}次完整流程，已完成工具耗时{summary['cumulative_completed_seconds']}秒；台账output/html_fidelity/audit/build_budget.json。没有并行重型TD。当前依据实际packing失败及吞吐失败进行等价结构优化。",s)
s=s.replace('准备对当前候选运行完整流程，依据实际packing和时序结果继续处理。','')
s+='''

## 20:05 UTC 实际失败与恢复进展

最终图层版本 full03 综合通过但布局打包失败：19051 LUT、10866寄存器、64×9K、16×32K、18DSP，5494 MSlices 超过4900，313.938秒、退出2。SYN=PASS，PNR=FAIL，STA未完成，BITGEN未运行；不能沿用first-phase位流宣称最终BUILD_PASS。源快照2f6d33865832799d25d892684db5dc582049c0cf570b5af62ab982033911871b，详见audit/full03_result.json。

真实frame_fifo_read/frame_fifo_write控制器联合测试：连续合法SPI字节速率下，256字读/256字写的猎鹰页在y120/x567欠流。相同条件下只把读突发改128，猎鹰页307200像素完全相符，25次写入共6400字地址顺序正确，读FIFO最低130字，写FIFO无溢出；首页同样通过。其余页面继续，尚未修改生产frame_read_write参数。此修复必须保留写突发256且验证源FIFO容量。

panel固定头字段改为到达时比较：实际四素材249856字、1956扇区和音频竞争通过，24固定字节独立破坏均拒绝；综合391→328LUT、309→118寄存器。locator与scene固定字段进一步流式验证通过六页8831字、170错误/传输/超时用例（含144固定字段逐位破坏）、普通BMP回退，源码和diff见verification/locator_scene_stream_v1。

OSD紧凑颜色、共享字体ROM、可达弹簧状态位宽和数据复位填充均有逐像素或穷举RTL等价证据。隔离综合4018→3729LUT、1017→898寄存器，BRAM不变，DSP11→12；尚未推广，继续评估十进制ROM优化。两bank调色板已完成无损候选（1843200背景像素和4729612字节RGBA完全相同），但正式SET_ID仍003adc1b，未因候选而替换正式媒体。

40项兼容快照完成：39PASS，control_storage旧替身缺ENABLE_HFXL参数编译FAIL。原失败保留，补齐替身接口后独立复测PASS；这不是删除测试或放宽断言。当前BMP同步扇区RAM专项13项已通过，其余正式HFXL接收/拒绝继续。
'''
p.write_bytes(s.encode())
p=r/'docs/harness/EVIDENCE.md';s=p.read_text();s+='''

### full03 packing failure and bounded recovery

`audit/full03_result.json` pins commit5aa8501, snapshot2f6d33865832799d25d892684db5dc582049c0cf570b5af62ab982033911871b, status/PIDs/TD identity/313.938s/exit2 and report hashes. SYN succeeded; PlacePacking required5494MSlices against4900. No final routedSTA or bitstream exists for this snapshot. The older full02 bit remains first-phase only.

`verification/20261015T194733755081Z/result.json`: streamed panel headers PASS all4panels249856words plus24 independent fixed-byte rejections and all prior transport/timeout checks. Isolated old/new SYN391LUT309REG vs328LUT118REG. `verification/locator_scene_stream_v1/verification.json`: current locator/scene fixed fields PASS6pages8831words and170 rejection cases including144singlebit faults; originals and exactdiffs retained.

Strict simultaneous reader/writer test found a real native eagle FIFO underrun with read256/write256. The identical legal continuous SPI input model passes eagle/home after read128 only; remaining page run is pending. Source rate comes from existing100MHz SPI/HIGH_SPEED_DIV=2, byteevery64systemclocks, 32bitwordevery102.4memoryclocks. Writer actualoccupied259memoryclocks. No hardwarebandwidthclaim.

OSD font and compact color candidate:3,687,348RGB/control comparisonsPASS. Spring width:1,221,490actualRTL transition checksPASS plus reachable-state closure. Data reset fill:200,004RGB/sync cycles over200resetsPASS. Isolated combinedSYN3729LUT898REG18×9K11×32K12DSP; production not replaced at this checkpoint. Formalmedia003adc1b unchanged. Optional palette candidate4c74bf6d is not a delivered asset set.
''';p.write_bytes(s.encode())
print(json.dumps({'full03_audit':str(a/'full03_result.json'),'budget':{k:v for k,v in summary.items() if k!='runs'},'status_sha256':sha(r/'docs/harness/STATUS.md')},indent=2))
