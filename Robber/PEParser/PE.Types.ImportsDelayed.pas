unit PE.Types.ImportsDelayed;

interface

// 4.8. Delay-Load Import Tables (Image Only)
// 4.8.1. The Delay-Load Directory Table
type
  TDelayLoadDirectoryTable = packed record
  private
    function GetUsesVA: boolean; inline;
    function GetUsesRVA: boolean; inline;
    function GetEmpty: boolean; inline;
  public

    // Must be zero.
    Attributes: UInt32;

    // The RVA of the name of the DLL to be loaded. The name resides in the
    // read-only data section of the image.
    Name: UInt32;

    // The RVA of the module handle (in the data section of the image) of the
    // DLL to be delay-loaded. It is used for storage by the routine that is
    // supplied to manage delay-loading.
    ModuleHandle: UInt32;

    // The RVA of the delay-load import address table. For more information,
    // see section “Delay Import Address Table (IAT).”
    DelayImportAddressTable: UInt32;

    // The RVA of the delay-load name table, which contains the names of the
    // imports that might need to be loaded. This matches the layout of the
    // import name table. For more information, see section “Hint/Name Table.”
    DelayImportNameTable: UInt32;

    // The RVA of the bound delay-load address table, if it exists.
    BoundDelayImportTable: UInt32;

    // The RVA of the unload delay-load address table, if it exists. This is an
    // exact copy of the delay import address table. If the caller unloads
    // the DLL, this table should be copied back over the delay import address
    // table so that subsequent calls to the DLL continue to use the thunking
    // mechanism correctly.
    UnloadDelayImportTable: UInt32;

    // The timestamp of the DLL to which this image has been bound.
    TimeStamp: UInt32;

    // Check if addresses are VA/RVA (by attibute).
    property UsesVA: boolean read GetUsesVA;
    property UsesRVA: boolean read GetUsesRVA;

    property Empty: boolean read GetEmpty;
  end;

implementation

const
  FLAG_RVA = 1;

  { TDelayLoadDirectoryTable }

function TDelayLoadDirectoryTable.GetUsesVA: boolean;
begin
  Result := (Attributes and FLAG_RVA) = 0;
end;

function TDelayLoadDirectoryTable.GetUsesRVA: boolean;
begin
  Result := (Attributes and FLAG_RVA) <> 0;
end;

function TDelayLoadDirectoryTable.GetEmpty: boolean;
begin
  Result := Name = 0;
end;

end.
