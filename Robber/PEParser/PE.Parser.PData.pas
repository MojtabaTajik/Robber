(*
  .pdata section parser
*)
unit PE.Parser.PData;

interface

uses
  PE.Image,
  PE.Section,
  PE.Sections,
  PE.Types.FileHeader,
  PE.Types.Sections;

{ http://msdn.microsoft.com/en-us/library/ms864326.aspx }

type
  PDATA_EH = packed record
    // OS Versions: Windows CE .NET 4.0 and later.
    // Header: no public definition.
    pHandler: uint32;     // Address of the exception handler for the function.
    pHandlerData: uint32; // Address of the exception handler data record for the function.
  end;

  { 5.5. The .pdata Section }

type
  { 32-bit MIPS images }
  TPDATA_MIPS32 = packed record
    // The VA of the corresponding function.
    BeginAddress: uint32;

    // The VA of the end of the function.
    EndAddress: uint32;

    // The pointer to the exception handler to be executed.
    ExceptionHandler: uint32;

    // The pointer to additional information to be passed to the handler.
    HandlerData: uint32;

    // The VA of the end of the function’s prolog.
    PrologEndAddress: uint32;
  end;

  PPDATA_MIPS32 = ^TPDATA_MIPS32;

  { ARM, PowerPC, SH3 and SH4 Windows CE platforms }
  TPDATA_ARM = packed record
  strict private
    _BeginAddress: uint32;
    _DATA: uint32;
  public
    // The VA of the corresponding function.
    function BeginAddress: uint32; inline;

    // 8 bit: The number of instructions in the function’s prolog.
    function PrologLength: uint8; inline;

    // 22 bit: The number of instructions in the function.
    function FunctionLength: uint32; inline;

    // 1 bit: If set, the function consists of 32-bit instructions.
    // If clear, the function consists of 16-bit instructions.
    function Is32Bit: boolean; inline;

    // 1 bit: If set, an exception handler exists for the function.
    // Otherwise, no exception handler exists.
    function IsExceptionFlag: boolean; inline;

    function IsEmpty: boolean; inline;

  end;

  PPDATA_ARM = ^TPDATA_ARM;

  { For x64 and Itanium platforms }
  TPDATA_x64 = packed record
    BeginAddress: uint32;      // The RVA of the corresponding function.
    EndAddress: uint32;        // The RVA of the end of the function.
    UnwindInformation: uint32; // The RVA of the unwind information.
  end;

  PPDATA_x64 = ^TPDATA_x64;

  { For the ARMv7 platform }
  TPDATA_ARMv7 = packed record
    // The RVA of the corresponding function.
    BeginAddress: uint32;

    // The RVA of the unwind information, including function length.
    // If the low 2 bits are non-zero, then this word represents a compacted
    // inline form of the unwind information, including function length.
    UnwindInformation: uint32;
  end;

  PPDATA_ARMv7 = ^TPDATA_ARMv7;

type
  TPDATAType = (pdata_NONE, pdata_MIPS32, pdata_ARM, pdata_x64, pdata_ARMv7);

  TPDATAItem = record
    function IsEmpty: boolean; inline;
    procedure Clear; inline;
  public
    case TPDATAType of
      pdata_NONE:
        (BeginAddress: uint32); // common field, can be RVA or VA
      pdata_MIPS32:
        (MIPS32: TPDATA_MIPS32);
      pdata_ARM:
        (ARM: TPDATA_ARM);
      pdata_x64:
        (x64: TPDATA_x64);
      pdata_ARMv7:
        (ARMv7: TPDATA_ARMv7);
  end;

type
  TPDATAItems = array of TPDATAItem;

  // Parses .PDATA section (if exists) and returns count of elements found
function ParsePDATA(PE: TPEImage; out &Type: TPDATAType; out Items: TPDATAItems): integer;

implementation

{ TPDATA_ARM }

function TPDATA_ARM.BeginAddress: uint32;
begin
  result := _BeginAddress;
end;

function TPDATA_ARM.FunctionLength: uint32;
begin
  result := (_DATA shr 8) and ((1 shl 22) - 1);
end;

function TPDATA_ARM.Is32Bit: boolean;
begin
  result := _DATA and (1 shl 30) <> 0;
end;

function TPDATA_ARM.IsEmpty: boolean;
begin
  result := (_BeginAddress = 0) or (_DATA = 0);
end;

function TPDATA_ARM.IsExceptionFlag: boolean;
begin
  result := _DATA and (1 shl 31) <> 0;
end;

function TPDATA_ARM.PrologLength: uint8;
begin
  result := byte(_DATA);
end;

{ ParsePDATA }

function ParsePDATA(PE: TPEImage; out &Type: TPDATAType; out Items: TPDATAItems): integer;
var
  sec: TPESection;
  i, Cnt, Size, Actual: uint32;
begin
  SetLength(Items, 0);

  Size := 0;
  &Type := pdata_NONE;

  sec := PE.Sections.FindByName('.pdata');

  if
    (sec <> nil) and
    (sec.RawSize > 0) and
    ((sec.flags and IMAGE_SCN_CNT_INITIALIZED_DATA) <> 0) and
    ((sec.flags and IMAGE_SCN_MEM_READ) <> 0) and
    (PE.SeekRVA(sec.RVA)) then
  begin
    // Load.
    case PE.FileHeader^.Machine of
      IMAGE_FILE_MACHINE_ARM, IMAGE_FILE_MACHINE_THUMB:
        begin
          Size := sizeof(TPDATA_ARM);
          &Type := pdata_ARM;
        end;
      IMAGE_FILE_MACHINE_AMD64:
        begin
          Size := sizeof(TPDATA_x64);
          &Type := pdata_x64;
        end;
    end;

    if &Type <> pdata_NONE then
    begin
      Cnt := sec.VirtualSize div Size;
      Actual := 0;
      SetLength(Items, Cnt); // pre-allocate
      if Cnt <> 0 then
      begin
        for i := 0 to Cnt - 1 do
        begin
          if (not PE.ReadEx(@Items[i], Size)) or (Items[i].IsEmpty) then
            break;
          inc(Actual);
        end;
      end;
      if Actual <> Cnt then
        SetLength(Items, Actual); // trim
    end;
  end;

  result := Length(Items);
end;

{ TPDATAItem }

procedure TPDATAItem.Clear;
begin
  FillChar(self, sizeof(self), 0);
end;

function TPDATAItem.IsEmpty: boolean;
begin
  result := self.BeginAddress = 0;
end;

end.
