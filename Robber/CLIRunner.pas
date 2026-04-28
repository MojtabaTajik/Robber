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
  DLLHijack, DigitalSignature, UAC, DLLSearchOrder, ScanThread, ScanExport;

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
// Scan
// ---------------------------------------------------------------------------
//
// Produces TScanResult records — the same shape used by the GUI scan thread —
// so JSON / CSV serialisation can be shared via the ScanExport unit. System
// DLL identification is delegated to DLLSearchOrder.GetSystemDirs /
// StripSystemDLLs to avoid two divergent implementations of the same logic.

function RunScan(const Opts: TCLIOptions): TArray<TScanResult>;
var
  FileList: TStringDynArray;
  EachFile, DLLName: string;
  PEFile: TDLLHijack;
  Sig: TDigitalSignature;
  ImportDLLs, Methods: TStringList;
  IsSigned: Boolean;
  Rate: THijackRate;
  Res: TScanResult;
  DLLInf: TDLLScanInfo;
  DLLList: TList<TDLLScanInfo>;
  Results: TList<TScanResult>;
  SysDirs: TArray<string>;
  SearchCache: TDictionary<string, Boolean>;
  i, j, Total: Integer;
begin
  SysDirs := DLLSearchOrder.GetSystemDirs;
  SearchCache := BuildSearchCache;
  Results := TList<TScanResult>.Create;
  try
    FileList := TDirectory.GetFiles(Opts.ScanPath, '*.exe',
      TSearchOption.soAllDirectories);
    Total := Length(FileList);

    for i := 0 to Total - 1 do
    begin
      EachFile := FileList[i];
      Err(Format('[%d/%d] %s', [i + 1, Total, ExtractFileName(EachFile)]));

      // Reset per-iteration record so stale fields can't leak into the
      // next result if a code path forgets to set one.
      Res := Default(TScanResult);

      // Initialise to nil so the finally block can safely Free anything
      // that did get constructed before a constructor raised.
      ImportDLLs := nil;
      PEFile := nil;
      Sig := nil;
      try
        try
          ImportDLLs := TStringList.Create;
          PEFile := TDLLHijack.Create(EachFile);
          Sig := TDigitalSignature.Create(EachFile);

          PEFile.GetHijackableImportedDLL(ImportDLLs);
          DLLSearchOrder.StripSystemDLLs(ImportDLLs, SysDirs);
          if ImportDLLs.Count = 0 then Continue;

          Rate := PEFile.GetHijackRate(Opts.BestDLLCount, Opts.BestExeSize,
                                        Opts.GoodDLLCount, Opts.GoodExeSize);

          if SkipByRate(Rate, Opts.RateFilter) then Continue;
          if SkipByImageType(PEFile.IsX86Image, Opts.ImageTypeFilter) then Continue;

          IsSigned := Sig.IsCodeSigned;
          if SkipBySign(IsSigned, Opts.SignFilter) then Continue;
          if SkipByWritePerm(EachFile, Opts.WritePermFilter) then Continue;

          Res.ExePath        := EachFile;
          Res.FileSize       := PEFile.GetFileSize;
          Res.IsX86          := PEFile.IsX86Image;
          Res.IsSigned       := IsSigned;
          Res.SignerCompany  := Sig.SignerCompany;
          Res.HijackRate     := Rate;
          Res.ExecutionLevel := GetExecutionLevel(EachFile);

          Methods := TStringList.Create;
          DLLList := TList<TDLLScanInfo>.Create;
          try
            for DLLName in ImportDLLs do
            begin
              Methods.Clear;
              PEFile.GetDLLMethods(DLLName, Methods);
              DLLInf.Name := DLLName;
              SetLength(DLLInf.Methods, Methods.Count);
              for j := 0 to Methods.Count - 1 do
                DLLInf.Methods[j] := Methods[j];
              DLLInf.SearchOrder := GetDLLSearchOrder(EachFile, DLLName, SearchCache);
              DLLList.Add(DLLInf);
            end;
            Res.DLLs := DLLList.ToArray;
          finally
            Methods.Free;
            DLLList.Free;
          end;

          Results.Add(Res);
        finally
          Sig.Free;
          PEFile.Free;
          ImportDLLs.Free;
        end;
      except
        // Skip unreadable files (access denied, corrupt PE, etc.)
      end;
    end;

    Result := Results.ToArray;
  finally
    Results.Free;
    SearchCache.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

procedure RunCLI;
var
  Opts: TCLIOptions;
  Results: TArray<TScanResult>;
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

  Results := RunScan(Opts);

  Err(Format('Found %d vulnerable executables', [Length(Results)]));

  Ext := LowerCase(ExtractFileExt(Opts.OutputFile));
  IsCSV := Ext = '.csv';

  if IsCSV then Output := ScanExport.BuildCSV(Results)
  else           Output := ScanExport.BuildJSON(Results);

  if Opts.OutputFile <> '' then
  begin
    TFile.WriteAllText(Opts.OutputFile, Output, TEncoding.UTF8);
    Err('Written to: ' + Opts.OutputFile);
  end
  else
    Out(Output);
end;

end.
