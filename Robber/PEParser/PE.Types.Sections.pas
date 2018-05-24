unit PE.Types.Sections;

interface

{$I 'PE.Types.Sections.inc'}


type
  TImageSectionHeader = packed record
  private
    FName: packed array [0 .. IMAGE_SIZEOF_SHORT_NAME - 1] of AnsiChar;
    FVirtualSize: uint32;
    FRVA: uint32;
    FSizeOfRawData: uint32;
    FPointerToRawData: uint32;
    FPointerToRelocations: uint32;
    FPointerToLinenumbers: uint32;
    FNumberOfRelocations: uint16;
    FNumberOfLinenumbers: uint16;
    FFlags: uint32;
  private
    function GetName: string;
    procedure SetName(const Value: string); // length trimmed to 8 chars
  public
    procedure Clear; inline;

    property Name: string read GetName write SetName;
    property VirtualSize: uint32 read FVirtualSize write FVirtualSize;
    property RVA: uint32 read FRVA write FRVA;
    property SizeOfRawData: uint32 read FSizeOfRawData write FSizeOfRawData;
    property PointerToRawData: uint32 read FPointerToRawData write FPointerToRawData;
    property Flags: uint32 read FFlags write FFlags;
  end;

  PImageSectionHeader = ^TImageSectionHeader;

implementation

{ TImageSectionHeader }

procedure TImageSectionHeader.Clear;
begin
  fillchar(self, sizeof(self), 0);
end;

function TImageSectionHeader.GetName: string;
var
  i: Integer;
begin
  i := 0;
  while (i < IMAGE_SIZEOF_SHORT_NAME) and (FName[i] <> #0) do
    inc(i);

  if i = 0 then
    exit('');

  setlength(result, i);

  dec(i);

  while i >= 0 do
  begin
    result[low(result) + i] := char(FName[i]);
    dec(i);
  end;
end;

procedure TImageSectionHeader.SetName(const Value: string);
var
  i, len: Integer;
begin
  i := 0;
  len := length(Value);

  while i < len do
  begin
    FName[i] := AnsiChar(Value[low(Value) + i]);
    inc(i);
  end;

  while i < IMAGE_SIZEOF_SHORT_NAME do
  begin
    FName[i] := #0;
    inc(i);
  end;
end;

end.
