"""Emulator diagnostics. Activity time is not data-ready perceived UI."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--adb',default=r'C:\Users\Sergio\AppData\Local\Android\Sdk\platform-tools\adb.exe');parser.add_argument('--device',default='emulator-5554');parser.add_argument('--mode',choices=['debug','profile'],default='debug');args=parser.parse_args()
    def adb(*commands):return subprocess.run([args.adb,'-s',args.device,*commands],capture_output=True,text=True,check=True).stdout
    values=[]
    for n in range(21):
        adb('shell','am','force-stop','es.sergiotech.mixtick')
        text=adb('shell','am','start','-W','-n','es.sergiotech.mixtick/.MainActivity')
        match=re.search(r'TotalTime:\s*(\d+)',text)
        if not match:raise RuntimeError('No actual Activity TotalTime in Android output')
        if n:values.append(int(match[1]))
        time.sleep(.2)
    time.sleep(2)
    memory=adb('shell','dumpsys','meminfo','es.sergiotech.mixtick')
    pss=re.search(r'TOTAL PSS:\s*(\d+)',memory)
    if not pss:raise RuntimeError('No measured PSS')
    ordered=sorted(values)
    result={'status':'PASS','scope':f'Pixel_10a emulator, Android17/API37, standard {args.mode} APK without backend config; process restarts, warm OS caches; Activity TotalTime only, not full Flutter/data-ready latency',
      'warmups_excluded':1,'n':20,'activity_total_ms':values,'median_ms':(ordered[9]+ordered[10])/2,'p95_ms':ordered[18],
      'pss_kb':int(pss[1]),'pss_samples':1,'physical_device':False,'profile':args.mode=='profile'}
    folder=ROOT/'docs/reports/phase08/evidence'
    (folder/f'android-{args.mode}-metrics.json').write_text(json.dumps(result,indent=2))
    (folder/f'android-{args.mode}-memory.txt').write_text(memory)
    (folder/f'android-{args.mode}-gfxinfo.txt').write_text(adb('shell','dumpsys','gfxinfo','es.sergiotech.mixtick','framestats'))
    print(json.dumps(result))
if __name__=='__main__':main()
