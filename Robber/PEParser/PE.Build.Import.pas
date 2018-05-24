unit PE.Build.Import;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Section,
  PE.Build.Common,
  PE.Utils;

type
  TImportBuilder = class(TDirectoryBuilder)
  public
    // Modified after Build called.
    BuiltIatRVA: TRVA;
    BuiltIatSize: uint32;
    procedure Build(DirRVA: TRVA; Stream: TStream); override;
    class function GetDefaultSectionFlags: Cardinal; override;
    class function GetDefaultSectionName: string; override;
    class function NeedRebuildingIfRVAChanged: Boolean; override;
  end;

implementation

uses
  // Expand
  PE.Image,
  PE.Types.FileHeader,
  //
  PE.Imports,
  PE.Imports.Lib,
  PE.Imports.Func,
  PE.Types.Imports;

{
  *  Import directory layout
  *
  *  IDT.
  *  For each library
  *    Import Descriptor
  *  Null Import Descriptor
  *
  *  Name pointers.
  *  For each library
  *    For each function
  *      Pointer to function hint/name or ordinal
  *    Null pointer
  *
  *  IAT.
  *  For each library
  *    For each function
  *      Function address
  *    Null address
  *
  *  Names.
  *  For each library
  *    Library name
  *    ** align 2 **
  *    For each function
  *      Hint: uint16
  *      Function name: variable length
}
procedure WriteStringAligned2(Stream: TStream; const s: string);
const
  null: byte = 0;
var
  bytes: TBytes;
begin
  bytes := TEncoding.ANSI.GetBytes(s);
  StreamWrite(Stream, bytes[0], length(bytes));
  StreamWrite(Stream, null, 1);
  if Stream.Position mod 2 <> 0 then
    StreamWrite(Stream, null, 1);
end;

procedure WriteIDT(
  Stream: TStream;
  var ofs_idt: uint32;
  const idt: TImportDirectoryTable);
begin
  Stream.Position := ofs_idt;
  StreamWrite(Stream, idt, sizeof(idt));
  inc(ofs_idt, sizeof(idt));
end;

procedure WriteNullIDT(Stream: TStream; var ofs_idt: uint32);
var
  idt: TImportDirectoryTable;
begin
  idt.Clear;
  WriteIDT(Stream, ofs_idt, idt);
end;

// Write library name and set idt name pointer, update name pointer offset.
procedure WriteLibraryName(
  Stream: TStream;
  Lib: TPEImportLibrary;
  DirRVA: TRVA;
  var ofs_names: uint32;
  var idt: TImportDirectoryTable);
begin
  // library name
  idt.NameRVA := DirRVA + ofs_names;
  Stream.Position := ofs_names;
  WriteStringAligned2(Stream, Lib.Name);
  ofs_names := Stream.Position;
end;

function MakeOrdinalRVA(ordinal: uint16; wordsize: byte): TRVA; inline;
begin
  if wordsize = 4 then
    result := $80000000 or ordinal
  else
    result := $8000000000000000 or ordinal;
end;

procedure WriteFunctionNamesOrOrdinalsAndIat(
  Stream: TStream;
  Lib: TPEImportLibrary;
  DirRVA: TRVA;
  var ofs_names: uint32;
  var ofs_name_pointers: uint32;
  var ofs_iat: uint32;
  var idt: TImportDirectoryTable;
  wordsize: byte);
var
  hint: uint16;
  fn: TPEImportFunction;
  rva_hint_name: TRVA;
begin
  if Lib.Functions.Count = 0 then
    exit;

  idt.ImportLookupTableRVA := DirRVA + ofs_name_pointers;

  if (not Lib.Original) then
  begin
    idt.ImportAddressTable := DirRVA + ofs_iat;

    // Update IAT in library.
    Lib.IatRva := idt.ImportAddressTable;
  end
  else
  begin
    idt.ImportAddressTable := Lib.IatRva;
  end;

  hint := 0;
  for fn in Lib.Functions do
  begin
    // Write name.
    if not fn.Name.IsEmpty then
    begin
      // If imported by name.
      rva_hint_name := DirRVA + ofs_names;
      Stream.Position := ofs_names;
      StreamWrite(Stream, hint, sizeof(hint));
      WriteStringAligned2(Stream, fn.Name);
      ofs_names := Stream.Position;
    end
    else
    begin
      // If imported by ordinal.
      rva_hint_name := MakeOrdinalRVA(fn.ordinal, wordsize);
    end;

    // Write name pointer.
    Stream.Position := ofs_name_pointers;
    StreamWrite(Stream, rva_hint_name, wordsize);
    inc(ofs_name_pointers, wordsize);

    // Write IAT item.
    Stream.Position := ofs_iat;
    StreamWrite(Stream, rva_hint_name, wordsize);
    inc(ofs_iat, wordsize);
  end;

  rva_hint_name := 0;

  // Write null name pointer.
  Stream.Position := ofs_name_pointers;
  StreamWrite(Stream, rva_hint_name, wordsize);
  ofs_name_pointers := Stream.Position;

  // Write null IAT item.
  Stream.Position := ofs_iat;
  StreamWrite(Stream, rva_hint_name, wordsize);
  inc(ofs_iat, wordsize);
end;

procedure TImportBuilder.Build(DirRVA: TRVA; Stream: TStream);
var
  idt: TImportDirectoryTable;
  Lib: TPEImportLibrary;
  elements: uint32;
var
  ofs_idt: uint32;
  ofs_name_pointers: uint32;
  ofs_iat, ofs_iat_0: uint32;
  ofs_names: uint32;
begin
  BuiltIatRVA := 0;
  BuiltIatSize := 0;

  if FPE.Imports.Libs.Count = 0 then
    exit;

  // Calculate initial offsets.
  elements := 0;
  for Lib in FPE.Imports.Libs do
    inc(elements, Lib.Functions.Count + 1);

  ofs_idt := 0;
  ofs_name_pointers := sizeof(idt) * (FPE.Imports.Libs.Count + 1);
  ofs_iat := ofs_name_pointers + elements * (FPE.ImageWordSize);
  ofs_iat_0 := ofs_iat;
  ofs_names := ofs_name_pointers + 2 * elements * (FPE.ImageWordSize);

  // Write.
  for Lib in FPE.Imports.Libs do
  begin
    idt.Clear;
    WriteLibraryName(Stream, Lib, DirRVA, ofs_names, idt);
    WriteFunctionNamesOrOrdinalsAndIat(Stream, Lib, DirRVA,
      ofs_names, ofs_name_pointers, ofs_iat, idt, FPE.ImageWordSize);
    WriteIDT(Stream, ofs_idt, idt);
  end;
  WriteNullIDT(Stream, ofs_idt);

  self.BuiltIatRVA := DirRVA + ofs_iat_0;
  self.BuiltIatSize := ofs_iat - ofs_iat_0;
end;

class function TImportBuilder.GetDefaultSectionFlags: Cardinal;
begin
  result := $C0000040;
end;

class function TImportBuilder.GetDefaultSectionName: string;
begin
  result := '.idata';
end;

class function TImportBuilder.NeedRebuildingIfRVAChanged: Boolean;
begin
  result := True;
end;

end.
