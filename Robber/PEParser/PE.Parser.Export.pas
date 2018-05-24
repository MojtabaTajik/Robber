unit PE.Parser.Export;

interface

uses
  PE.Common,
  PE.Types,
  PE.Types.Directories,
  PE.Types.Export;

type
  TPEExportParser = class(TPEParser)
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image,
  PE.ExportSym;

{ TPEExportParser }

function TPEExportParser.Parse: TParserResult;
var
  PE: TPEImage;
  ExpIDD: TImageDataDirectory;
  ExpDir: TImageExportDirectory;
  i, base: uint32;
  ordnl: uint16;
  RVAs: array of uint32;
  NamePointerRVAs: array of uint32;
  OrdinalTableRVAs: array of uint16;
  Exp: array of TPEExportSym;
  Item: TPEExportSym;
begin
  PE := TPEImage(FPE);

  // Clear exports.
  PE.ExportSyms.Clear;

  // Get export dir.
  if not PE.DataDirectories.Get(DDIR_EXPORT, @ExpIDD) then
    exit(PR_OK);

  // No exports is ok.
  if ExpIDD.IsEmpty then
    exit(PR_OK);

  // If can't find Export dir, failure.
  if not PE.SeekRVA(ExpIDD.VirtualAddress) then
    exit(PR_ERROR);

  // If can't read whole table, failure.
  if not PE.ReadEx(@ExpDir, Sizeof(ExpDir)) then
  begin
    PE.Msg.Write('Export Parser: not enough space to read dir. header.');
    exit(PR_ERROR);
  end;

  // If no addresses, ok.
  if ExpDir.AddressTableEntries = 0 then
  begin
    PE.Msg.Write('Export Parser: directory present, but there are no functions.');
    exit(PR_OK);
  end;

  if ExpDir.ExportFlags <> 0 then
  begin
    PE.Msg.Write('Export Parser: reserved directory flags <> 0');
    exit(PR_ERROR);
  end;

  // Read lib exported name.
  if (ExpDir.NameRVA <> 0) then
  begin
    if not PE.SeekRVA(ExpDir.NameRVA) then
    begin
      PE.Msg.Write('Export Parser: Wrong RVA of dll exported name = 0x%x', [ExpDir.NameRVA]);
      exit(PR_ERROR);
    end;
    PE.ExportedName := PE.ReadAnsiString;
  end;

  base := ExpDir.OrdinalBase;

  // Check if there's too many exports.
  if (ExpDir.AddressTableEntries >= SUSPICIOUS_MIN_LIMIT_EXPORTS) or
    (ExpDir.NumberOfNamePointers >= SUSPICIOUS_MIN_LIMIT_EXPORTS) then
  begin
    exit(PR_SUSPICIOUS);
  end;

  SetLength(Exp, ExpDir.AddressTableEntries);
  SetLength(RVAs, ExpDir.AddressTableEntries);

  // load RVAs of exported data
  if not(PE.SeekRVA(ExpDir.ExportAddressTableRVA) and
    PE.ReadEx(@RVAs[0], 4 * ExpDir.AddressTableEntries)) then
    exit(PR_ERROR);

  if ExpDir.NumberOfNamePointers <> 0 then
  begin
    // name/ordinal only
    SetLength(NamePointerRVAs, ExpDir.NumberOfNamePointers);
    SetLength(OrdinalTableRVAs, ExpDir.NumberOfNamePointers);

    // load RVAs of name pointers
    if not((PE.SeekRVA(ExpDir.NamePointerRVA)) and
      PE.ReadEx(@NamePointerRVAs[0], 4 * ExpDir.NumberOfNamePointers)) then
      exit(PR_ERROR);

    // load ordinals according to names
    if not((PE.SeekRVA(ExpDir.OrdinalTableRVA)) and
      PE.ReadEx(@OrdinalTableRVAs[0], 2 * ExpDir.NumberOfNamePointers)) then
      exit(PR_ERROR);
  end;

  if ExpDir.AddressTableEntries <> 0 then
  begin
    for i := 0 to ExpDir.AddressTableEntries - 1 do
    begin
      Item := TPEExportSym.Create;
      Item.Ordinal := i + base;
      Item.RVA := RVAs[i];

      Exp[i] := Item;

      // if rva in export section, it's forwarder
      Exp[i].Forwarder := ExpIDD.Contain(RVAs[i]);
    end;
  end;

  // read names
  if ExpDir.NumberOfNamePointers <> 0 then
  begin
    for i := 0 to ExpDir.NumberOfNamePointers - 1 do
    begin
      if (NamePointerRVAs[i] <> 0) then
      begin
        ordnl := OrdinalTableRVAs[i];

        // Check if ordinal is correct.
        if ordnl >= length(Exp) then
          continue;

        if not Exp[ordnl].IsValid then
          continue;

        // Read export name.
        if not PE.SeekRVA(NamePointerRVAs[i]) then
          exit(PR_ERROR);

        Exp[ordnl].Name := PE.ReadAnsiString;

        // Read forwarder, if it is.
        if Exp[ordnl].Forwarder then
        begin
          // if it is forwarder, rva will point inside of export dir.
          if not PE.SeekRVA(Exp[ordnl].RVA) then
            exit(PR_ERROR);
          Exp[ordnl].ForwarderName := PE.ReadAnsiString;
          Exp[ordnl].RVA := 0; // no real address
        end;

      end;
    end;
  end;

  // finally array to list
  for i := low(Exp) to high(Exp) do
    if Exp[i].IsValid then
      PE.ExportSyms.Add(Exp[i])
    else
      Exp[i].Free;

  exit(PR_OK);
end;

end.
