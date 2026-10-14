"""Actual Android screenshots and trusted host worker trigger, no APK secret."""
import argparse
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--adb',required=True);parser.add_argument('--device',default='emulator-5554');parser.add_argument('--log',required=True);args=parser.parse_args()
    target=ROOT/'docs/reports/phase08/account-native/previews';target.mkdir(parents=True,exist_ok=True)
    captured=set();worked=False
    def adb(*command):return subprocess.run([args.adb,'-s',args.device,*command],capture_output=True,check=True).stdout
    deadline=time.monotonic()+600
    while time.monotonic()<deadline:
        log=Path(args.log).read_text('utf-8-sig',errors='replace')
        for name in ('account-delete-light','account-delete-dark','account-delete-enabled','account-deleted-session'):
            if 'P8_SCREEN:'+name in log and name not in captured:
                (target/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'));captured.add(name)
                if name=='account-delete-light':adb('shell','cmd','uimode','night','yes')
                if name=='account-delete-dark':adb('shell','cmd','uimode','night','no')
                print('PASS actual Android screenshot '+name,flush=True)
        if 'P8_WORKER_REQUIRED' in log and not worked:
            run=subprocess.run([sys.executable,str(ROOT/'scripts/invoke_local_worker.py')],capture_output=True,text=True,check=True)
            print(run.stdout.strip(),flush=True);worked=True
        if 'P8_DONE:' in log:
            if len(captured)!=4 or not worked:raise RuntimeError('Missing native capture/worker')
            return
        if 'Some tests failed' in log or 'Test failed' in log:raise RuntimeError('Native test failed')
        time.sleep(.25)
    raise RuntimeError('Native companion timeout')
if __name__=='__main__':main()
