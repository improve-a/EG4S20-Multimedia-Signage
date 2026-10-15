#!/usr/bin/env python3
"""Windows-native reproduction of the final control and APUG011 memory suite.

Uses the existing explicit Icarus harness. Historical per-address physical-memory
models are deliberately excluded: only the aligned four-beat group tests assert
compatibility with the documented SDRAM IP transaction contract.
"""
import argparse,datetime,hashlib,json,os,pathlib,subprocess,sys,time

def case(top,sources,scope):
    return {"top":top,"sources":["tests/"+top+".v"]+sources,"scope":scope}
CONTROL=["rtl/media_controls.v"]
SD=CONTROL+["rtl/SD/sd_card_bmp.v","rtl/ext/media_sector_arbiter.v"]
VIEW=["rtl/ext/exhibit_viewport.v"]
GROUP=["rtl/ext/html_memory_bridge.v","rtl/ext/exhibit_viewport.v","rtl/SD/frame_fifo_read.v","rtl/display_commit.v"]
CASES=[
 case("control_modes_tb",CONTROL,"Legacy key/settings behavior"),
 case("content_modes_tb",SD,"Legacy daily/emergency grouping and eight-slot discovery"),
 case("exhibit_keys_tb",CONTROL,"Physical debounce, previous chord, six focus presets, zoom and pause/mute"),
 case("exhibit_control_tb",SD,"Six-page resident readiness, real ACK ownership, late resources, rapid previous/next and exact5400ms"),
 case("exhibit_panel_mux_tb",SD,"One existing physical SD arbiter, audio/panel routing and parser isolation; transport modeled"),
 case("exhibit_packed_tb",VIEW,"Logical address geometry only: six full640x480 packed/zoom/focus frames"),
 case("exhibit_aperture_tb",VIEW,"Logical aperture geometry only: explicit forward/reverse, all pixels and actual frame-time easing"),
 case("html_group_bridge_tb",GROUP,"APUG011 aligned four-beat physical model: four complete640x480 frames, source cache, packed/zoom/focus, refresh and write arbitration"),
 case("html_group_aperture_tb",GROUP,"APUG011 physical model: every cutoff modulo4, rapid frame commits, safe actualACK flush and negative response diagnostics"),
 case("audio_arbiter_tb",["rtl/ext/audio_media.v","rtl/ext/audio_pcm_player.v","rtl/ext/audio_async_fifo.v","rtl/ext/wav_stream_parser.v","rtl/ext/media_sector_arbiter.v"],"Unchanged audio preservation: exact2304PCM frames under continuous BMP traffic")
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root",type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1])
    ap.add_argument("--run-id",default=datetime.datetime.now(datetime.timezone.utc).strftime("final_suite_%Y%m%dT%H%M%S%fZ"))
    ap.add_argument("--only",action="append",choices=[c["top"] for c in CASES])
    ap.add_argument("--list",action="store_true",help="Print the final cases and scopes without running")
    ap.add_argument("--sim-timeout",type=int,default=600)
    args=ap.parse_args()
    selected=[c for c in CASES if not args.only or c["top"] in args.only]
    if args.list:
        print(json.dumps(selected,indent=2));return 0
    if not args.run_id or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in args.run_id):
        ap.error("run-id must contain only letters, digits, underscores or hyphens")
    root=args.root.resolve();out=root/"output/html_fidelity/page_control"/args.run_id
    out.mkdir(parents=True,exist_ok=False)
    now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
    report={"schema":1,"UNIT_SIM":"RUNNING","FULL_SYSTEM_SIM":"NOT_VERIFIED","HARDWARE":"NOT_VERIFIED","pid":os.getpid(),"started_utc":now(),"root":str(root),"python":sys.version,"cases":[],"tools":{}}
    for exe in [r"C:\iverilog\bin\iverilog.exe",r"C:\iverilog\bin\vvp.exe"]:
        p=subprocess.run([exe,"-V"],capture_output=True,timeout=30)
        report["tools"][exe]={"exit":p.returncode,"identity":(p.stdout+p.stderr).decode(errors="replace")}
    files=sorted({"harness/test_runner.py","scripts/html_control_verify.py"}|{s for c in selected for s in c["sources"]})
    report["source_sha256"]={name:sha(root/name) for name in files}
    (out/"inputs.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    started=time.monotonic()
    for spec in selected:
        top=spec["top"];target=out/top
        cmd=[sys.executable,str(root/"harness/test_runner.py"),"--top",top,"--output",str(target),"--cwd",str(root),"--sim-timeout",str(args.sim_timeout)]+[str(root/p) for p in spec["sources"]]
        item={"top":top,"scope":spec["scope"],"command":cmd,"started_utc":now()};tick=time.monotonic()
        with (out/(top+"_runner.log")).open("wb") as log:
            p=subprocess.Popen(cmd,cwd=root,stdout=log,stderr=subprocess.STDOUT)
            item["pid"]=p.pid;item["exit"]=p.wait()
        item["elapsed_seconds"]=time.monotonic()-tick
        result=target/"result.json"
        item["result"]=json.loads(result.read_text(encoding="utf-8")) if result.exists() else {"SIM":"MISSING_RESULT"}
        report["cases"].append(item)
        report["elapsed_seconds"]=time.monotonic()-started
        (out/"result.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
        print(json.dumps({"top":top,"SIM":item["result"].get("SIM"),"pid":item["pid"],"exit":item["exit"],"seconds":round(item["elapsed_seconds"],3)}),flush=True)
    report["UNIT_SIM"]="PASS" if all(c["exit"]==0 and c["result"].get("SIM")=="PASS" for c in report["cases"]) else "FAIL"
    report["finished_utc"]=now();report["elapsed_seconds"]=time.monotonic()-started
    (out/"result.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps({"UNIT_SIM":report["UNIT_SIM"],"cases":len(selected),"evidence":str(out),"seconds":round(report["elapsed_seconds"],3)}))
    return 0 if report["UNIT_SIM"]=="PASS" else 1

if __name__=="__main__":
    raise SystemExit(main())
