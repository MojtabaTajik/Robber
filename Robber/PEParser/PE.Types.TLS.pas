unit PE.Types.TLS;

interface

uses
  PE.Common;

// 5.7.1. The TLS Directory
type
  TTLSDirectory32 = packed record
    RawDataStartVA: uint32;     // The starting address of the TLS template. The template is a block of data that is used to initialize TLS data. The system copies all of this data each time a thread is created, so it must not be corrupted. Note that this address is not an RVA; it is an address for which there should be a base relocation in the .reloc section.
    RawDataEndVA: uint32;       // The address of the last byte of the TLS, except for the zero fill. As with the Raw Data Start VA field, this is a VA, not an RVA.
    AddressofIndex: uint32;     // The location to receive the TLS index, which the loader assigns. This location is in an ordinary data section, so it can be given a symbolic name that is accessible to the program.
    AddressofCallbacks: uint32; // The pointer to an array of TLS callback functions. The array is null-terminated, so if no callback function is supported, this field points to 4 bytes set to zero. For information about the prototype for these functions, see section 6.7.2, “TLS Callback Functions.”
    SizeofZeroFill: uint32;     // The size in bytes of the template, beyond the initialized data delimited by the Raw Data Start VA and Raw Data End VA fields. The total template size should be the same as the total size of TLS data in the image file. The zero fill is the amount of data that comes after the initialized nonzero data.
    Characteristics: uint32;    // Reserved for possible future use by TLS flags.
  end;


  TTLSDirectory64 = packed record
    RawDataStartVA: uint64;     // The starting address of the TLS template. The template is a block of data that is used to initialize TLS data. The system copies all of this data each time a thread is created, so it must not be corrupted. Note that this address is not an RVA; it is an address for which there should be a base relocation in the .reloc section.
    RawDataEndVA: uint64;       // The address of the last byte of the TLS, except for the zero fill. As with the Raw Data Start VA field, this is a VA, not an RVA.
    AddressofIndex: uint64;     // The location to receive the TLS index, which the loader assigns. This location is in an ordinary data section, so it can be given a symbolic name that is accessible to the program.
    AddressofCallbacks: uint64; // The pointer to an array of TLS callback functions. The array is null-terminated, so if no callback function is supported, this field points to 4 bytes set to zero. For information about the prototype for these functions, see section 6.7.2, “TLS Callback Functions.”
    SizeofZeroFill: uint32;     // The size in bytes of the template, beyond the initialized data delimited by the Raw Data Start VA and Raw Data End VA fields. The total template size should be the same as the total size of TLS data in the image file. The zero fill is the amount of data that comes after the initialized nonzero data.
    Characteristics: uint32;    // Reserved for possible future use by TLS flags.
  end;

  TTLSDirectory = packed record
    case integer of
      32: (tls32: TTLSDirectory32);
      64: (tls64: TTLSDirectory64);
    end;

  PIMAGE_TLS_CALLBACK = procedure(DllHandle: pointer; Reason: dword; Reserved: pointer); stdcall;

implementation

end.
