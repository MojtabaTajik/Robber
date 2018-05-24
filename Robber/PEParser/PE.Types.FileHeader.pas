unit PE.Types.FileHeader;

interface

// 2.3.1. Machine Types
const
  IMAGE_FILE_MACHINE_UNKNOWN          = $0;     // The contents of this field are assumed to be applicable to any machine type
  IMAGE_FILE_MACHINE_AM33             = $1D3;   // Matsushita AM33
  IMAGE_FILE_MACHINE_AMD64            = $8664;  // x64
  IMAGE_FILE_MACHINE_ARM              = $1C0;   // ARM little endian
  IMAGE_FILE_MACHINE_ARMV7            = $1C4;   // ARMv7 (or higher) Thumb mode only
  IMAGE_FILE_MACHINE_EBC              = $EBC;   // EFI byte code
  IMAGE_FILE_MACHINE_I386             = $14C;   // Intel 386 or later processors and compatible processors
  IMAGE_FILE_MACHINE_IA64             = $200;   // Intel Itanium processor family
  IMAGE_FILE_MACHINE_M32R             = $9041;  // Mitsubishi M32R little endian
  IMAGE_FILE_MACHINE_MIPS16           = $266;   // MIPS16
  IMAGE_FILE_MACHINE_MIPSFPU          = $366;   // MIPS with FPU
  IMAGE_FILE_MACHINE_MIPSFPU16        = $466;   // MIPS16 with FPU
  IMAGE_FILE_MACHINE_POWERPC          = $1F0;   // Power PC little endian
  IMAGE_FILE_MACHINE_POWERPCFP        = $1F1;   // Power PC with floating point support
  IMAGE_FILE_MACHINE_R4000            = $166;   // MIPS little endian
  IMAGE_FILE_MACHINE_SH3              = $1A2;   // Hitachi SH3
  IMAGE_FILE_MACHINE_SH3DSP           = $1A3;   // Hitachi SH3 DSP
  IMAGE_FILE_MACHINE_SH4              = $1A6;   // Hitachi SH4
  IMAGE_FILE_MACHINE_SH5              = $1A8;   // Hitachi SH5
  IMAGE_FILE_MACHINE_THUMB            = $1C2;   // ARM or Thumb (“interworking”)
  IMAGE_FILE_MACHINE_WCEMIPSV2        = $169;   // MIPS little-endian WCE v2

// 2.3.2. Characteristics
  IMAGE_FILE_RELOCS_STRIPPED	        = $0001;  // Image only, Windows CE, and Windows NT® and later. This indicates that the file does not contain base relocations and must therefore be loaded at its preferred base address. If the base address is not available, the loader reports an error. The default behavior of the linker is to strip base relocations from executable (EXE) files.
  IMAGE_FILE_EXECUTABLE_IMAGE	        = $0002;  // Image only. This indicates that the image file is valid and can be run. If this flag is not set, it indicates a linker error.
  IMAGE_FILE_LINE_NUMS_STRIPPED	      = $0004;	// COFF line numbers have been removed. This flag is deprecated and should be zero.
  IMAGE_FILE_LOCAL_SYMS_STRIPPED	    = $0008;	// COFF symbol table entries for local symbols have been removed. This flag is deprecated and should be zero.
  IMAGE_FILE_AGGRESSIVE_WS_TRIM	      = $0010;	// Obsolete. Aggressively trim working set. This flag is deprecated for Windows 2000 and later and must be zero.
  IMAGE_FILE_LARGE_ADDRESS_AWARE	    = $0020;	// Application can handle > 2 GB addresses.
