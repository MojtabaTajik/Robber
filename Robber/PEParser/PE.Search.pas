unit PE.Search;

interface

uses
  System.SysUtils,
  PE.Section;

{
  *
  * Search byte pattern in ASection starting from AOffset.
  * Result is True if found and false otherwise.
  * AOffset will be set to last position scanned.
  *
  * Each byte of AMask is AND'ed with source byte and compared to pattern.
  * AMask can be smaller than APattern (or empty), but cannot be bigger.
  *
  * ADirection can be negative or positive to choose search direction.
  * If it is 0 the only match checked.
  *
  * Example:
  *
  *              AA ?? BB should be represented like:
  *   APattern:  AA 00 BB
  *   AMask:     AA 00 BB
  *
  *              AA 00 BB should be represented like:
  *   APattern:  AA 00 BB
  *   AMask:     AA FF BB
  *
}
function SearchBytes(
  const ASection: TPESection;
  const APattern: array of byte;
  const AMask: array of byte;
  var AOffset: UInt32;
  ADirection: Integer
  ): boolean;

{
  * Check string contains valid pattern text and return number of elements on
  * success. Result is 0 if pattern text is invalid or string is empty.
}
function ValidatePattern(const S: string): Integer;

{
  * Convert string like AA??BB (or AA ?? BB)
  * to pattern          AA00BB
  * and mask            FF00FF
  *
  * String must not contain spaces.
  * Output length of Pattern and Mask is same.
}
function StringToPattern(
  const S: string;
  out Pattern: TBytes;
  out Mask: TBytes): boolean;

implementation

function MatchPattern(
  pSrc: pbyte;
  const APattern: array of byte;
  const AMask: array of byte
  ): boolean;
var
  MaskLeft: Integer;
  Mask: byte;
  i: Integer;
begin
  Result := True;

  MaskLeft := Length(AMask);
  for i := 0 to High(APattern) do
  begin
    if MaskLeft <> 0 then
      Mask := AMask[i]
    else
      Mask := $FF;

    if (pSrc[i] and Mask) <> APattern[i] then
    begin
      Result := False;
      break;
    end;

    if MaskLeft <> 0 then
      dec(MaskLeft);
  end;
end;

function SearchBytes;
var
  pSrc: pbyte;
  LastOffset: UInt32;
begin
  Result := False;

  if Length(APattern) = 0 then
    Exit;

  if (AOffset + Length(APattern)) > ASection.AllocatedSize then
    Exit;

  if ADirection < 0 then
    ADirection := -1
  else if ADirection > 0 then
    ADirection := 1;

  pSrc := @ASection.Mem[AOffset];
  LastOffset := ASection.AllocatedSize - Length(APattern);

  while AOffset <= LastOffset do
  begin
    Result := MatchPattern(pSrc, APattern, AMask);

    // Break if: found/no direction/at lower bound.
    if (Result) or (ADirection = 0) or ((ADirection < 0) and (AOffset = 0)) then
      break;

    // Next address/offset.
    inc(AOffset, ADirection);
    inc(pSrc, ADirection);
  end;
end;

function ValidatePattern(const S: string): Integer;
var
  i: Integer;
  ElementLen: Integer;
  c: char;
begin
  Result := 0;

  if S.IsEmpty then
    Exit;

  { Any element is 2 chars max }
  ElementLen := 0;

  i := 0;
  while i < S.Length do
  begin
    c := S.Chars[i];
    case c of
      '?':
        begin
          if (ElementLen = 0) or ((ElementLen < 2) and (S.Chars[i - 1] = '?')) then
            inc(ElementLen)
          else
            Exit(0);
        end;
      '0' .. '9', 'A' .. 'F', 'a' .. 'f':
        begin
          if (ElementLen = 0) or ((ElementLen < 2) and CharInSet(S.Chars[i - 1], ['0' .. '9', 'A' .. 'F', 'a' .. 'f'])) then
            inc(ElementLen)
          else
            Exit(0);
        end;
    end;

    inc(i);

    if (ElementLen <> 0) and ((i = S.Length) or (c = ' ')) then
      inc(Result);

    if c = ' ' then
      ElementLen := 0;
  end;
end;

function StringToPattern(
  const S: string;
  out Pattern: TBytes;
  out Mask: TBytes): boolean;
var
  i, hcn, masked: Integer;
  hc: array [0 .. 1] of byte;
  c: char;
  element, count: Integer;
begin
  count := ValidatePattern(S);
  if count = 0 then
    Exit(False);

  SetLength(Pattern, count);
  SetLength(Mask, count);

  element := 0;

  hcn := 0;
  hc[0] := 0;
  hc[1] := 0;
  masked := 0;

  i := 0;
  while i < S.Length do
  begin
    c := S.Chars[i];

    case c of
      '0' .. '9':
        begin
          hc[hcn] := Integer(c) - Integer('0');
          inc(hcn);
        end;
      'A' .. 'F':
        begin
          hc[hcn] := Integer(c) - Integer('A') + 10;
          inc(hcn);
        end;
      'a' .. 'f':
        begin
          hc[hcn] := Integer(c) - Integer('a') + 10;
          inc(hcn);
        end;
      '?':
        inc(masked);
    end;

    inc(i);

    if (i = S.Length) or (c = ' ') then
    begin
      case hcn of
        0:
          if masked <> 0 then
          begin
            Pattern[element] := 0;
            Mask[element] := 0;
            inc(element);
          end;
        1:
          begin
            Pattern[element] := hc[0];
            Mask[element] := $FF;
            inc(element);
          end;
        2:
          begin
            Pattern[element] := (hc[0] shl 4) or hc[1];
            Mask[element] := $FF;
            inc(element);
          end;
      end;

      hcn := 0;
      hc[0] := 0;
      hc[1] := 0;
      masked := 0;
    end;
  end;

  Exit(True);
end;

end.
