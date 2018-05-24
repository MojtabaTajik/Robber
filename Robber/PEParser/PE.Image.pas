unit PE.Image;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,

  PE.Common,
  PE.Headers,
  PE.DataDirectories,

  PE.Msg,
  PE.Utils,

  PE.Image.Defaults,
  PE.Image.Saving,

  PE.Types,
  PE.Types.DOSHeader,
  PE.Types.Directories,
  PE.Types.FileHeader,
  PE.Types.NTHeaders,
  PE.Types.Sections,
  PE.Types.Relocations,
  PE.Types.Imports,
  PE.Types.Export,

  PE.ExportSym,

  PE.TLS,
  PE.Section,
  PE.Sections,
  PE.Imports,
  PE.Resources,

  PE.Parser.Headers,
  PE.Parser.Export,
  PE.Parser.Import,
  PE.Parser.ImportDelayed,
  PE.Parser.Relocs,
  PE.Parser.TLS,
  PE.Parser.Resources,

  PE.COFF,
  PE.COFF.Types,

  PE.MemoryStream,
  PE.ProcessModuleStream,

  PE.ParserCallbacks;

type

  { TPEImage }

  TPEImage = class
  private
    FImageKind: TPEImageKind;
    FParseStages: TParserFlags;
    FParseCallbacks: IPEParserCallbacks;
    FOptions: TParserOptions;

    // Used only for loading from mapped image. Nil for disk images.
    FPEMemoryStream: TPEMemoryStream;

    FFileName: string;
    FFileSize: UInt64;
    FDefaults: TPEDefaults;
    FImageBitSize: byte;  // 32/64
    FImageWordSize: byte; // 4/8

    FCOFF: TCOFF;

    FDosHeader: TImageDOSHeader; // DOS header.
    FLFANew: uint32;             // Address of new header next after DOS.
    FDosBlock: TBytes;           // Bytes between DOS header and next header.
    FSecHdrGap: TBytes;          // Gap after section headers.

    FFileHeader: TImageFileHeader;
    FOptionalHeader: TPEOptionalHeader;

    FSections: TPESections;
    FRelocs: TRelocs;
    FImports: TPEImport;        // of TPEImportFunction
    FImportsDelayed: TPEImport; // of TPEImportFunctionDelayed
    FExports: TPEExportSyms;
    FExportedName: String;
    FTLS: TTLS;
    FResourceTree: TResourceTree;
    FOverlay: TOverlay;

    FParsers: array [TParserFlag] of TPEParserClass;
    FMsg: TMsgMgr;
    FDataDirectories: TDataDirectories;
  private
    // Used for read/write.
    FCurrentSec: TPESection; // Current section.
    FPositionRVA: TRVA;      // Current RVA.
    FCurrentOfs: uint32;     // Current offset in section.

    procedure SetPositionRVA(const Value: TRVA);

    procedure SetPositionVA(const Value: TVA);
    function GetPositionVA: TVA;

    function ReadWrite(Buffer: Pointer; Count: cardinal; Read: boolean): uint32;
  private
    // Add new section to have range of addresses for image header.
    procedure LoadingAddHeaderAsASection(Stream: TStream);
  private

    { Notifiers }
    procedure DoReadError;

    { Parsers }
    procedure InitParsers;

    { Base loading }
    function LoadSectionHeaders(AStream: TStream): boolean;
    function LoadSectionData(AStream: TStream): UInt16;

    // Replace /%num% to name from COFF string table.
    procedure ResolveSectionNames;

    function GetImageBase: TRVA; inline;
    procedure SetImageBase(Value: TRVA); inline;

    function GetSizeOfImage: UInt64; inline;
    procedure SetSizeOfImage(Value: UInt64); inline;

    function EntryPointRVAGet: TRVA; inline;
    procedure EntryPointRVASet(Value: TRVA); inline;

    function FileAlignmentGet: uint32; inline;
    procedure FileAlignmentSet(const Value: uint32); inline;

    function SectionAlignmentGet: uint32; inline;
    procedure SectionAlignmentSet(const Value: uint32); inline;

    function GetFileHeader: PImageFileHeader; inline;
    function GetImageDOSHeader: PImageDOSHeader; inline;
    function GetOptionalHeader: PPEOptionalHeader; inline;

    function GetIsDll: boolean;
    procedure SetIsDll(const Value: boolean);

  protected

    // If image is disk-based, result is created TFileStream.
    // If it's memory mapped, result is opened memory stream.
    function SourceStreamGet(Mode: word): TStream;

    // If image is disk-based, stream is freed.
    // If it's memory mapped, nothing happens.
    procedure SourceStreamFree(Stream: TStream);

  public

    // Create without message proc.
    constructor Create(); overload;

    // Create with message proc.
    constructor Create(AMsgProc: TMsgProc); overload;

    destructor Destroy; override;

    // Check if stream at offset Ofs is MZ/PE image.
    // Result is False if either failed to make check or it's not valid image.
    class function IsPE(AStream: TStream; Ofs: UInt64 = 0): boolean; overload; static;

    // Check if file is PE.
    class function IsPE(const FileName: string): boolean; overload; static;

    // Check if image is 32/64 bit.
    function Is32bit: boolean; inline;
    function Is64bit: boolean; inline;

    // Get image bitness. 32/64 or 0 if unknown.
    function GetImageBits: UInt16; inline;
    procedure SetImageBits(Value: UInt16);

    { PE Streaming }

    // Seek RVA or VA and return True on success.
    function SeekRVA(RVA: TRVA): boolean;
    function SeekVA(VA: TVA): boolean;

    // Read Count bytes from current RVA/VA position to Buffer and
    // return number of bytes read.
    // It cannot read past end of section.
    function Read(Buffer: Pointer; Count: cardinal): uint32; overload;
    function Read(var Buffer; Count: cardinal): uint32; overload; inline;

    // Read Count bytes to Buffer and return True if all bytes were read.
    function ReadEx(Buffer: Pointer; Count: cardinal): boolean; overload; inline;
    function ReadEx(var Buffer; Size: cardinal): boolean; overload; inline;

    // Read 1/2/4/8-sized word.
    // If WordSize is 0 size native to image is used (4 for PE32, 8 for PE64).
    function ReadWord(WordSize: byte = 0): UInt64;

    // Try to read 1/2/4/8-sized word.
    // Result shows if all bytes are read.
    function ReadWordEx(WordSize: byte; OutValue: PUInt64): boolean;

    // Skip Count bytes.
    procedure Skip(Count: integer);

    // Read 1-byte 0-terminated string.
    function ReadAnsiString: String;

    // MaxLen: 0 - no limit
    function ReadAnsiStringLen(MaxLen: integer; out Len: integer; out Str: string): boolean;

    // Read 2-byte UTF-16 string with length prefix (2 bytes).
    function ReadUnicodeStringLenPfx2: String;

    // Reading values.
    // todo: these functions should be Endianness-aware.
    function ReadUInt8: UInt8; overload; inline;
    function ReadUInt16: UInt16; overload; inline;
    function ReadUInt32: uint32; overload; inline;
    function ReadUInt64: UInt64; overload; inline;
    function ReadUIntPE: UInt64; overload; inline; // 64/32 depending on PE format.

    function ReadUInt8(OutData: PUInt8): boolean; overload; inline;
    function ReadUInt16(OutData: PUInt16): boolean; overload; inline;
    function ReadUInt32(OutData: PUInt32): boolean; overload; inline;
    function ReadUInt64(OutData: PUInt64): boolean; overload; inline;
    function ReadUIntPE(OutData: PUInt64): boolean; overload; inline; // 64/32 depending on PE format.

    // Write Count bytes from Buffer to current position.
    function Write(Buffer: Pointer; Count: cardinal): uint32; overload;
    function Write(const Buffer; Count: cardinal): uint32; overload;

    function WriteEx(Buffer: Pointer; Count: cardinal): boolean; overload; inline;
    function WriteEx(const Buffer; Count: cardinal): boolean; overload; inline;

    { Address conversions }

    // Check if RVA exists.
    function RVAExists(RVA: TRVA): boolean;

    // Convert RVA to memory pointer.
    function RVAToMem(RVA: TRVA): Pointer;

    // Convert RVA to file offset. OutOfs can be nil.
    function RVAToOfs(RVA: TRVA; OutOfs: PDword): boolean;

    // Find Section by RVA. OutSec can be nil.
    function RVAToSec(RVA: TRVA; OutSec: PPESection): boolean;

    // Convert RVA to VA.
    function RVAToVA(RVA: TRVA): TVA; inline;

    // Check if VA exists.
    function VAExists(VA: TRVA): boolean;

    // Convert VA to memory pointer.
    function VAToMem(VA: TVA): Pointer; inline;

    // Convert VA to file offset. OutOfs can be nil.
    function VAToOfs(VA: TVA; OutOfs: PDword): boolean; inline;

    // Find Section by VA. OutSec can be nil.
    function VAToSec(VA: TRVA; OutSec: PPESection): boolean;

    // Convert VA to RVA.
    // Make sure VA is >= ImageBase.
    function VAToRVA(VA: TVA): TRVA; inline;

    // Check if RVA/VA belongs to image.
    function ContainsRVA(RVA: TRVA): boolean; inline;
    function ContainsVA(VA: TVA): boolean; inline;

    { Image }

    // Clear image.
    procedure Clear;

    // Calculate not aligned size of headers.
    function CalcHeadersSizeNotAligned: uint32; inline;

    // Calculate valid aligned size of image.
    function CalcVirtualSizeOfImage: UInt64; inline;

    // Calc raw size of image (w/o overlay), or 0 if failed.
    // Can be used if image loaded from stream and exact image size is unknown.
    // Though we still don't know overlay size.
    function CalcRawSizeOfImage: UInt64; inline;

    // Calc offset of section headers.
    function CalcSecHdrOfs: TFileOffset;

    // Calc offset of section headers end.
    function CalcSecHdrEndOfs: TFileOffset;

    // Calc size of optional header w/o directories.
    function CalcSizeOfPureOptionalHeader: uint32;

    // Set aligned SizeOfHeaders.
    procedure FixSizeOfHeaders; inline;

    // Set valid size of image.
    procedure FixSizeOfImage; inline;

    { Loading }

    // Load image from stream.
    function LoadFromStream(AStream: TStream;
      AParseStages: TParserFlags = DEFAULT_PARSER_FLAGS;
      ImageKind: TPEImageKind = PEIMAGE_KIND_DISK): boolean;

    // Load image from file.
    function LoadFromFile(const AFileName: string;
      AParseStages: TParserFlags = DEFAULT_PARSER_FLAGS): boolean;

    // Load PE image from image in memory of current process.
    // Won't help if image in memory has spoiled headers.
    function LoadFromMappedImage(const AFileName: string;
      AParseStages: TParserFlags = DEFAULT_PARSER_FLAGS): boolean; overload;
    function LoadFromMappedImage(ModuleBase: NativeUInt;
      AParseStages: TParserFlags = DEFAULT_PARSER_FLAGS): boolean; overload;

    // Load PE image from running process.
    // Address defines module to load.
    function LoadFromProcessImage(ProcessId: DWORD; Address: NativeUInt;
      AParseStages: TParserFlags = DEFAULT_PARSER_FLAGS): boolean;

    { Saving }

    // Save image to stream.
    function SaveToStream(AStream: TStream): boolean;

    // Save image to file.
    function SaveToFile(const AFileName: string): boolean;

    { Sections }

    // Get last section containing raw offset and size.
    // Get nil if no good section found.
    function GetLastSectionWithValidRawData: TPESection;

    { Overlay }

    // Get overlay record pointer.
    function GetOverlay: POverlay;

    // Save overlay to file. It can be either appended to existing file or new
    // file will be created.
    function SaveOverlayToFile(const AFileName: string; Append: boolean = false): boolean;

    // Remove overlay from current image file.
    function RemoveOverlay: boolean;

    // Set overlay for current image file from file data of AFileName file.
    // If Offset and Size are 0, then whole file is appended.
    function LoadOverlayFromFile(const AFileName: string;
      Offset: UInt64 = 0; Size: UInt64 = 0): boolean; overload;

    { Writing to external stream }

    // Write RVA to stream (32/64 bit sized depending on image).
    function StreamWriteRVA(AStream: TStream; RVA: TRVA): boolean;

    { Dump }

    // Save memory region to stream/file (in section boundary).
    // Result is number of bytes written.
    // If trying to save more bytes than section contains it will save until
    // section end.
    // AStream can be nil if you want just check how many bytes can be saved.
    // todo: maybe also add cross-section dumps.
    function SaveRegionToStream(AStream: TStream; RVA: TRVA; Size: uint32): uint32;
    function SaveRegionToFile(const AFileName: string; RVA: TRVA; Size: uint32): uint32;

    // Load data from Stream at Offset to memory. RVA and Size must define region
    // that completely fit into some section. If region is larger than file or
    // section it is truncated.
    // ReadSize is optional param to get number of bytes read.
    function LoadRegionFromStream(AStream: TStream; Offset: UInt64; RVA: TRVA; Size: uint32; ReadSize: PUInt32 = nil): boolean;
    function LoadRegionFromFile(const AFileName: string; Offset: UInt64; RVA: TRVA; Size: uint32; ReadSize: PUInt32 = nil): boolean;

    { Regions }

    procedure RegionRemove(RVA: TRVA; Size: uint32);

    // Check if region belongs to some section and has enough raw/virtual size.
    function RegionExistsRaw(RVA: TRVA; RawSize: uint32): boolean;
    function RegionExistsVirtual(RVA: TRVA; VirtSize: uint32): boolean;

    { Properties }

    property Msg: TMsgMgr read FMsg;

    property Defaults: TPEDefaults read FDefaults;

    property ImageBitSize: byte read FImageBitSize;
    property ImageWordSize: byte read FImageWordSize;

    property ParseCallbacks: IPEParserCallbacks read FParseCallbacks write FParseCallbacks;

    // Current read/write position.
    property PositionRVA: TRVA read FPositionRVA write SetPositionRVA;
    property PositionVA: TVA read GetPositionVA write SetPositionVA;

    property ImageKind: TPEImageKind read FImageKind;
    property FileName: string read FFileName;

    // Offset of NT headers, used building new image.
    property LFANew: uint32 read FLFANew write FLFANew;
    property DosBlock: TBytes read FDosBlock;
    property SecHdrGap: TBytes read FSecHdrGap;

    // Headers.
    property DOSHeader: PImageDOSHeader read GetImageDOSHeader;
    property FileHeader: PImageFileHeader read GetFileHeader;
    property OptionalHeader: PPEOptionalHeader read GetOptionalHeader;

    // Directories.
    property DataDirectories: TDataDirectories read FDataDirectories;

    // Image sections.
    property Sections: TPESections read FSections;

    // Relocations.
    property Relocs: TRelocs read FRelocs;

    // Import items.
    property Imports: TPEImport read FImports;
    property ImportsDelayed: TPEImport read FImportsDelayed;

    // Export items.
    property ExportSyms: TPEExportSyms read FExports;

    // Image exported name.
    property ExportedName: String read FExportedName write FExportedName;

    // Thread Local Storage items.
    property TLS: TTLS read FTLS;

    // Resource items.
    property ResourceTree: TResourceTree read FResourceTree;

    property ImageBase: TRVA read GetImageBase write SetImageBase;
    property SizeOfImage: UInt64 read GetSizeOfImage write SetSizeOfImage;

    // 32/64
    property ImageBits: UInt16 read GetImageBits write SetImageBits;

    property EntryPointRVA: TRVA read EntryPointRVAGet write EntryPointRVASet;
    property FileAlignment: uint32 read FileAlignmentGet write FileAlignmentSet;
    property SectionAlignment: uint32 read SectionAlignmentGet write SectionAlignmentSet;

    property IsDLL: boolean read GetIsDll write SetIsDll;

    property Options: TParserOptions read FOptions write FOptions;
  end;

