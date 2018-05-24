{
  Module to convert constants of PE.Types.FileHeader to string.
}
unit PE.FileHeaderToStr;

interface

uses
  PE.Image,
  PE.Types.FileHeader;

function MachineToStr(PE: TPEImage): string;

implementation

function MachineToStr(PE: TPEImage): string;
begin
  case PE.FileHeader^.Machine of
    IMAGE_FILE_MACHINE_UNKNOWN:
      Result := ''; // The contents of this field are assumed to be applicable to any machine type
    IMAGE_FILE_MACHINE_AM33:
      Result := 'Matsushita AM33';
    IMAGE_FILE_MACHINE_AMD64:
      Result := 'x64';
    IMAGE_FILE_MACHINE_ARM:
      Result := 'ARM little endian';
    IMAGE_FILE_MACHINE_ARMV7:
      Result := 'ARMv7 (or higher) Thumb mode only';
    IMAGE_FILE_MACHINE_EBC:
      Result := 'EFI byte code';
    IMAGE_FILE_MACHINE_I386:
      Result := 'Intel 386 and compatible processors';
    IMAGE_FILE_MACHINE_IA64:
      Result := 'Intel Itanium processor family';
    IMAGE_FILE_MACHINE_M32R:
      Result := 'Mitsubishi M32R little endian';
    IMAGE_FILE_MACHINE_MIPS16:
      Result := 'MIPS16';
    IMAGE_FILE_MACHINE_MIPSFPU:
      Result := 'MIPS with FPU';
    IMAGE_FILE_MACHINE_MIPSFPU16:
      Result := 'MIPS16 with FPU';
    IMAGE_FILE_MACHINE_POWERPC:
      Result := 'Power PC little endian';
    IMAGE_FILE_MACHINE_POWERPCFP:
      Result := 'Power PC with floating point support';
    IMAGE_FILE_MACHINE_R4000:
      Result := 'MIPS little endian';
    IMAGE_FILE_MACHINE_SH3:
      Result := 'Hitachi SH3';
    IMAGE_FILE_MACHINE_SH3DSP:
      Result := 'Hitachi SH3 DSP';
    IMAGE_FILE_MACHINE_SH4:
      Result := 'Hitachi SH4';
    IMAGE_FILE_MACHINE_SH5:
      Result := 'Hitachi SH5';
    IMAGE_FILE_MACHINE_THUMB:
      Result := 'ARM or Thumb (“interworking”)';
    IMAGE_FILE_MACHINE_WCEMIPSV2:
      Result := 'MIPS little-endian WCE v2';
    else
      Result := 'Unknown Machine';
  end;
end;

end.
