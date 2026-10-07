"""Équivalent minimal de zipalign : aligne sur 4 octets les données des entrées non compressées
(exigé pour resources.arsc à partir de targetSdk 30)."""
import sys, zipfile

src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as zin, open(dst, "wb") as f, zipfile.ZipFile(f, "w") as zout:
    for info in zin.infolist():
        data = zin.read(info)
        new = zipfile.ZipInfo(info.filename, date_time=info.date_time)
        new.compress_type = info.compress_type
        new.external_attr = info.external_attr
        if info.compress_type == zipfile.ZIP_STORED:
            start = f.tell() + 30 + len(info.filename.encode())
            new.extra = b"\0" * ((-start) % 4)
        zout.writestr(new, data)