implementation

const
  VM_PAGE_SIZE = $1000; // 4 KB page

  { TPEImage }

function TPEImage.EntryPointRVAGet: TRVA;
begin
  Result := FOptionalHeader.AddressOfEntryPoint;
end;

procedure TPEImage.EntryPointRVASet(Value: TRVA);
begin
  FOptionalHeader.AddressOfEntryPoint := Value;
end;

function TPEImage.GetImageBase: TRVA;
begin
  Result := FOptionalHeader.ImageBase;
end;

procedure TPEImage.SetImageBase(Value: TRVA);
begin
  FOptionalHeader.ImageBase := Value;
end;

function TPEImage.GetSizeOfImage: UInt64;
begin
  Result := FOptionalHeader.SizeOfImage;
end;

procedure TPEImage.SetSizeOfImage(Value: UInt64);
begin
  FOptionalHeader.SizeOfImage := Value;
end;

function TPEImage.StreamWriteRVA(AStream: TStream; RVA: TRVA): boolean;
var
  rva32: uint32;
  rva64: UInt64;
begin
  if Is32bit then
  begin
    rva32 := RVA;
    Result := AStream.Write(rva32, 4) = 4;
    exit;
  end;
  if Is64bit then
  begin
    rva64 := RVA;
    Result := AStream.Write(rva64, 8) = 8;
    exit;
  end;
  exit(false);
