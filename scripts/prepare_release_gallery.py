"""Generate the explicitly scoped local gallery fixture without extra packages."""
from pathlib import Path
import struct
import zlib

root=Path(__file__).resolve().parents[1]
target=root/'.tooling/phase04-gallery.png'
def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
width,height=320,240
pixels=b''.join(b'\0'+bytes((190,65,40))*width for _ in range(height))
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
target.parent.mkdir(exist_ok=True)
if target.exists():
    print('PASS: existing scoped gallery fixture preserved')
else:
    target.write_bytes(png)
    print('PASS: created controlled 320x240 PNG in ignored tooling directory')
