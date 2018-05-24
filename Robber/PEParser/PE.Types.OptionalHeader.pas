unit PE.Types.OptionalHeader;

interface

uses
  PE.Types.Directories;

// 2.4.1. Optional Header Standard Fields (Image Only)
// 2.4.2. Optional Header Windows-Specific Fields (Image Only)
type
//  PImageOptionalHeader = ^TImageOptionalHeader;
//  TImageOptionalHeader = packed record
//     // Standard fields.
//     Magic                    : uint16;   //  0x10b: PE32
//                                          //  0x20b: PE32+
//     MajorLinkerVersion       : uint8;
//     MinorLinkerVersion       : uint8;
//     SizeOfCode               : uint32;
//     SizeOfInitializedData    : uint32;
//     SizeOfUninitializedData  : uint32;
//     AddressOfEntryPoint      : uint32;
//     BaseOfCode               : uint32;
//
//     BaseOfData               : uint32;   // PE32 only
//
//     // NT additional fields.
//     ImageBase                    : uint3264;
//     SectionAlignment             : uint32;
//     FileAlignment                : uint32;
//     MajorOperatingSystemVersion  : uint16;
//     MinorOperatingSystemVersion  : uint16;
//     MajorImageVersion            : uint16;
//     MinorImageVersion            : uint16;
//     MajorSubsystemVersion        : uint16;
//     MinorSubsystemVersion        : uint16;
//     Win32VersionValue            : uint32;
//     SizeOfImage                  : uint32;
//     SizeOfHeaders                : uint32;
//     CheckSum                     : uint32;
//     Subsystem                    : uint16;
//     DllCharacteristics           : uint16;
//     SizeOfStackReserve           : uint3264;
//     SizeOfStackCommit            : uint3264;
//     SizeOfHeapReserve            : uint3264;
//     SizeOfHeapCommit             : uint3264;
//     LoaderFlags                  : uint32;
//     NumberOfRvaAndSizes          : uint32;
//
////   DataDirectory: array [0 .. IMAGE_NUMBEROF_DIRECTORY_ENTRIES - 1] of TImageDataDirectory;
//     DataDirectories              : TImageDataDirectories;
// end;

  TImageOptionalHeader32 = packed record

     // Standard fields.
     Magic                    : uint16;   //  0x10b: PE32
                                          //  0x20b: PE32+
     MajorLinkerVersion       : uint8;
     MinorLinkerVersion       : uint8;
     SizeOfCode               : uint32;
     SizeOfInitializedData    : uint32;
     SizeOfUninitializedData  : uint32;
     AddressOfEntryPoint      : uint32;
     BaseOfCode               : uint32;

     BaseOfData               : uint32;   // PE32 only

     // NT additional fields.
     ImageBase                    : uint32;

     SectionAlignment             : uint32;
     FileAlignment                : uint32;
     MajorOperatingSystemVersion  : uint16;
     MinorOperatingSystemVersion  : uint16;
     MajorImageVersion            : uint16;
     MinorImageVersion            : uint16;
     MajorSubsystemVersion        : uint16;
     MinorSubsystemVersion        : uint16;
     Win32VersionValue            : uint32;
     SizeOfImage                  : uint32;
     SizeOfHeaders                : uint32;
     CheckSum                     : uint32;
     Subsystem                    : uint16;
     DllCharacteristics           : uint16;

     SizeOfStackReserve           : uint32;
     SizeOfStackCommit            : uint32;
     SizeOfHeapReserve            : uint32;
     SizeOfHeapCommit             : uint32;

     LoaderFlags                  : uint32;
     NumberOfRvaAndSizes          : uint32;

     //   DataDirectory: array [0 .. IMAGE_NUMBEROF_DIRECTORY_ENTRIES - 1] of TImageDataDirectory;
     DataDirectories              : TImageDataDirectories;
  end;
  PImageOptionalHeader32 = ^TImageOptionalHeader32;

  TImageOptionalHeader64 = packed record

     // Standard fields.
     Magic                    : uint16;   //  0x10b: PE32
                                          //  0x20b: PE32+
     MajorLinkerVersion       : uint8;
     MinorLinkerVersion       : uint8;
     SizeOfCode               : uint32;
     SizeOfInitializedData    : uint32;
     SizeOfUninitializedData  : uint32;
     AddressOfEntryPoint      : uint32;
     BaseOfCode               : uint32;

     // NT additional fields.
     ImageBase                    : uint64;

     SectionAlignment             : uint32;
     FileAlignment                : uint32;
     MajorOperatingSystemVersion  : uint16;
     MinorOperatingSystemVersion  : uint16;
     MajorImageVersion            : uint16;
     MinorImageVersion            : uint16;
     MajorSubsystemVersion        : uint16;
     MinorSubsystemVersion        : uint16;
     Win32VersionValue            : uint32;
     SizeOfImage                  : uint32;
     SizeOfHeaders                : uint32;
     CheckSum                     : uint32;
     Subsystem                    : uint16;
     DllCharacteristics           : uint16;

     SizeOfStackReserve           : uint64;
     SizeOfStackCommit            : uint64;
     SizeOfHeapReserve            : uint64;
     SizeOfHeapCommit             : uint64;

     LoaderFlags                  : uint32;
     NumberOfRvaAndSizes          : uint32;

     //   DataDirectory: array [0 .. IMAGE_NUMBEROF_DIRECTORY_ENTRIES - 1] of TImageDataDirectory;
     DataDirectories              : TImageDataDirectories;
  end;
  PImageOptionalHeader64 = ^TImageOptionalHeader64;

  TImageOptionalHeader = packed record
     case integer of
       32: (pe32: TImageOptionalHeader32);
       64: (pe64: TImageOptionalHeader64);
     end;


  implementation

  end.
