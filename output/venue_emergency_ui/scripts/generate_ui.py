#!/usr/bin/env python3
"""Original Venue Flow vector scenes. Coordinates are native 640x480 pixels."""
import json
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
NAVY='#0B1220'; PANEL='#142238'; BLUE='#3D8EF7'; WHITE='#F7FAFC'
MUTED='#A9BBCE'; ORANGE='#F6AD39'; RED='#EB4D4B'; GREEN='#21B787'
scenes=[]
def scene(code, title):
    s={'id':code,'title':title,'width':640,'height':480,'ops':[]}; scenes.append(s); return s['ops']
def rect(s,x,y,w,h,c,r=0,stroke=None,sw=1):s.append(dict(kind='rect',x=x,y=y,w=w,h=h,color=c,r=r,stroke=stroke,sw=sw))
def text(s,t,x,y,size=18,c=WHITE,weight='regular'):s.append(dict(kind='text',text=t,x=x,y=y,size=size,color=c,weight=weight))
def line(s,points,c,sw=1):s.append(dict(kind='line',points=points,color=c,sw=sw))
def poly(s,points,c,stroke=None,sw=1):s.append(dict(kind='poly',points=points,color=c,stroke=stroke,sw=sw))
def circle(s,x,y,r,c,stroke=None,sw=1):s.append(dict(kind='circle',x=x,y=y,r=r,color=c,stroke=stroke,sw=sw))
def base(s,n,tag=None,color=BLUE):
    rect(s,0,0,640,480,NAVY)
    # Original brand mark: two open architectural portals, one forward route.
    line(s,[[33,44],[33,25],[43,25],[43,44]],WHITE,3)
    line(s,[[49,44],[49,25],[59,25],[59,44]],BLUE,3)
    line(s,[[33,49],[59,49],[65,43]],BLUE,3)
    text(s,'场序',78,19,22,WHITE,'bold');text(s,'VENUE FLOW',133,27,11,MUTED,'semibold')
    if tag:
        rect(s,421,24,187,30,color,7);text(s,tag,434,28,15,NAVY,'bold')
    else:text(s,'公共空间 · 有序同行',438,27,15,MUTED)
    line(s,[[32,69],[608,69]],'#26374E',1)
    text(s,n,32,445,13,MUTED);text(s,'场序 / VENUE FLOW',447,445,13,MUTED)
def arch(s,x,y,w,h):
    # Abstract civic architecture, drawn solely from original geometric shapes.
    rect(s,x,y,w,h,'#173457',12)
    for k in range(6):line(s,[[x+22+k*48,y],[x+22+k*48,y+h]],'#203F63',1)
    for k in range(5):line(s,[[x,y+32+k*48],[x+w,y+32+k*48]],'#203F63',1)
    circle(s,x+w*.77,y+h*.26,w*.22,'#245CA0')
    circle(s,x+w*.77,y+h*.26,w*.13,'#327ED3')
    poly(s,[[x+12,y+h*.76],[x+w*.58,y+h*.56],[x+w-10,y+h*.70],[x+w-10,y+h-20],[x+12,y+h-20]],'#102440')
    poly(s,[[x+w*.12,y+h*.46],[x+w*.57,y+h*.24],[x+w*.86,y+h*.37],[x+w*.44,y+h*.60]],'#75B5F4')
    poly(s,[[x+w*.12,y+h*.46],[x+w*.44,y+h*.60],[x+w*.44,y+h*.88],[x+w*.12,y+h*.72]],'#245B91')
    poly(s,[[x+w*.44,y+h*.60],[x+w*.86,y+h*.37],[x+w*.86,y+h*.70],[x+w*.44,y+h*.88]],'#3D8EF7')
    for k in range(6):
        xx=x+w*(.49+k*.06);line(s,[[xx,y+h*(.575-k*.032)],[xx,y+h*(.855-k*.026)]],'#A0CEFB',2)
    for k in range(4):
        xx=x+w*(.18+k*.065);line(s,[[xx,y+h*(.525+k*.028)],[xx,y+h*(.735+k*.027)]],'#4F91CA',2)
    line(s,[[x+15,y+h-14],[x+w-15,y+h-14]],'#A9C9E9',2)

