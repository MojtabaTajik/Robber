unit PE.RTTI;

interface

uses
  System.Classes;

type
  TRecordFieldDesc = record
    Flags: uint32;
    FieldName: PChar;
  end;

  PRecordFieldDesc = ^TRecordFieldDesc;

  // TRttiReadFunc must return:
  // - OutFieldSize: size of field.
  // - OutReadSize size to read into field.
  TRttiFieldResolveProc = procedure(Desc: PRecordFieldDesc;
    OutFieldSize, OutReadWriteSize: PInteger; ud: pointer);

  TRttiOperation = (RttiRead, RttiWrite, RttiCalcSize);

  // MaxSize: -1 means no limit.
function RTTI_Process(Stream: TStream; Op: TRttiOperation; Buf: PByte;
  FieldDesc: PRecordFieldDesc; FieldDescCnt: integer; MaxSize: integer;
  ResolveProc: TRttiFieldResolveProc; ud: pointer): uint32;

implementation

{$IFDEF DIAG}

uses
  System.SysUtils;

procedure DbgLogData(Desc: PRecordFieldDesc; Stream: TStream;
  FieldSize: integer; IOSize: integer);
begin
  writeln(Format('"%s" @ %x FieldSize: %x IOSize: %x',
    [Desc.FieldName, Stream.Position, FieldSize, IOSize]));
end;
{$ENDIF}

function RTTI_Process;
var
  i: integer;
  FieldSize, ReadWriteSize, tmp: integer;
begin
  Result := 0;

  if (Buf = nil) or (FieldDesc = nil) or (FieldDescCnt = 0) or (MaxSize = 0)
  then
    exit;

  for i := 0 to FieldDescCnt - 1 do
  begin
    ResolveProc(FieldDesc, @FieldSize, @ReadWriteSize, ud);

{$IFDEF DIAG}
    DbgLogData(FieldDesc, Stream, FieldSize, ReadWriteSize);
{$ENDIF}
    if ReadWriteSize <> 0 then
    begin
      case Op of
        RttiRead:
          begin
            if ReadWriteSize < FieldSize then
              FillChar(Buf^, FieldSize, 0);
            tmp := Stream.Read(Buf^, ReadWriteSize);
          end;
        RttiWrite:
          tmp := Stream.Write(Buf^, ReadWriteSize);
        RttiCalcSize:
          tmp := ReadWriteSize;
      else
        tmp := ReadWriteSize;
      end;

      if tmp <> ReadWriteSize then
        break; // read error
{$IFDEF DIAG}
      case tmp of
        1:
          writeln(Format('= %x', [PByte(Buf)^]));
        2:
          writeln(Format('= %x', [PWord(Buf)^]));
        4:
          writeln(Format('= %x', [PCardinal(Buf)^]));
        8:
          writeln(Format('= %x', [PUint64(Buf)^]));
      end;
{$ENDIF}
    end;

    inc(Result, ReadWriteSize);
    inc(Buf, FieldSize);
    inc(FieldDesc);

{$WARN COMPARING_SIGNED_UNSIGNED OFF}
    if (MaxSize <> -1) and (Result >= MaxSize) then
      break;
{$WARN COMPARING_SIGNED_UNSIGNED ON}
  end;

end;

end.
