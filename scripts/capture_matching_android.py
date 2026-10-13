"""Observe integration-test markers and capture the actual emulator display."""
import argparse
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parent.parent
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--adb',required=True)
    parser.add_argument('--device',default='emulator-5554')
    parser.add_argument('--log',required=True)
    parser.add_argument('--previews',default='docs/reports/phase06/previews')
    args=parser.parse_args()
    destination=(ROOT / args.previews).resolve()
    if not destination.is_relative_to(ROOT / 'docs/reports/phase06'):
        raise RuntimeError('Captures must stay in phase06 reports')
    destination.mkdir(parents=True,exist_ok=True)
    captured=set()
    def adb(*cmd):
        return subprocess.run([args.adb,'-s',args.device,*cmd],capture_output=True,check=True).stdout
    deadline=time.monotonic()+900
    while time.monotonic()<deadline:
        log=Path(args.log).read_text('utf-8-sig',errors='replace')
        for name in ['matching-debug','matching-selection','matching-light','matching-dark']:
            if 'P6_SCREEN:'+name in log and name not in captured:
                (destination / (name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
                captured.add(name)
                print('PASS: actual Android screenshot '+name,flush=True)
                if name=='matching-light':adb('shell','cmd','uimode','night','yes')
                if name=='matching-dark':adb('shell','cmd','uimode','night','no')
        if {'matching-selection','matching-light','matching-dark'}.issubset(captured):return
        if 'Some tests failed' in log or 'Test failed' in log:
            raise RuntimeError('Integration test failed before all captures')
        time.sleep(0.25)
    raise RuntimeError('Timed out waiting for screen markers')
if __name__=='__main__':main()