s=scene('UI01','欢迎首页');base(s,'01 / 欢迎首页')
text(s,'场序',32,102,40,WHITE,'bold');text(s,'VENUE FLOW',34,158,16,BLUE,'semibold')
text(s,'让信息有序',32,214,31,WHITE,'bold');text(s,'让行动清晰',32,256,31,WHITE,'bold')
text(s,'公共场馆多媒体信息发布',32,319,19,MUTED);text(s,'与应急引导演示系统',32,350,19,MUTED)
arch(s,313,98,295,290)
rect(s,32,408,576,1,'#26374E');text(s,'面向科技馆、展览馆与公共服务大厅',32,417,16,MUTED)

s=scene('UI02','日常信息展示');base(s,'02 / 日常信息')
text(s,'今日在场',32,90,34,WHITE,'bold');text(s,'探索、相遇与发现',222,105,18,MUTED)
arch(s,32,151,298,219)
rect(s,46,321,155,33,NAVY,6);text(s,'未来城市 · 主题展',58,327,16,WHITE,'semibold')
text(s,'活动公告 / 示例',356,151,16,BLUE,'semibold')
text(s,'城市与未来',356,188,25,WHITE,'bold');text(s,'主题展览 · A 展厅',356,227,18,MUTED)
line(s,[[356,264],[608,264]],'#2B3C53',1)
text(s,'创客体验',356,282,24,WHITE,'bold');text(s,'互动工坊 · B 展厅',356,320,18,MUTED)
rect(s,32,388,576,47,PANEL,8);text(s,'公共服务',47,401,16,BLUE,'semibold')
text(s,'咨询服务台  /  无障碍通道  /  文明参观',138,400,17,WHITE)

s=scene('UI03','安全预警');base(s,'03 / 安全预警', '模拟演示 / DEMO',ORANGE)
rect(s,32,94,133,30,ORANGE,5);text(s,'注意级 · 示例',44,98,16,NAVY,'bold')
text(s,'安全预警',32,143,38,WHITE,'bold');text(s,'请留意现场指引',32,205,26,WHITE,'semibold')
poly(s,[[506,96],[585,234],[427,234]],ORANGE)
rect(s,500,138,12,51,NAVY,5);circle(s,506,209,7,NAVY)
rect(s,32,268,576,107,PANEL,10);rect(s,32,278,4,87,ORANGE,2)
text(s,'通道临时维护',52,281,23,WHITE,'bold')
text(s,'模拟区域  二层东侧通道',52,319,19,MUTED)
text(s,'示例时间  14:30',402,330,16,ORANGE,'semibold')
circle(s,39,403,3,ORANGE);text(s,'避开维护区域，选择其他开放通道',52,388,19,WHITE)
circle(s,39,430,3,ORANGE);text(s,'保持通道畅通，配合现场工作人员',52,417,19,MUTED)

s=scene('UI04','紧急指引');base(s,'04 / 模拟紧急指引','模拟演示 / DEMO',RED)
text(s,'请有序前往安全出口',32,92,35,WHITE,'bold')
rect(s,32,163,245,177,RED,12)
poly(s,[[64,251],[141,193],[141,229],[242,229],[242,273],[141,273],[141,310]],WHITE)
text(s,'向左撤离',309,170,34,WHITE,'bold');text(s,'沿箭头方向前行',310,225,22,MUTED)
text(s,'01  保持冷静，依次通行',310,280,18,WHITE)
text(s,'02  服从现场人员指引',310,312,18,WHITE)
rect(s,32,366,576,66,PANEL,8)
text(s,'安全提示',49,377,16,RED,'bold');text(s,'不奔跑、不拥挤、不返回取物',49,401,19,WHITE)

