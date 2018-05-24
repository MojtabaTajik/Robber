{
  Unified Optional Header.
  Represents both 32 and 64 bit.
  Directories not included.
}

unit PE.Headers;

interface

uses
  System.Classes;

type

  { **********************************************************************************************************************
    * Comparision of optional headers
    **********************************************************************************************************************
    *  TImageOptionalHeader32 = packed record                    TImageOptionalHeader64 = packed record
    *
    *    // Standard fields.                                       // Standard fields.
    *    Magic                    : uint16;                        Magic                    : uint16;
    *
    *    MajorLinkerVersion       : uint8;                         MajorLinkerVersion       : uint8;
    *    MinorLinkerVersion       : uint8;                         MinorLinkerVersion       : uint8;
    *    SizeOfCode               : uint32;                        SizeOfCode               : uint32;
    *    SizeOfInitializedData    : uint32;                        SizeOfInitializedData    : uint32;
    *    SizeOfUninitializedData  : uint32;                        SizeOfUninitializedData  : uint32;
    *    AddressOfEntryPoint      : uint32;                        AddressOfEntryPoint      : uint32;
    *    BaseOfCode               : uint32;                        BaseOfCode               : uint32;
    *
    *    BaseOfData               : uint32;   // PE32 only
    *
    *    // NT additional fields.                                  // NT additional fields.
    *    ImageBase                    : uint32;                    ImageBase                    : uint64;
    *
    *    SectionAlignment             : uint32;                    SectionAlignment             : uint32;
    *    FileAlignment                : uint32;                    FileAlignment                : uint32;
    *    MajorOperatingSystemVersion  : uint16;                    MajorOperatingSystemVersion  : uint16;
    *    MinorOperatingSystemVersion  : uint16;                    MinorOperatingSystemVersion  : uint16;
    *    MajorImageVersion            : uint16;                    MajorImageVersion            : uint16;
    *    MinorImageVersion            : uint16;                    MinorImageVersion            : uint16;
    *    MajorSubsystemVersion        : uint16;                    MajorSubsystemVersion        : uint16;
    *    MinorSubsystemVersion        : uint16;                    MinorSubsystemVersion        : uint16;
    *    Win32VersionValue            : uint32;                    Win32VersionValue            : uint32;
    *    SizeOfImage                  : uint32;                    SizeOfImage                  : uint32;
    *    SizeOfHeaders                : uint32;                    SizeOfHeaders                : uint32;
    *    CheckSum                     : uint32;                    CheckSum                     : uint32;
    *    Subsystem                    : uint16;                    Subsystem                    : uint16;
    *    DllCharacteristics           : uint16;                    DllCharacteristics           : uint16;
    *
    *    SizeOfStackReserve           : uint32;                    SizeOfStackReserve           : uint64;
    *    SizeOfStackCommit            : uint32;                    SizeOfStackCommit            : uint64;
    *    SizeOfHeapReserve            : uint32;                    SizeOfHeapReserve            : uint64;
    *    SizeOfHeapCommit             : uint32;                    SizeOfHeapCommit             : uint64;
    *
    *    LoaderFlags                  : uint32;                    LoaderFlags                  : uint32;
    *    NumberOfRvaAndSizes          : uint32;                    NumberOfRvaAndSizes          : uint32;
    *
    *    DataDirectories              : TImageDataDirectories;     DataDirectories              : TImageDataDirectories;
    * end;                                                      end;
    **********************************************************************************************************************
  }

  UIntCommon = uint64;

  TPEOptionalHeader = packed record

    // Standard fields.
    Magic: uint16;

    MajorLinkerVersion: uint8;
    MinorLinkerVersion: uint8;
    SizeOfCode: uint32;
    SizeOfInitializedData: uint32;
    SizeOfUninitializedData: uint32;
    AddressOfEntryPoint: uint32;
    BaseOfCode: uint32;

    // PE32 only
    BaseOfData: uint32;

    // NT additional fields.
    ImageBase: UIntCommon;

    SectionAlignment: uint32;
    FileAlignment: uint32;
    MajorOperatingSystemVersion: uint16;
    MinorOperatingSystemVersion: uint16;
    MajorImageVersion: uint16;
    MinorImageVersion: uint16;
    MajorSubsystemVersion: uint16;
    MinorSubsystemVersion: uint16;
    Win32VersionValue: uint32;
    SizeOfImage: uint32;
    SizeOfHeaders: uint32;
    CheckSum: uint32;
    Subsystem: uint16;
    DllCharacteristics: uint16;

    SizeOfStackReserve: UIntCommon;
    SizeOfStackCommit: UIntCommon;
    SizeOfHeapReserve: UIntCommon;
    SizeOfHeapCommit: UIntCommon;

    LoaderFlags: uint32;
    NumberOfRvaAndSizes: uint32;

    // Return number of bytes read.
    function ReadFromStream(Stream: TStream; ImageBits: uint32; MaxSize: integer): uint32;

    // Return number of bytes written.
    function WriteToStream(Stream: TStream; ImageBits: uint32; MaxSize: integer): uint32;

    // Calcualte size of normal optional header.
    function CalcSize(ImageBits: uint32): uint32;

  end;

  PPEOptionalHeader = ^TPEOptionalHeader;

