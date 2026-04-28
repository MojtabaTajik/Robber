unit CLIRunner;

{
  CLI mode: Robber.exe --path <dir> [options] [--output file]

  Options:
    --path <dir>               Directory to scan (required)
    --output <file>            Output file (.json or .csv). Default: stdout JSON
    --image-type any|x86|x64  Filter by architecture
    --sign any|signed          Filter by signing status
    --rate any|best|good|bad   Filter by hijack rate
    --write-perm               Only include dirs with write permission
    --best-dll-count <n>       Threshold for Best rating  (default 2)
    --best-exe-size  <n>       Threshold KB for Best      (default 10240)
    --good-dll-count <n>       Threshold for Good rating  (default 5)
    --good-exe-size  <n>       Threshold KB for Good      (default 51200)
}

interface

function IsCLIMode: Boolean;
procedure RunCLI;

implementation

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, System.Types,
  System.Classes, System.Generics.Collections, System.StrUtils,
  DLLHijack, DigitalSignature, UAC;

// ---------------------------------------------------------------------------
// Console I/O
// ---------------------------------------------------------------------------

var
  GConsoleAttached: Boolean = False;

procedure EnsureConsole;
begin
  if not GConsoleAttached then
  begin
    GConsoleAttached := AttachConsole(ATTACH_PARENT_PROCESS) or (AllocConsole <> 0);
  end;
end;

procedure WriteStd(Handle: DWORD; const S: string);
var
  hOut: THandle;
  Bytes: TBytes;
  Written: DWORD;
begin
  hOut := GetStdHandle(Handle);
  if (hOut = 0) or (hOut = INVALID_HANDLE_VALUE) then Exit;
  Bytes := TEncoding.UTF8.GetBytes(S);
  if Length(Bytes) > 0 then
    WriteFile(hOut, Bytes[0], Length(Bytes), Written, nil);
end;