end;

constructor TPEImage.Create;
begin
  Create(nil);
end;

constructor TPEImage.Create(AMsgProc: TMsgProc);
begin
  FOptions := DEFAULT_OPTIONS;
  FMsg := TMsgMgr.Create(AMsgProc);
  FDefaults := TPEDefaults.Create(self);

  FDataDirectories := TDataDirectories.Create(self);

  FSections := TPESections.Create(self);

  FRelocs := TRelocs.Create;

  FImports := TPEImport.Create;
  FImportsDelayed := TPEImport.Create;

  FExports := TPEExportSyms.Create;

  FTLS := TTLS.Create;

  FResourceTree := TResourceTree.Create;

  FCOFF := TCOFF.Create(self);

  InitParsers;

  FDefaults.SetAll;
end;

procedure TPEImage.Clear;
begin
  if FImageKind = PEIMAGE_KIND_MEMORY then
    raise Exception.Create('Can''t clear mapped in-memory image.');

  FLFANew := 0;
  SetLength(FDosBlock, 0);
  SetLength(FSecHdrGap, 0);

  FCOFF.Clear;
  FDataDirectories.Clear;
  FSections.Clear;
  FImports.Clear;
  FImportsDelayed.Clear;
  FExports.Clear;
  FTLS.Clear;
  FResourceTree.Clear;
end;

function TPEImage.ContainsRVA(RVA: TRVA): boolean;
begin
  if FSections.Count = 0 then
    raise Exception.Create('Image contains no sections.');
  Result := (RVA >= FSections.First.RVA) and (RVA < FSections.Last.GetEndRVA);
end;

function TPEImage.ContainsVA(VA: TVA): boolean;
begin
  Result := (VA >= ImageBase) and ContainsRVA(VAToRVA(VA));
end;

destructor TPEImage.Destroy;
begin
  FPEMemoryStream.Free;
  FResourceTree.Free;
  FTLS.Free;
  FExports.Free;
  FImports.Free;
  FImportsDelayed.Free;
  FRelocs.Free;
  FSections.Free;
  FDataDirectories.Free;
  FCOFF.Free;
  inherited Destroy;
end;

procedure TPEImage.DoReadError;
begin
  raise Exception.Create('Read Error.');
end;

function TPEImage.SaveRegionToStream(AStream: TStream; RVA: TRVA; Size: uint32): uint32;
const
  BUFSIZE = 8192;
var
  Sec: TPESection;
  Ofs, TmpSize: uint32;
  pCur: PByte;
begin
  if not RVAToSec(RVA, @Sec) then
    exit(0);

  Ofs := RVA - Sec.RVA; // offset to read from

  // If end position is over section end then override size to read until end
  // of section.
  if Ofs + Size > Sec.GetAllocatedSize then
    Size := Sec.GetAllocatedSize - Ofs;

  Result := Size;

  if Assigned(AStream) then
  begin
    pCur := Sec.Mem + Ofs; // memory to read from

    while Size <> 0 do
    begin
      if Size >= BUFSIZE then
        TmpSize := BUFSIZE
      else
        TmpSize := Size;
      AStream.Write(pCur^, TmpSize);
      inc(pCur, TmpSize);
      dec(Size, TmpSize);
    end;
  end;
end;

function TPEImage.SaveRegionToFile(const AFileName: string; RVA: TRVA; Size: uint32): uint32;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmCreate);
  try
    Result := SaveRegionToStream(fs, RVA, Size);
  finally
    fs.Free;
  end;
end;

function TPEImage.LoadRegionFromStream(AStream: TStream; Offset: UInt64; RVA: TRVA; Size: uint32; ReadSize: PUInt32): boolean;
var
  Sec: TPESection;
  p: PByte;
  ActualSize: uint32;
