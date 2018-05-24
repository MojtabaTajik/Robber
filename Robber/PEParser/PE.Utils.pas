unit PE.Utils;

interface

// When writing padding use PADDINGX string instead of zeros.
{$DEFINE WRITE_PADDING_STRING}


uses
  System.Classes,
  System.SysUtils,

  PE.Common;

function StreamRead(AStream: TStream; var Buf; Count: longint): boolean; inline;
function StreamPeek(AStream: TStream; var Buf; Count: longint): boolean; inline;
function StreamWrite(AStream: TStream; const Buf; Count: longint): boolean; inline;

// Read 0-terminated 1-byte string.
function StreamReadStringA(AStream: TStream; var S: string): boolean;

// Read 0-terminated 2-byte string
function StreamReadStringW(AStream: TStream; var S: string): boolean;

// Write string and return number of bytes written.
// If AlignAfter isn't 0 zero bytes will be written to align it up to AlignAfter value.
function StreamWriteString(AStream: TStream; const S: string; Encoding: TEncoding; AlignAfter: integer = 0): uint32;
// Write ANSI string and return number of bytes written.
function StreamWriteStringA(AStream: TStream; const S: string; AlignAfter: integer = 0): uint32;

const
  PATTERN_PADDINGX: array [0 .. 7] of AnsiChar = ('P', 'A', 'D', 'D', 'I', 'N', 'G', 'X');

  // Write pattern to stream. If Pattern is nil or size of patter is 0 then
  // nulls are written (default).
procedure WritePattern(AStream: TStream; Count: uint32; Pattern: Pointer = nil; PatternSize: integer = 0);

function StreamSeek(AStream: TStream; Offset: TFileOffset): boolean; inline;
function StreamSkip(AStream: TStream; Count: integer = 1): boolean; inline;

// Seek from current position to keep alignment.
function StreamSeekAlign(AStream: TStream; Align: integer): boolean; inline;

// Try to seek Offset and insert padding if Offset < stream Size.
procedure StreamSeekWithPadding(AStream: TStream; Offset: TFileOffset);

function Min(const A, B: uint64): uint64; inline; overload;
function Min(const A, B, C: uint64): uint64; inline; overload;

function Max(const A, B: uint64): uint64; inline;

function AlignUp(Value: uint64; Align: uint32): uint64; inline;
function AlignDown(Value: uint64; Align: uint32): uint64; inline;

function IsAlphaNumericString(const S: String): boolean;

function CompareRVA(A, B: TRVA): integer; inline;

function ReplaceSpecialSymobls(const source: string): string;

implementation

{ Stream }

function StreamRead(AStream: TStream; var Buf; Count: longint): boolean;
begin
  Result := AStream.Read(Buf, Count) = Count;
end;

function StreamPeek(AStream: TStream; var Buf; Count: longint): boolean; inline;
var
  Read: integer;
begin
  Read := AStream.Read(Buf, Count);
  AStream.Seek(-Read, soFromCurrent);
  Result := Read = Count;
end;

function StreamWrite(AStream: TStream; const Buf; Count: longint): boolean;
begin
  Result := AStream.Write(Buf, Count) = Count;
end;

function StreamReadStringA(AStream: TStream; var S: string): boolean;
var
  C: byte;
begin
  S := '';
  while True do
    if AStream.Read(C, SizeOf(C)) <> SizeOf(C) then
      break
    else if (C = 0) then
      exit(True)
    else
      S := S + Char(C);
  exit(False);
end;

function StreamReadStringW(AStream: TStream; var S: string): boolean;
var
  C: word;
begin
  S := '';
  while True do
    if AStream.Read(C, SizeOf(C)) <> SizeOf(C) then
      break
    else if (C = 0) then
      exit(True)
    else
      S := S + Char(C);
  exit(False);
end;

function StreamWriteString(AStream: TStream; const S: string; Encoding: TEncoding; AlignAfter: integer): uint32;
var
  Bytes: TBytes;