implementation

uses
  System.SysUtils,
  PE.RTTI;

const
  RF_SIZE8       = 1 shl 0;
  RF_SIZE16      = 1 shl 1;
  RF_SIZE32      = 1 shl 2;
  RF_SIZE64      = 1 shl 3;
  RF_SIZEMACHINE = 1 shl 4; // Size is (32 or 64) in 64 bit slot.
  RF_PE32        = 1 shl 5; // Present in 32-bit image.
  RF_PE64        = 1 shl 6; // Present in 64-bit image.

  RF_PE3264 = RF_PE32 or RF_PE64;

  COMMON_08      = RF_SIZE8 or RF_PE3264;
  COMMON_16      = RF_SIZE16 or RF_PE3264;
  COMMON_32      = RF_SIZE32 or RF_PE3264;
  COMMON_MACHINE = RF_SIZEMACHINE or RF_PE3264;

const
  MACHINE_DWORD_SIZE = -1;

  OptionalHeaderFieldDesc: packed array [0 .. 29] of TRecordFieldDesc =
    (
    (Flags: COMMON_16; FieldName: 'Magic'),

    (Flags: COMMON_08; FieldName: 'MajorLinkerVersion'),
    (Flags: COMMON_08; FieldName: 'MinorLinkerVersion'),
    (Flags: COMMON_32; FieldName: 'SizeOfCode'),
    (Flags: COMMON_32; FieldName: 'SizeOfInitializedData'),
    (Flags: COMMON_32; FieldName: 'SizeOfUninitializedData'),
    (Flags: COMMON_32; FieldName: 'AddressOfEntryPoint'),
    (Flags: COMMON_32; FieldName: 'BaseOfCode'),

    (Flags: RF_SIZE32 or RF_PE32; FieldName: 'BaseOfData'),

    (Flags: COMMON_MACHINE; FieldName: 'ImageBase'),

    (Flags: COMMON_32; FieldName: 'SectionAlignment'),
    (Flags: COMMON_32; FieldName: 'FileAlignment'),
    (Flags: COMMON_16; FieldName: 'MajorOperatingSystemVersion'),
    (Flags: COMMON_16; FieldName: 'MinorOperatingSystemVersion'),
    (Flags: COMMON_16; FieldName: 'MajorImageVersion'),
    (Flags: COMMON_16; FieldName: 'MinorImageVersion'),
    (Flags: COMMON_16; FieldName: 'MajorSubsystemVersion'),
    (Flags: COMMON_16; FieldName: 'MinorSubsystemVersion'),
    (Flags: COMMON_32; FieldName: 'Win32VersionValue'),
    (Flags: COMMON_32; FieldName: 'SizeOfImage'),
    (Flags: COMMON_32; FieldName: 'SizeOfHeaders'),
    (Flags: COMMON_32; FieldName: 'CheckSum'),
    (Flags: COMMON_16; FieldName: 'Subsystem'),
    (Flags: COMMON_16; FieldName: 'DllCharacteristics'),

    (Flags: COMMON_MACHINE; FieldName: 'SizeOfStackReserve'),
    (Flags: COMMON_MACHINE; FieldName: 'SizeOfStackCommit'),
    (Flags: COMMON_MACHINE; FieldName: 'SizeOfHeapReserve'),
    (Flags: COMMON_MACHINE; FieldName: 'SizeOfHeapCommit'),

    (Flags: COMMON_32; FieldName: 'LoaderFlags'),
    (Flags: COMMON_32; FieldName: 'NumberOfRvaAndSizes')
    );

