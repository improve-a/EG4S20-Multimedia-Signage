from pathlib import Path
import re, json, sys
p = Path(sys.argv[1])
out = Path(sys.argv[2])
s = re.sub(r'//[^\n]*', '', p.read_text(encoding='utf-8', errors='replace'))
cells = []
for m in re.finditer(r'((?:EG_PHY_|AL_MAP_|AL_BUFKEEP)\w+)\s*#\((.*?)\)\s*([^\s(]+)\s*\((.*?)\);', s, re.S):
    typ, par, name, port = m.groups()
    pars = dict(re.findall(r'\.(\w+)\((.*?)\)', par))
    ports = dict(re.findall(r'\.(\w+)\((.*?)\)', port))
    cells.append(dict(type=typ, name=name, params=pars, ports=ports))
out.write_text(json.dumps(cells), encoding='utf-8')
print('cells', len(cells), '->', out)
