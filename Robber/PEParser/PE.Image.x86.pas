{
  *
  * Class for X86, X86-64 specifics.
  *
}
unit PE.Image.x86;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  PE.Common,
  PE.Image,
  PE.Section;

type
  // Buf points to data which should be matched.
  // Set MatchedSize to size of matched sequence. If nothing matched don't set it.
  // VA is address to be matched.
  // Size is size left in scanned region you can check starting from VA.
  TPatternMatchFunc = reference to procedure(VA: TVA; Size: integer; Buf: PByte; var MatchedSize: integer);

  TPEImageX86 = class(TPEImage)
  protected
    // Find relative jump or call in section, e.g e8,x,x,x,x or e9,x,x,x,x.
    // List must be created before passing it to the function.
    // Found VAs will be appended to list.
    function FindRelativeJumpInternal(
      const Sec: TPESection;
      ByteOpcode: Byte;
      TargetVA: TVA;
      const List: TList<TVA>): boolean;
  public
    function FindRelativeJump(
      const Sec: TPESection;
      TargetVA: TVA;
      const List: TList<TVA>): boolean;

    function FindRelativeCall(
      const Sec: TPESection;
      TargetVA: TVA;
      const List: TList<TVA>): boolean;

    // Fill Count bytes at VA with nops (0x90).
    // Result is number of nops written.
    function Nop(VA: TVA; Count: integer = 1): UInt32;

    // Nop range.
    // BeginVA: inclusive
    // EndVA: exclusive
    function NopRange(BeginVA, EndVA: TVA): UInt32; inline;

    // Nop Call or Jump.
    function NopCallOrJump(VA: TVA): boolean;

    // Write call or jump, like:
    // E8/E9 xx xx xx xx
    // IsCall: True - call, False - jump.
    function WriteRelCallOrJump(SrcVA, DstVA: TVA; IsCall: boolean): boolean;

    // Perform custom pattern matching scan for Sec section.
    // All found addresses are stored in List (if it is not nil, otherwise
    // user must handle it manually).
    // PatternMatchFunc function used to match pattern.
    // VA0, Size define range (optional). Whole section is scanned by default.
    function ScanRange(
      const Sec: TPESection;
      PatternMatchFunc: TPatternMatchFunc;
      const List: TList<TVA> = nil;
      VA: TVA = 0;
      Size: integer = 0
      ): boolean;
  end;

implementation

const
  OPCODE_NOP      = $90;
  OPCODE_CALL_REL = $E8;
  OPCODE_JUMP_REL = $E9;

  { TPEImageX86 }

function TPEImageX86.FindRelativeCall(
  const Sec: TPESection;
  TargetVA: TVA;
  const List: TList<TVA>): boolean;
begin
  Result := FindRelativeJumpInternal(Sec, OPCODE_CALL_REL, TargetVA, List);
end;

function TPEImageX86.FindRelativeJump(
  const Sec: TPESection;
  TargetVA: TVA;
  const List: TList<TVA>): boolean;
begin
  Result := FindRelativeJumpInternal(Sec, OPCODE_JUMP_REL, TargetVA, List);
end;

function TPEImageX86.FindRelativeJumpInternal(
  const Sec: TPESection;
  ByteOpcode: Byte;
  TargetVA: TVA;
  const List: TList<TVA>): boolean;
var
  curVa, VA0, VA1, tstVa: TVA;
  delta: int32;
  opc: Byte;
begin
  Result := False;

  VA0 := RVAToVA(Sec.RVA);
  VA1 := RVAToVA(Sec.GetEndRVA - SizeOf(ByteOpcode) - SizeOf(delta));

  if not SeekVA(VA0) then
    exit(False);

  while self.PositionVA <= VA1 do
  begin
    curVa := self.PositionVA;

    // get opcode
    if Read(@opc, SizeOf(ByteOpcode)) <> SizeOf(ByteOpcode) then
      exit;
    if opc = ByteOpcode then
    // on found probably jmp/call
    begin
      delta := int32(ReadUInt32);
      tstVa := curVa + SizeOf(ByteOpcode) + SizeOf(delta) + delta;
      if tstVa = TargetVA then
      begin // hit
        List.Add(curVa);
        Result := True; // at least 1 result is ok
      end
      else
      begin
        if not SeekVA(curVa + SizeOf(ByteOpcode)) then
          exit;
      end;
    end;
  end;
end;

function TPEImageX86.Nop(VA: TVA; Count: integer): UInt32;
begin
  Result := Sections.FillMemory(VAToRVA(VA), Count, OPCODE_NOP);
end;

function TPEImageX86.NopRange(BeginVA, EndVA: TVA): UInt32;
begin
  if EndVA > BeginVA then
    Result := Nop(BeginVA, EndVA - BeginVA)
  else
    Result := 0;
end;

function TPEImageX86.ScanRange(
  const Sec: TPESection;
  PatternMatchFunc: TPatternMatchFunc;
  const List: TList<TVA>;
  VA: TVA;
  Size: integer): boolean;
var
  Buf: PByte;
  MatchedSize: integer;
begin
  // Define range.
  if VA = 0 then
    VA := RVAToVA(Sec.RVA);
  if Size = 0 then
    Size := Sec.VirtualSize;

  // Start scan at VA0.
  Buf := self.VAToMem(VA);
  if Buf = nil then
    exit(False); // such address not found

  while Size > 0 do
  begin
    MatchedSize := 0;
    PatternMatchFunc(VA, Size, Buf, MatchedSize);
    if MatchedSize <> 0 then
    begin
      if Assigned(List) then
        List.Add(VA);
    end
    else
      MatchedSize := 1;

    inc(Buf, MatchedSize);
    inc(VA, MatchedSize);
    dec(Size, MatchedSize);
  end;

  exit(True);
end;

function TPEImageX86.NopCallOrJump(VA: TVA): boolean;
begin
  Result := Sections.FillMemoryEx(VAToRVA(VA), 5, True, OPCODE_NOP) = 5;
end;

function TPEImageX86.WriteRelCallOrJump(SrcVA, DstVA: TVA; IsCall: boolean): boolean;
type
  TJump = packed record
    Opcode: Byte;
    delta: integer;
  end;
var
  jmp: TJump;

begin
  if IsCall then
    jmp.Opcode := OPCODE_CALL_REL
  else
    jmp.Opcode := OPCODE_JUMP_REL;
  jmp.delta := DstVA - (SrcVA + SizeOf(TJump));
  self.PositionVA := SrcVA;
  Result := self.WriteEx(@jmp, SizeOf(TJump));
end;

end.
