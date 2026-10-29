from http.server import BaseHTTPRequestHandler,HTTPServer
from pathlib import Path
import json,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[2]
out=root/'assets/models/infinite-tower-20261029'
out.mkdir(parents=True,exist_ok=True)
def vec(e,v):
 for key,val in zip(('X','Y','Z'),v): ET.SubElement(e,key).text=str(val)
def prop(parent,name,kind,value):
 e=ET.SubElement(parent,kind,name=name)
 if kind=='Vector3': vec(e,value)
 elif kind=='Vector2':
  for k,v in zip(('X','Y'),value): ET.SubElement(e,k).text=str(v)
 elif kind=='CoordinateFrame':
  for k,v in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),value): ET.SubElement(e,k).text=str(v)
 elif kind=='Color3':
  for k,v in zip(('R','G','B'),value): ET.SubElement(e,k).text=str(v)
 elif kind=='Content': ET.SubElement(e,'url').text=value
 elif kind=='bool': e.text='true' if value else 'false'
 elif kind in ('NumberSequence','ColorSequence','NumberRange'): e.text=' '.join(str(v) for v in value)
 else: e.text=str(value)
def make(node,parent):
 item=ET.SubElement(parent,'Item',{'class':node['Class'],'referent':'RBX'+str(node['Id'])})
 props=ET.SubElement(item,'Properties');prop(props,'Name','string',node['Name'])
 for name,entry in (node.get('Props') or {}).items():
  kind,value=entry['Type'],entry['Value']
  if name=='Color' and node['Class'] in ('Part','WedgePart','CornerWedgePart'):
   r,g,b=(round(v*255) for v in value);name='Color3uint8';kind='Color3uint8';value=(255<<24)|(r<<16)|(g<<8)|b
  if name=='Shape': name='shape'
  prop(props,name,kind,value)
 for child in node.get('Children',[]): make(child,item)
def export(data,name):
 doc=ET.Element('roblox',{'version':'4'})
 make(data,doc)
 ET.ElementTree(doc).write(out/name,encoding='utf-8',xml_declaration=True)
class Handler(BaseHTTPRequestHandler):
 chunks={}
 def do_POST(self):
  if self.path not in ('/tower','/original'): self.send_error(404);return
  n=int(self.headers.get('Content-Length','0'))
  if n>6000000: self.send_error(413);return
  data=json.loads(self.rfile.read(n))
  if 'Chunk' in data:
   parts=self.chunks.setdefault(self.path,[]);parts.append(data['Chunk'])
   if not data['Final']:
    self.send_response(200);self.end_headers();self.wfile.write(b'Chunk received');return
   data=json.loads(''.join(self.chunks.pop(self.path)))
  name='InfiniteTower.rbxmx' if self.path=='/tower' else 'PreviousInfiniteTower.rbxmx'
  export(data,name)
  (out/(name+'.snapshot.json')).write_text(json.dumps(data),encoding='utf-8')
  self.send_response(200);self.end_headers();self.wfile.write(b'Exported')
 def log_message(self,*args): pass
if __name__=='__main__': HTTPServer(('127.0.0.1',34876),Handler).serve_forever()
