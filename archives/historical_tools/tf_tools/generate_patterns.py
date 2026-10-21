"""Deterministic RGB24 BI_RGB calibration patterns; no external dependencies."""
import pathlib,struct,hashlib,json,zlib,binascii
W,H=640,480
OUT=pathlib.Path(__file__).resolve().parent.parent/'images';OUT.mkdir(exist_ok=True)
FONT={
'0':['01110','10001','10011','10101','11001','10001','01110'],
'1':['00100','01100','00100','00100','00100','00100','01110'],
'2':['01110','10001','00001','00010','00100','01000','11111'],
'3':['11110','00001','00001','01110','00001','00001','11110'],
'4':['00010','00110','01010','10010','11111','00010','00010'],
'6':['01110','10000','10000','11110','10001','10001','01110'],
'8':['01110','10001','10001','01110','10001','10001','01110'],
'A':['01110','10001','10001','11111','10001','10001','10001'],
'B':['11110','10001','10001','11110','10001','10001','11110'],
'C':['01111','10000','10000','10000','10000','10000','01111'],
'D':['11110','10001','10001','10001','10001','10001','11110'],
'E':['11111','10000','10000','11110','10000','10000','11111'],
'F':['11111','10000','10000','11110','10000','10000','10000'],
'G':['01111','10000','10000','10111','10001','10001','01111'],
'H':['10001','10001','10001','11111','10001','10001','10001'],
'I':['11111','00100','00100','00100','00100','00100','11111'],
'L':['10000','10000','10000','10000','10000','10000','11111'],
'M':['10001','11011','10101','10101','10001','10001','10001'],
'N':['10001','11001','10101','10011','10001','10001','10001'],
'O':['01110','10001','10001','10001','10001','10001','01110'],
'P':['11110','10001','10001','11110','10000','10000','10000'],
'R':['11110','10001','10001','11110','10100','10010','10001'],
'S':['01111','10000','10000','01110','00001','00001','11110'],
'T':['11111','00100','00100','00100','00100','00100','00100'],
'U':['10001','10001','10001','10001','10001','10001','01110'],
'W':['10001','10001','10001','10101','10101','11011','10001'],
'X':['10001','10001','01010','00100','01010','10001','10001'],
'Y':['10001','10001','01010','00100','00100','00100','00100'],
' ':['00000']*7,'-':['00000','00000','00000','11111','00000','00000','00000']}
def pixel(a,x,y,c):
 if 0<=x<W and 0<=y<H:a[(y*W+x)*3:(y*W+x)*3+3]=bytes(c)
def rect(a,x,y,w,h,c):
 for yy in range(max(0,y),min(H,y+h)):
  for xx in range(max(0,x),min(W,x+w)):pixel(a,xx,yy,c)
def text(a,x,y,t,scale=3,c=(255,255,255)):
 for ch in t:
  for yy,row in enumerate(FONT[ch]):
   for xx,v in enumerate(row):
    if v=='1':rect(a,x+xx*scale,y+yy*scale,scale,scale,c)
  x+=6*scale
def png(data):
 def chunk(t,b):return struct.pack('>I',len(b))+t+b+struct.pack('>I',binascii.crc32(t+b)&0xffffffff)
 rows=b''.join(b'\0'+data[y*W*3:(y+1)*W*3] for y in range(H))
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b'')
meta=[]
for idx in range(1,4):
 a=bytearray(bytes((15,22,34))*W*H)
 if idx==1:
  colors=[(255,255,255),(255,255,0),(0,255,255),(0,255,0),(255,0,255),(255,0,0),(0,0,255),(0,0,0)]
  for k,c in enumerate(colors):rect(a,k*80,80,80,280,c)
  for x in range(W):rect(a,x,370,1,48,(x*255//639,)*3)
  title='HX4S20C 01 RGB BARS'
 elif idx==2:
  for y in range(80,420):
   for x in range(W):
    v=x*255//639
    pixel(a,x,y,(v,v,v) if y<245 else (((255,)*3) if (x//16+y//16)%2 else (0,0,0)))
  for x in range(0,W,80):rect(a,x,80,1,340,(255,0,0))
  for y in range(80,421,68):rect(a,0,y,640,1,(0,255,0))
  title='HX4S20C 02 GRAY GRID'
 else:
  for y in range(80,420):
   for x in range(W):
    dx=x-320;dy=y-250;radius=dx*dx+dy*dy
    if 118**2<=radius<=122**2:pixel(a,x,y,(255,255,255))
    elif x%40==0 or (y-90)%40==0:pixel(a,x,y,(52,66,84))
  rect(a,319,80,2,340,(255,255,0));rect(a,0,249,640,2,(255,255,0))
  rect(a,12,88,75,55,(255,0,0));text(a,30,104,'1',4)
  rect(a,553,88,75,55,(0,180,0));text(a,574,104,'2',4)
  rect(a,12,356,75,55,(0,0,255));text(a,30,372,'3',4)
  rect(a,553,356,75,55,(190,0,190));text(a,574,372,'4',4)
  title='HX4S20C 03 GEOMETRY'
 text(a,16,14,title);text(a,16,49,'TOP - 640X480 RGB24',2,(120,200,255))
 text(a,16,440,'BOTTOM - TEST '+str(idx),3,(255,205,100))
 for x in range(W):pixel(a,x,0,(255,255,255));pixel(a,x,H-1,(255,255,255))
 for y in range(H):pixel(a,0,y,(255,255,255));pixel(a,W-1,y,(255,255,255))
 body=bytearray()
 for y in range(H-1,-1,-1):
  row=a[y*W*3:(y+1)*W*3]
  for x in range(W):body.extend(row[x*3:x*3+3][::-1])
 header=struct.pack('<2sIHHI',b'BM',54+len(body),0,0,54)+struct.pack('<IiiHHIIiiII',40,W,H,1,24,0,len(body),2835,2835,0,0)
 data=header+body;name=f'HXTEST{idx:02}.BMP';p=OUT/name
 with p.open('xb') as f:f.write(data)
 (OUT/f'HXTEST{idx:02}.png').write_bytes(png(a))
 meta.append({'name':name,'size':len(data),'sha256':hashlib.sha256(data).hexdigest(),'width':W,'height':H,'bits':24,'compression':0,'pixel_offset':54,'row_bytes':1920,'orientation':'positive height, bottom-up BGR','description':title})
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2))
print(json.dumps(meta,indent=2))
