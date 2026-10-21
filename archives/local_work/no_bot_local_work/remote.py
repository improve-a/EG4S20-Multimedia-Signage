import subprocess,sys
p=subprocess.run(["ssh","-o","BatchMode=yes","-o","ConnectTimeout=15","thinkpad",r"D:\python3.12.3\python.exe -X utf8 -"],input=sys.stdin.buffer.read(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=int(sys.argv[1]) if len(sys.argv)>1 else 90)
sys.stdout.buffer.write(p.stdout);sys.stderr.buffer.write(p.stderr);raise SystemExit(p.returncode)
