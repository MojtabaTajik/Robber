{
  Memory Stream based on already mapped PE image in current process.
  Basically it's TMemoryStream with Memory pointing to ImageBase and Size equal
  to SizeOfImage.
}
unit PE.MemoryStream;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TPECustomMemoryStream = class(TStream)
  protected
    FMemory: Pointer;
    FSize, FPosition: NativeInt;
  public
    constructor CreateFromPointer(Ptr: Pointer; Size: integer);

    procedure SetPointer(Ptr: Pointer; const Size: NativeInt);

    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: integer): integer; override;

    procedure SaveToStream(Stream: TStream); virtual;
    procedure SaveToFile(const FileName: string);

    property Memory: Pointer read FMemory;
  end;

  TPEMemoryStream = class(TPECustomMemoryStream)
  private
    FModuleToUnload: HMODULE; // needed if module loading is forced.
    FModuleFileName: string;
    FModuleSize: uint32;
  private
    procedure CreateFromModulePtr(ModulePtr: Pointer);
  public
    // Create stream from module in current process.
    // If module is not found exception raised.
    // To force loading module set ForceLoadingModule to True.
    constructor Create(const ModuleName: string; ForceLoadingModule: boolean = False); overload;

    // Create from module by known base address.
    constructor Create(ModuleBase: NativeUInt); overload;

    destructor Destroy; override;

    // Simply read SizeOfImage from memory.
    class function GetModuleImageSize(ModulePtr: PByte): uint32; static;
  end;

implementation

uses
  WinApi.Windows,

  PE.Types.DosHeader,
  PE.Types.NTHeaders;

{ TPECustomMemoryStream }

procedure TPECustomMemoryStream.SetPointer(Ptr: Pointer; const Size: NativeInt);
begin
  FMemory := Ptr;
  FSize := Size;
  FPosition := 0;
end;

constructor TPECustomMemoryStream.CreateFromPointer(Ptr: Pointer; Size: integer);
begin
  inherited Create;
  SetPointer(Ptr, Size);
end;

procedure TPECustomMemoryStream.SaveToFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TPECustomMemoryStream.SaveToStream(Stream: TStream);
begin
  if FSize <> 0 then
    Stream.WriteBuffer(FMemory^, FSize);
end;

function TPECustomMemoryStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FSize + Offset;
  end;
  Result := FPosition;
end;

function TPECustomMemoryStream.Read(var Buffer; Count: integer): Longint;
begin
  if Count = 0 then
    Exit(0);
  Result := FSize - FPosition;
  if Result > 0 then
  begin
    if Result > Count then
      Result := Count;
    Move(PByte(FMemory)[FPosition], Buffer, Result);
    Inc(FPosition, Result);
  end;
end;

function TPECustomMemoryStream.Write(const Buffer; Count: integer): integer;
begin
  if Count = 0 then
    Exit(0);
  Result := FSize - FPosition;
  if Result > 0 then
  begin
    if Result > Count then
      Result := Count;
    Move(Buffer, PByte(FMemory)[FPosition], Result);
    Inc(FPosition, Result);
  end;
end;

{ TPEMemoryStream }

procedure TPEMemoryStream.CreateFromModulePtr(ModulePtr: Pointer);
begin
  if ModulePtr = nil then
    raise Exception.CreateFmt('Module "%s" not found in address space',
      [FModuleFileName]);

  FModuleSize := TPEMemoryStream.GetModuleImageSize(ModulePtr);

  SetPointer(ModulePtr, FModuleSize);
end;

constructor TPEMemoryStream.Create(const ModuleName: string;
  ForceLoadingModule: boolean);
var
  FModulePtr: Pointer;
begin
  inherited Create;
  FModuleFileName := ModuleName;

  FModulePtr := Pointer(GetModuleHandle(PChar(ModuleName)));
  FModuleToUnload := 0;

  if (FModulePtr = nil) and (ForceLoadingModule) then
  begin
    FModuleToUnload := LoadLibrary(PChar(ModuleName));
    FModulePtr := Pointer(FModuleToUnload);
  end;

  CreateFromModulePtr(FModulePtr);
end;

constructor TPEMemoryStream.Create(ModuleBase: NativeUInt);
begin
  inherited Create;
  FModuleFileName := GetModuleName(ModuleBase);

  FModuleToUnload := 0; // we didn't load it and won't free it

  CreateFromModulePtr(Pointer(ModuleBase));
end;

destructor TPEMemoryStream.Destroy;
begin
  if FModuleToUnload <> 0 then
    FreeLibrary(FModuleToUnload);
  inherited;
end;

class function TPEMemoryStream.GetModuleImageSize(ModulePtr: PByte): uint32;
var
  dos: PImageDOSHeader;
  nt: PImageNTHeaders;
begin
  dos := PImageDOSHeader(ModulePtr);

  if not dos.e_magic.IsMZ then
    raise Exception.Create('Not PE image');

  nt := PImageNTHeaders(ModulePtr + dos^.e_lfanew);

  if not nt.Signature.IsPE00 then
    raise Exception.Create('Not PE image');

  Result := nt^.OptionalHeader.pe32.SizeOfImage;
end;

end.
