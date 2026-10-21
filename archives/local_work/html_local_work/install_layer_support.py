import sys,json,base64,pathlib
sys.path.insert(0,'harness')
from windows_runner import remote_python
b=pathlib.Path('output/html_fidelity/local_temp')
files={f:base64.b64encode((b/pathlib.Path(f).name).read_bytes()).decode() for f in ['rtl/ext/html_resource_locator.v','tests/html_write_contract_tb.v']}
code="from pathlib import Path\nimport base64\nr=Path(r'D:\\FPGA\\EG4S20-Multimedia-Signage')\n"
code+=f'files={files!r}\n'
code+="for n,data in files.items():\n p=r/n;p.write_bytes(base64.b64decode(data));print(n)\n"
print(remote_python(code))
