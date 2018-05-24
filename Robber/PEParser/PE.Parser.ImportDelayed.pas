unit PE.Parser.ImportDelayed;

interface

uses
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Imports,
  PE.Types,
  PE.Types.Directories,
  PE.Types.FileHeader, // expand TPEImage.Is32bit
  PE.Types.Imports,
  PE.Types.ImportsDelayed,
  PE.Utils;

type
  TPEImportDelayedParser = class(TPEParser)
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image,
  PE.Imports.Func,
  PE.Imports.Lib;

// Testing mode: check if read fields are correct.
function ParseTable(
  const PE: TPEImage;
  const Table: TDelayLoadDirectoryTable;
  Testing: boolean
  ): boolean;
var
  DllName: string;
  FnName: string;
  Fn: TPEImportFunctionDelayed;
  HintNameRva: TRVA;
  Ilt: TImportLookupTable;
  iFunc: uint32;
var
  iLen: integer;
  Ordinal: UInt16;
  Hint: UInt16 absolute Ordinal;
  Iat: TRVA;
  SubValue: uint32;
  Lib: TPEImportLibrary;
begin
  if Table.UsesVA then
    SubValue := PE.ImageBase
  else
    SubValue := 0;

  if Testing then
  begin
    if (Table.Name = 0) or (Table.Name < SubValue) then
    begin
      PE.Msg.Write('Delayed Import: Name address incorrect.');
      exit(false);
    end;

    if (Table.DelayImportNameTable = 0) or (Table.DelayImportNameTable < SubValue) then
    begin
      PE.Msg.Write('Delayed Import: Name table address incorrect.');
      exit(false);
    end;

    if (Table.DelayImportAddressTable = 0) or (Table.DelayImportAddressTable < SubValue) then
    begin
      PE.Msg.Write('Delayed Import: Address table incorrect.');
      exit(false);
    end;
  end;

  if not PE.SeekRVA(Table.Name - SubValue) then
    exit(false);

  if not PE.ReadAnsiStringLen(MAX_PATH_WIN, iLen, DllName) then
    exit(false);

  if not Testing then
  begin
    Lib := TPEImportLibrary.Create(DllName, False, True);
    PE.ImportsDelayed.Add(Lib);
  end
  else
  begin
    Lib := nil; // compiler friendly
  end;

  iFunc := 0;
  Iat := Table.DelayImportAddressTable - SubValue;

  while PE.SeekRVA(Table.DelayImportNameTable - SubValue + iFunc * PE.ImageWordSize) do
  begin
    HintNameRva := PE.ReadWord();
    if HintNameRva = 0 then
      break;

    Ilt.Create(HintNameRva, PE.Is32bit);

    Ordinal := 0;
    FnName := '';

    if Ilt.IsImportByOrdinal then
    begin
      // Import by ordinal only. No hint/name.
      Ordinal := Ilt.OrdinalNumber;
    end
    else
    begin
      // Import by name. Get hint/name
      if not PE.SeekRVA(HintNameRva - SubValue) then
      begin
        PE.Msg.Write('Delayed Import: incorrect Hint/Name RVA encountered.');
        exit(false);
      end;

      Hint := PE.ReadWord(2);
      FnName := PE.ReadANSIString;
    end;

    if not Testing then
    begin
      Fn := TPEImportFunctionDelayed.Create(FnName, Ordinal);
      Lib.Functions.Add(Fn);
    end;

    inc(Iat, PE.ImageWordSize);
    inc(iFunc);
  end;

  exit(true);
end;

function TPEImportDelayedParser.Parse: TParserResult;
var
  PE: TPEImage;
  ddir: TImageDataDirectory;
  ofs: uint32;
  Table: TDelayLoadDirectoryTable;
  Tables: TList<TDelayLoadDirectoryTable>;
  TablesUseRVA: boolean;
begin
  PE := TPEImage(FPE);

  result := PR_ERROR;

  // If no imports, it's ok.
  if not PE.DataDirectories.Get(DDIR_DELAYIMPORT, @ddir) then
    exit(PR_OK);
  if ddir.IsEmpty then
    exit(PR_OK);

  // Seek import dir.
  if not PE.SeekRVA(ddir.VirtualAddress) then
    exit;

  Tables := TList<TDelayLoadDirectoryTable>.Create;
  try

    // Delay-load dir. tables.
    ofs := 0;
    TablesUseRVA := true; // default, compiler-friendly
    while true do
    begin
      if ofs > ddir.Size then
        exit(PR_ERROR);

      if not PE.ReadEx(Table, SizeOf(Table)) then
        break;

      if Table.Empty then
        break;

      // Attribute:
      // 0: addresses are VA (old VC6 binaries)
      // 1: addresses are RVA

      if (ofs = 0) then
      begin
        TablesUseRVA := Table.UsesRVA; // initialize once
      end
      else if TablesUseRVA <> Table.UsesRVA then
      begin
        // Normally all tables must use either VA or RVA. No mix allowed.
        // If mix found it must be not real table.
        // For example, some Delphi versions used such optimization.
        break;
      end;

      Tables.Add(Table);
      inc(ofs, SizeOf(Table));
    end;

    // Parse tables.
    for Table in Tables do
      // First test if fields are correct
      if ParseTable(PE, Table, true) then
        // Then do real reading.
        ParseTable(PE, Table, false);

    exit(PR_OK);
  finally
    Tables.Free;
  end;
end;

end.
