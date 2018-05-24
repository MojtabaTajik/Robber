{
  Load and map module into current process.
  Module MUST have relocations or be RIP-addressed to be loaded normally.
}
unit PE.ExecutableLoader;

interface

uses
  System.Classes,
  System.Generics.Collections,

  WinApi.Windows,

  PE.Common,
  PE.Image;

type
  TMapStatus = (
    msOK,
    msImageAlreadyMapped,
    msError,
    msImageSizeError,
    msMapSectionsError,
    msSectionAllocError,
    msProtectSectionsError,
    msImportLibraryNotFound,
    msImportNameNotFound,
    msImportOrdinalNotFound,
    msEntryPointFailure
    );

  TMapStatusHelper = record helper for TMapStatus
    function ToString: string;
  end;

  TExecutableLoadingOption = (
    // Write PE header into start of allocated image.
    elo_MapHeader,

    // Apply fixups after image mapping.
    elo_FixRelocations,

    // Resolve imported functions after image mapping.
    elo_FixImports,

    // Apply protection defined in section header to mapped sections.
    elo_ProtectSections,

    // Call EXE or DLL entry point when image mapped.
    elo_CallEntryPoint
    );

  TExecutableLoadingOptions = set of TExecutableLoadingOption;

const
  DEFAULT_OPTIONS = [
    elo_MapHeader,
    elo_FixRelocations,
    elo_FixImports,
    elo_ProtectSections,
    elo_CallEntryPoint
    ];

type
  TEXEEntry = procedure(); stdcall;
  TDLLEntry = function(hInstDLL: HINST; fdwReason: DWORD; lpvReserved: LPVOID): BOOL; stdcall;

  TLoadedModules = TDictionary<string, HMODULE>;

  TExecutableModule = class
  private
    FPE: TPEImage;
    FOptions: TExecutableLoadingOptions;
    FInstance: NativeUInt;
    FEntry: Pointer;
    FSizeOfImage: UInt32;
    FLoadedImports: TLoadedModules;
    function Check(const Desc: string; var rslt: TMapStatus; ms: TMapStatus): boolean;

    function MapSections(PrefferedVa: UInt64): TMapStatus;
    function MapHeader: TMapStatus;
    function ProtectSections: TMapStatus;
    function Relocate: TMapStatus;
    function LoadImports: TMapStatus;

    procedure UnloadImports;
  public
    constructor Create(PE: TPEImage);
    destructor Destroy; override;

    function IsImageMapped: boolean; inline;

    function Load(
      PrefferedVa: UInt64 = 0;
      Options: TExecutableLoadingOptions = DEFAULT_OPTIONS): TMapStatus;

    function Unload: boolean;

    property Instance: NativeUInt read FInstance;
  end;

implementation

uses
  System.SysUtils,

  PE.Types.FileHeader,
  PE.Utils,
  PE.Sections,
  PE.Image.Saving,

  PE.Imports,
  PE.Imports.Func,
  PE.Imports.Lib,

  PE.MemoryStream,
  PE.Section,
  PE.Types.Relocations;

function HasBits(Value, mask: DWORD): boolean; inline;
begin
  Result := (Value and mask) <> 0;
end;

function CharacteristicsToProtect(CH: DWORD): DWORD;
var
  X, R, W, C: boolean;
begin
  Result := 0;

  X := HasBits(CH, IMAGE_SCN_MEM_EXECUTE);
  R := HasBits(CH, IMAGE_SCN_MEM_READ);
  W := HasBits(CH, IMAGE_SCN_MEM_WRITE);
  C := HasBits(CH, IMAGE_SCN_MEM_NOT_CACHED);

  if X then
  begin
    if R then
    begin
      if W then
        Result := Result or PAGE_EXECUTE_READWRITE
      else
        Result := Result or PAGE_EXECUTE_READ;
    end
    else if W then
      Result := Result or PAGE_EXECUTE_WRITECOPY
    else
      Result := Result or PAGE_EXECUTE;
  end
  else if R then
  begin
    if W then
      Result := Result or PAGE_READWRITE
    else
      Result := Result or PAGE_READONLY;
  end
  else if W then
    Result := Result or PAGE_WRITECOPY
  else
  begin
    Result := Result or PAGE_NOACCESS;
  end;

  if C then
    Result := Result or PAGE_NOCACHE;
end;

function min(d1, d2: DWORD): DWORD;
begin
  if d1 < d2 then
    Result := d1
  else
    Result := d2;
end;

{ TExecutableModule }

function TExecutableModule.Check(const Desc: string; var rslt: TMapStatus;
  ms: TMapStatus): boolean;
begin
  rslt := ms;
  Result := ms = msOK;

  if Result then
    FPE.Msg.Write(Desc + ' .. OK.')
  else
    FPE.Msg.Write(Desc + ' .. failed.')
