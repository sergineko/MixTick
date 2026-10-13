"""Companion to the actual Android integration test; native Photo Picker only.

Flutter integration_test cannot drive native platform dialogs. This helper
observes UIAutomator hierarchy, then operates only the unique controlled image.
Screenshots are actual emulator captures, not widget/golden renders.
"""
import argparse
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parent.parent
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--adb',required=True)
    parser.add_argument('--device',default='emulator-5554')
    parser.add_argument('--log',required=True)
    parser.add_argument('--image-name',required=True)
    parser.add_argument('--previews',default='docs/reports/phase04/previews')
    args=parser.parse_args()
    evidence=(ROOT / args.previews).resolve()
    if not evidence.is_relative_to(ROOT / 'docs/reports'):
        raise RuntimeError('Gallery captures must stay in reports')
    evidence.mkdir(parents=True,exist_ok=True)
    def adb(*commands):
        return subprocess.run([args.adb,'-s',args.device,*commands],capture_output=True,check=True).stdout
    handled=set()
    deadline=time.monotonic()+900
    while time.monotonic()<deadline:
        log=Path(args.log).read_text('utf-8-sig',errors='replace')
        for mode in ('cancel','pick'):
            marker='P4_GALLERY:'+mode
            if marker not in log or marker in handled:
                continue
            tree=None
            for _ in range(45):
                try:
                    adb('shell','uiautomator','dump','/sdcard/MixTick-Phase04-ui.xml')
                    xml=adb('shell','cat','/sdcard/MixTick-Phase04-ui.xml').decode('utf-8')
                    candidate=ET.fromstring(xml)
                    if any('providers.media' in n.get('package','') or 'photopicker' in n.get('package','') for n in candidate.iter('node')):
                        tree=candidate
                        (evidence / f'gallery-{mode}.xml').write_text(xml,'utf-8')
                        break
                except (subprocess.CalledProcessError,ET.ParseError):
                    pass
                time.sleep(0.5)
            if tree is None:
                raise RuntimeError('Native Photo Picker hierarchy not observed')
            if mode=='cancel':
                adb('shell','input','keyevent','BACK')
                print('PASS: cancelled the actual Android Photo Picker',flush=True)
            else:
                media=adb('shell','content','query','--uri','content://media/external/images/media','--projection','_display_name').decode('utf-8')
                if args.image_name not in media or len(re.findall(r'Row: ',media)) != 1:
                    raise RuntimeError('Only the single controlled gallery fixture may be selected')
                thumbnails=[n for n in tree.iter('node') if re.search(r'(?:icon_thumbnail|image_thumbnail|thumbnail|image_preview)$',n.get('resource-id',''))]
                if not thumbnails:
                    # Android 17 uses Compose semantics rather than resource
                    # IDs. This label and bounds were observed in UIAutomator.
                    thumbnails=[n for n in tree.iter('node') if n.get('content-desc','').startswith('Photo taken on ')]
                if len(thumbnails)!=1:
                    print('Observed resource IDs:',sorted({n.get('resource-id','') for n in tree.iter('node')}),flush=True)
                    raise RuntimeError('Unique gallery thumbnail not found in observed hierarchy')
                bounds=re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',thumbnails[0].get('bounds',''))
                if bounds is None:
                    raise RuntimeError('Thumbnail bounds missing')
                x1,y1,x2,y2=map(int,bounds.groups())
                png=adb('exec-out','screencap','-p')
                (evidence / 'gallery-system.png').write_bytes(png)
                adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
                # Observed Android 17 picker requires its visible Done action
                # after selecting the item, even for this single-image request.
                done=None
                for _ in range(20):
                    adb('shell','uiautomator','dump','/sdcard/MixTick-Phase04-ui.xml')
                    confirmation_xml=adb('shell','cat','/sdcard/MixTick-Phase04-ui.xml').decode('utf-8')
                    confirmation=ET.fromstring(confirmation_xml)
                    done=next((n for n in confirmation.iter('node') if n.get('text')=='Done'),None)
                    if done is not None:
                        (evidence / 'gallery-confirm.xml').write_text(confirmation_xml,'utf-8')
                        break
                    time.sleep(0.25)
                if done is None:
                    raise RuntimeError('Observed Done confirmation action not found')
                done_bounds=re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',done.get('bounds',''))
                if done_bounds is None:
                    raise RuntimeError('Done action has no observed bounds')
                dx1,dy1,dx2,dy2=map(int,done_bounds.groups())
                adb('shell','input','tap',str((dx1+dx2)//2),str((dy1+dy2)//2))
                print('PASS: selected the unique controlled image in the actual Android Photo Picker',flush=True)
            handled.add(marker)
        for name in ('editor-gallery','detail-light','detail-dark'):
            marker='P4_SCREEN:'+name
            if marker in log and marker not in handled:
                png=adb('exec-out','screencap','-p')
                if not png.startswith(b'\x89PNG\r\n\x1a\n'):
                    raise RuntimeError('Emulator screenshot did not return PNG bytes')
                (evidence / (name+'.png')).write_bytes(png)
                print('PASS: actual Android screenshot '+name,flush=True)
                if name=='detail-light':
                    adb('shell','cmd','uimode','night','yes')
                elif name=='detail-dark':
                    adb('shell','cmd','uimode','night','no')
                handled.add(marker)
        if len(handled)==5:
            return
        if 'Some tests failed' in log:
            raise RuntimeError('Native Flutter test failed before completing gallery/screenshots')
        time.sleep(0.25)
    raise RuntimeError('Native gallery companion timed out')

if __name__=='__main__':
    main()
