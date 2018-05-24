unit PE.DataDirectories;

interface

uses
  System.Classes,
  System.SysUtils,

  PE.Common,
  PE.Msg,
  PE.Section,
  PE.Sections,
  PE.Types.Directories,
  PE.Utils;

type
  TDataDirectories = class
  private
    FPE: TObject; // TPEImage
    FItems: array of TImageDataDirectory;
    function GetCount: integer; inline;
    procedure SetCount(const Value: integer);
  public
    constructor Create(APE: TObject);

    procedure Clear;

    procedure NullInvalid(const Msg: TMsgMgr);

    // Load array of TImageDataDirectory (va,size) from stream.
    procedure LoadDirectoriesFromStream(
      Stream: TStream;
      const Msg: TMsgMgr;
      DeclaredCount: uint32; // # of rva and sizes
      MaxBytes: uint16
      );

    // Save array of TImageDataDirectory (va,size) to stream.
    // Return saved size.
    function SaveDirectoriesToStream(Stream: TStream): integer;

    // Check if index is in item range.
    function IsGoodIndex(Index: integer): boolean; inline;

    // Get TImageDataDirectory by Index.
    // Result is True if Index exists.
    // OutDir is optional and can be nil.
    function Get(Index: integer; OutDir: PImageDataDirectory): boolean;

    // Get directory name.
    function GetName(Index: integer): string;

    // Put directory safely. If Index > than current item count, empty items
    // will be added.
    procedure Put(Index: integer; const Dir: TImageDataDirectory); overload;

    procedure Put(Index: integer; RVA, Size: uint32); overload;

    // If Index exists set RVA and Size to 0.
    procedure Null(Index: integer);

    // Check if directory by Index occuppies whole section. If it's true,
    // result is section. Otherwise result is nil.
    function GetSectionDedicatedToDir(Index: integer;
      AlignSize: boolean = False): TPESection;

    // Get index of directory, which occupies whole Section. Result is -1 if
    // not found.
    function GetDirDedicatedToSection(Section: TPESection; AlignSize: boolean = False): integer;

    // Save data pointed by directory RVA and Size to file.
    // Index is directory index.
    function SaveToStream(Index: integer; Stream: TStream): boolean;
    function SaveToFile(Index: integer; const FileName: string): boolean;

    // Load data into memory pointed by directory RVA and Size.
    // Index is directory index.
    // Offset is file offset where to start reading from.
    // Result is True if complete size was read.
    function LoadFromStream(Index: integer; Stream: TStream; Offset: uint64): boolean;
    function LoadFromFile(Index: integer; const FileName: string; Offset: uint64): boolean;

    property Count: integer read GetCount write SetCount;
  end;

implementation

uses
  // Expand
  PE.Headers,
  PE.Image;

{ TDataDirectories }

procedure TDataDirectories.Clear;
begin
  FItems := nil;
  self.Count := 0;
end;

constructor TDataDirectories.Create(APE: TObject);
begin
  self.FPE := APE;
end;

function TDataDirectories.GetSectionDedicatedToDir(Index: integer;
  AlignSize: boolean): TPESection;
var
  Dir: TImageDataDirectory;
  sec: TPESection;
  ExpectedSize, VSize: uint32;
  img: TPEImage;
begin
  Result := nil;
  if not Get(Index, @Dir) then
    exit;
  if Dir.IsEmpty then
    exit;
  img := TPEImage(FPE);
  if not img.Sections.RVAToSec(Dir.VirtualAddress, @sec) then
    exit;
  if (sec.RVA <> Dir.VirtualAddress) then
    exit;
  if AlignSize then
  begin
    ExpectedSize := AlignUp(Dir.Size, img.SectionAlignment);
    VSize := AlignUp(sec.VirtualSize, img.SectionAlignment);
  end
  else
  begin
    ExpectedSize := Dir.Size;
    VSize := sec.VirtualSize;
  end;
  if (VSize = ExpectedSize) then
    Result := sec;
end;

function TDataDirectories.IsGoodIndex(Index: integer): boolean;
begin
  Result := (Index >= 0) and (Index < Length(FItems));
end;

function TDataDirectories.Get(Index: integer; OutDir: PImageDataDirectory): boolean;
begin
  Result := IsGoodIndex(Index);
  if Result and Assigned(OutDir) then
    OutDir^ := FItems[Index];
end;

procedure TDataDirectories.Put(Index: integer; const Dir: TImageDataDirectory);
begin
  if Index >= Length(FItems) then
    SetLength(FItems, Index + 1)
  else if Index < 0 then
    Index := 0;
  FItems[Index] := Dir;
end;

procedure TDataDirectories.Put(Index: integer; RVA, Size: uint32);
var
  d: TImageDataDirectory;
begin
  d.RVA := RVA;
  d.Size := Size;
  Put(Index, d);
end;

procedure TDataDirectories.Null(Index: integer);
begin
  if (Index >= 0) and (Index < Length(FItems)) then
    FItems[Index] := NULL_IMAGE_DATA_DIRECTORY;
end;

function TDataDirectories.GetCount: integer;
begin
  Result := Length(FItems);
end;

function TDataDirectories.GetDirDedicatedToSection(Section: TPESection; AlignSize: boolean = False): integer;
var
  i: integer;