end;

constructor TExecutableModule.Create(PE: TPEImage);
begin
  FPE := PE;
  FLoadedImports := TLoadedModules.Create;
end;

destructor TExecutableModule.Destroy;
begin
  Unload;
  FLoadedImports.Free;
  inherited;
end;

function TExecutableModule.IsImageMapped: boolean;
begin
  Result := FInstance <> 0;
end;

function TExecutableModule.MapSections(PrefferedVa: UInt64): TMapStatus;
var
  i: integer;
  sec: TPESection;
  size: DWORD;
  va: pbyte;
begin
  Result := msMapSectionsError;

  FSizeOfImage := FPE.CalcVirtualSizeOfImage;

  if FSizeOfImage = 0 then
    exit(msImageSizeError);

  // Reserve and commit memory for image.
  FInstance := NativeUInt(VirtualAlloc(
    Pointer(PrefferedVa),
    FSizeOfImage,
    MEM_RESERVE or MEM_COMMIT,
    PAGE_READWRITE
    ));

  if FInstance = 0 then
    exit(msSectionAllocError);

  // copy sections and header
  // todo: header

  for i := 0 to FPE.Sections.Count - 1 do
  begin
    sec := FPE.Sections[i];
    if sec.VirtualSize <> 0 then
    begin
      va := pbyte(FInstance) + sec.RVA;
      size := min(sec.VirtualSize, sec.RawSize);
      if not FPE.SeekRVA(sec.RVA) then
        exit;
      FPE.Read(va, size);
    end;
  end;

  Result := msOK;
end;

function TExecutableModule.MapHeader: TMapStatus;
var
  ms: TPECustomMemoryStream;
begin
  if not(elo_MapHeader in FOptions) then
    exit(msOK);

  ms := TPECustomMemoryStream.CreateFromPointer(Pointer(FInstance), FSizeOfImage);
  try
    // Write header as-is without recalcualtions.
    if not SaveHeaders(FPE, ms, False) then
      exit(msError);
  finally
    ms.Free;
  end;

  exit(msOK);
end;

function TExecutableModule.LoadImports: TMapStatus;
var
  ImpLib: TPEImportLibrary;
  Fn: TPEImportFunction;
  ImpLibName: String;
  hmod: HMODULE;
  proc: Pointer;
  RVA: TRVA;
  va: TVA;
  ModuleMustBeFreed: boolean;
begin
  if not(elo_FixImports in FOptions) then
    exit(msOK);

  for ImpLib in FPE.Imports.Libs do
  begin
    ImpLibName := ImpLib.Name;

    FPE.Msg.Write('Processing import module: "%s"', [ImpLibName]);

    // Check if module already in address space.
    hmod := GetModuleHandle(PChar(ImpLibName));
    ModuleMustBeFreed := hmod = 0;

    // Try make system load lib from default paths.
    if hmod = 0 then
      hmod := LoadLibrary(PChar(ImpLibName));
    // Try load from dir, where image located.
    if (hmod = 0) and (FPE.FileName <> '') then
    begin
      hmod := LoadLibrary(PChar(ExtractFilePath(FPE.FileName) + ImpLibName));
    end;
    // If lib not found, raise.
    if hmod = 0 then
    begin
      FPE.Msg.Write('Imported module "%s" not loaded.', [ImpLibName]);
      // It's either not found, or its dependencies not found.
      exit(msImportLibraryNotFound);
    end;

    // Module found.
    if ModuleMustBeFreed then
      FLoadedImports.Add(ImpLibName, hmod);

    // Process import functions.
    RVA := ImpLib.IatRva;

    for Fn in ImpLib.Functions do
    begin
      // Find imported function.

      // By Name.
      if Fn.Name <> '' then
      begin
        proc := GetProcAddress(hmod, PChar(Fn.Name));
        if proc = nil then
        begin
          FPE.Msg.Write('Imported name "%s" not found.', [Fn.Name]);
          exit(msImportNameNotFound);
        end;
      end
      else
      // By Ordinal.
      begin
        proc := GetProcAddress(hmod, PAnsiChar(Fn.Ordinal));
        if proc = nil then
        begin
          FPE.Msg.Write('Imported ordinal "%d" not found.', [Fn.Ordinal]);
          exit(msImportOrdinalNotFound);
        end;
      end;

      // Patch.
      va := FInstance + RVA;
      if FPE.Is32bit then
        PUINT(va)^ := UInt32(proc)
      else if FPE.Is64bit then
        PUInt64(va)^ := UInt64(proc);

      inc(RVA, FPE.ImageWordSize);
    end;

    // inc(RVA, FPE.ImageWordSize); // null
  end;
  Result := msOK;
