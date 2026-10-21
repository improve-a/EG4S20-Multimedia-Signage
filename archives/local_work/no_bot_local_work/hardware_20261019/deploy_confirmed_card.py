"""Guarded deployment to one explicitly approved removable card; no disk discovery."""
import argparse
import base64
import ctypes as C
import ctypes.wintypes as W
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(r'D:\FPGA\EG4S20-NoBot')
RUN = ROOT / 'output/hardware/no_bot_20261019T140608Z'
IMAGE = ROOT / 'output/html_fidelity/no_bot/media/no_bot_fat32.img'
IMAGE_SHA = '22f08ad1161d21f2b86ee6177cd8e4c957e295e218a49a8fba53f73b64bc0f9f'
NBYTES = 64 * 1024 * 1024
PHYSICAL = r'\\.\PhysicalDrive3'
VOLUME = r'\\.\K:'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, data):
    temp = path.with_suffix('.tmp')
    temp.write_bytes((json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    os.replace(temp, path)


def identity():
    ps = r'''$ErrorActionPreference='Stop';[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false);
$d=Get-Disk -Number 3;$p=Get-Partition -DriveLetter K;$v=Get-Volume -DriveLetter K;
if($d.Size -ne 62531305472 -or $d.IsBoot -or $d.IsSystem -or $d.IsOffline -or $d.IsReadOnly -or $d.BusType -ne 'USB' -or $d.SerialNumber -ne '000000001532' -or $d.UniqueId -ne 'USBSTOR\DISK&VEN_GENERIC&PROD_STORAGE_DEVICE&REV_1532\000000001532&1:thinkpad' -or $p.DiskNumber -ne 3 -or $p.Offset -ne 4194304 -or $v.FileSystem -ne 'FAT32' -or $v.FileSystemLabel -ne 'ANLOGIC2026'){throw 'Confirmed card identity mismatch'};
[ordered]@{Disk=$d|Select Number,FriendlyName,SerialNumber,UniqueId,Size,BusType,IsBoot,IsSystem;Partition=$p|Select DiskNumber,PartitionNumber,Offset,Size,DriveLetter;Volume=$v|Select FileSystemLabel,FileSystem,Size,SizeRemaining}|ConvertTo-Json -Depth 6'''
    result = subprocess.run(['powershell', '-NoProfile', '-EncodedCommand',
                             base64.b64encode(ps.encode('utf-16le')).decode()],
                            capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.decode(errors='replace'))
    return json.loads(result.stdout.decode('utf-8-sig'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deploy-confirmed', action='store_true')
    args = parser.parse_args()
    approval = json.loads((RUN / 'card_deploy_approval.json').read_text(encoding='utf-8'))
    assert approval['human_reply'] == '确认，部署最终镜像'
    assert approval['authorized_target']['disk_number'] == 3
    original = json.loads((RUN / 'card_before/manifest.json').read_text(encoding='utf-8'))
    assert original['state'] == 'BACKUP_PASS' and not original['read_errors']
    assert sha((RUN / 'card_before/first64MiB.bin').read_bytes()) == original['first64MiB_sha256']
    for item in original['files']:
        assert sha(Path(item['backup']).read_bytes()) == item['sha256']
        if not item['path'].startswith('K:\\System Volume Information\\'):
            assert sha(Path(item['path']).read_bytes()) == item['sha256']
    image = IMAGE.read_bytes()
    assert len(image) == NBYTES and sha(image) == IMAGE_SHA
    selected = identity()
    plan = {'state': 'READY_FOR_CONFIRMED_DEPLOYMENT', 'image': str(IMAGE),
            'image_bytes': NBYTES, 'image_sha256': IMAGE_SHA, 'physical_target': PHYSICAL,
            'volume_target': VOLUME, 'byte_range': [0, NBYTES - 1],
            'identity': selected, 'backup': str(RUN / 'card_before'),
            'approval': str(RUN / 'card_deploy_approval.json'),
            'script_sha256': sha(Path(__file__).read_bytes()),
            'writes_outside_first64MiB': False}
    save(RUN / 'card_deploy_plan.json', plan)
    if not args.deploy_confirmed:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return

    out = RUN / 'card_deployed'
    out.mkdir(exist_ok=False)
    record = dict(plan, state='STARTING', pid=os.getpid(), started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), bytes_written=0)
    result_path = out / 'deployment.json'
    save(result_path, record)
    kernel = C.WinDLL('kernel32', use_last_error=True)
    kernel.CreateFileW.argtypes = [W.LPCWSTR, W.DWORD, W.DWORD, C.c_void_p, W.DWORD, W.DWORD, W.HANDLE]
    kernel.CreateFileW.restype = W.HANDLE
    kernel.CloseHandle.argtypes = [W.HANDLE]
    kernel.CloseHandle.restype = W.BOOL
    kernel.DeviceIoControl.argtypes = [W.HANDLE, W.DWORD, C.c_void_p, W.DWORD, C.c_void_p, W.DWORD, C.POINTER(W.DWORD), C.c_void_p]
    kernel.DeviceIoControl.restype = W.BOOL
    kernel.SetFilePointerEx.argtypes = [W.HANDLE, C.c_longlong, C.POINTER(C.c_longlong), W.DWORD]
    kernel.SetFilePointerEx.restype = W.BOOL
    kernel.ReadFile.argtypes = [W.HANDLE, C.c_void_p, W.DWORD, C.POINTER(W.DWORD), C.c_void_p]
    kernel.ReadFile.restype = W.BOOL
    kernel.WriteFile.argtypes = [W.HANDLE, C.c_void_p, W.DWORD, C.POINTER(W.DWORD), C.c_void_p]
    kernel.WriteFile.restype = W.BOOL
    kernel.FlushFileBuffers.argtypes = [W.HANDLE]
    kernel.FlushFileBuffers.restype = W.BOOL
    volume = disk = None
    locked = False
    started = time.monotonic()

    def check(ok):
        if not ok:
            raise C.WinError(C.get_last_error())

    def open_handle(path, flags=0):
        handle = kernel.CreateFileW(path, 0xC0000000, 3, None, 3, flags, None)
        if handle == C.c_void_p(-1).value:
            raise C.WinError(C.get_last_error())
        return handle

    def control(handle, code):
        done = W.DWORD()
        check(kernel.DeviceIoControl(handle, code, None, 0, None, 0, C.byref(done), None))

    def read_prefix(handle):
        check(kernel.SetFilePointerEx(handle, 0, None, 0))
        chunks = []
        for _ in range(NBYTES // (1024 * 1024)):
            buffer = C.create_string_buffer(1024 * 1024)
            done = W.DWORD()
            check(kernel.ReadFile(handle, buffer, len(buffer), C.byref(done), None))
            assert done.value == len(buffer), 'Short physical read'
            chunks.append(buffer.raw)
        return b''.join(chunks)

    try:
        volume = open_handle(VOLUME)
        control(volume, 0x00090018)  # FSCTL_LOCK_VOLUME
        locked = True
        control(volume, 0x00090020)  # FSCTL_DISMOUNT_VOLUME
        disk = open_handle(PHYSICAL, 0x80000000)  # FILE_FLAG_WRITE_THROUGH
        locked_before = read_prefix(disk)
        (out / 'locked_before64MiB.bin').write_bytes(locked_before)
        record['locked_before_sha256'] = sha(locked_before)
        record['state'] = 'VOLUME_LOCKED_DISMOUNTED_BEFORE_WRITE'
        save(result_path, record)
        check(kernel.SetFilePointerEx(disk, 0, None, 0))
        for offset in range(0, NBYTES, 1024 * 1024):
            chunk = image[offset:offset + 1024 * 1024]
            assert offset % 512 == 0 and len(chunk) % 512 == 0 and offset + len(chunk) <= NBYTES
            buffer = C.create_string_buffer(chunk, len(chunk))
            done = W.DWORD()
            check(kernel.WriteFile(disk, buffer, len(chunk), C.byref(done), None))
            assert done.value == len(chunk), 'Short physical write'
            record['bytes_written'] += done.value
            record['state'] = 'WRITING'
            save(result_path, record)
        check(kernel.FlushFileBuffers(disk))
        actual = read_prefix(disk)
        assert len(actual) == NBYTES
        (out / 'readback64MiB.img').write_bytes(actual)
        record['readback_sha256'] = sha(actual)
        record['readback_exact'] = actual == image
        assert record['readback_exact'] and record['readback_sha256'] == IMAGE_SHA
        record['state'] = 'DEPLOYED_EXACT_READBACK_PASS'
        record['physical_write_performed'] = True
    except BaseException as error:
        record['state'] = 'FAILED_NO_AUTOMATIC_RETRY'
        record['error'] = repr(error)
        record['physical_write_performed'] = record['bytes_written'] > 0
        raise
    finally:
        if disk is not None:
            kernel.CloseHandle(disk)
        if volume is not None:
            if locked:
                try:
                    control(volume, 0x0009001C)  # FSCTL_UNLOCK_VOLUME
                except OSError as error:
                    record['unlock_note'] = repr(error)
            kernel.CloseHandle(volume)
        record['wall_seconds'] = round(time.monotonic() - started, 3)
        record['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save(result_path, record)
    print(json.dumps(record, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
