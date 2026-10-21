"""Actual diagnostic top -> unchanged AXIS -> HDMI input, with no available media."""
import datetime,hashlib,json,os,shutil,subprocess,time,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FILES=['rtl/top_tf_hdmi_audio.v', 'rtl/reset_sync.v', 'rtl/display_commit.v', 'rtl/startup_pulse.v', 'rtl/media_controls.v', 'rtl/hdmi_audio_tone_pcm_scale.v', 'rtl/audio_arc_calculate.v', 'rtl/SD/color_bar.v', 'rtl/SD/video_timing_data.v', 'rtl/SD/video_delay.v', 'rtl/SD/frame_read_write.v', 'rtl/SD/frame_fifo_read.v', 'rtl/SD/frame_fifo_write.v', 'rtl/SD/seg_decoder.v', 'rtl/SD/seg_scan.v', 'rtl/IP/afifo_32_16_256.v', 'rtl/IP/afifo_16_32_256.v', 'rtl/ext/legacy_exhibit_media.v', 'rtl/ext/legacy_exhibit_loader.v', 'rtl/ext/bmp_scale.v', 'rtl/ext/media_sector_arbiter.v', 'rtl/ext/frame_config_bridge.v', 'rtl/ext/video_transition.v', 'rtl/ext/video_extensions.v', 'rtl/ext/pixel_adjust.v', 'rtl/ext/html_video_overlay.v', 'rtl/ext/html_osd_overlay.v', 'rtl/ext/html_osd_swap_rom.v', 'rtl/ext/html_caption_column_rom.v', 'rtl/ext/html_rom16.v', 'rtl/ext/html_assets/html_caption_map.v', 'rtl/ext/audio_async_fifo.v', 'rtl/ext/audio_media.v', 'rtl/ext/audio_pcm_player.v', 'rtl/ext/audio_output_mux.v', 'rtl/ext/audio_visualizer.v', 'rtl/ext/wav_stream_parser.v', 'rtl/video_rgb_to_axis_640x480.v', 'rtl/ext/hdmi_colorbar_source.v', 'tests/hdmi_colorbar_top_leaves.v', 'tests/hdmi_colorbar_top_tb.v']
BASE=Path(r'D:\FPGA\EG4S20-NoBot')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 out=ROOT/'output/offline_debug'/('hdmi_colorbar_'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'));out.mkdir(parents=True)
 status=out/'verification.json';started=time.time()
 d={'state':'PREPARING','runner_pid':os.getpid(),'started':started,'root':str(ROOT),'base_commit':'17ac5f2','scope':'Actual diagnostic top and unchanged adapter -> actual HDMI input ports, native800x525, full2frames exact8x80px. Protected HDMI/PHY are external-leaf stubs, not TMDS/receiver simulation.','reset_model':'Actual top reset chain/PLL lock synchronization; test deposits rst_cnt=999995 only after synchronized locks. No force of clock/reset/video.','external_models':'Same nominal100/40/25/125MHz PLL leaves as existing actualtop harness. Card and SDRAM permanently notready; zero valid bytes/returns; no file/card access. HDMI wrapper and PHY stubs observe interfaces only.','production_origin':'Original canonical unchanged; only diagnostic worktree top/project hook/newcolorbarsource differs.'}
 def save():status.write_bytes(json.dumps(d,indent=2).encode())
 save()
 try:
  names=FILES+['rtl/SD/video_define.v','project/td_project/hx4s20_basic.al']+[str(q.relative_to(ROOT)).replace('\\','/') for q in (ROOT/'rtl/ext/html_assets').glob('*.hex')]
  d['input_hashes']={}
  for name in names:
   q=ROOT/name;dst=out/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(q,dst);d['input_hashes'][name]=sha(q)
  protected=['rtl/video_rgb_to_axis_640x480.v','rtl/reset_sync.v','rtl/system_clocks.v','rtl/video_clocks.v','rtl/hdmi_phy_warpper.v','rtl/lane_lvds_10_1.v','rtl/audio_arc_calculate.v','rtl/hdmi_audio_tone_pcm_scale.v','rtl/ext/audio_output_mux.v']
  d['preserved_inputs']={name:{'sha256':sha(ROOT/name),'original_sha256':sha(BASE/name),'equal':sha(ROOT/name)==sha(BASE/name)} for name in protected};assert all(v['equal'] for v in d['preserved_inputs'].values())
  d['script_sha256']=sha(Path(__file__));d['tools']={str(q):sha(q) for q in [Path(r'C:\iverilog\bin\iverilog.exe'),Path(r'C:\iverilog\bin\vvp.exe')]};d['state']='COMPILING';save()
  cmd=[r'C:\iverilog\bin\iverilog.exe','-g2012','-DHTML_SIM','-Irtl/SD','-s','hdmi_colorbar_top_tb','-o','diagnostic.vvp']+FILES
  c=subprocess.run(cmd,cwd=out,capture_output=True,timeout=60);(out/'compile.log').write_bytes(c.stdout+c.stderr);d.update(compile_command=cmd,compile_exit=c.returncode);save();assert c.returncode==0,'compile failed'
  with (out/'runtime.log').open('wb') as log:
   v=subprocess.Popen([r'C:\iverilog\bin\vvp.exe','diagnostic.vvp'],cwd=out,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,close_fds=True);d.update(state='RUNNING',vvp_pid=v.pid);save();code=v.wait(timeout=900)
  text=(out/'runtime.log').read_text(errors='replace');d.update(exit_code=code,output=text,state='UNIT_SIM_PASS' if code==0 and 'TEST_PASS HDMI_COLORBAR_ACTUAL_TOP' in text else 'FAIL')
 except Exception as e:d.update(state='FAIL',error=str(e),traceback=traceback.format_exc())
 d.update(finished=time.time(),wall_seconds=time.time()-started);save();print(d['state'],out,flush=True);return 0 if d['state']=='UNIT_SIM_PASS' else 1
if __name__=='__main__':raise SystemExit(main())