end;

function TExecutableModule.ProtectSections: TMapStatus;
var
  i: integer;
  sec: TPESection;
  prot: cardinal;
  va: pbyte;
  dw: DWORD;
begin
  if not(elo_ProtectSections in FOptions) then
    exit(msOK);

  for i := 0 to FPE.Sections.Count - 1 do
  begin
    Result := msProtectSectionsError;
    sec := FPE.Sections[i];
    if sec.VirtualSize <> 0 then
    begin
      va := Pointer(FInstance);
      inc(va, sec.RVA);
      prot := CharacteristicsToProtect(sec.Flags);
      if not VirtualProtect(va, sec.VirtualSize, prot, dw) then
        exit;
    end;
  end;
  Result := msOK;
end;

function TExecutableModule.Relocate: TMapStatus;
var
  Reloc: TReloc;
  Delta: UInt32;
  pDst: PCardinal;
begin
  if not(elo_FixRelocations in FOptions) then
    exit(msOK);

  Delta := FInstance - FPE.ImageBase;

  if Delta = 0 then
    exit(msOK); // no relocation needed

  for Reloc in FPE.Relocs.Items do
  begin
    case Reloc.&Type of
      IMAGE_REL_BASED_HIGHLOW:
        begin
          pDst := PCardinal(FInstance + Reloc.RVA);
          inc(pDst^, Delta);
        end;
    else
      raise Exception.CreateFmt('Unsupported relocation type: %d', [Reloc.&Type]);
    end;
  end;
  Result := msOK;
end;

function TExecutableModule.Load(
  PrefferedVa: UInt64;
  Options: TExecutableLoadingOptions): TMapStatus;
var
  EntryOK: boolean;
begin
  if IsImageMapped then
    exit(msImageAlreadyMapped);

  Result := msError;

  FOptions := Options;

  if
    Check('Map Sections', Result, MapSections(PrefferedVa)) and
    Check('Map Header', Result, MapHeader()) and
    Check('Fix Relocation', Result, Relocate()) and
    Check('Fix Imports', Result, LoadImports()) and
    Check('Protect Sections', Result, ProtectSections()) then
  begin
    if FPE.EntryPointRVA = 0 then
      FEntry := nil
    else
      FEntry := Pointer(FInstance + FPE.EntryPointRVA);

    // If don't need to call entry or there is no entry just skip this part
    if (not Assigned(FEntry)) or (not(elo_CallEntryPoint in FOptions)) then
      EntryOK := True
      // Call Entry Point.
    else if FPE.IsDLL then
    begin
      FPE.Msg.Write('Calling DLL Entry with DLL_PROCESS_ATTACH.');
      EntryOK := TDLLEntry(FEntry)(FInstance, DLL_PROCESS_ATTACH, nil);
      if not EntryOK then
        FPE.Msg.Write('DLL returned FALSE.');
    end
    else
    begin
      FPE.Msg.Write('Calling EXE Entry.');
      TEXEEntry(FEntry)();
      EntryOK := True;
    end;

    if EntryOK then
      exit(msOK)
    else
      Result := msEntryPointFailure;
  end;

  // If something failed.
  Unload;
end;

function TExecutableModule.Unload: boolean;
begin
  if not IsImageMapped then
    exit(True);

  if (elo_CallEntryPoint in FOptions) and Assigned(FEntry) then
  begin
    // DLL finalization.
    if FPE.IsDLL then
    begin
      FPE.Msg.Write('Calling DLL Entry with DLL_PROCESS_DETACH.');
      TDLLEntry(FEntry)(FInstance, DLL_PROCESS_DETACH, nil);
    end;
  end;

  // Unload imported libraries.
  UnloadImports;

  // Free image memory
  VirtualFree(Pointer(FInstance), FSizeOfImage, MEM_RELEASE);
  FInstance := 0;

  Result := True;
end;

procedure TExecutableModule.UnloadImports;
var
  Pair: TPair<string, HMODULE>;
begin
  for Pair in FLoadedImports do
  begin
    FPE.Msg.Write('Unloading import "%s"', [Pair.Key]);
    FreeLibrary(Pair.Value);
  end;
  FLoadedImports.Clear;
end;

{ TMapStatusHelper }

const
  MapStatusText: array [TMapStatus] of string = (
    'OK',
    'Image already mapped',
    'Error',
    'Image size error',
    'Map sections error',
    'Section allocation error',
    'Protect sections error',
    'Import library not found',
    'Import name not found',
    'Import ordinal not found',
    'Entry point failure'
    );

function TMapStatusHelper.ToString: string;
begin
  if self in [low(TMapStatus) .. high(TMapStatus)] then
    Result := MapStatusText[self]
  else
    Result := '???';
end;

end.
