#!/usr/bin/env python3
"""Actual production top, accelerated read-only image and bounded external leaves."""
import sys,json,hashlib,time,datetime,subprocess,shutil,importlib.util,traceback,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TOOL=Path(r'C:\iverilog\bin')
FILES='rtl/top_tf_hdmi_audio.v rtl/reset_sync.v rtl/display_commit.v rtl/startup_pulse.v rtl/media_controls.v rtl/hdmi_audio_tone_pcm_scale.v rtl/audio_arc_calculate.v rtl/SD/color_bar.v rtl/SD/video_timing_data.v rtl/SD/video_delay.v rtl/SD/frame_read_write.v rtl/SD/frame_fifo_read.v rtl/SD/frame_fifo_write.v rtl/SD/seg_decoder.v rtl/SD/seg_scan.v rtl/IP/afifo_32_16_256.v rtl/IP/afifo_16_32_256.v rtl/ext/legacy_exhibit_media.v rtl/ext/legacy_exhibit_loader.v rtl/ext/bmp_scale.v rtl/ext/media_sector_arbiter.v rtl/ext/frame_config_bridge.v rtl/ext/video_transition.v rtl/ext/video_extensions.v rtl/ext/pixel_adjust.v rtl/ext/html_video_overlay.v rtl/ext/html_osd_overlay.v rtl/ext/html_osd_swap_rom.v rtl/ext/html_caption_column_rom.v rtl/ext/html_rom16.v rtl/ext/html_assets/html_caption_map.v rtl/ext/audio_async_fifo.v rtl/ext/audio_media.v rtl/ext/audio_pcm_player.v rtl/ext/audio_output_mux.v rtl/ext/audio_visualizer.v rtl/ext/wav_stream_parser.v rtl/video_rgb_to_axis_640x480.v tests/no_bot_actual_top_leaves.v tests/no_bot_actual_top_tb.v'.split()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def stamp():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def save(p,d):p.write_bytes((json.dumps(d,indent=2)+'\n').encode())
def main():
 out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True);status=out/'status.json';started=time.monotonic()
 d={'state':'PREPARING','runner_pid':os.getpid(),'started_utc':stamp(),'root':str(ROOT),'production_edited':False,'model_boundaries':['Actual top and all authored media/FIFO/video/audio/control RTL','Only PLL, SD card, SDRAM, HDMI encrypted core/PHY replaced by leaves','SD initialization64 sysclocks, readonly sector512 bytes one byte/sysclock; not SPI/card speed','SDRAM10-cycle read response,614400 words,601-cycle refresh requests with20-cycle legal drained stalls; not native encrypted PHY','HDMI stub monitors actual input only, no receiver locking/TMDS/physical claim','Actual clocks100/40/25MHz and full20ms reset,800x525; gold assertions only, never data injection']};save(status,d)
 try:
  hashes={}
  for name in FILES+['rtl/SD/video_define.v']+[str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'rtl/ext/html_assets').glob('*.hex')]:
   src=ROOT/name;dst=out/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);hashes[name]=sha(src)
  image=Path(r'D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\media\no_bot_fat32.img');shutil.copyfile(image,out/'card.img')
  media=out/'media';media.mkdir();b=image.read_bytes();ui=b[2081*512:2081*512+922112];(media/'UI01.BMP').write_bytes(ui)
  spec=importlib.util.spec_from_file_location('oracle',ROOT/'scripts/no_bot_legacy_oracle.py');oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle);rgb,meta=oracle.expected_rgb(0,False,1,0,media)
  (out/'gold_image.hex').write_bytes(b''.join(rgb[i:i+3].hex().encode()+b'\n' for i in range(0,len(rgb),3)))
  pcm=b[16491*512+44:16491*512+44+8192];(out/'real_pcm.hex').write_bytes(b''.join(pcm[i:i+2][::-1].hex().encode()+b'\n' for i in range(0,len(pcm),2)))
  d.update(input_hashes=hashes,card_source=str(image),card_sha256=sha(image),oracle=meta,real_pcm={'source_lba':16491,'byte_offset':44,'samples':4096,'sha256':hashlib.sha256(pcm).hexdigest(),'header_modified':False},state='COMPILING');save(status,d)
  cmd=[str(TOOL/'iverilog.exe'),'-g2012','-DHTML_SIM','-Irtl/SD','-s','no_bot_actual_top_tb','-o','actual_top.vvp']+FILES
  d['compile_command']=cmd;p=subprocess.run(cmd,cwd=out,capture_output=True);(out/'compile.stdout.log').write_bytes(p.stdout);(out/'compile.stderr.log').write_bytes(p.stderr);d['compile_exit']=p.returncode
  if p.returncode:raise RuntimeError('compile failed')
  if '--compile-only' in sys.argv:d['state']='COMPILE_PASS';save(status,d);return
  with (out/'runtime.log').open('wb') as log:
   p=subprocess.Popen([str(TOOL/'vvp.exe'),'actual_top.vvp'],cwd=out,stdout=log,stderr=subprocess.STDOUT);d.update(state='RUNNING',vvp_pid=p.pid,simulation_started_utc=stamp());save(status,d)
   try:code=p.wait(timeout=6000)
   except subprocess.TimeoutExpired:p.kill();code=p.wait();d['timeout']=True
  d.update(exit_code=code,state='PASS' if code==0 and 'TEST_PASS ACTUAL_TOP' in (out/'runtime.log').read_text(errors='replace') else 'FAIL')
  if (out/'actual_hdmi_input.ppm').exists():d['actual_hdmi_ppm_sha256']=sha(out/'actual_hdmi_input.ppm')
 except Exception as e:d.update(state='FAIL',error=str(e),traceback=traceback.format_exc())
 d.update(finished_utc=stamp(),wall_seconds=time.monotonic()-started);save(status,d)
if __name__=='__main__':main()
