"""Editable, offline 16:9 pitch diagrams. No API calls or transaction simulation."""
from pathlib import Path
from html import escape
import base64
import json
import re
import xml.etree.ElementTree as ET
from PIL import ImageFont, Image, ImageDraw

ROOT = Path(__file__).resolve().parent
FONTS = ROOT / 'fonts'
C = dict(bg='#f1eee7', panel='#faf8f1', ink='#242c27', muted='#62685e', line='#d0cec5', green='#365840', pale='#e1e6d8', red='#9a4035', rose='#f2e2db', amber='#7d5b1e', sand='#eee5ce')
font_rules = ''.join('@font-face{font-family:Plex;src:url(data:font/ttf;base64,' + base64.b64encode((FONTS/f'IBMPlexSans-{w}.ttf').read_bytes()).decode() + f') format("truetype");font-weight:{w};font-style:normal;}}' for w in (400, 500))
measurements = []


class Slide:
    def __init__(self, title, subtitle, tag, number):
        self.s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080" role="img" aria-labelledby="title desc"><title id="title">{escape(title)}</title><desc id="desc">{escape(subtitle)}</desc>', '<defs><style>' + font_rules + '</style></defs>']
        self.rect(0, 0, 1920, 1080, 'bg')
        self.text(96, 73, 'SupplierPulse', 26, weight=500)
        self.text(1824, 73, tag.upper(), 19, 'muted', anchor='end', tracking=2)
        self.line(96, 104, 1824, 104, 'line', 1)
        self.text(96, 198, title, 62, weight=400, maxwidth=1730)
        self.text(96, 250, subtitle, 26, 'muted', maxwidth=1730)
        self.line(96, 1002, 1824, 1002, 'line', 1)
        self.text(96, 1040, 'PAPER / SUPPLIERPULSE', 17, 'muted', tracking=1.5)
        self.text(1824, 1040, f'{number:02d}', 20, 'muted', anchor='end')

    def rect(self, x, y, w, h, fill='panel', stroke=None, r=5):
        self.s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{C.get(fill,fill)}"' + (f' stroke="{C.get(stroke,stroke)}" stroke-width="1.5"' if stroke else '') + '/>')

    def text(self, x, y, text, size=26, color='ink', weight=400, anchor='start', maxwidth=None, tracking=None):
        font = ImageFont.truetype(str(FONTS/f'IBMPlexSans-{weight}.ttf'), size)
        width = font.getlength(text)
        if maxwidth is not None:
            measurements.append((text, round(width,1), maxwidth))
            assert width <= maxwidth, (text, width, maxwidth)
        self.s.append(f'<text x="{x}" y="{y}" fill="{C.get(color,color)}" font-family="Plex,Arial,sans-serif" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}"' + (f' letter-spacing="{tracking}"' if tracking else '') + f'>{escape(text)}</text>')

    def lines(self, x, y, lines, size=24, color='muted', gap=36, maxwidth=None):
        for i, line in enumerate(lines): self.text(x, y+i*gap, line, size, color, maxwidth=maxwidth)

    def line(self, x1, y1, x2, y2, color='line', width=2, dash=None):
        self.s.append(f'<path d="M{x1} {y1} L{x2} {y2}" fill="none" stroke="{C.get(color,color)}" stroke-width="{width}"' + (f' stroke-dasharray="{dash}"' if dash else '') + '/>')

    def path(self, d, color='line', width=2, dash=None):
        self.s.append(f'<path d="{d}" fill="none" stroke="{C.get(color,color)}" stroke-width="{width}" stroke-linejoin="round"' + (f' stroke-dasharray="{dash}"' if dash else '') + '/>')

    def arrow(self, x1, y1, x2, y2, color='green', width=2.5, dash=None):
        self.line(x1, y1, x2, y2, color, width, dash)
        if y1 == y2:
            direction = 1 if x2 > x1 else -1
            self.path(f'M{x2-9*direction} {y2-6} L{x2} {y2} L{x2-9*direction} {y2+6}', color, width)
        else:
            direction = 1 if y2 > y1 else -1
            self.path(f'M{x2-6} {y2-9*direction} L{x2} {y2} L{x2+6} {y2-9*direction}', color, width)

    def dot(self, x, y, radius=7, color='green'):
        self.s.append(f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{C[color]}"/>')

    def node(self, x, y, w, h, step, title, lines, fill='panel', accent='green', title_size=30):
        self.rect(x,y,w,h,fill,'line')
        self.text(x+25,y+39,step,18,accent,weight=500,tracking=1)
        self.text(x+25,y+89,title,title_size,weight=500,maxwidth=w-50)
        self.lines(x+25,y+132,lines,22,maxwidth=w-50,gap=33)

    def write(self, name):
        text='\n'.join(self.s)+'</svg>'
        ET.fromstring(text)
        (ROOT/name).write_text(text)


def gate():
    s=Slide('A supplier check that controls the next payment.', 'Fresh signed evidence → a limited payment permit → release only when eligible.', 'The payment gate', 1)
    xs=[96,438,780,1162,1514]
    s.node(xs[0],385,278,222,'SOURCE','Company registry',['Companies House','or GLEIF'],title_size=28)
    s.node(xs[1],385,278,222,'OFF-CHAIN','Agent',['Fetch via AirnodeHub','Pays x402 · submits'])
    s.node(xs[2],385,318,222,'ON-CHAIN','SupplierPulse',['Authenticates the record','Applies buyer rules'],fill='pale')
    s.node(xs[3],385,278,222,'PERMISSION','Payment permit',['One next milestone','Expires · used once'])
    s.node(xs[4],385,310,222,'SETTLEMENT','Supplier paid',['Buyer approved + due','Valid permit required'])
    for a,b in [(374,438),(716,780),(1098,1162),(1440,1514)]:s.arrow(a+9,495,b-9,495)
    s.lines(435,319,['API3 Airnode signs the response.'],22,'green',maxwidth=650)
    s.line(438,344,1098,344,'green',1)
    s.text(98,698,'Buyer funds escrow before the workflow.',24,weight=500,maxwidth=610)
    s.lines(98,743,['Funds stay in the contract until a permitted', 'milestone is released or an eligible refund is called.'],23,maxwidth=625)
    s.arrow(939,607,939,678,'red')
    s.rect(780,692,318,132,'rose')
    s.text(805,731,'Invalid proof',29,'red',500,maxwidth=268)
    s.lines(805,769,['Reject this submission.','It does not trigger a refund.'],21,'red',gap=29,maxwidth=268)
    s.path('M1098 566 L1130 566 L1130 758 L1162 758','amber',2.5)
    s.rect(1162,692,662,132,'sand')
    s.text(1187,731,'Authentic record, failed rules',29,'amber',500,maxwidth=612)
    s.lines(1187,769,['Hold the unpaid balance. Buyer can refund while held;', 'other callers must wait for the grace period.'],22,'amber',gap=30,maxwidth=612)
    s.line(96,884,1824,884,'line',1)
    s.text(96,929,'The agent brings evidence. The contract decides whether money can move.',31,weight=400,maxwidth=1728)
    s.text(96,972,'A valid signature authenticates the source and bytes; it does not guarantee delivery or real-world truth.',20,'muted',maxwidth=1728)
    s.write('payment-gate.svg')


def architecture():
    s=Slide('Data off chain. Payment rules on chain.', 'Two separate rails: buying authenticated evidence and releasing supplier escrow.', 'Evidence and settlement', 2)
    s.text(96,319,'OFF-CHAIN  /  EVIDENCE',19,'muted',tracking=1.5)
    s.node(96,352,370,190,'01','Company registry',['Company status and filings'],title_size=32)
    s.node(596,352,370,190,'02','API3 Airnode',['Signs exact response bytes'],title_size=32)
    s.node(1096,352,370,190,'03','Agent',['Fetch · pay x402 · submit'],title_size=32)
    s.arrow(478,447,584,447)
    s.arrow(978,447,1084,447)
    s.text(1488,405,'Data purchase',25,'green',500,maxwidth=335)
    s.lines(1488,445,['x402 · aUSD','Base Sepolia'],23,maxwidth=335)
    s.line(96,585,1824,585,'line',1,'6 8')
    s.text(96,624,'ON-CHAIN  /  ETHEREUM SEPOLIA',19,'muted',tracking=1.5)
    s.arrow(1281,542,1281,660)
    s.rect(828,676,638,172,'pale','line')
    s.text(853,716,'SupplierPulse contract',33,weight=500,maxwidth=588)
    s.lines(853,758,['Request · timing · replay · signer', 'Buyer rules + known supplier failure'],24,maxwidth=588)
    s.rect(96,676,636,172,'panel','line')
    s.text(121,716,'Buyer-funded escrow',33,weight=500,maxwidth=586)
    s.lines(121,758,['Milestone amounts and due dates', 'Buyer approves each milestone'],24,maxwidth=586)
    s.arrow(744,762,816,762,'ink')
    s.arrow(1478,762,1534,762)
    s.text(1560,718,'Release',31,'green',500,maxwidth=264)
    s.lines(1560,760,['Valid permit', '+ approved + due', '→ supplier payout'],23,'green',gap=32,maxwidth=264)
    s.path('M1281 848 L1281 888 L96 888','line',1.5)
    s.dot(1281,888,5)
    s.text(96,934,'Invalid evidence → reject',27,'red',500,maxwidth=560)
    s.text(740,934,'Failed rules → hold',27,'amber',500,maxwidth=550)
    s.text(96,978,'The x402 data purchase and the supplier payout are separate transactions on separate testnets.',21,'muted',maxwidth=1728)
    s.write('evidence-and-settlement.svg')


def milestone():
    s=Slide('Protect the payments still ahead.', 'Illustrative customer journey · €240,000 order · 30% / 40% / 30% milestones.', 'The customer story', 3)
    s.text(96,326,'A CLEAN CHECK ENABLES THE FIRST PAYMENT',18,'green',tracking=1.2)
    s.line(140,417,680,417,'green',3)
    s.line(680,417,1760,417,'line',3)
    for x in [140,820,1448]:s.dot(x,417,10,'green' if x==140 else 'amber')
    s.node(96,462,520,232,'MILESTONE 1  /  30%','€72,000 paid',['Fresh permit + buyer approval + due','This payment has already left escrow.'],fill='pale',title_size=46)
    s.node(724,462,520,232,'MILESTONE 2  /  40%','€96,000 held',['An authentic negative status arrives.','The contract holds this order.'],fill='sand',accent='amber',title_size=46)
    s.node(1352,462,472,232,'MILESTONE 3  /  30%','€72,000 retained',['Still part of the unpaid balance.','No further milestone is released.'],fill='sand',accent='amber',title_size=43)
    s.rect(648,366,284,33,'bg')
    s.text(666,390,'SIGNED NEGATIVE RECORD',17,'amber',weight=500,tracking=1)
    s.line(680,400,680,455,'amber',2)
    s.rect(96,747,1728,209,'panel','line')
    s.text(128,799,'€168,000',68,'green',400,maxwidth=450)
    s.text(130,845,'unpaid balance remains in escrow',25,'green',maxwidth=560)
    s.text(750,798,'Hold → refund to buyer',35,weight=500,maxwidth=1000)
    s.lines(750,846,['Buyer can call the refund immediately while held.', 'Other callers can do so after the configured grace period.'],25,maxwidth=1000)
    s.text(130,918,'Previously paid funds are not recovered.',23,'muted',maxwidth=560)
    s.text(96,981,'Scenario illustration, not a recorded supplier transition. EUR amounts are fictional; demo escrow uses testnet ETH.',20,'muted',maxwidth=1728)
    s.write('milestone-story.svg')


def export_png(path):
    """Render the small SVG vocabulary above to a supersampled 1080p PNG."""
    import math
    scale = 2
    canvas = Image.new('RGB',(1920*scale,1080*scale),C['bg'])
    draw = ImageDraw.Draw(canvas)
    def segment(a,b,color,width,dash=None):
        if not dash:
            draw.line([tuple(v*scale for v in a),tuple(v*scale for v in b)],fill=color,width=max(1,round(width*scale)))
            return
        length=math.dist(a,b)
        position=0
        part=0
        while position<length:
            end=min(length,position+dash[part%len(dash)])
            if part%2==0:
                points=[(a[0]+(b[0]-a[0])*v/length,a[1]+(b[1]-a[1])*v/length) for v in (position,end)]
                segment(*points,color,width)
            position=end;part+=1
    for el in ET.parse(path).getroot():
        kind=el.tag.split('}')[-1];a=el.attrib
        if kind=='rect':
            x,y,w,h=[float(a[k])*scale for k in ['x','y','width','height']]
            draw.rounded_rectangle((x,y,x+w,y+h),float(a.get('rx',0))*scale,fill=a.get('fill'),outline=a.get('stroke'),width=max(1,round(float(a.get('stroke-width',1))*scale)))
        elif kind=='circle':
            x,y,r=[float(a[k])*scale for k in ['cx','cy','r']]
            draw.ellipse((x-r,y-r,x+r,y+r),fill=a['fill'])
        elif kind=='path':
            coords=[float(n) for n in re.findall(r'-?\d+(?:\.\d+)?',a['d'])]
            points=list(zip(coords[::2],coords[1::2]))
            dash=[float(n) for n in a.get('stroke-dasharray','').split()] or None
            for p,q in zip(points,points[1:]):segment(p,q,a['stroke'],float(a.get('stroke-width',1)),dash)
        elif kind=='text':
            x,y=float(a['x'])*scale,float(a['y'])*scale
            font=ImageFont.truetype(str(FONTS/f'IBMPlexSans-{a.get("font-weight","400")}.ttf'),round(float(a['font-size'])*scale))
            text=el.text or '';tracking=float(a.get('letter-spacing',0))*scale
            width=font.getlength(text)+max(0,len(text)-1)*tracking
            if a.get('text-anchor')=='end':x-=width
            for char in text:
                draw.text((x,y),char,font=font,fill=a['fill'],anchor='ls')
                x+=font.getlength(char)+tracking
    canvas.resize((1920,1080),Image.Resampling.LANCZOS).save(path.with_suffix('.png'))


if __name__=='__main__':
    gate(); architecture(); milestone()
    for path in ROOT.glob('*.svg'):export_png(path)
    (ROOT/'text-fit-check.json').write_text(json.dumps({'canvas':[1920,1080],'checked_strings':len(measurements),'checks':measurements},indent=2))
    print(f'Built 3 standalone SVGs; {len(measurements)} text-width checks passed.')