s=scene('UI05','模拟疏散路线');base(s,'05 / 模拟疏散路线','模拟演示 / DEMO',GREEN)
text(s,'模拟疏散路线',32,91,32,WHITE,'bold')
rect(s,32,145,403,264,'#E7EFF5',10)
text(s,'二层 / 虚构场馆',48,154,15,'#455A70','semibold')
rect(s,51,185,103,61,'#C6D6E5',5);text(s,'A 展厅',68,203,18,NAVY,'semibold')
rect(s,173,185,111,61,'#C6D6E5',5);text(s,'B 展厅',191,203,18,NAVY,'semibold')
rect(s,303,185,112,61,'#C6D6E5',5);text(s,'服务区',321,203,18,NAVY,'semibold')
rect(s,51,286,103,83,'#C6D6E5',5);text(s,'互动区',69,314,18,NAVY,'semibold')
rect(s,174,286,110,83,'#B7E5D6',5);text(s,'当前区域',185,314,18,'#0F614B','bold')
rect(s,303,286,112,83,'#C6D6E5',5);text(s,'休息区',321,314,18,NAVY,'semibold')
rect(s,266,283,16,8,'#E7EFF5')
line(s,[[274,352],[274,265],[41,265],[41,392],[67,392]],GREEN,7)
circle(s,274,352,8,GREEN,WHITE,3)
poly(s,[[158,265],[175,256],[175,274]],GREEN)
poly(s,[[41,354],[35,338],[47,338]],GREEN)
rect(s,50,380,114,24,GREEN,4);text(s,'安全出口 A',61,381,15,NAVY,'bold')
text(s,'路线说明',457,157,18,WHITE,'bold')
circle(s,469,214,6,GREEN);text(s,'当前位置',486,201,16,MUTED)
line(s,[[460,256],[479,256]],GREEN,5);text(s,'疏散路线',486,242,16,MUTED)
rect(s,460,287,18,17,GREEN,2);text(s,'安全出口',486,283,16,MUTED)
text(s,'沿绿色路线',457,340,18,WHITE,'semibold');text(s,'前往出口 A',457,370,18,WHITE,'semibold')
text(s,'虚构场馆 · 模拟疏散示意图',32,416,18,ORANGE,'semibold')
text(s,'仅供演示，实际疏散以现场标识与指引为准',32,447,13,MUTED)
# Replace default footer because map caveat occupies the footer.
s[:]=[op for op in s if not(op['kind']=='text' and op.get('y')==445)]

s=scene('UI06','恢复常态');base(s,'06 / 恢复日常展示','模拟演示 / DEMO',GREEN)
text(s,'演示结束',32,117,38,WHITE,'bold');text(s,'继续发现精彩',32,176,31,WHITE,'bold')
text(s,'模拟应急展示已完成',32,234,20,MUTED)
circle(s,510,210,79,'#143C37');circle(s,510,210,61,GREEN)
line(s,[[480,209],[502,231],[543,187]],WHITE,8)
line(s,[[44,315],[306,315]],'#355269',2)
for xx,label in [(44,'日常信息'),(175,'场馆宣传'),(306,'媒体轮播')]:
    circle(s,xx,315,7,GREEN);text(s,label,xx-12,336,17,MUTED)
rect(s,32,387,576,47,PANEL,8);text(s,'模拟演示已结束 · 日常展示待继续',49,400,19,WHITE)

ROOT.joinpath('assets/design').mkdir(parents=True,exist_ok=True)
ROOT.joinpath('assets/design/scenes.json').write_text(json.dumps(scenes,ensure_ascii=False,indent=2))
for sc in scenes:
    els=[]
    for o in sc['ops']:
        k=o['kind']; c=o['color']; stroke=f' stroke="{o["stroke"]}" stroke-width="{o["sw"]}"' if o.get('stroke') else ''
        if k=='rect':els.append(f'<rect x="{o["x"]}" y="{o["y"]}" width="{o["w"]}" height="{o["h"]}" rx="{o["r"]}" fill="{c}"{stroke}/>')
        elif k=='circle':els.append(f'<circle cx="{o["x"]}" cy="{o["y"]}" r="{o["r"]}" fill="{c}"{stroke}/>')
        elif k in ('line','poly'):
            pts=' '.join(f'{p[0]},{p[1]}' for p in o['points'])
            els.append(f'<{ "polyline" if k=="line" else "polygon"} points="{pts}" fill="{ "none" if k=="line" else c}" stroke="{c if k=="line" else (o.get("stroke") or "none")}" stroke-width="{o["sw"]}" stroke-linejoin="round" stroke-linecap="round"/>')
        elif k=='text':
            weight={'regular':400,'semibold':600,'bold':700}[o['weight']]
            els.append(f'<text x="{o["x"]}" y="{o["y"]+o["size"]*1.16}" font-size="{o["size"]}" font-weight="{weight}" fill="{c}">{escape(o["text"])}</text>')
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480" viewBox="0 0 640 480"><style>@font-face{font-family:Noto Sans SC;src:url(fonts/NotoSansSC.ttf);font-weight:100 900}text{font-family:"Noto Sans SC","PingFang SC",sans-serif}</style>'+''.join(els)+'</svg>'
    ROOT.joinpath(f'assets/{sc["id"][:2]}-{sc["id"][2:]}.svg').write_text(svg)
print('Generated six original vector scenes and editable SVGs.')