begin
  if Size = 0 then
    exit(true);
  if Offset >= AStream.Size then
    exit(false);
  if (Offset + Size) > AStream.Size then
    Size := AStream.Size - Offset;
  if not RVAToSec(RVA, @Sec) then
    exit(false);
  if (RVA + Size) > Sec.GetEndRVA then
    Size := Sec.GetEndRVA - RVA;

  AStream.Position := Offset;

  p := Sec.Mem + (RVA - Sec.RVA);
  ActualSize := AStream.Read(p^, Size);

  if Assigned(ReadSize) then
    ReadSize^ := ActualSize;

  exit(true);
end;

function TPEImage.LoadRegionFromFile(const AFileName: string; Offset: UInt64; RVA: TRVA; Size: uint32; ReadSize: PUInt32): boolean;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LoadRegionFromStream(fs, Offset, RVA, Size, ReadSize);
  finally
    fs.Free;
  end;
end;

procedure TPEImage.InitParsers;
begin
  FParsers[PF_EXPORT] := TPEExportParser;
  FParsers[PF_IMPORT] := TPEImportParser;
  FParsers[PF_IMPORT_DELAYED] := TPEImportDelayedParser;
  FParsers[PF_RELOCS] := TPERelocParser;
  FParsers[PF_TLS] := TPETLSParser;
  FParsers[PF_RESOURCES] := TPEResourcesParser;
end;

function TPEImage.CalcHeadersSizeNotAligned: uint32;
begin
  Result := CalcSecHdrEndOfs;
end;

procedure TPEImage.FixSizeOfHeaders;
begin
  FOptionalHeader.SizeOfHeaders :=
    AlignUp(CalcHeadersSizeNotAligned, FileAlignment);
end;

function TPEImage.CalcVirtualSizeOfImage: UInt64;
begin
  with FSections do
  begin
    if Count <> 0 then
      Result := AlignUp(Last.RVA + Last.VirtualSize, SectionAlignment)
    else
      Result := AlignUp(CalcHeadersSizeNotAligned, SectionAlignment);
  end;
end;

function TPEImage.CalcRawSizeOfImage: UInt64;
var
  Last: TPESection;
begin
  Last := GetLastSectionWithValidRawData;
  if (Last <> nil) then
    Result := Last.GetEndRawOffset
  else
    Result := 0;
end;

procedure TPEImage.FixSizeOfImage;
begin
  SizeOfImage := CalcVirtualSizeOfImage;
end;

function TPEImage.CalcSecHdrOfs: TFileOffset;
var
  SizeOfPureOptionalHeader: uint32;
begin
  SizeOfPureOptionalHeader := CalcSizeOfPureOptionalHeader();
  Result :=
    FLFANew +
    4 +
    SizeOf(TImageFileHeader) +
    SizeOfPureOptionalHeader +
    FDataDirectories.Count * SizeOf(TImageDataDirectory);
end;

function TPEImage.CalcSecHdrEndOfs: TFileOffset;
begin
  Result := CalcSecHdrOfs + FSections.Count * SizeOf(TImageSectionHeader);
end;

function TPEImage.CalcSizeOfPureOptionalHeader: uint32;
begin
  Result := FOptionalHeader.CalcSize(ImageBits);
end;

function TPEImage.GetFileHeader: PImageFileHeader;
begin
  Result := @self.FFileHeader;
end;

function TPEImage.LoadSectionHeaders(AStream: TStream): boolean;
var
  Sec: TPESection;
  i: integer;
  sh: TImageSectionHeader;
  NumberOfSections: UInt16;
  SizeOfHeader, SizeOfHeaderMapped: uint32;
  HeaderList: TList<TImageSectionHeader>;
  VSizeToBeMapped: uint32;
  CorrectRawDataPositions: integer;
  StreamSize: UInt64;
  SecNameOldHex: string;
begin
  NumberOfSections := FFileHeader.NumberOfSections;

  // Header comes from offset: 0 to SizeOfHeader
  SizeOfHeader := CalcHeadersSizeNotAligned;
  SizeOfHeaderMapped := AlignUp(SizeOfHeader, VM_PAGE_SIZE);

  FSections.Clear; // it clears FFileHeader.NumberOfSections

  if NumberOfSections = 0 then
  begin
    Msg.Write(SCategorySections, 'There are no sections in the image');
    exit(true);
  end;

  HeaderList := TList<TImageSectionHeader>.Create;
  try
    // -------------------------------------------------------------------------
    // Load section headers.
    CorrectRawDataPositions := 0;
    StreamSize := AStream.Size;
    for i := 1 to NumberOfSections do
    begin
      if not StreamRead(AStream, sh, SizeOf(sh)) then
        break;

      if (sh.SizeOfRawData = 0) or (sh.PointerToRawData < AStream.Size) then
      begin
        inc(CorrectRawDataPositions);
        HeaderList.Add(sh);
      end
      else
        Msg.Write(SCategorySections, 'Raw data is outside of stream (0x%x>0x%x). Skipped.', [sh.PointerToRawData, StreamSize]);
    end;

    if CorrectRawDataPositions = 0 then
    begin
      Msg.Write(SCategorySections, 'No good raw data positions found.');
      exit(false);
    end
    else if CorrectRawDataPositions <> NumberOfSections then
    begin
      Msg.Write(SCategorySections, '%d of %d sections contain correct raw data positions.', [CorrectRawDataPositions, NumberOfSections]);
    end;

    // -------------------------------------------------------------------------
    // Check section count.
    if HeaderList.Count <> NumberOfSections then
      FMsg.Write(SCategorySections, 'Found %d of %d section headers.', [HeaderList.Count, NumberOfSections]);

    // -------------------------------------------------------------------------
    for i := 0 to HeaderList.Count - 1 do
    begin
      sh := HeaderList[i];

      if sh.SizeOfRawData <> 0 then
      begin
        // If section data points into header.
        if (sh.PointerToRawData < SizeOfHeader) then
        begin
          Msg.Write(SCategorySections, 'Section # %d is inside of headers', [i]);

          // Headers are always loaded at image base with
          // RawSize = SizeOfHeaders
          // VirtualSize = SizeOfHeaderMapped

          // Override section header.
          sh.PointerToRawData := 0;
          sh.SizeOfRawData := Min(sh.SizeOfRawData, FFileSize, SizeOfHeaderMapped);
          sh.VirtualSize := SizeOfHeaderMapped;
        end;
      end;

      if (sh.VirtualSize = 0) and (sh.SizeOfRawData = 0) then
      begin
        Msg.Write(SCategorySections, 'Section # %d has vsize and rsize = 0, skipping it', [i]);
        continue;
      end;

      if (sh.SizeOfRawData > sh.VirtualSize) then
      begin
        // Correct virtual size to be sure all raw data will be loaded.
        VSizeToBeMapped := AlignUp(sh.VirtualSize, VM_PAGE_SIZE);
        sh.VirtualSize := PE.Utils.Min(sh.SizeOfRawData, VSizeToBeMapped);
      end;

      {
        * Raw size can be 0
        * Virtual size can't be 0 as it won't be mapped
      }

      if sh.VirtualSize = 0 then
      begin
        Msg.Write(SCategorySections, 'Section # %d has vsize = 0', [i]);
        if PO_SECTION_VSIZE_FALLBACK in FOptions then
        begin
          sh.VirtualSize := AlignUp(sh.SizeOfRawData, SectionAlignment);
        end
        else
        begin
          Msg.Write(SCategorySections, 'Option to fallback to RSize isn''t included, skipping');
          continue;
        end;
      end;

      Sec := TPESection.Create(sh, nil, @FMsg);

      if Sec.Name.IsEmpty or (not IsAlphaNumericString(Sec.Name)) then
      begin
        if PO_SECTION_AUTORENAME_NON_ALPHANUMERIC in FOptions then
        begin
          SecNameOldHex := Sec.NameAsHex;
          Sec.Name := format('sec_%4.4x', [i]);
          Msg.Write(SCategorySections, 'Section name can be garbage (hex: %s). Overriding to %s', [SecNameOldHex, Sec.Name]);
        end;
      end;

      FSections.Add(Sec); // changes FFileHeader.NumberOfSections
    end;
  finally
    HeaderList.Free;
  end;

  exit(true);
