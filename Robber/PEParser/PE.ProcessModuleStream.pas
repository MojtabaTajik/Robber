{
  * Class to access memory of Windows process.
  *
  * Stream begin is base of module.
  * Stream size is size of image of target module.
}
unit PE.ProcessModuleStream;

interface

uses
  System.Classes,
  System.SysUtils,

  WinApi.PsApi,
  WinApi.TlHelp32,
  WinApi.Windows,

  WinHelper;

type
  TProcessModuleStream = class(TStream)
  private
    FProcessHandle: THandle;
    FModuleBase: NativeUInt;
    FModuleSize: DWORD;
  private
    FCurrentRVA: UInt64;
  public
    constructor Create(ProcessID: DWORD; const me: TModuleEntry32);

    // Create from known process ID. Module base is found from ModuleName.
    // If process id is invalid or no module found exception raised.
    constructor CreateFromPidAndModuleName(ProcessID: DWORD; const ModuleName: string);

    constructor CreateFromPidAndAddress(ProcessID: DWORD; Address: NativeUInt);

    // Create from known process id. Main module used (i.e. started exe).
    constructor CreateFromPid(ProcessID: DWORD);

    destructor Destroy; override;

    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    function Read(var Buffer; Count: Longint): Longint; override;

    property ModuleBase: NativeUInt read FModuleBase;
  end;

implementation

{ TProcessModuleStream }

procedure RaiseFailedToFindModule;
begin
  raise Exception.Create('Failed to find main module.');
end;

constructor TProcessModuleStream.Create(ProcessID: DWORD; const me: TModuleEntry32);
begin
  inherited Create;
  FProcessHandle := OpenProcess(MAXIMUM_ALLOWED, False, ProcessID);
  if FProcessHandle = 0 then
    RaiseLastOSError;
  FModuleBase := NativeUInt(me.modBaseAddr);
  FModuleSize := me.modBaseSize;
end;

constructor TProcessModuleStream.CreateFromPidAndModuleName(ProcessID: DWORD; const ModuleName: string);
var
  me: TModuleEntry32;
begin
  if not FindModuleByName(ProcessID, ModuleName) then
    RaiseFailedToFindModule;
  Create(ProcessID, me);
end;

constructor TProcessModuleStream.CreateFromPidAndAddress(ProcessID: DWORD; Address: NativeUInt);
var
  me: TModuleEntry32;
begin
  if not FindModuleByAddress(ProcessID, Address, me) then
    RaiseFailedToFindModule;
  Create(ProcessID, me);
end;

constructor TProcessModuleStream.CreateFromPid(ProcessID: DWORD);
var
  me: TModuleEntry32;
begin
  if not FindMainModule(ProcessID, me) then
    RaiseFailedToFindModule;
  Create(ProcessID, me);
end;

destructor TProcessModuleStream.Destroy;
begin
  CloseHandle(FProcessHandle);
  inherited;
end;

function TProcessModuleStream.Read(var Buffer; Count: Integer): Longint;
var
  p: pbyte;
  done: NativeUInt;
begin
  p := pbyte(FModuleBase) + FCurrentRVA;
  done := 0;
  ReadProcessMemory(FProcessHandle, p, @Buffer, Count, done);
  inc(FCurrentRVA, done);
  Result := done;
end;

function TProcessModuleStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FCurrentRVA := Offset;
    soCurrent:
      FCurrentRVA := FCurrentRVA + Offset;
    soEnd:
      FCurrentRVA := FModuleSize + Offset;
  end;
  Result := FCurrentRVA;
end;

end.
