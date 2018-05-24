unit PE.Types.Directories;

interface

type
  TImageDataDirectory = packed record
    RVA: uint32;
    Size: uint32;
    function IsEmpty: boolean; inline;
    function Contain(rva: uint32): boolean; inline;

    // todo: VirtualAddress is deprecated, use RVA instead.
    property VirtualAddress: uint32 read RVA write RVA;
  end;

  PImageDataDirectory = ^TImageDataDirectory;

type
  // 2.4.3. Optional Header Data Directories (Image Only)

  // variant #1
  TImageDataDirectories = packed record
    ExportTable: TImageDataDirectory;         // The export table address and size.
    ImportTable: TImageDataDirectory;         // The import table address and size.
    ResourceTable: TImageDataDirectory;       // The resource table address and size.
    ExceptionTable: TImageDataDirectory;      // The exception table address and size.
    CertificateTable: TImageDataDirectory;    // The attribute certificate table address and size.
    BaseRelocationTable: TImageDataDirectory; // The base relocation table address and size.
    Debug: TImageDataDirectory;               // The debug data starting address and size.
    Architecture: TImageDataDirectory;        // Reserved, must be 0
    GlobalPtr: TImageDataDirectory;           // The RVA of the value to be stored in the global pointer register.
    // The size member of this structure must be set to zero.
    TLSTable: TImageDataDirectory;              // The thread local storage (TLS) table address and size.
    LoadConfigTable: TImageDataDirectory;       // The load configuration table address and size.
    BoundImport: TImageDataDirectory;           // The bound import table address and size.
    IAT: TImageDataDirectory;                   // The import address table address and size.
    DelayImportDescriptor: TImageDataDirectory; // The delay import descriptor address and size.
    CLRRuntimeHeader: TImageDataDirectory;      // The CLR runtime header address and size.
    RESERVED: TImageDataDirectory;              // Reserved, must be zero
  end;

  PImageDataDirectories = ^TImageDataDirectories;

const
  NULL_IMAGE_DATA_DIRECTORY: TImageDataDirectory = (RVA: 0; Size: 0);

  IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;

  TYPICAL_NUMBER_OF_DIRECTORIES = IMAGE_NUMBEROF_DIRECTORY_ENTRIES;

  // variant #2
  // TImageDataDirectories = packed array [0 .. IMAGE_NUMBEROF_DIRECTORY_ENTRIES-1] of TImageDataDirectory;

// Get directory name by index or format index as a string (like dir_0001) if
// it's not in range of known names.
function GetDirectoryName(Index: integer): string;

implementation

uses
  System.SysUtils;

function TImageDataDirectory.Contain(rva: uint32): boolean;
begin
  Result := (rva >= Self.VirtualAddress) and (rva < Self.VirtualAddress + Self.Size);
end;

function TImageDataDirectory.IsEmpty: boolean;
begin
  // In some cases Size can be 0, but VirtualAddress will point to valid data.
  Result := (VirtualAddress = 0);
end;

const
  DirectoryNames: array [0 .. IMAGE_NUMBEROF_DIRECTORY_ENTRIES - 1] of string =
    (
    'Export',
    'Import',
    'Resource',
    'Exception',
    'Certificate',
    'Base Relocation',
    'Debug',
    'Architecture',
    'Global Pointer',
    'Thread Local Storage',
    'Load Config',
    'Bound Import',
    'Import Address Table',
    'Delay Import Descriptor',
    'CLR Runtime Header',
    ''
    );

function GetDirectoryName(Index: integer): string;
begin
  if (Index >= 0) and (Index < Length(DirectoryNames)) then
    Result := DirectoryNames[Index]
  else
    Result := format('dir_%4.4d', [index]);
end;

end.
