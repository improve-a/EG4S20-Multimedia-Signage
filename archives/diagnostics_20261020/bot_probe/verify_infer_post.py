import pathlib,json,hashlib,zipfile,subprocess
R=pathlib.Path('D:/FPGA/EG4S20-Bot-HDMIProbe');ID='bot_hdmi_probe_infer_add_off_001';D=R/'output/html_fidelity/builds'/ID
sha=lambda b:hashlib.sha256(b).hexdigest()
with zipfile.ZipFile(R/'artifacts'/(ID+'_source.zip')) as z:
 keys=[k for k in z.namelist() if k.startswith('work/design/') and not k.endswith('.al')]
 assert len(keys)==132
 for k in keys:assert z.read(k)==(D/k).read_bytes(),k
 print('POST_BUILD_132_INPUTS_BYTE_IDENTICAL')
 for name in ['exported_syn.tcl','exported_phy.tcl']:
  old=(R/'output/html_fidelity/builds/bot_hdmi_probe_001/runs/bot_hdmi_probe_001'/name).read_bytes()
  new=(D/'runs'/ID/name).read_bytes()
  print(name,'identical',old==new,'sha256',sha(new))
bit=D/'work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit'
delivered=R/'output/bot_probe_infer_add_delivery'/(ID+'.bit')
assert bit.read_bytes()==delivered.read_bytes()
print('FINAL_PHY_EQUALS_DELIVERY',sha(bit.read_bytes()))
for name in ['EG4S20-NoBot','EG4S20-NoBot-HDMIProbe','EG4S20-Multimedia-Signage']:
 p=pathlib.Path('D:/FPGA')/name
 print(name,subprocess.check_output(['git','rev-parse','HEAD'],cwd=p,text=True).strip())
 print(subprocess.check_output(['git','status','--short'],cwd=p,text=True))
donor=pathlib.Path('D:/FPGA/EG4S20-NoBot-HDMIProbe/output/html_fidelity/builds/hdmi_probe_001/work/design/td_project/hx4s20_basic_Runs/phy_1/hx4s20_basic.bit')
assert sha(donor.read_bytes())=='bbb83a715ada3587f7193652e8b1504cbe3a2e2bb102f8ee6cda526f48cbf618'
print('KNOWN_PASS_PROBE_BIT_UNCHANGED',sha(donor.read_bytes()))
