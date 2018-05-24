unit PE.Section;

interface

uses
  System.Classes,
  System.SysUtils,

  PE.Common,
  PE.Msg,
  PE.Types,
  PE.Types.Sections,
  PE.Utils;

type
  TPESectionBase = class
  private
    FMsg: PMsgMgr;
    FName: String;      // Section name.
    FVSize: uint32;     // Virtual Size.
    FRVA: TRVA;         // Relative Virtual Address.
    FRawSize: uint32;   // Raw size.
    FRawOffset: uint32; // Raw offset.
    FFlags: uint32;     // Section flags.
    FMem: TBytes;       // Memory allocated for section, size = raw size
    function GetImageSectionHeader: TImageSectionHeader;
    function GetMemPtr: PByte;

    procedure SetAllocatedSize(Value: uint32);
  public

    constructor Create(const ASecHdr: TImageSectionHeader; AMem: pointer;
      AMsg: PMsgMgr = nil); overload;

    destructor Destroy; override;

    function GetAllocatedSize: uint32; inline;

    // Set section values from Section Header.
    // Allocate memory for section data.
    // If ChangeData is True memory will be overwritten.
    procedure SetHeader(ASecHdr: TImageSectionHeader; ASrcData: pointer;
      ChangeData: boolean = True);

    // Can be used to load mapped section.
    // SetHeader must be called first.
    function LoadDataFromStreamEx(AStream: TStream;
      ARawOffset, ARawSize: uint32): boolean;

    // Allocate Mem and read RawSize bytes from RawOffset of AStream.
    function LoadDataFromStream(AStream: TStream): boolean;

    // Save section data to AStream.
    function SaveDataToStream(AStream: TStream): boolean;

    // Save section data to file.
    function SaveToFile(const FileName: string): boolean;

    // Deallocate section data.
    procedure ClearData;

    procedure Resize(NewSize: uint32);

    function ContainRVA(RVA: TRVA): boolean; {$IFNDEF DEBUG}inline; {$ENDIF}
    function GetEndRVA: TRVA; inline;
    function GetEndRawOffset: uint32; inline;
    function GetLastRVA: TRVA; inline;

    function IsCode: boolean; inline;

    function NameAsHex: string;

    property Name: String read FName write FName;
    property VirtualSize: uint32 read FVSize;
    property RVA: TRVA read FRVA;
    property RawSize: uint32 read FRawSize;
    property RawOffset: uint32 read FRawOffset write FRawOffset;
    property Flags: uint32 read FFlags write FFlags;
    property ImageSectionHeader: TImageSectionHeader read GetImageSectionHeader;
    property AllocatedSize: uint32 read GetAllocatedSize;

    // Don't use Mem directly.
    // Use TPEImage functions to read/write data.
    property Mem: PByte read GetMemPtr;
  end;

  TPESectionImageHeader = class(TPESectionBase);

  TPESection = class(TPESectionBase);

  PPESection = ^TPESection;

implementation

{ TPESection }

function TPESectionBase.ContainRVA(RVA: TRVA): boolean;
begin
  Result := (RVA >= Self.RVA) and (RVA < Self.GetEndRVA);
end;

constructor TPESectionBase.Create(const ASecHdr: TImageSectionHeader; AMem: pointer;
  AMsg: PMsgMgr);
begin
  FMsg := AMsg;
  SetHeader(ASecHdr, AMem);
end;

destructor TPESectionBase.Destroy;
begin
  ClearData;
  inherited;
end;

function TPESectionBase.SaveToFile(const FileName: string): boolean;
var
  fs: TFileStream;
begin
  try
    fs := TFileStream.Create(FileName, fmCreate or fmShareDenyWrite);
    try
      fs.Write(Self.Mem^, Self.FVSize);
      Result := True;
    finally
      FreeAndNil(fs);
    end;
  except
    Result := false;
  end;
end;

procedure TPESectionBase.SetAllocatedSize(Value: uint32);
begin
  SetLength(FMem, Value);
end;

procedure TPESectionBase.SetHeader(ASecHdr: TImageSectionHeader; ASrcData: pointer;
  ChangeData: boolean);
var
  SizeToAlloc: uint32;