end;

function TPEImage.LoadSectionData(AStream: TStream): UInt16;
var
  i: integer;
  Sec: TPESection;
begin
  Result := 0;
  // todo: check if section overlaps existing sections.
  for i := 0 to FSections.Count - 1 do
  begin
    Sec := FSections[i];

    // Process only normal sections.
    // Section like "image header" is skipped.
    if Sec.ClassType = TPESection then
    begin
      if FImageKind = PEIMAGE_KIND_DISK then
      begin
        if Sec.LoadDataFromStream(AStream) then
          inc(Result);
      end
      else
      begin
        if Sec.LoadDataFromStreamEx(AStream, Sec.RVA, Sec.VirtualSize) then
          inc(Result);
      end;
    end;
  end;
end;

procedure TPEImage.ResolveSectionNames;
var
  StringOfs, err: integer;
  Sec: TPESection;
  t: string;
begin
  for Sec in FSections do
  begin
    if Sec.Name.StartsWith('/') then
    begin
      val(Sec.Name.Substring(1), StringOfs, err);
      if (err = 0) and (FCOFF.GetString(StringOfs, t)) and (not t.IsEmpty) then
        Sec.Name := t; // long name from COFF strings
    end;
  end;
end;

function TPEImage.Is32bit: boolean;
begin
  Result := FOptionalHeader.Magic = PE_MAGIC_PE32;
end;

function TPEImage.Is64bit: boolean;
begin
  Result := FOptionalHeader.Magic = PE_MAGIC_PE32PLUS;
end;

class function TPEImage.IsPE(const FileName: string): boolean;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := TPEImage.IsPE(Stream);
  finally
    Stream.Free;
  end;
end;

class function TPEImage.IsPE(AStream: TStream; Ofs: UInt64): boolean;
var
  dos: TImageDOSHeader;
  peSig: TNTSignature;
begin
  if not StreamSeek(AStream, Ofs) then
    exit(false);

  if StreamRead(AStream, dos, SizeOf(dos)) then
    if dos.e_magic.IsMZ then
    begin
      Ofs := Ofs + dos.e_lfanew;
      if Ofs >= AStream.Size then
        exit(false);
      if StreamSeek(AStream, Ofs) then
        if StreamRead(AStream, peSig, SizeOf(peSig)) then
          exit(peSig.IsPE00);
    end;
  exit(false);
end;

function TPEImage.GetImageBits: UInt16;
begin
  Result := FImageBitSize;
end;

function TPEImage.GetImageDOSHeader: PImageDOSHeader;
begin
  Result := @self.FDosHeader;
end;

procedure TPEImage.SetImageBits(Value: UInt16);
begin
  case Value of
    32:
      FOptionalHeader.Magic := PE_MAGIC_PE32;
    64:
      FOptionalHeader.Magic := PE_MAGIC_PE32PLUS;
  else
    begin
      FOptionalHeader.Magic := 0;
      raise Exception.Create('Value unsupported.');
    end;
  end;
  FImageBitSize := Value;
  FImageWordSize := Value div 8;
end;

procedure TPEImage.SetPositionRVA(const Value: TRVA);
begin
  if not SeekRVA(Value) then
    raise Exception.CreateFmt('Invalid RVA position (0x%x)', [Value]);
end;

procedure TPEImage.SetPositionVA(const Value: TVA);
begin
  SetPositionRVA(VAToRVA(Value));
end;

function TPEImage.GetPositionVA: TVA;
begin
  Result := RVAToVA(FPositionRVA);
end;

function TPEImage.GetIsDll: boolean;
begin
  Result := (FFileHeader.Characteristics and IMAGE_FILE_DLL) <> 0;
end;

procedure TPEImage.SetIsDll(const Value: boolean);
begin
  if Value then
    FFileHeader.Characteristics := FFileHeader.Characteristics or IMAGE_FILE_DLL
  else
    FFileHeader.Characteristics := FFileHeader.Characteristics and (not IMAGE_FILE_DLL);
end;

function TPEImage.FileAlignmentGet: uint32;
begin
  Result := FOptionalHeader.FileAlignment;
end;

procedure TPEImage.FileAlignmentSet(const Value: uint32);
begin
  FOptionalHeader.FileAlignment := Value;
end;

function TPEImage.SectionAlignmentGet: uint32;
begin
  Result := FOptionalHeader.SectionAlignment;
end;

procedure TPEImage.SectionAlignmentSet(const Value: uint32);
begin
  FOptionalHeader.SectionAlignment := Value;
end;

function TPEImage.SeekRVA(RVA: TRVA): boolean;
begin
  // Section.
  if not RVAToSec(RVA, @FCurrentSec) then
    exit(false);

  // RVA/Offset.
  FPositionRVA := RVA;
  FCurrentOfs := FPositionRVA - FCurrentSec.RVA;

  exit(true);
end;

function TPEImage.SeekVA(VA: TVA): boolean;
begin
  Result := (VA >= ImageBase) and SeekRVA(VAToRVA(VA));
end;

procedure TPEImage.Skip(Count: integer);
begin
  inc(FPositionRVA, Count);
end;

procedure TPEImage.SourceStreamFree(Stream: TStream);
begin
  if FImageKind = PEIMAGE_KIND_DISK then
    Stream.Free;
end;

function TPEImage.SourceStreamGet(Mode: word): TStream;
begin
  if FImageKind = PEIMAGE_KIND_DISK then
    Result := TFileStream.Create(FFileName, Mode)
  else
    Result := FPEMemoryStream;
end;

function TPEImage.ReadWord(WordSize: byte): UInt64;
begin
  if not ReadWordEx(WordSize, @Result) then
    raise Exception.Create('Read error');
end;

function TPEImage.ReadWordEx(WordSize: byte; OutValue: PUInt64): boolean;
var
  tmp: UInt64;
begin
  case WordSize of
    0:
      WordSize := FImageWordSize;
    1, 2, 4, 8:
      ; // allowed size
  else
    raise Exception.Create('Unsupported word size for ReadWord');
  end;

  tmp := 0;
  Result := ReadEx(tmp, WordSize);

  if Assigned(OutValue) then
    OutValue^ := tmp;
end;