type
  TPECtx = record
    ImageBits: uint32;
  end;

  PPECtx = ^TPECtx;

procedure ResolveProc(Desc: PRecordFieldDesc; OutFieldSize, OutEffectiveSize: PInteger; ud: pointer);
begin
  OutFieldSize^ := 0;
  OutEffectiveSize^ := 0;

  // OutFieldSize (mandatory)
  if ((Desc^.Flags and RF_SIZE8) <> 0) then
    OutFieldSize^ := 1
  else if ((Desc^.Flags and RF_SIZE16) <> 0) then
    OutFieldSize^ := 2
  else if ((Desc^.Flags and RF_SIZE32) <> 0) then
    OutFieldSize^ := 4
  else if ((Desc^.Flags and RF_SIZE64) <> 0) then
    OutFieldSize^ := 8
  else if ((Desc^.Flags and RF_SIZEMACHINE) <> 0) then
    OutFieldSize^ := SizeOf(UIntCommon)
  else
    raise Exception.Create('Unsupported image.');

  if ((Desc^.Flags and RF_PE3264) = RF_PE32) and (PPECtx(ud)^.ImageBits <> 32) then
    exit;
  if ((Desc^.Flags and RF_PE3264) = RF_PE64) and (PPECtx(ud)^.ImageBits <> 64) then
    exit;

  // OutEffectiveSize
  if ((Desc^.Flags and RF_SIZE8) <> 0) then
    OutEffectiveSize^ := 1
  else if ((Desc^.Flags and RF_SIZE16) <> 0) then
    OutEffectiveSize^ := 2
  else if ((Desc^.Flags and RF_SIZE32) <> 0) then
    OutEffectiveSize^ := 4
  else if ((Desc^.Flags and RF_SIZE64) <> 0) then
    OutEffectiveSize^ := 8
  else if ((Desc^.Flags and RF_SIZEMACHINE) <> 0) then
    OutEffectiveSize^ := PPECtx(ud)^.ImageBits div 8
  else
    raise Exception.Create('Unsupported image.');

end;

{ TPEOptionalHeader }

function TPEOptionalHeader.CalcSize(ImageBits: uint32): uint32;
var
  ctx: TPECtx;
begin
  ctx.ImageBits := ImageBits;

  Result := RTTI_Process(nil, RttiCalcSize, @Self,
    @OptionalHeaderFieldDesc[0], Length(OptionalHeaderFieldDesc),
    -1,
    ResolveProc,
    @ctx);
end;

function TPEOptionalHeader.ReadFromStream;
var
  ctx: TPECtx;
begin
  // Not all fields can be read, so must clear whole structure.
  FillChar(Self, SizeOf(Self), 0);

  ctx.ImageBits := ImageBits;

  Result := RTTI_Process(Stream, RttiRead, @Self,
    @OptionalHeaderFieldDesc[0], Length(OptionalHeaderFieldDesc),
    MaxSize,
    ResolveProc,
    @ctx);
end;

function TPEOptionalHeader.WriteToStream;
var
  ctx: TPECtx;
begin
  ctx.ImageBits := ImageBits;

  Result := RTTI_Process(Stream, RttiWrite, @Self,
    @OptionalHeaderFieldDesc[0], Length(OptionalHeaderFieldDesc),
    MaxSize,
    ResolveProc,
    @ctx);
end;

end.
