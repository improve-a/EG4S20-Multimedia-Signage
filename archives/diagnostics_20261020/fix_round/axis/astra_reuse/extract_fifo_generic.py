"""Translate only the mapped receiver FIFO-control LUT/FF cone to plain Verilog.
No vendor cell implementations, BRAM data model, or full HDMI simulation.
"""
from decode_generic import *
fifo=rx+'u_w24_d1024_fifo/'
axis='\\u_hdmi_1_4b_transmitter_core_wrapper/'
external={axis+'I_axis_s_user':'user',axis+'I_axis_s_valid':'valid',
 rx+'I_video_source_sof':'sof',rx+'I_video_source_sol':'sol',
 fifo+'I_fifo_rd_en':'read_en'}
names={};lines=[];reg_count=0;comb_count=0
def get(n):
 global reg_count,comb_count
 n=n.strip()
 if n in ('0','1'):return "1'b"+n
 if n.startswith('open_n'):return "1'b0"
 if n in external:return external[n]
 if '/I_rst_dup_' in n or n.endswith('/S_sync_reset_1d') or n.endswith('/I_rst') or n=='\\acr/I_rst':return 'rst'
 if n in names:return names[n]
 label='n'+str(len(names));names[n]=label
 c,port,i=dr[n]
 if port=='q':
  assert c['params'].get('CLKMUX','"CLK"')=='"CLK"'
  assert c['ports']['clk'].strip()=='\\extensions/osd/clk'
  if c['type']=='AL_MAP_SEQ':
   d=pin(c,'d',0)
   sm=c['params'].get('SRMUX','"0"').strip('"')
   sr=pin(c,'sr',0) if sm=='SR' else "1'b0"
   ce="1'b1"
   init=1 if c['params'].get('REGSET')=='"SET"' else 0
  else:
   mode=c['params']['REG'+str(i)+'_SD'].strip('"')
   if mode=='F':d=func(c,i)
   elif mode=='FX':d='('+pin(c,'mi',0)+' ? '+func(c,1)+' : '+func(c,0)+')'
   elif mode=='MI':d=pin(c,'mi',i)
   else:raise ValueError(mode)
   sm=c['params'].get('SRMUX','"0"').strip('"')
   sr=pin(c,'sr',0) if sm=='SR' else "1'b0"
   assert sm in ['SR','0']
   ce=c['params'].get('CEMUX','"1"').strip('"')
   ce="1'b1" if ce=='1' else ('~'+pin(c,'ce',0) if ce=='INV' else pin(c,'ce',0))
   init=1 if c['params'].get('REG'+str(i)+'_REGSET')=='"SET"' else 0
  lines.append(f'  reg {label}; // {n}')
  lines.append(f'  always @(posedge clk or posedge {sr}) if ({sr}) {label}<=1\'b{init}; else if ({ce}) {label}<={d};')
  reg_count+=1
 else:
  assert port in ('f','fx','o'),(n,port)
  lines.append(f'  wire {label}={func(c,i)}; // {n}');comb_count+=1
 return label
def pin(c,p,i):
 bb=list(reversed(bits(c['ports'].get(p,"2'b00"))))
 return get(bb[i] if i<len(bb) else '0')
def func(c,i):
 pp=c['params']
 if c['type'].startswith('AL_MAP_LUT'):
  a=pp.get('INIT','16\'b0')
  full=int(a.split("'b")[-1],2) if "'b" in a else int(a.split("'h")[-1],16); width=4
  support=[any(((full>>x)^(full>>(x^(1<<j))))&1 for x in range(1<<width)) for j in range(width)]
  args=[pin(c,'abcd'[j],i) if support[j] else "1'b0" for j in range(width)]
  return f"(16'h{full:x} >> {{"+','.join(reversed(args))+"}) & 1'b1"
 assert pp.get('MODE','"LOGIC"')=='"LOGIC"',c['name']
 if c['type']=='EG_PHY_LSLICE':
  assert pp.get('LSFMUX'+str(i),'"FUNC5"')=='"FUNC5"'
  a=pp.get('INIT_LUTF'+str(i),"16'b0");b=pp.get('INIT_LUTG'+str(i),"16'b0")
  table=int(a.split("'b")[-1],2) if "'b" in a else int(a.split("'h")[-1],16)
  upper=int(b.split("'b")[-1],2) if "'b" in b else int(b.split("'h")[-1],16)
  full=table|(upper<<16);width=5
 else:
  a=pp.get('INIT_LUT'+str(i),"16'b0")
  full=int(a.split("'b")[-1],2) if "'b" in a else int(a.split("'h")[-1],16);width=4
 support=[any(((full>>x)^(full>>(x^(1<<j))))&1 for x in range(1<<width)) for j in range(width)]
 args=[pin(c,'abcde'[j],i) if support[j] else "1'b0" for j in range(width)]
 return f"({1<<width}'h{full:x} >> {{"+','.join(reversed(args))+"}) & 1'b1"
roots={'locked':axis+'O_video_locked','pause':rx+'O_video_source_pause',
 'fifo_rst':fifo+'I_rst','write_go':axis+'I_axis_s_valid_syn_4','read_go':fifo+'I_fifo_rd_en_syn_8'}
assigns=[f'  assign {label}={get(name)};' for label,name in roots.items()]
bram=next(c for c in cells if c['type']=='EG_PHY_BRAM' and 'u_video_axi_stream_receiver/' in c['name'])
for port,out in [('addra','write_address'),('addrb','read_address')]:
 bb=bits(bram['ports'][port])[:-3]
 assigns.append('  assign '+out+'={'+','.join(get(b) for b in bb)+'};')
header='module mapped_receiver_control(input clk,rst,user,valid,sof,sol,read_en,output locked,pause,fifo_rst,write_go,read_go,output [9:0] write_address,read_address);\n'
Path(os.environ.get('MODEL_OUT',str(root/'mapped_receiver_control.v'))).write_text(header+'\n'.join(lines+assigns)+'\nendmodule\n')
Path(os.environ.get('MAP_OUT',str(root/'fifo_cone_map.json'))).write_text(json.dumps({'registers':reg_count,'combinational_nodes':comb_count,'nodes':names,'external_boundaries':external},indent=2))
print('Extracted',reg_count,'FF',comb_count,'LUT outputs')