procedure TPEImage.RegionRemove(RVA: TRVA; Size: uint32);
begin
  // Currently it's just placeholder.
  // Mark memory as free.
  FSections.FillMemory(RVA, Size, $CC);
end;

function TPEImage.RegionExistsRaw(RVA: TRVA; RawSize: uint32): boolean;
var
  Sec: TPESection;
  Ofs: uint32;
begin
  if not RVAToSec(RVA, @Sec) then
    exit(false);
  Ofs := RVA - Sec.RVA;
  Result := Ofs + RawSize <= Sec.RawSize;
end;

function TPEImage.RegionExistsVirtual(RVA: TRVA; VirtSize: uint32): boolean;
var
  Sec: TPESection;
  Ofs: uint32;
begin
  if not RVAToSec(RVA, @Sec) then
    exit(false);
  Ofs := RVA - Sec.RVA;
  Result := Ofs + VirtSize <= Sec.VirtualSize;
end;

function TPEImage.ReadWrite(Buffer: Pointer; Count: cardinal; Read: boolean): uint32;
begin
  // If count is 0 or no valid position was set we cannot do anything.
  if (Count = 0) or (not Assigned(FCurrentSec)) then
    exit(0);

  // Check how many bytes we can process.
  Result := Min(Count, FCurrentSec.AllocatedSize - FCurrentOfs);
  if Result = 0 then
    exit;

  if Assigned(Buffer) then
  begin
    if Read then
      Move(FCurrentSec.Mem[FCurrentOfs], Buffer^, Result)
    else
      Move(Buffer^, FCurrentSec.Mem[FCurrentOfs], Result);
  end;

  // Move next.
  inc(FPositionRVA, Result);
  inc(FCurrentOfs, Result);
end;

function TPEImage.Read(Buffer: Pointer; Count: cardinal): uint32;
begin
  Result := ReadWrite(Buffer, Count, true);
end;

function TPEImage.Read(var Buffer; Count: cardinal): uint32;
begin
  Result := Read(@Buffer, Count);
end;

function TPEImage.ReadEx(Buffer: Pointer; Count: cardinal): boolean;
begin
  Result := Read(Buffer, Count) = Count;
end;

function TPEImage.ReadEx(var Buffer; Size: cardinal): boolean;
begin
  Result := ReadEx(@Buffer, Size);
end;

function TPEImage.ReadAnsiString: string;
var
  Len: integer;
begin
  if not ReadAnsiStringLen(0, Len, Result) then
    Result := '';
end;

function TPEImage.ReadAnsiStringLen(MaxLen: integer; out Len: integer; out Str: string): boolean;
var
  available: uint32;
  pBegin, pCur, pEnd: PAnsiChar;
begin
  Len := 0;
  Str := '';
  Result := false;

  if not Assigned(FCurrentSec) then
    exit;

  available := FCurrentSec.AllocatedSize - FCurrentOfs;

  if (MaxLen <> 0) and (MaxLen < available) then
    available := MaxLen;

  pBegin := @FCurrentSec.Mem[FCurrentOfs];
  pCur := pBegin;
  pEnd := pBegin + available;
  while pCur < pEnd do
  begin
    if pCur^ = #0 then
    begin
      Result := true;
      break;
    end;
    inc(pCur);
  end;

  Len := pCur - pBegin;

  if Result then
  begin
    // String.
    Str := string(pBegin);

    // Include null at end.
    inc(Len);

    // Move current position.
    inc(FPositionRVA, Len);
    inc(FCurrentOfs, Len);
  end;
end;

function TPEImage.ReadUnicodeStringLenPfx2: string;
var
  Size: uint32;
  Bytes: TBytes;
begin
  // Check if there is at least 2 bytes for length.
  if Assigned(FCurrentSec) and (FCurrentOfs + 2 <= FCurrentSec.AllocatedSize) then
  begin
    Size := ReadUInt16 * 2;
    if Size <> 0 then
    begin
      // Check if there is enough space to read string.
      if FCurrentOfs + Size <= FCurrentSec.AllocatedSize then
      begin
        SetLength(Bytes, Size);
        Read(Bytes[0], Size);
        Result := TEncoding.Unicode.GetString(Bytes);
        exit;
      end;
    end;
  end;
  exit('');
end;

function TPEImage.ReadUInt8: UInt8;
begin
  if not ReadUInt8(@Result) then
    DoReadError;
end;

function TPEImage.ReadUInt16: UInt16;
begin
  if not ReadUInt16(@Result) then
    DoReadError;
end;

function TPEImage.ReadUInt32: uint32;
begin
  if not ReadUInt32(@Result) then
    DoReadError;
end;

function TPEImage.ReadUInt64: UInt64;
begin
  if not ReadUInt64(@Result) then
    DoReadError;
end;

function TPEImage.ReadUIntPE: UInt64;
begin
  if not ReadUIntPE(@Result) then
    DoReadError;
end;

function TPEImage.ReadUInt8(OutData: PUInt8): boolean;
begin
  Result := ReadEx(OutData, 1);
end;

function TPEImage.ReadUInt16(OutData: PUInt16): boolean;
begin
  Result := ReadEx(OutData, 2);
end;

function TPEImage.ReadUInt32(OutData: PUInt32): boolean;
begin
  Result := ReadEx(OutData, 4);
end;

function TPEImage.ReadUInt64(OutData: PUInt64): boolean;
begin
  Result := ReadEx(OutData, 8);
end;

function TPEImage.ReadUIntPE(OutData: PUInt64): boolean;
begin
  if OutData <> nil then
    OutData^ := 0;

  case ImageBits of
    32:
      Result := ReadEx(OutData, 4);
    64:
      Result := ReadEx(OutData, 8);
  else
    begin
      DoReadError;
      Result := false; // compiler friendly
    end;
  end;
end;

function TPEImage.Write(Buffer: Pointer; Count: cardinal): uint32;
begin
  Result := ReadWrite(Buffer, Count, false);
end;

function TPEImage.Write(const Buffer; Count: cardinal): uint32;
begin
  Result := Write(@Buffer, Count);
end;

function TPEImage.WriteEx(Buffer: Pointer; Count: cardinal): boolean;
begin
  Result := Write(Buffer, Count) = Count;
end;

function TPEImage.WriteEx(const Buffer; Count: cardinal): boolean;
begin
  Result := Write(@Buffer, Count) = Count;
end;

function TPEImage.RVAToMem(RVA: TRVA): Pointer;
var
  Ofs: integer;
  s: TPESection;
begin
  if RVAToSec(RVA, @s) and (s.Mem <> nil) then
  begin
    Ofs := RVA - s.RVA;
    exit(@s.Mem[Ofs]);
  end;
  exit(nil);
end;

function TPEImage.RVAExists(RVA: TRVA): boolean;
begin
  Result := RVAToSec(RVA, nil);
end;

function TPEImage.RVAToOfs(RVA: TRVA; OutOfs: PDword): boolean;
begin
  Result := FSections.RVAToOfs(RVA, OutOfs);
end;

function TPEImage.RVAToSec(RVA: TRVA; OutSec: PPESection): boolean;
begin
  Result := FSections.RVAToSec(RVA, OutSec);
end;

