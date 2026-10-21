import base64,glob,os,sys
R=sys.argv[1];src=R+'/src'
css=''.join(open(f).read() for f in sorted(glob.glob(src+'/*.css')))
assets={}
for f in sorted(glob.glob(R+'/assets/*')):
  k=os.path.splitext(os.path.basename(f))[0];mt='image/png' if f.endswith('.png') else 'image/jpeg'
  assets[k]=f'data:{mt};base64,'+base64.b64encode(open(f,'rb').read()).decode()
js='const ASSETS={'+','.join(f'"{k}":"{v}"' for k,v in assets.items())+'};\n'
js+=''.join(open(f).read() for f in sorted(glob.glob(src+'/[2-9]*.js')))
html=open(src+'/index.tpl.html').read().replace('/*CSS*/',css).replace('/*JS*/',js)
open(R+'/anlogic-exhibit.html','w').write(html);print(len(html)//1024,'KB')
