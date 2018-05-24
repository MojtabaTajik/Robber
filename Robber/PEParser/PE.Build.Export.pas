{
  Building export table to stream.
  This stream can be later saved to section or replace old export table.

  todo: clear old export data
}

{$WARN COMBINING_SIGNED_UNSIGNED OFF}

unit PE.Build.Export;

interface

uses
  System.Classes,

  PE.Build.Common,
  PE.Common,
  PE.Utils;

type
  TExportBuilder = class(TDirectoryBuilder)
  public
    procedure Build(DirRVA: UInt64; Stream: TStream); override;
    class function GetDefaultSectionFlags: Cardinal; override;
    class function GetDefaultSectionName: string; override;
    class function NeedRebuildingIfRVAChanged: Boolean; override;
  end;

implementation

uses
  System.Generics.Defaults,
  System.Generics.Collections,
  System.SysUtils,
  PE.ExportSym,
  PE.Types.Export;

type
  TSym = record
    sym: TPEExportSym;
    nameRVA: TRVA;
  end;

  TSyms = TList<TSym>;

  { TExportBuilder }

procedure TExportBuilder.Build(DirRVA: UInt64; Stream: TStream);
var
  i: integer;
  ExpDir: TImageExportDirectory;
  ofs_SymRVAs: uint32;  // sym rvas offsets
  ofs_NameRVAs: uint32; // name rva offsets
  ofs_NameOrds: uint32; // name ordinals
  ofs_LibName: uint32;  // offset of address of names
  sym: TPEExportSym;
  rva32: uint32;
  RVAs: packed array of uint32;
  minIndex, maxIndex: word;
var
  nSyms: TSyms;
  nSym: TSym;
  ordinal: word;
begin
  nSyms := TSyms.Create;

  try
    // Collect named items.
    // Find min and max index.
    maxIndex := 0;
    if FPE.ExportSyms.Count = 0 then
      minIndex := 1
    else
      minIndex := $FFFF;

    for sym in FPE.ExportSyms.Items do
    begin
      nSym.sym := sym;
      nSym.nameRVA := 0;
      nSyms.Add(nSym);

      if sym.ordinal > maxIndex then
        maxIndex := sym.ordinal;
      if sym.ordinal < minIndex then
        minIndex := sym.ordinal;
    end;

    // Create RVAs.
    if maxIndex <> 0 then
    begin
      SetLength(RVAs, maxIndex);
      for i := 0 to FPE.ExportSyms.Count - 1 do
      begin
        sym := FPE.ExportSyms.Items[i];
        if sym.ordinal <> 0 then
          RVAs[sym.ordinal - minIndex] := sym.RVA;
      end;
    end;

    // Calc offsets.
    ofs_SymRVAs := SizeOf(ExpDir);
    ofs_NameRVAs := ofs_SymRVAs + Length(RVAs) * SizeOf(rva32);
    ofs_NameOrds := ofs_NameRVAs + nSyms.Count * SizeOf(rva32);
    ofs_LibName := ofs_NameOrds + nSyms.Count * SizeOf(ordinal);

    // Initial seek.
    Stream.Size := ofs_LibName;
    Stream.Position := ofs_LibName;

    // Write exported name.
    if FPE.ExportedName <> '' then
      StreamWriteStringA(Stream, FPE.ExportedName);

    // Sort nSyms by names (lexicographical order) to allow binary searches.
    nSyms.Sort(TComparer<TSym>.Construct(
      function(const a, b: TSym): integer
      begin
        Result := CompareStr(a.sym.Name, b.sym.Name)
      end
      ));

    // Write names.
    for i := 0 to nSyms.Count - 1 do
    begin
      nSym := nSyms[i];
      nSym.nameRVA := DirRVA + Stream.Position;
      nSyms[i] := nSym;
      StreamWriteStringA(Stream, nSym.sym.Name);
    end;

    // Write forwarder names.
    for i := 0 to nSyms.Count - 1 do
    begin
      nSym := nSyms[i];
      if nSym.sym.Forwarder then
      begin
        RVAs[nSym.sym.ordinal - minIndex] := DirRVA + Stream.Position;
        StreamWriteStringA(Stream, nSym.sym.ForwarderName);
      end;
    end;

    // Fill export dir.
    ExpDir.ExportFlags := 0;
    ExpDir.TimeDateStamp := 0;
    ExpDir.MajorVersion := 0;
    ExpDir.MinorVersion := 0;
    if FPE.ExportedName <> '' then
      ExpDir.nameRVA := DirRVA + ofs_LibName
    else
      ExpDir.nameRVA := 0;
    ExpDir.OrdinalBase := minIndex;
    ExpDir.AddressTableEntries := Length(RVAs);
    ExpDir.NumberOfNamePointers := nSyms.Count;
    ExpDir.ExportAddressTableRVA := DirRVA + ofs_SymRVAs;
    ExpDir.NamePointerRVA := DirRVA + ofs_NameRVAs;
    ExpDir.OrdinalTableRVA := DirRVA + ofs_NameOrds;

    // Seek start.
    Stream.Position := 0;

    // Write export dir.
    Stream.Write(ExpDir, SizeOf(ExpDir));

    // Write RVAs of all symbols.
    StreamWrite(Stream, RVAs[0], Length(RVAs) * SizeOf(RVAs[0]));

    // Write name RVAs.
    for i := 0 to nSyms.Count - 1 do
    begin
      nSym := nSyms[i];
      rva32 := nSym.nameRVA;
      StreamWrite(Stream, rva32, SizeOf(rva32));
    end;

    // Write name ordinals.
    for i := 0 to nSyms.Count - 1 do
    begin
      nSym := nSyms[i];
      ordinal := nSym.sym.ordinal - minIndex;
      StreamWrite(Stream, ordinal, SizeOf(ordinal));
    end;

  finally
    nSyms.Free;
  end;
end;

class function TExportBuilder.GetDefaultSectionFlags: Cardinal;
begin
  Result := $40000040; // readable, initialized data
end;

class function TExportBuilder.GetDefaultSectionName: string;
begin
  Result := '.edata';
end;

class function TExportBuilder.NeedRebuildingIfRVAChanged: Boolean;
begin
  Result := True;
end;

end.
