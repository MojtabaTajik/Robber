{
  This is unit to parse PEID signature base text file.
}
unit PE.ID;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Image,
  PE.Section,
  PE.Search;

type
  TPEIDSignature = record
  public
    Text: string;
    Pattern: TBytes;
    Mask: TBytes;
  end;

  TPEIDSignatureList = TList<TPEIDSignature>;

  { Class which contain PEID signatures. }
  TPEIDSignatures = class
  private
    FSigsEpOnly: TPEIDSignatureList;
    FSigsAnywhere: TPEIDSignatureList;
  public
    constructor Create;
    destructor Destroy; override;

    property SigsEpOnly: TPEIDSignatureList read FSigsEpOnly;
    property SigsAnywhere: TPEIDSignatureList read FSigsAnywhere;
  end;

  {
    Try to load signatures.
    Returns nil if failed or created class on success.
  }
function PeidLoadSignatures(const SigFileName: string): TPEIDSignatures;

{
  Scan section at RVA for Signatures and return Found signature names.
}
procedure PeidScanSection(
  PE: TPEImage;
  RVA: TRVA;
  Signatures: TPEIDSignatureList;
  Found: TStringList);

procedure PeidScan(
  PE: TPEImage;
  Signatures: TPEIDSignatures;
  Found: TStringList);

implementation

{ For string like "key = value" return value }
function GetStrPairValue(const Line: string): string;
var
  a: integer;
begin
  a := Line.IndexOf('=');
  if a < 0 then
    result := ''
  else
    result := Line.Substring(a + 1).Trim;
end;

function PeidLoadSignatures(const SigFileName: string): TPEIDSignatures;
var
  sl: TStringList;
  i: integer;
  Line, PatternText: string;
  sig: TPEIDSignature;
  EntryPointOnly: Boolean;
begin
  result := nil;

  if not FileExists(SigFileName) then
    exit;

  { Do so simple parsing by loading into string list and parsing each line. }
  sl := TStringList.Create;
  try
    sl.LoadFromFile(SigFileName);
    i := 0;
    while i < sl.count do
    begin
      Line := sl[i];

      { Skip empty lines and comments }
      if Line.IsEmpty or Line.StartsWith(';') then
      begin
        inc(i);
        continue;
      end;

      { Expect signature text like [Some text] }
      if Line.StartsWith('[') and Line.EndsWith(']') then
      begin
        { This is 3-line signature descriptor. Check if we have 3 lines. }
        if i + 3 > sl.count then
        begin
          break;
        end;

        { Check format of next 2 lines }
        if
          (not sl[i + 1].StartsWith('signature = ')) or
          (not sl[i + 2].StartsWith('ep_only = ')) then
        begin
          break;
        end;

        { Check pattern format is correct and get fields. }
        PatternText := GetStrPairValue(sl[i + 1]);

        if not StringToPattern(PatternText, sig.Pattern, sig.Mask) then
        begin
          break;
        end;

        sig.Text := Line.Substring(1, Line.Length - 2);

        EntryPointOnly := GetStrPairValue(sl[i + 2]).ToLower = 'true';

        { Got at least one signature, add it to list }
        if not Assigned(result) then
          result := TPEIDSignatures.Create;

        if EntryPointOnly then
          result.FSigsEpOnly.Add(sig)
        else
          result.FSigsAnywhere.Add(sig);

        inc(i, 3);
      end;
    end;

    if Assigned(result) then
    begin
      result.FSigsEpOnly.TrimExcess;
      result.FSigsAnywhere.TrimExcess;
    end;
  finally
    sl.Free;
  end;
end;

procedure PeidScanSection(
  PE: TPEImage;
  RVA: TRVA;
  Signatures: TPEIDSignatureList;
  Found: TStringList);
var
  sec: TPESection;
  sig: TPEIDSignature;
  offset: uint32;
begin
  if not PE.RVAToSec(RVA, @sec) then
    exit;

  for sig in Signatures do
  begin
    offset := RVA - sec.RVA;
    if SearchBytes(sec, sig.Pattern, sig.Mask, offset, 0) then
    begin
      Found.Add(sig.Text);
    end;
  end;
end;

procedure PeidScan(
  PE: TPEImage;
  Signatures: TPEIDSignatures;
  Found: TStringList);
var
  sec: TPESection;
  sig: TPEIDSignature;
  offset: uint32;
begin
  if PE.Sections.count = 0 then
    exit;

  { First try EPOnly signatures }
  PeidScanSection(PE, PE.EntryPointRVA, Signatures.SigsEpOnly, Found);

  sec := PE.Sections.First;

  for sig in Signatures.SigsAnywhere do
  begin
    offset := 0;
    while SearchBytes(sec, sig.Pattern, sig.Mask, offset, 1) do
    begin
      inc(offset);
      Found.Add(sig.Text);
    end;
  end;
end;

{ TPEIDSignatures }

constructor TPEIDSignatures.Create;
begin
  inherited Create;
  FSigsEpOnly := TPEIDSignatureList.Create;
  FSigsAnywhere := TPEIDSignatureList.Create;
end;

destructor TPEIDSignatures.Destroy;
begin
  FSigsEpOnly.Free;
  FSigsAnywhere.Free;
  inherited;
end;

end.