procedure Out(const S: string);   begin WriteStd(STD_OUTPUT_HANDLE, S + #10); end;
procedure Err(const S: string);   begin WriteStd(STD_ERROR_HANDLE,  S + #10); end;

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

function GetArg(const Key: string; const Default: string = ''): string;
var
  i: Integer;
begin
  for i := 1 to ParamCount - 1 do
    if SameText(ParamStr(i), '--' + Key) then
      Exit(ParamStr(i + 1));
  Result := Default;
end;

function HasFlag(const Key: string): Boolean;
var
  i: Integer;
begin
  for i := 1 to ParamCount do
    if SameText(ParamStr(i), '--' + Key) then
      Exit(True);
  Result := False;
end;

function IsCLIMode: Boolean;
begin
  Result := HasFlag('path') or HasFlag('help') or HasFlag('h');
end;

// ---------------------------------------------------------------------------
// Options
// ---------------------------------------------------------------------------

type
  TCLIOptions = record
    ScanPath: string;
    OutputFile: string;
    ImageTypeFilter: Integer;
    SignFilter: Integer;
    RateFilter: Integer;
    WritePermFilter: Integer;
    BestDLLCount: Integer;
    BestExeSize: Integer;
    GoodDLLCount: Integer;
    GoodExeSize: Integer;
  end;

procedure PrintUsage;
begin
  Out('');
  Out('Robber - DLL Hijack Scanner');
  Out('');
  Out('Usage:');
  Out('  Robber.exe --path <dir> [options]');
  Out('');
  Out('Options:');
  Out('  --path <dir>               Directory to scan (required)');
  Out('  --output <file>            Output file (.json or .csv). Default: stdout JSON');
  Out('  --image-type any|x86|x64  Filter by architecture (default: any)');
  Out('  --sign any|signed          Filter by signing status (default: any)');
  Out('  --rate any|best|good|bad   Filter by hijack rate (default: any)');
  Out('  --write-perm               Only include dirs with write permission');
  Out('  --best-dll-count <n>       Best rating DLL threshold (default: 2)');
  Out('  --best-exe-size <n>        Best rating size KB threshold (default: 10240)');
  Out('  --good-dll-count <n>       Good rating DLL threshold (default: 5)');
  Out('  --good-exe-size <n>        Good rating size KB threshold (default: 51200)');
  Out('  --help                     Show this help');
  Out('');
end;

function ParseOptions(out Opts: TCLIOptions): Boolean;
var
  S: string;
begin
  Result := False;
  Opts := Default(TCLIOptions);

  Opts.ScanPath := GetArg('path');
  if Opts.ScanPath = '' then
  begin
    Err('Error: --path is required');
    PrintUsage;
    Exit;
  end;
  if not DirectoryExists(Opts.ScanPath) then
  begin
    Err('Error: directory not found: ' + Opts.ScanPath);
    Exit;
  end;

  Opts.OutputFile := GetArg('output');

  S := LowerCase(GetArg('image-type', 'any'));
  if S = 'x86' then Opts.ImageTypeFilter := 1
  else if S = 'x64' then Opts.ImageTypeFilter := 2
  else Opts.ImageTypeFilter := 0;

  S := LowerCase(GetArg('sign', 'any'));
  if S = 'signed' then Opts.SignFilter := 1
  else Opts.SignFilter := 0;

  S := LowerCase(GetArg('rate', 'any'));
  if S = 'best' then Opts.RateFilter := 1
  else if S = 'good' then Opts.RateFilter := 2
  else if S = 'bad' then Opts.RateFilter := 3
  else Opts.RateFilter := 0;

  Opts.WritePermFilter := IfThen(HasFlag('write-perm'), 1, 0);
  Opts.BestDLLCount    := StrToIntDef(GetArg('best-dll-count', '2'),     2);
  Opts.BestExeSize     := StrToIntDef(GetArg('best-exe-size',  '10240'), 10240);
  Opts.GoodDLLCount    := StrToIntDef(GetArg('good-dll-count', '5'),     5);
  Opts.GoodExeSize     := StrToIntDef(GetArg('good-exe-size',  '51200'), 51200);

  Result := True;
end;

// ---------------------------------------------------------------------------
// Filters (mirror of ScanThread logic)
// ---------------------------------------------------------------------------

function SkipByRate(Rate: THijackRate; Filter: Integer): Boolean;
begin
  case Filter of
    1: Result := Rate <> hrBest;
    2: Result := Rate <> hrGood;
    3: Result := Rate <> hrBad;
  else
    Result := False;
  end;
end;

function SkipByImageType(IsX86: Boolean; Filter: Integer): Boolean;
begin
  case Filter of
    1: Result := not IsX86;
    2: Result := IsX86;
  else
    Result := False;
  end;
end;

function SkipBySign(IsSigned: Boolean; Filter: Integer): Boolean;
begin
  if Filter = 1 then Result := not IsSigned
  else Result := False;
end;

function SkipByWritePerm(const FilePath: string; Filter: Integer): Boolean;
const
  TempFile = 'RobberWriteCheck.txt';
var
  TempPath: string;
  FS: TFileStream;
begin
  if Filter = 0 then Exit(False);
  TempPath := TPath.Combine(TPath.GetDirectoryName(FilePath), TempFile);
  try
    FS := TFile.Create(TempPath);
    try Result := False; finally FS.Free; TFile.Delete(TempPath); end;
  except
    Result := True;
  end;
end;

// ---------------------------------------------------------------------------
// System DLL filter (same logic as ScanThread)
// ---------------------------------------------------------------------------

function BuildSystemDirs: TArray<string>;
var
  Buf: array[0..MAX_PATH] of Char;
  W: string;
begin
  GetWindowsDirectory(Buf, MAX_PATH);
  W := IncludeTrailingPathDelimiter(Buf);
  Result := [W + 'System32\', W + 'SysWOW64\', W + 'System\'];
end;

procedure StripSystemDLLs(DLLs: TStrings; const SysDirs: TArray<string>);
var
  i: Integer;
  Dir: string;
  Found: Boolean;
begin
  for i := DLLs.Count - 1 downto 0 do
  begin
    Found := False;
    for Dir in SysDirs do
      if FileExists(Dir + DLLs[i]) then begin Found := True; Break; end;
    if Found then DLLs.Delete(i);
  end;
end;

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

type
  TDLLInfo = record
    Name: string;
    Methods: TArray<string>;
  end;

  TScanHit = record
    ExePath: string;
    FileSize: Cardinal;
    IsX86: Boolean;
    IsSigned: Boolean;
    SignerCompany: string;
    HijackRate: THijackRate;
    ExecutionLevel: string;
    DLLs: TArray<TDLLInfo>;
  end;

function RateStr(R: THijackRate): string;
begin
  case R of
    hrBest: Result := 'Best';
    hrGood: Result := 'Good';
    hrBad:  Result := 'Bad';
  else
    Result := '';
  end;
end;

// ---------------------------------------------------------------------------
// Scan
// ---------------------------------------------------------------------------

function RunScan(const Opts: TCLIOptions): TArray<TScanHit>;
var
  FileList: TStringDynArray;
  EachFile, DLLName: string;
  PEFile: TDLLHijack;
  Sig: TDigitalSignature;
  ImportDLLs, Methods: TStringList;
  IsSigned: Boolean;
  Rate: THijackRate;
  Hit: TScanHit;
  DLLInf: TDLLInfo;
  DLLList: TList<TDLLInfo>;
  Hits: TList<TScanHit>;
  SysDirs: TArray<string>;
  i, Total: Integer;
begin
  SysDirs := BuildSystemDirs;
  Hits := TList<TScanHit>.Create;
  try
    FileList := TDirectory.GetFiles(Opts.ScanPath, '*.exe',
      TSearchOption.soAllDirectories);
    Total := Length(FileList);

    for i := 0 to Total - 1 do
    begin
      EachFile := FileList[i];
      Err(Format('[%d/%d] %s', [i + 1, Total, ExtractFileName(EachFile)]));

      try
        ImportDLLs := TStringList.Create;
        PEFile := TDLLHijack.Create(EachFile);
        Sig := TDigitalSignature.Create(EachFile);
        try
          PEFile.GetHijackableImportedDLL(ImportDLLs);
          StripSystemDLLs(ImportDLLs, SysDirs);
          if ImportDLLs.Count = 0 then Continue;

          Rate := PEFile.GetHijackRate(Opts.BestDLLCount, Opts.BestExeSize,
                                        Opts.GoodDLLCount, Opts.GoodExeSize);

          if SkipByRate(Rate, Opts.RateFilter) then Continue;
          if SkipByImageType(PEFile.IsX86Image, Opts.ImageTypeFilter) then Continue;

          IsSigned := Sig.IsCodeSigned;
          if SkipBySign(IsSigned, Opts.SignFilter) then Continue;
          if SkipByWritePerm(EachFile, Opts.WritePermFilter) then Continue;

          Hit.ExePath        := EachFile;
          Hit.FileSize       := PEFile.GetFileSize;
          Hit.IsX86          := PEFile.IsX86Image;
          Hit.IsSigned       := IsSigned;
          Hit.SignerCompany  := Sig.SignerCompany;
          Hit.HijackRate     := Rate;
          Hit.ExecutionLevel := GetExecutionLevel(EachFile);

          Methods := TStringList.Create;
          DLLList := TList<TDLLInfo>.Create;
          try
            for DLLName in ImportDLLs do
            begin
              Methods.Clear;
              PEFile.GetDLLMethods(DLLName, Methods);
              DLLInf.Name := DLLName;
              SetLength(DLLInf.Methods, Methods.Count);
              var j: Integer;
              for j := 0 to Methods.Count - 1 do
                DLLInf.Methods[j] := Methods[j];
              DLLList.Add(DLLInf);
            end;
            Hit.DLLs := DLLList.ToArray;
          finally
            Methods.Free;
            DLLList.Free;
          end;

          Hits.Add(Hit);
        finally
          Sig.Free;
          ImportDLLs.Free;
          PEFile.Free;
        end;
      except
        // Skip unreadable files
      end;
    end;

    Result := Hits.ToArray;
  finally
    Hits.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Serializers
// ---------------------------------------------------------------------------

function JSONEsc(const S: string): string;
begin
  Result := S
    .Replace('\', '\\').Replace('"', '\"')
    .Replace(#13, '\r').Replace(#10, '\n').Replace(#9, '\t');
end;

function CSVEsc(const S: string): string;
begin
  if S.Contains(',') or S.Contains('"') or S.Contains(#10) or S.Contains(#13) then
    Result := '"' + S.Replace('"', '""') + '"'
  else
    Result := S;
end;

function BuildJSON(const Hits: TArray<TScanHit>): string;
var
  SB: TStringBuilder;
  Hit: TScanHit;
  DLL: TDLLInfo;
  M: string;
  FirstHit, FirstDLL, FirstMethod: Boolean;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('[');
    FirstHit := True;
    for Hit in Hits do
    begin
      if not FirstHit then SB.AppendLine(',');
      FirstHit := False;
      SB.AppendLine('  {');
      SB.AppendLine(Format('    "path": "%s",',         [JSONEsc(Hit.ExePath)]));
      SB.AppendLine(Format('    "fileSizeKB": %d,',     [Hit.FileSize]));
      SB.AppendLine(Format('    "architecture": "%s",', [IfThen(Hit.IsX86, 'x86', 'x64')]));
      SB.AppendLine(Format('    "signed": %s,',         [IfThen(Hit.IsSigned, 'true', 'false')]));
      SB.AppendLine(Format('    "signer": "%s",',       [JSONEsc(Hit.SignerCompany)]));
      SB.AppendLine(Format('    "hijackRate": "%s",',     [RateStr(Hit.HijackRate)]));
      SB.AppendLine(Format('    "executionLevel": "%s",', [JSONEsc(Hit.ExecutionLevel)]));
      SB.AppendLine('    "dlls": [');
      FirstDLL := True;
      for DLL in Hit.DLLs do
      begin
        if not FirstDLL then SB.AppendLine(',');
        FirstDLL := False;
        SB.AppendLine('      {');
        SB.AppendLine(Format('        "name": "%s",', [JSONEsc(DLL.Name)]));
        SB.AppendLine('        "methods": [');
        FirstMethod := True;
        for M in DLL.Methods do
        begin
          if not FirstMethod then SB.AppendLine(',');
          FirstMethod := False;
          SB.Append(Format('          "%s"', [JSONEsc(M)]));
        end;
        if Length(DLL.Methods) > 0 then SB.AppendLine('');
        SB.AppendLine('        ]');
        SB.Append('      }');
      end;
      if Length(Hit.DLLs) > 0 then SB.AppendLine('');
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

function BuildCSV(const Hits: TArray<TScanHit>): string;
var
  Lines: TStringList;
  Hit: TScanHit;
  DLL: TDLLInfo;
  M, Row: string;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('ExePath,FileSize,Architecture,Signed,Signer,HijackRate,UAC,DLL,Method');
    for Hit in Hits do
      for DLL in Hit.DLLs do
      begin
        if Length(DLL.Methods) = 0 then
        begin
          Lines.Add(
            CSVEsc(Hit.ExePath) + ',' + IntToStr(Hit.FileSize) + ',' +
            IfThen(Hit.IsX86, 'x86', 'x64') + ',' +
            IfThen(Hit.IsSigned, 'true', 'false') + ',' +
            CSVEsc(Hit.SignerCompany) + ',' + RateStr(Hit.HijackRate) + ',' +
            Hit.ExecutionLevel + ',' +
            CSVEsc(DLL.Name) + ',');
        end
        else
          for M in DLL.Methods do
          begin
            Row :=
              CSVEsc(Hit.ExePath) + ',' + IntToStr(Hit.FileSize) + ',' +
              IfThen(Hit.IsX86, 'x86', 'x64') + ',' +
              IfThen(Hit.IsSigned, 'true', 'false') + ',' +
              CSVEsc(Hit.SignerCompany) + ',' + RateStr(Hit.HijackRate) + ',' +
              Hit.ExecutionLevel + ',' +
              CSVEsc(DLL.Name) + ',' + CSVEsc(M);
            Lines.Add(Row);
          end;
      end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

procedure RunCLI;
var
  Opts: TCLIOptions;
  Hits: TArray<TScanHit>;
  Output, Ext: string;
  IsCSV: Boolean;
begin
  EnsureConsole;

  if HasFlag('help') or HasFlag('h') then
  begin
    PrintUsage;
    Exit;
  end;

  if not ParseOptions(Opts) then
    Exit;

  Err(Format('Scanning: %s', [Opts.ScanPath]));

  Hits := RunScan(Opts);

  Err(Format('Found %d vulnerable executables', [Length(Hits)]));

  Ext := LowerCase(ExtractFileExt(Opts.OutputFile));
  IsCSV := Ext = '.csv';

  if IsCSV then Output := BuildCSV(Hits)
  else           Output := BuildJSON(Hits);

  if Opts.OutputFile <> '' then
  begin
    TFile.WriteAllText(Opts.OutputFile, Output, TEncoding.UTF8);
    Err('Written to: ' + Opts.OutputFile);
  end
  else
    Out(Output);
end;

end.
