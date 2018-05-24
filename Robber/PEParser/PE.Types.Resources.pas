unit PE.Types.Resources;

interface

{$IFDEF DEBUG}
uses
  System.SysUtils; // to Raise
{$ENDIF}

// 5.9.1. Resource Directory Table

type

  { TResourceDirectoryTable }

  TResourceDirectoryTable = packed record

    // Resource flags. This field is reserved for future use.
    // It is currently set to zero.
    Characteristics: uint32;

    // The time that the resource data was created by the resource compiler.
    TimeDateStamp: uint32;

    // The major version number, set by the user.
    MajorVersion: uint16;

    // The minor version number, set by the user.
    MinorVersion: uint16;

    // The number of directory entries immediately following the table that
    // use strings to identify Type, Name, or Language entries (depending on
    // the level of the table).
    NumberOfNameEntries: uint16;

    // The number of directory entries immediately following the Name entries
    // that use numeric IDs for Type, Name, or Language entries.
    NumberOfIDEntries: uint16;

  end;

  PResourceDirectoryTable = ^TResourceDirectoryTable;

  TResourceEntryType = (ResourceEntryById, ResourceEntryByName);

  { TResourceDirectoryEntry }

  TResourceDirectoryEntry = packed record
  private

    // Either Name RVA or Id.
    FEntry: uint32;

    DataEntryRVAorSubdirectoryRVA: uint32;

    function GetDataEntryRVAorSubdirectoryRVA: uint32; inline;
    function GetIntegerID: uint32; inline;
    function GetNameRVA: uint32; inline;
    procedure SetSubDirRVA(const Value: uint32); inline;
    procedure SetDataEntryRVA(const Value: uint32); inline;
    procedure SetNameRVA(const Value: uint32); inline;
    procedure SetIntegerID(const Value: uint32); inline;
    function GetResourceEntryType: TResourceEntryType; inline;

  public

    procedure Clear;

    // To check which union select.
    function IsDataEntryRVA: boolean; inline;
    function IsSubdirectoryRVA: boolean; inline;

    // High bit 0. Address of a Resource Data entry (a leaf).
    property DataEntryRVA: uint32 read GetDataEntryRVAorSubdirectoryRVA write SetDataEntryRVA;

    // High bit 1. The lower 31 bits are the address of another resource
    // directory table (the next level down).
    property SubdirectoryRVA: uint32 read GetDataEntryRVAorSubdirectoryRVA write SetSubDirRVA;

    property EntryType: TResourceEntryType read GetResourceEntryType;

    property NameRVA: uint32 read GetNameRVA write SetNameRVA;
    property IntegerID: uint32 read GetIntegerID write SetIntegerID;
  end;

  PResourceDirectoryEntry = ^TResourceDirectoryEntry;

  { TResourceDataEntry }

  TResourceDataEntry = packed record
    // The address of a unit of resource data in the Resource Data area.
    DataRVA: uint32;

    // The size, in bytes, of the resource data that is pointed to by the
    // Data RVA field.
    Size: uint32;

    // The code page that is used to decode code point values within the
    // resource data. Typically, the code page would be the Unicode code page.
    Codepage: uint32;

    // Reserved, must be 0.
    Reserved: uint32;
  end;

implementation

procedure TResourceDirectoryEntry.Clear;
begin
  FEntry := 0;
  DataEntryRVAorSubdirectoryRVA := 0;
end;

function TResourceDirectoryEntry.GetDataEntryRVAorSubdirectoryRVA: uint32;
begin
  Result := DataEntryRVAorSubdirectoryRVA and $7FFFFFFF;
end;

function TResourceDirectoryEntry.GetIntegerID: uint32;
begin
{$IFDEF DEBUG}
  if EntryType <> ResourceEntryById then
    raise Exception.Create('Attempt to get ID of named-entry.');
{$ENDIF}
  Result := FEntry and $FFFF;
end;

function TResourceDirectoryEntry.GetNameRVA: uint32;
begin
{$IFDEF DEBUG}
  if EntryType <> ResourceEntryByName then
    raise Exception.Create('Attempt to get name RVA of ID-entry.');
{$ENDIF}
  Result := FEntry and $7FFFFFFF;
end;

function TResourceDirectoryEntry.GetResourceEntryType: TResourceEntryType;
begin
  if (self.FEntry and $80000000) = 0 then
    Result := ResourceEntryById
  else
    Result := ResourceEntryByName;
end;

function TResourceDirectoryEntry.IsDataEntryRVA: boolean;
begin
  Result := (DataEntryRVAorSubdirectoryRVA and $80000000) = 0;
end;

function TResourceDirectoryEntry.IsSubdirectoryRVA: boolean;
begin
  Result := (DataEntryRVAorSubdirectoryRVA and $80000000) <> 0;
end;

procedure TResourceDirectoryEntry.SetDataEntryRVA(const Value: uint32);
begin
  DataEntryRVAorSubdirectoryRVA := Value and $7FFFFFFF;
end;

procedure TResourceDirectoryEntry.SetIntegerID(const Value: uint32);
begin
  FEntry := Value and $7FFFFFFF;
end;

procedure TResourceDirectoryEntry.SetNameRVA(const Value: uint32);
begin
  FEntry := Value or $80000000;
end;

procedure TResourceDirectoryEntry.SetSubDirRVA(const Value: uint32);
begin
  DataEntryRVAorSubdirectoryRVA := Value or $80000000;
end;

end.