//                                      $0040	  // This flag is reserved for future use.
  IMAGE_FILE_BYTES_REVERSED_LO	      = $0080;  // Little endian: the least significant bit (LSB) precedes the most significant bit (MSB) in memory. This flag is deprecated and should be zero.
  IMAGE_FILE_32BIT_MACHINE	          = $0100;  // Machine is based on a 32-bit-word architecture.
  IMAGE_FILE_DEBUG_STRIPPED	          = $0200;  // Debugging information is removed from the image file.
  IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP	= $0400;  // If the image is on removable media, fully load it and copy it to the swap file.
  IMAGE_FILE_NET_RUN_FROM_SWAP	      = $0800;  // If the image is on network media, fully load it and copy it to the swap file.
  IMAGE_FILE_SYSTEM	                  = $1000;  // The image file is a system file, not a user program.
  IMAGE_FILE_DLL	                    = $2000;  // The image file is a dynamic-link library (DLL). Such files are considered executable files for almost all purposes, although they cannot be directly run.
  IMAGE_FILE_UP_SYSTEM_ONLY	          = $4000;  // The file should be run only on a uniprocessor machine.
  IMAGE_FILE_BYTES_REVERSED_HI      	= $8000;  // Big endian: the MSB precedes the LSB in memory. This flag is deprecated and should be zero.


// 2.4. Optional Header (Image Only)
  PE_MAGIC_PE32     = $10b;
  PE_MAGIC_PE32PLUS = $20b;

// 2.4.2. Optional Header Windows-Specific Fields (Image Only)
// Windows Subsystem
  IMAGE_SUBSYSTEM_UNKNOWN	                = 0;	//  An unknown subsystem
  IMAGE_SUBSYSTEM_NATIVE	                = 1;	//  Device drivers and native Windows processes
  IMAGE_SUBSYSTEM_WINDOWS_GUI	            = 2;	//  The Windows graphical user interface (GUI) subsystem
  IMAGE_SUBSYSTEM_WINDOWS_CUI	            = 3;	//  The Windows character subsystem
  IMAGE_SUBSYSTEM_POSIX_CUI	              = 7;	//  The Posix character subsystem
  IMAGE_SUBSYSTEM_WINDOWS_CE_GUI	        = 9;  //	Windows CE
  IMAGE_SUBSYSTEM_EFI_APPLICATION	        = 10;	//  An Extensible Firmware Interface (EFI) application
  IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER = 11; //	An EFI driver with boot services
  IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER      = 12; //	An EFI driver with run-time services
  IMAGE_SUBSYSTEM_EFI_ROM	                = 13; //	An EFI ROM image
  IMAGE_SUBSYSTEM_XBOX	                  = 14; //	XBOX

// DLL Characteristics
//RESERVED_0x0001                                 = $0001;  // Reserved, must be zero.
//RESERVED_0x0002                                 = $0002;  // Reserved, must be zero.
//RESERVED_0x0004                                 = $0004;  // Reserved, must be zero.
//RESERVED_0x0008                                 = $0008;  // Reserved, must be zero.
  IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE          = $0040;  // DLL can be relocated at load time.
  IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY       = $0080;  // Code Integrity checks are enforced.
  IMAGE_DLL_CHARACTERISTICS_NX_COMPAT             = $0100;  // Image is NX compatible.
  IMAGE_DLLCHARACTERISTICS_NO_ISOLATION           = $0200;  // Isolation aware, but do not isolate the image.
  IMAGE_DLLCHARACTERISTICS_NO_SEH                 = $0400;  // Does not use structured exception (SE) handling. No SE handler may be called in this image.
  IMAGE_DLLCHARACTERISTICS_NO_BIND                = $0800;  // Do not bind the image.
//RESERVED_0x1000                                 = $1000;  // Reserved, must be zero.
  IMAGE_DLLCHARACTERISTICS_WDM_DRIVER             = $2000;  // A WDM driver.
  IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE  = $8000;  // Terminal Server aware.


type
  TImageFileHeader = packed record
    Machine: uint16;
    NumberOfSections: uint16;
    TimeDateStamp: uint32;
    PointerToSymbolTable: uint32;
    NumberOfSymbols: uint32;
    SizeOfOptionalHeader: uint16;
    Characteristics: uint16;
  end;

  PImageFileHeader = ^TImageFileHeader;

implementation

end.