function TPEImage.RVAToVA(RVA: TRVA): UInt64;
begin
  Result := RVA + FOptionalHeader.ImageBase;
end;

function TPEImage.VAExists(VA: TRVA): boolean;
begin
  Result := (VA >= ImageBase) and RVAToSec(VAToRVA(VA), nil);
end;

function TPEImage.VAToMem(VA: TVA): Pointer;
begin
  Result := RVAToMem(VAToRVA(VA));
end;

function TPEImage.VAToOfs(VA: TVA; OutOfs: PDword): boolean;
begin
  Result := (VA >= ImageBase) and RVAToOfs(VAToRVA(VA), OutOfs);
end;

function TPEImage.VAToSec(VA: TRVA; OutSec: PPESection): boolean;
begin
  Result := (VA >= ImageBase) and RVAToSec(VAToRVA(VA), OutSec);
end;

function TPEImage.VAToRVA(VA: TVA): TRVA;
begin
  if VA >= FOptionalHeader.ImageBase then
    Result := VA - FOptionalHeader.ImageBase
  else
    raise Exception.Create('VAToRVA: VA argument must be >= ImageBase.');
end;

function TPEImage.LoadFromFile(const AFileName: string;
  AParseStages: TParserFlags): boolean;
var
  fs: TFileStream;
begin
  if not FileExists(AFileName) then
  begin
    FMsg.Write(SCategoryLoadFromFile, 'File not found.');
    exit(false);
  end;

  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    FFileName := AFileName;
    fs.Position := 0;
    Result := LoadFromStream(fs, AParseStages);
  finally
    fs.Free;
  end;
end;

function TPEImage.LoadFromMappedImage(const AFileName: string;
  AParseStages: TParserFlags): boolean;
begin
  FPEMemoryStream := TPEMemoryStream.Create(AFileName);
  Result := LoadFromStream(FPEMemoryStream, AParseStages, PEIMAGE_KIND_MEMORY);
end;

function TPEImage.LoadFromMappedImage(ModuleBase: NativeUInt;
  AParseStages: TParserFlags): boolean;
begin
  FPEMemoryStream := TPEMemoryStream.Create(ModuleBase);
  Result := LoadFromStream(FPEMemoryStream, AParseStages, PEIMAGE_KIND_MEMORY);
end;

function TPEImage.LoadFromProcessImage(ProcessId: DWORD; Address: NativeUInt;
  AParseStages: TParserFlags): boolean;
var
  Stream: TProcessModuleStream;
begin
  Stream := TProcessModuleStream.CreateFromPidAndAddress(ProcessId, Address);
  try
    Result := LoadFromStream(Stream, AParseStages, PEIMAGE_KIND_MEMORY);
  finally
    Stream.Free;
  end;
end;

function TPEImage.LoadFromStream(AStream: TStream; AParseStages: TParserFlags;
  ImageKind: TPEImageKind): boolean;
const
  PE_HEADER_ALIGN = 4;
var
  OptHdrOfs, DataDirOfs, SecHdrOfs, SecHdrEndOfs, SecDataOfs: TFileOffset;
  SecHdrGapSize: integer;
  OptHdrSizeRead: int32; // w/o directories
  Stage: TParserFlag;
  Parser: TPEParser;
  Signature: TNTSignature;
  DOSBlockSize: uint32;
begin
  Result := false;

  FImageKind := ImageKind;
  FFileSize := AStream.Size;
  FParseStages := AParseStages;

  // DOS header.
  if not LoadDosHeader(AStream, FDosHeader) then
  begin
    Msg.Write(SCategoryDOSHeader, 'No DOS header found.');
    exit;
  end;

  if (FDosHeader.e_lfanew = 0) then
  begin
    Msg.Write(SCategoryDOSHeader, 'This is probably 16-bit executable.');
    exit;
  end;

  // Check PE ofs < 256 MB (see RtlImageNtHeaderEx)
  if (FDosHeader.e_lfanew >= 256 * 1024 * 1024) then
  begin
    Msg.Write(SCategoryDOSHeader, 'e_lfanew >= 256 MB');
    exit;
  end;

  if (FDosHeader.e_lfanew mod PE_HEADER_ALIGN) <> 0 then
  begin
    Msg.Write(SCategoryDOSHeader, 'PE header is not properly aligned.');
    exit;
  end;

  if (FDosHeader.e_lfanew < SizeOf(TImageDOSHeader)) then
  begin
    Msg.Write(SCategoryDOSHeader, 'e_lfanew points into itself (0x%x)', [FDosHeader.e_lfanew]);
  end;

  // Check if e_lfanew is ok
  if not StreamSeek(AStream, FDosHeader.e_lfanew) then
    exit; // e_lfanew is wrong

  // @ e_lfanew

  // Store offset of NT headers.
  FLFANew := FDosHeader.e_lfanew;

  // Read DOS Block
  self.FDosBlock := nil;
  if FDosHeader.e_lfanew > SizeOf(FDosHeader) then
  begin
    DOSBlockSize := FDosHeader.e_lfanew - SizeOf(FDosHeader);
    SetLength(self.FDosBlock, DOSBlockSize);
    if (DOSBlockSize <> 0) then
      if StreamSeek(AStream, SizeOf(FDosHeader)) then
      begin
        if not StreamRead(AStream, self.FDosBlock[0], DOSBlockSize) then
          SetLength(self.FDosBlock, 0);
      end;
  end;

  // Go back to new header.
  if not StreamSeek(AStream, FDosHeader.e_lfanew) then
    exit; // e_lfanew is wrong

  // Load signature.
  if not StreamRead(AStream, Signature, SizeOf(Signature)) then
    exit;

  // Check signature.
  if not Signature.IsPE00 then
    exit; // not PE file

  // Load File Header.
  if not LoadFileHeader(AStream, FFileHeader) then
    exit; // File Header failed.

  // Get offsets of Optional Header and Section Headers.
  OptHdrOfs := AStream.Position;
  SecHdrOfs := OptHdrOfs + FFileHeader.SizeOfOptionalHeader;
  SecHdrEndOfs := SecHdrOfs + SizeOf(TImageSectionHeader) * FFileHeader.NumberOfSections;

  // Read opt.hdr. magic to know if image is 32 or 64 bit.
  AStream.Position := OptHdrOfs;
  if not StreamPeek(AStream, FOptionalHeader.Magic, SizeOf(FOptionalHeader.Magic)) then
    exit;

  // Set some helper fields.
  case FOptionalHeader.Magic of
    PE_MAGIC_PE32:
      begin
        FImageBitSize := 32;
        FImageWordSize := 4;
      end;
    PE_MAGIC_PE32PLUS:
      begin
        FImageBitSize := 64;
        FImageWordSize := 8;
      end
  else
    raise Exception.Create('Image type is unknown.');
  end;

  // Safe read optional header.
  OptHdrSizeRead := FOptionalHeader.ReadFromStream(AStream, FImageBitSize, -1);

  // Can't read more bytes then available.
  if OptHdrSizeRead > FFileHeader.SizeOfOptionalHeader then
    raise Exception.Create('Read size of opt. header > FileHeader.SizeOfOptionalHeader');

  DataDirOfs := AStream.Position;

  // Load Section Headers.
  AStream.Position := SecHdrOfs;
  if not LoadSectionHeaders(AStream) then
    exit;

  // Add header as a section.
  // LoadingAddHeaderAsASection(AStream);

  // Read data directories.
  if OptHdrSizeRead <> 0 then
  begin
    AStream.Position := DataDirOfs;

    FDataDirectories.LoadDirectoriesFromStream(AStream, Msg,
      FOptionalHeader.NumberOfRvaAndSizes,              // declared count
      FFileHeader.SizeOfOptionalHeader - OptHdrSizeRead // bytes left in optional header
      );
  end;

  // Mapped image can't have overlay, so correct total size.
  if FImageKind = PEIMAGE_KIND_MEMORY then
    FFileSize := CalcRawSizeOfImage;

  // Read COFF.
  FCOFF.LoadFromStream(AStream);

  // Convert /%num% section names to long names if possible.
  ResolveSectionNames;

  // Read Gap after Section Header.
  if FSections.Count <> 0 then
  begin
    SecDataOfs := FSections.First.RawOffset;
    if SecDataOfs >= SecHdrEndOfs then
    begin
      SecHdrGapSize := SecDataOfs - SecHdrEndOfs;
      SetLength(self.FSecHdrGap, SecHdrGapSize);
      if SecHdrGapSize <> 0 then
      begin
        AStream.Position := SecHdrEndOfs;
        AStream.Read(self.FSecHdrGap[0], SecHdrGapSize);
      end;
    end;
  end;

  Result := true;

  // Load section data.
  LoadSectionData(AStream);

  // Now base headers loaded.
  // Define regions loaded before.

  // Execute parsers.
  if AParseStages <> [] then
  begin
    for Stage in AParseStages do
      if Assigned(FParsers[Stage]) then
      begin
        Parser := FParsers[Stage].Create(self);
        try
          case Parser.Parse of
            PR_ERROR:
              Msg.Write('[%s] Parser returned error.', [Parser.ToString]);
            PR_SUSPICIOUS:
              Msg.Write('[%s] Parser returned status SUSPICIOUS.',
                [Parser.ToString]);
          end;
        finally
          Parser.Free;
        end;
      end;
  end;
