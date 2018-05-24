unit PE.Resources.Windows.Strings;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TStringBundleID = uint32;

  TResourceStringBundle = class
  public
    id: TStringBundleID;
    Strings: TStringList;

    function GetStringId(stringNumber: cardinal): cardinal;

    constructor Create(id: TStringBundleID);
    destructor Destroy; override;

    procedure LoadFromStream(Stream: TStream);
  end;

function BundleToStringId(bundleID: TStringBundleID): cardinal; inline;

// Parse string bundle.
function ParseStringResource(const Stream: TStream; bundleID: TStringBundleID): TResourceStringBundle;

implementation

{
  see
  https://msdn.microsoft.com/en-us/library/windows/desktop/aa381050
  http://blogs.msdn.com/b/oldnewthing/archive/2004/01/30/65013.aspx
}

// Bundle id to first string id in block of 16 strings.
function BundleToStringId(bundleID: TStringBundleID): cardinal;
begin
  if bundleID < 1 then
    raise Exception.Create('Wrong bundle id.');
  result := (bundleID - 1) * 16;
end;

{ TResourceStringBundle }

constructor TResourceStringBundle.Create(id: TStringBundleID);
begin
  self.id := id;
  self.Strings := TStringList.Create;
  self.Strings.Capacity := 16;
end;

destructor TResourceStringBundle.Destroy;
begin
  Strings.Free;
  inherited;
end;

function TResourceStringBundle.GetStringId(stringNumber: cardinal): cardinal;
begin
  result := BundleToStringId(id) + stringNumber;
end;

procedure TResourceStringBundle.LoadFromStream(Stream: TStream);
var
  dwLen: uint16;
  allocLen: integer;
  bytes: TBytes;
  str: string;
begin
  self.Strings.Clear;

  while Stream.Position < Stream.Size do
  begin
    if Stream.Read(dwLen, 2) <> 2 then
      raise Exception.Create('Failed to read string length.');

    if dwLen = 0 then
    begin
      continue;
    end;

    dwLen := dwLen * 2; // 2 bytes per char

    if length(bytes) < dwLen then
    begin
      allocLen := ((dwLen + 128) div 128) * 128;
      setlength(bytes, allocLen);
    end;

    if Stream.Read(bytes, dwLen) <> dwLen then
      raise Exception.Create('String read error.');

    str := TEncoding.Unicode.GetString(bytes, 0, dwLen);

    Strings.Add(str);
  end;
end;

function ParseStringResource(const Stream: TStream; bundleID: TStringBundleID): TResourceStringBundle;
begin
  result := TResourceStringBundle.Create(bundleID);
  try
    result.LoadFromStream(Stream);
  except
    result.Free;
    result := nil;
  end;
end;

end.
