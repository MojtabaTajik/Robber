unit PE.Types.Export;

interface

uses
  PE.Common;

type
  TImageExportDirectory = packed record
    ExportFlags:           uint32;     //  Reserved, must be 0.
    TimeDateStamp:         uint32;     //  The time and date that the export data was created.
    MajorVersion:          uint16;     //  The major version number.
                                       //  The major and minor version numbers can be set by the user.
    MinorVersion:          uint16;     //  The minor version number.
    NameRVA:               uint32;     //  The address of the ASCII string that contains the name of the DLL.
                                       //  This address is relative to the image base.
    OrdinalBase:           uint32;     //  The starting ordinal number for exports in this image.
                                       //  This field specifies the starting ordinal number for the export address table.
                                       //  It is usually set to 1.
    AddressTableEntries:   uint32;     //  NumberOfFunctions; The number of entries in the export address table.
    NumberOfNamePointers:  uint32;     //  The number of entries in the name pointer table.
                                       //  This is also the number of entries in the ordinal table.
    ExportAddressTableRVA: uint32;     //  The address of the export address table, relative to the image base.
    NamePointerRVA:        uint32;     //  The address of the export name pointer table, relative to the image base.
                                       //  The table size is given by the Number of Name Pointers field.
    OrdinalTableRVA:       uint32;     //  The address of the ordinal table, relative to the image base.
  end;

  PImageExportDirectory = ^TImageExportDirectory;

implementation

end.