begin
  Bytes := Encoding.GetBytes(S);
  Result := AStream.Write(Bytes, Length(Bytes));

  if AlignAfter <> 0 then
  begin
    // Number of bytes left to write to be aligned.
    AlignAfter := AlignAfter - (AStream.Size mod AlignAfter);
    WritePattern(AStream, AlignAfter, nil, 0);
  end;
end;

function StreamWriteStringA(AStream: TStream; const S: string; AlignAfter: integer): uint32;
begin
  Result := StreamWriteString(AStream, S, TEncoding.ANSI, AlignAfter);
end;

procedure WritePattern(AStream: TStream; Count: uint32; Pattern: Pointer; PatternSize: integer);
var
  p: pbyte;
  i: integer;
begin
  if Count = 0 then
    exit;

  if Assigned(Pattern) and (PatternSize > 0) then
  begin
    p := GetMemory(Count);
    if PatternSize = 1 then
      FillChar(p^, Count, pbyte(Pattern)^)
    else
    begin
      for i := 0 to Count - 1 do
        p[i] := pbyte(Pattern)[i mod PatternSize];
    end;
  end
  else
  begin
    p := AllocMem(Count); // filled with nulls
  end;

  try
    AStream.Write(p^, Count);
  finally
    FreeMem(p);
  end;
end;

function StreamSeek(AStream: TStream; Offset: TFileOffset): boolean;
begin
  Result := AStream.Seek(Offset, TSeekOrigin.soBeginning) = Offset;
end;

function StreamSkip(AStream: TStream; Count: integer): boolean; inline;
var
  Offset: TFileOffset;
begin
  Offset := AStream.Position + Count;
  Result := AStream.Seek(Offset, TSeekOrigin.soBeginning) = Offset;
end;

function StreamSeekAlign(AStream: TStream; Align: integer): boolean;
var
  m: integer;
  pos: TFileOffset;
begin
  if Align in [0, 1] then
    exit(True); // don't need alignment
  pos := AStream.Position;
  m := pos mod Align;
  if m = 0 then
    exit(True);        // already aligned
  inc(pos, Align - m); // next aligned position
  Result := AStream.Seek(pos, TSeekOrigin.soBeginning) = pos;
end;

procedure StreamSeekWithPadding(AStream: TStream; Offset: TFileOffset);
begin
  if Offset <= AStream.Size then
  begin
    AStream.Seek(Offset, TSeekOrigin.soBeginning);
    exit;
  end;
  // Insert padding if need.
  AStream.Seek(AStream.Size, TSeekOrigin.soBeginning);
  WritePattern(AStream, Offset - AStream.Size, nil, 0);
end;

{ Min / Max }

function Min(const A, B: uint64): uint64;
begin
  if A < B then
    exit(A)
  else
    exit(B);
end;

function Min(const A, B, C: uint64): uint64;
begin
  Result := Min(Min(A, B), C);
end;

function Max(const A, B: uint64): uint64;
begin
  if A > B then
    exit(A)
  else
    exit(B);
end;

{ AlignUp }

function AlignUp(Value: uint64; Align: uint32): uint64;
var
  d, m: uint32;
begin
  d := Value div Align;
  m := Value mod Align;
  if m = 0 then
    Result := Value
  else
    Result := (d + 1) * Align;
end;

function AlignDown(Value: uint64; Align: uint32): uint64;
begin
  Result := (Value div Align) * Align;
end;

function IsAlphaNumericString(const S: String): boolean;
const
  ALLOWED_CHARS = ['0' .. '9', 'A' .. 'Z', 'a' .. 'z'];
var
  C: Char;
begin
  for C in S do
    if not CharInSet(c, ALLOWED_CHARS) then
      exit(False);
  exit(True);
end;

function CompareRVA(A, B: TRVA): integer;
begin
  if A > B then
    exit(1)
  else if A < B then
    exit(-1)
  else
    exit(0);
end;

function ReplaceSpecialSymobls(const source: string): string;
begin
  Result := source.
    Replace(#10, '\n').
    Replace(#13, '\r');
end;

end.