begin
  for i := 0 to Length(FItems) - 1 do
  begin
    if GetSectionDedicatedToDir(i, AlignSize) = Section then
      exit(i);
  end;
  exit(-1);
end;

function TDataDirectories.GetName(Index: integer): string;
begin
  if IsGoodIndex(Index) then
    Result := GetDirectoryName(index)
  else
    Result := '';
end;

procedure TDataDirectories.NullInvalid(const Msg: TMsgMgr);
var
  i: integer;
  needToNullDir: boolean;
begin
  // Check RVAs.
  for i := 0 to self.Count - 1 do
  begin
    // Empty dir is ok.
    if FItems[i].IsEmpty then
      continue;

    needToNullDir := False;

    if (FItems[i].Size = 0) and (FItems[i].RVA <> 0) then
    begin
      Msg.Write(SCategoryDataDirecory, 'Directory # %d has size = 0.', [i]);
      needToNullDir := true;
    end
    else if not TPEImage(FPE).RVAExists(FItems[i].RVA) then
    begin
      Msg.Write(SCategoryDataDirecory, 'Directory # %d RVA is not in image.', [i]);
      needToNullDir := true;
    end;

    if needToNullDir and (PO_NULL_INVALID_DIRECTORY in TPEImage(FPE).Options) then
    begin
      FItems[i] := NULL_IMAGE_DATA_DIRECTORY;
      Msg.Write(SCategoryDataDirecory, 'Directory # %d nulled.', [i]);
    end;
  end;
end;

procedure TDataDirectories.LoadDirectoriesFromStream;
var
  MaxCountPossible: integer;
  CountToRead: integer;
  SizeToFileEnd: uint64;
  Size: uint32;
  MaxSizePossible: uint16;
begin
  Clear;

  if DeclaredCount = 0 then
  begin
    Msg.Write(SCategoryDataDirecory, 'No data directories.');
    exit;
  end;

  SizeToFileEnd := (Stream.Size - Stream.Position);

  // Max size available for dirs.
  if SizeToFileEnd > MaxBytes then
    MaxSizePossible := MaxBytes
  else
    MaxSizePossible := SizeToFileEnd;

  MaxCountPossible := MaxSizePossible div SizeOf(TImageDataDirectory);

  // File can have part of dword stored. It must be extended with zeros.
  if (MaxSizePossible mod SizeOf(TImageDataDirectory)) <> 0 then
    inc(MaxCountPossible);

  if DeclaredCount <> TYPICAL_NUMBER_OF_DIRECTORIES then
    Msg.Write(SCategoryDataDirecory, 'Non-usual count of directories declared (0x%x).', [DeclaredCount]);

  if DeclaredCount > MaxCountPossible then
  begin
    CountToRead := MaxCountPossible;

    Msg.Write(SCategoryDataDirecory,
      'Declared count of directories is greater than file can contain (0x%x > 0x%x).',
      [DeclaredCount, MaxCountPossible]);
    Msg.Write(SCategoryDataDirecory, 'Fall back to 0x%x.', [MaxCountPossible]);
  end
  else
  begin
    CountToRead := DeclaredCount;
  end;

  // Read data directories.

  Size := CountToRead * SizeOf(TImageDataDirectory);
  SetLength(FItems, CountToRead);

  // Must clear buffer, cause it can have partial values (filled with zeros).
  FillChar(FItems[0], Size, 0);

  // Not all readed size/rva can be valid. You must check rvas before use.
  Stream.Read(FItems[0], Size);

  // Set final count.
  self.Count := CountToRead;

  NullInvalid(Msg);
end;

function TDataDirectories.SaveToStream(Index: integer; Stream: TStream): boolean;
var
  Dir: TImageDataDirectory;
begin
  if Get(Index, @Dir) then
  begin
    TPEImage(FPE).SaveRegionToStream(Stream, Dir.VirtualAddress, Dir.Size);
    exit(true);
  end;
  exit(False);
end;

function TDataDirectories.SaveToFile(Index: integer; const FileName: string): boolean;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(FileName, fmCreate);
  try
    Result := SaveToStream(Index, fs);
  finally
    fs.Free;
  end;
end;

function TDataDirectories.LoadFromStream(Index: integer; Stream: TStream; Offset: uint64): boolean;
var
  Dir: TImageDataDirectory;
  ReadCount: uint32;
begin
  if Get(Index, @Dir) then
  begin
    TPEImage(FPE).LoadRegionFromStream(Stream, Offset, Dir.VirtualAddress, Dir.Size, @ReadCount);
    exit(ReadCount = Dir.Size);
  end;
  exit(False);
end;

function TDataDirectories.LoadFromFile(Index: integer; const FileName: string; Offset: uint64): boolean;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LoadFromStream(Index, fs, Offset);
  finally
    fs.Free;
  end;
end;

function TDataDirectories.SaveDirectoriesToStream(Stream: TStream): integer;
begin
  Result := Stream.Write(FItems[0], Length(FItems) * SizeOf(TImageDataDirectory))
end;

procedure TDataDirectories.SetCount(const Value: integer);
begin
  SetLength(FItems, Value);
  TPEImage(FPE).OptionalHeader.NumberOfRvaAndSizes := Value;
end;

end.
