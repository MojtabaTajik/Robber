unit NullStream;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TNullStream = class(TStream)
  private
    FPosition: int64;
    FSize: int64;
  protected
    procedure SetSize(NewSize: Integer); override;
  public
    function Seek(const Offset: int64; Origin: TSeekOrigin): int64; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

implementation

{ TNullStream }

procedure TNullStream.SetSize(NewSize: Integer);
begin
  FSize := NewSize;
end;

function TNullStream.Seek(const Offset: int64; Origin: TSeekOrigin): int64;
begin
  case Origin of
    soBeginning:
      FPosition := Offset;
    soCurrent:
      Inc(FPosition, Offset);
    soEnd:
      FPosition := FSize + Offset;
  end;
  Result := FPosition;
end;

function TNullStream.Read(var Buffer; Count: Integer): Longint;
begin
  raise Exception.Create('Null stream cannot read');
end;

function TNullStream.Write(const Buffer; Count: Integer): Longint;
var
  pos: int64;
begin
  if (FPosition >= 0) and (Count >= 0) then
  begin
    pos := FPosition + Count;
    if pos > FSize then
      FSize := pos;
    FPosition := pos;
    exit(Count);
  end;
  exit(0);
end;

end.
