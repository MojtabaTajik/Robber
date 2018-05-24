unit PE.Types.Imports;

interface

{ 5.4.1. Import Directory Table }
type
  TImportType = (itNoBinding, itOldBinding, itNewBinding);

  TImportDirectoryTable = packed record
  public
    // The RVA of the import lookup table. This table contains
    // a name or ordinal for each import.

    ImportLookupTableRVA: uint32; // OriginalFirstThunk, old (Characteristics)

    // The stamp that is set to zero until the image is bound.
    // After the image is bound, this field is set to the time/data
    // stamp of the DLL.
    TimeDateStamp: uint32;

    // The index of the first forwarder reference.
    ForwarderChain: uint32;

    // The address of an ASCII string that contains the name
    // of the DLL. This address is relative to the image base.
    NameRVA: uint32;

    // (Thunk Table); The RVA of the import address table.
    // The contents of this table are identical to the contents of
    // the import lookup table until the image is bound.

    ImportAddressTable: uint32; // First thunk

    function IsEmpty: boolean; inline;
    function IsBound: boolean; inline;
    function GetType: TImportType; inline;
    procedure Clear; inline;

    property FirstThunk: uint32 read ImportAddressTable;
    property OriginalFirstThunk: uint32 read ImportLookupTableRVA;
  end;
  PImportDirectoryTable = ^TImportDirectoryTable;

  { 5.4.2. Import Lookup Table }
  TImportLookupTable = packed record
  private
    FData: uint64; // 32/64 bits
    FIs32: boolean;
  public
    procedure Create(Data: uint64; Is32: boolean); inline;
    function IsEmpty: boolean; inline;
    function IsImportByOrdinal: boolean; inline;
    function IsImportByName: boolean; inline;
    function OrdinalNumber: uint16; inline; // only if import by ordinal
    function HintNameTableRVA: uint32;      // inline; // only if import by name
  end;

  { 5.4.3. Hint/Name Table }
  THintNameTable = packed record
  public
    // An index into the export name pointer table. A match is attempted
    // first with this value. If it fails, a binary search is performed
    // on the DLL’s export name pointer table.
    Hint: uint16;

    // An ASCII string that contains the name to import. This is
    // the string that must be matched to the public name in the DLL.
    // This string is case sensitive and terminated by a null byte.
    Name: String;

    { Pad : 0/1 bytes }
  end;


implementation

{ TImportLookupTable }

procedure TImportLookupTable.Create(Data: uint64; Is32: boolean);
begin
  FData := Data;
  FIs32 := Is32;
end;

function TImportLookupTable.HintNameTableRVA: uint32;
begin
  if IsImportByName then
    result := FData and $7FFFFFFF // for both 32 and 64 bit images
  else
    result := 0;
end;

function TImportLookupTable.IsEmpty: boolean;
begin
  result := FData = 0;
end;

function TImportLookupTable.IsImportByName: boolean;
begin
  result := not IsImportByOrdinal;
end;

function TImportLookupTable.IsImportByOrdinal: boolean;
begin
  if FIs32 then
    result := (FData and $80000000) <> 0
  else
    result := (FData and $8000000000000000) <> 0;
end;

function TImportLookupTable.OrdinalNumber: uint16;
begin
  if IsImportByOrdinal then
    result := FData and $FFFF
  else
    result := 0;
end;

{ TImportDirectoryTable }

procedure TImportDirectoryTable.Clear;
begin
  FillChar(self, SizeOf(self), 0);
end;

function TImportDirectoryTable.IsBound: boolean;
begin
  result := TimeDateStamp <> 0;
end;

function TImportDirectoryTable.GetType: TImportType;
begin
  case TimeDateStamp of
    0:
      result := itNoBinding;
    $FFFFFFFF:
      result := itNewBinding;
  else
    result := itOldBinding;
  end;
end;

function TImportDirectoryTable.IsEmpty: boolean;
begin
  Result := NameRva = 0;
end;

end.
