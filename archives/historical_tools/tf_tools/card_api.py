import ctypes as C,ctypes.wintypes as W,struct
k=C.WinDLL('kernel32',use_last_error=True)
k.CreateFileW.argtypes=[W.LPCWSTR,W.DWORD,W.DWORD,C.c_void_p,W.DWORD,W.DWORD,W.HANDLE];k.CreateFileW.restype=W.HANDLE
k.CloseHandle.argtypes=[W.HANDLE];k.CloseHandle.restype=W.BOOL
k.DeviceIoControl.argtypes=[W.HANDLE,W.DWORD,C.c_void_p,W.DWORD,C.c_void_p,W.DWORD,C.POINTER(W.DWORD),C.c_void_p];k.DeviceIoControl.restype=W.BOOL
k.FlushFileBuffers.argtypes=[W.HANDLE];k.FlushFileBuffers.restype=W.BOOL
class Handle:
 def __init__(self,path,access=0x80000000,share=7):
  self.h=k.CreateFileW(path,access,share,None,3,0,None)
  if self.h==C.c_void_p(-1).value:raise C.WinError(C.get_last_error())
 def __enter__(self):return self.h
 def __exit__(self,*args):k.CloseHandle(self.h)
def ioctl(h,code,data,outsize):
 inp=C.create_string_buffer(data);out=C.create_string_buffer(outsize) if outsize else None;done=W.DWORD()
 ok=k.DeviceIoControl(h,code,inp,len(data),out,outsize,C.byref(done),None)
 if not ok:raise C.WinError(C.get_last_error())
 return out.raw[:done.value] if out else b''
def bitmap(h):
 b=ioctl(h,0x9006f,struct.pack('<q',0),1024*1024)
 start,total=struct.unpack_from('<qq',b);return start,total,b[16:]
def free(bits,start,lcn):return not (bits[(lcn-start)//8]>>(lcn-start)%8)&1
def extents(h):
 b=ioctl(h,0x90073,struct.pack('<q',0),65536)
 n=struct.unpack_from('<I',b)[0];vcn=struct.unpack_from('<q',b,8)[0];out=[]
 for i in range(n):
  nxt,lcn=struct.unpack_from('<qq',b,16+16*i);out.append(dict(vcn=vcn,next_vcn=nxt,lcn=lcn,clusters=nxt-vcn));vcn=nxt
 return out
class MoveData(C.Structure):
 _fields_=[('FileHandle',W.HANDLE),('StartingVcn',C.c_int64),('StartingLcn',C.c_int64),('ClusterCount',W.DWORD)]
def move(vol,file,target,count):
 assert C.sizeof(MoveData)==32
 m=MoveData(file,0,target,count);ioctl(vol,0x90074,bytes(m),0)
def flush(h):
 if not k.FlushFileBuffers(h):raise C.WinError(C.get_last_error())