begin
  FName := ASecHdr.Name;
  FVSize := ASecHdr.VirtualSize;
  FRVA := ASecHdr.RVA;
  FRawSize := ASecHdr.SizeOfRawData;
  FRawOffset := ASecHdr.PointerToRawData;
  FFlags := ASecHdr.Flags;

  if ChangeData then
  begin
    SizeToAlloc := FVSize;

    if SizeToAlloc = 0 then
      raise Exception.Create('Section data size = 0.');

    // If no source mem specified, alloc empty block.
    // If have source mem, copy it.
    if ASrcData = nil then
    begin
      SetAllocatedSize(0);
      SetAllocatedSize(SizeToAlloc);
    end
    else
    begin
      SetAllocatedSize(SizeToAlloc);
      Move(ASrcData^, Mem^, SizeToAlloc);
    end;
  end;
end;

procedure TPESectionBase.ClearData;
begin
  SetAllocatedSize(0);
  FRawSize := 0;
  FRawOffset := 0;
end;

function TPESectionBase.GetEndRVA: TRVA;
begin
  Result := Self.RVA + Self.VirtualSize;
end;

function TPESectionBase.GetLastRVA: TRVA;
begin
  Result := Self.RVA + Self.VirtualSize - 1;
end;

function TPESectionBase.GetImageSectionHeader: TImageSectionHeader;
begin
  Result.Clear;
  Result.Name := FName;
  Result.RVA := RVA;
  Result.VirtualSize := VirtualSize;
  Result.SizeOfRawData := RawSize;
  Result.PointerToRawData := RawOffset;
  Result.Flags := Flags;
end;

function TPESectionBase.GetMemPtr: PByte;
begin
  Result := @FMem[0];
end;

function TPESectionBase.GetAllocatedSize: uint32;
begin
  Result := Length(FMem);
end;

function TPESectionBase.GetEndRawOffset: uint32;
begin
  Result := Self.FRawOffset + Self.FRawSize;
end;

function TPESectionBase.IsCode: boolean;
begin
  Result := (Flags and IMAGE_SCN_CNT_CODE) <> 0;
end;

function TPESectionBase.LoadDataFromStream(AStream: TStream): boolean;
begin
  Result := LoadDataFromStreamEx(AStream, FRawOffset, FRawSize);
end;

function TPESectionBase.LoadDataFromStreamEx(AStream: TStream;
  ARawOffset, ARawSize: uint32): boolean;
var
  cnt: uint32;
begin
  if (ARawOffset = 0) or (ARawSize = 0) then
    Exit(false); // Bad args.

  if not StreamSeek(AStream, ARawOffset) then
    Exit(false); // Can't find position in file.

  if ARawSize > GetAllocatedSize then
    ARawSize := GetAllocatedSize;

  cnt := AStream.Read(Mem^, ARawSize);
  if cnt = 0 then
  begin
    ClearData;
    if Assigned(FMsg) then
      FMsg.Write('Section %s has no raw data.', [FName]);
  end
  else if (cnt <> ARawSize) then
  begin
    if Assigned(FMsg) then
      FMsg.Write
        ('Section %s has less raw data than header declares: 0x%x instead of 0x%x.',
        [FName, cnt, ARawSize]);
    if Assigned(FMsg) then
      FMsg.Write('Actual raw size was loaded.');
  end;
  Exit(True);
end;

function TPESectionBase.NameAsHex: string;
var
  bytes: array [0 .. IMAGE_SIZEOF_SHORT_NAME - 1] of byte;
  i, len: integer;
begin
  fillchar(bytes[0], IMAGE_SIZEOF_SHORT_NAME, 0);
  len := Min(Length(name), IMAGE_SIZEOF_SHORT_NAME);
  if len > 0 then
    for i := 0 to len - 1 do
      bytes[i] := byte(name.Chars[i]);

  Result := format('%2.2x%2.2x%2.2x%2.2x%2.2x%2.2x%2.2x%2.2x', [
    bytes[0],
    bytes[1],
    bytes[2],
    bytes[3],
    bytes[4],
    bytes[5],
    bytes[6],
    bytes[7]
    ]);
end;

function TPESectionBase.SaveDataToStream(AStream: TStream): boolean;
begin
{$WARN COMPARING_SIGNED_UNSIGNED OFF}
  Result := false;
  if (FMem = nil) or (FRawSize = 0) then
  begin
    if Assigned(FMsg) then
      FMsg.Write('No data to save.');
    Exit;
  end;
  Result := AStream.Write(Mem^, FRawSize) = FRawSize;
{$WARN COMPARING_SIGNED_UNSIGNED ON}
end;

procedure TPESectionBase.Resize(NewSize: uint32);
begin
  FRawSize := NewSize;
  FVSize := NewSize;
  SetAllocatedSize(NewSize);
end;

end.