end;

procedure TPEImage.LoadingAddHeaderAsASection(Stream: TStream);
var
  sh: TImageSectionHeader;
  Sec: TPESection;
  oldPos: int64;
begin
  oldPos := Stream.Position;
  try
    sh.Clear;
    sh.Name := 'header';
    sh.SizeOfRawData := FOptionalHeader.SizeOfHeaders;
    sh.VirtualSize := AlignUp(FOptionalHeader.SizeOfHeaders, FOptionalHeader.SectionAlignment);

    Sec := TPESection(TPESectionImageHeader.Create(sh, nil));

    FSections.Insert(0, Sec);

    Stream.Position := 0;
    Stream.Read(Sec.Mem^, sh.SizeOfRawData);
  finally
    Stream.Position := oldPos;
  end;
end;

function TPEImage.SaveToStream(AStream: TStream): boolean;
begin
  Result := PE.Image.Saving.SaveImageToStream(self, AStream);
end;

function TPEImage.SaveToFile(const AFileName: string): boolean;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmCreate);
  try
    Result := SaveToStream(fs);
  finally
    fs.Free;
  end;
end;

function TPEImage.GetOptionalHeader: PPEOptionalHeader;
begin
  Result := @self.FOptionalHeader;
end;

function TPEImage.GetOverlay: POverlay;
var
  lastSec: TPESection;
begin
  lastSec := GetLastSectionWithValidRawData;

  if (lastSec <> nil) then
  begin
    FOverlay.Offset := lastSec.GetEndRawOffset; // overlay offset

    // Check overlay offet present in file.
    if FOverlay.Offset < FFileSize then
    begin
      FOverlay.Size := FFileSize - FOverlay.Offset;
      exit(@FOverlay);
    end;
  end;

  exit(nil);
end;

function TPEImage.GetLastSectionWithValidRawData: TPESection;
var
  i: integer;
begin
  for i := FSections.Count - 1 downto 0 do
    if (FSections[i].RawOffset <> 0) and (FSections[i].RawSize <> 0) then
      exit(FSections[i]);
  exit(nil);
end;

function TPEImage.SaveOverlayToFile(const AFileName: string;
  Append: boolean = false): boolean;
var
  src, dst: TStream;
  ovr: POverlay;
begin
  Result := false;

  ovr := GetOverlay;
  if Assigned(ovr) then
  begin
    // If no overlay, we're done.
    if ovr^.Size = 0 then
      exit(true);
    try
      src := SourceStreamGet(fmOpenRead or fmShareDenyWrite);

      if Append and FileExists(AFileName) then
      begin
        dst := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyWrite);
        dst.Seek(0, soFromEnd);
      end
      else
        dst := TFileStream.Create(AFileName, fmCreate);

      try
        src.Seek(ovr^.Offset, TSeekOrigin.soBeginning);
        dst.CopyFrom(src, ovr^.Size);
        Result := true;
      finally
        SourceStreamFree(src);
        dst.Free;
      end;
    except
    end;
  end;
end;

function TPEImage.RemoveOverlay: boolean;
var
  ovr: POverlay;
  fs: TFileStream;
begin
  Result := false;

  if FImageKind = PEIMAGE_KIND_MEMORY then
  begin
    FMsg.Write('Can''t remove overlay from mapped image.');
    exit;
  end;

  ovr := GetOverlay;
  if (ovr <> nil) and (ovr^.Size <> 0) then
  begin
    try
      fs := TFileStream.Create(FFileName, fmOpenWrite or fmShareDenyWrite);
      try
        fs.Size := fs.Size - ovr^.Size; // Trim file.
        self.FFileSize := fs.Size;      // Update filesize.
        Result := true;
      finally
        fs.Free;
      end;
    except
    end;
  end;
end;

function TPEImage.LoadOverlayFromFile(const AFileName: string; Offset,
  Size: UInt64): boolean;
var
  ovr: POverlay;
  fs: TFileStream;
  src: TStream;
  newImgSize: uint32;
begin
  Result := false;

  if FImageKind = PEIMAGE_KIND_MEMORY then
  begin
    FMsg.Write('Can''t append overlay to mapped image.');
    exit;
  end;

  fs := TFileStream.Create(FFileName, fmOpenWrite or fmShareDenyWrite);
  src := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if (Offset = 0) and (Size = 0) then
      Size := src.Size;
    if Size <> 0 then
    begin
      if (Offset + Size) > src.Size then
        exit(false);
      src.Position := Offset;

      ovr := GetOverlay;
      if (ovr <> nil) and (ovr^.Size <> 0) then
        fs.Size := fs.Size - ovr^.Size // Trim file.
      else
      begin
        newImgSize := CalcRawSizeOfImage();
        fs.Size := newImgSize;
      end;

      fs.Position := fs.Size;

      fs.CopyFrom(src, Size);

      self.FFileSize := fs.Size; // Update filesize.
    end;
    Result := true;
  finally
    src.Free;
    fs.Free;
  end;
end;

end.
