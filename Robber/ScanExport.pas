unit ScanExport;

// Centralised JSON / CSV serialisation for scan results.
//
// Both the GUI (fMain) and the CLI runner produce TScanResult records and
// need to render them identically. Keeping this logic in one place avoids
// drift in escaping rules, column ordering, and field selection between
// the two output paths.

interface

uses
  ScanThread, DLLHijack;

function HijackRateStr(Rate: THijackRate): string;
function BuildJSON(const Results: TArray<TScanResult>): string;
function BuildCSV(const Results: TArray<TScanResult>): string;

implementation

uses
  System.SysUtils, System.Classes, System.StrUtils, DLLSearchOrder;

function JSONEscape(const S: string): string;
begin
  Result := S
    .Replace('\', '\\')
    .Replace('"', '\"')
    .Replace(#13, '\r')
    .Replace(#10, '\n')
    .Replace(#9,  '\t');
end;

function CSVEscape(const S: string): string;
begin
  if S.Contains(',') or S.Contains('"') or S.Contains(#10) or S.Contains(#13) then
    Result := '"' + S.Replace('"', '""') + '"'
  else
    Result := S;
end;

function HijackRateStr(Rate: THijackRate): string;
begin
  case Rate of
    hrBest: Result := 'Best';
    hrGood: Result := 'Good';
    hrBad:  Result := 'Bad';
  else
    Result := '';
  end;
end;

function BoolStr(B: Boolean): string;
begin
  if B then Result := 'true' else Result := 'false';
end;

function CollectWritablePaths(const SearchOrder: TArray<TSearchEntry>): string;
var
  SO: TSearchEntry;
begin
  Result := '';
  for SO in SearchOrder do
    if SO.Writable then
    begin
      if Result <> '' then
        Result := Result + '; ';
      Result := Result + SO.Path;
    end;
end;

function BuildJSON(const Results: TArray<TScanResult>): string;
var
  SB: TStringBuilder;
  Res: TScanResult;
  DLL: TDLLScanInfo;
  SO: TSearchEntry;
  M: string;
  FirstRes, FirstDLL, FirstSO, FirstMethod: Boolean;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('[');
    FirstRes := True;

    for Res in Results do
    begin
      if not FirstRes then SB.AppendLine(',');
      FirstRes := False;

      SB.AppendLine('  {');
      SB.AppendLine(Format('    "path": "%s",',          [JSONEscape(Res.ExePath)]));
      SB.AppendLine(Format('    "fileSizeKB": %d,',      [Res.FileSize]));
      SB.AppendLine(Format('    "architecture": "%s",',  [IfThen(Res.IsX86, 'x86', 'x64')]));
      SB.AppendLine(Format('    "signed": %s,',          [BoolStr(Res.IsSigned)]));
      SB.AppendLine(Format('    "signer": "%s",',        [JSONEscape(Res.SignerCompany)]));
      SB.AppendLine(Format('    "hijackRate": "%s",',    [HijackRateStr(Res.HijackRate)]));
      SB.AppendLine(Format('    "executionLevel": "%s",',[JSONEscape(Res.ExecutionLevel)]));
      SB.AppendLine('    "dlls": [');

      FirstDLL := True;
      for DLL in Res.DLLs do
      begin
        if not FirstDLL then SB.AppendLine(',');
        FirstDLL := False;

        SB.AppendLine('      {');
        SB.AppendLine(Format('        "name": "%s",', [JSONEscape(DLL.Name)]));

        // Search order array
        SB.AppendLine('        "searchOrder": [');
        FirstSO := True;
        for SO in DLL.SearchOrder do
        begin
          if not FirstSO then SB.AppendLine(',');
          FirstSO := False;
          SB.Append(Format(
            '          {"path":"%s","label":"%s","writable":%s,"containsDLL":%s}',
            [JSONEscape(SO.Path), JSONEscape(SO.Label_),
             BoolStr(SO.Writable), BoolStr(SO.ContainsDLL)]));
        end;
        if Length(DLL.SearchOrder) > 0 then SB.AppendLine('');
        SB.AppendLine('        ],');

        // Methods array
        SB.AppendLine('        "methods": [');
        FirstMethod := True;
        for M in DLL.Methods do
        begin
          if not FirstMethod then SB.AppendLine(',');
          FirstMethod := False;
          SB.Append(Format('          "%s"', [JSONEscape(M)]));
        end;
        if Length(DLL.Methods) > 0 then SB.AppendLine('');
        SB.AppendLine('        ]');
        SB.Append('      }');
      end;

      if Length(Res.DLLs) > 0 then SB.AppendLine('');
      SB.AppendLine('    ]');
      SB.Append('  }');
    end;

    SB.AppendLine('');
    SB.AppendLine(']');

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function BuildCSV(const Results: TArray<TScanResult>): string;
var
  Lines: TStringList;
  Res: TScanResult;
  DLL: TDLLScanInfo;
  M, Row, WritablePaths: string;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('ExePath,FileSize,Architecture,Signed,Signer,HijackRate,UAC,DLL,WritableAttackPaths,Method');

    for Res in Results do
      for DLL in Res.DLLs do
      begin
        WritablePaths := CollectWritablePaths(DLL.SearchOrder);

        if Length(DLL.Methods) = 0 then
        begin
          Row := CSVEscape(Res.ExePath) + ',' +
                 IntToStr(Res.FileSize) + ',' +
                 IfThen(Res.IsX86, 'x86', 'x64') + ',' +
                 BoolStr(Res.IsSigned) + ',' +
                 CSVEscape(Res.SignerCompany) + ',' +
                 HijackRateStr(Res.HijackRate) + ',' +
                 Res.ExecutionLevel + ',' +
                 CSVEscape(DLL.Name) + ',' +
                 CSVEscape(WritablePaths) + ',';
          Lines.Add(Row);
        end
        else
          for M in DLL.Methods do
          begin
            Row := CSVEscape(Res.ExePath) + ',' +
                   IntToStr(Res.FileSize) + ',' +
                   IfThen(Res.IsX86, 'x86', 'x64') + ',' +
                   BoolStr(Res.IsSigned) + ',' +
                   CSVEscape(Res.SignerCompany) + ',' +
                   HijackRateStr(Res.HijackRate) + ',' +
                   Res.ExecutionLevel + ',' +
                   CSVEscape(DLL.Name) + ',' +
                   CSVEscape(WritablePaths) + ',' +
                   CSVEscape(M);
            Lines.Add(Row);
          end;
      end;

    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
