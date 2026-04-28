unit ScanThread;

interface

uses
  System.Classes, System.SysUtils, System.IOUtils, System.Types,
  System.Generics.Collections, Winapi.Windows,
  DLLHijack, DigitalSignature, UAC;

type
  TDLLScanInfo = record
    Name: string;
    Methods: TArray<string>;
  end;

  TScanResult = record
    ExePath: string;
    FileSize: Cardinal;
    IsX86: Boolean;
    IsSigned: Boolean;
    SignerCompany: string;
    HijackRate: THijackRate;
    ExecutionLevel: string;  // 'requireAdministrator' | 'highestAvailable' | 'asInvoker' | ''
    DLLs: TArray<TDLLScanInfo>;
  end;

  TScanOptions = record
    SearchPath: string;
    ImageTypeFilter: Integer;
    SignFilter: Integer;
    AbuseCandidateFilter: Integer;
    WritePermFilter: Integer;
    BestChoiceDLLCount: Integer;
    BestChoiceExeSize: Integer;
    GoodChoiceDLLCount: Integer;
    GoodChoiceExeSize: Integer;
  end;

  TOnScanProgress = procedure(Current, Total: Integer; const FileName: string) of object;
  TOnScanResult = procedure(const Result: TScanResult) of object;
  TOnScanDone = procedure(Cancelled: Boolean) of object;

  TScanThread = class(TThread)
  private
    FOptions: TScanOptions;
    FOnProgress: TOnScanProgress;
    FOnResult: TOnScanResult;
    FOnDone: TOnScanDone;

    // Staging fields for Synchronize callbacks (no params allowed)
    FSyncCurrent: Integer;
    FSyncTotal: Integer;
    FSyncFileName: string;
    FSyncResult: TScanResult;
    FSyncCancelled: Boolean;

    procedure DoProgress;
    procedure DoResult;
    procedure DoDone;

    function FilterHijackRate(Rate: THijackRate): Boolean;
    function FilterImageType(IsX86: Boolean): Boolean;
    function FilterSign(IsSigned: Boolean): Boolean;
    function FilterWritePerm(const FilePath: string): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const Options: TScanOptions;
      OnProgress: TOnScanProgress;
      OnResult: TOnScanResult;
      OnDone: TOnScanDone);
  end;

implementation

constructor TScanThread.Create(const Options: TScanOptions;
  OnProgress: TOnScanProgress; OnResult: TOnScanResult; OnDone: TOnScanDone);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FOptions := Options;
  FOnProgress := OnProgress;
  FOnResult := OnResult;
  FOnDone := OnDone;
end;

procedure TScanThread.DoProgress;
begin
  if Assigned(FOnProgress) then
    FOnProgress(FSyncCurrent, FSyncTotal, FSyncFileName);
end;

procedure TScanThread.DoResult;
begin
  if Assigned(FOnResult) then
    FOnResult(FSyncResult);
end;

procedure TScanThread.DoDone;
begin
  if Assigned(FOnDone) then
    FOnDone(FSyncCancelled);
end;

function TScanThread.FilterHijackRate(Rate: THijackRate): Boolean;
begin
  case FOptions.AbuseCandidateFilter of
    0: Result := False;
    1: Result := Rate <> hrBest;
    2: Result := Rate <> hrGood;
    3: Result := Rate <> hrBad;
  else
    Result := False;
  end;
end;

function TScanThread.FilterImageType(IsX86: Boolean): Boolean;
begin
  case FOptions.ImageTypeFilter of
    0: Result := False;
    1: Result := not IsX86;  // x86 only: skip x64
    2: Result := IsX86;      // x64 only: skip x86
  else
    Result := False;
  end;
end;

function TScanThread.FilterSign(IsSigned: Boolean): Boolean;
begin
  case FOptions.SignFilter of
    0: Result := False;
    1: Result := not IsSigned;  // signed only: skip unsigned
  else
    Result := False;
  end;
end;

function TScanThread.FilterWritePerm(const FilePath: string): Boolean;
const
  TempFileName = 'RobberWriteCheck.txt';
var
  TempFilePath: string;
  FS: TFileStream;
begin
  if FOptions.WritePermFilter = 0 then
    Exit(False);

  // Return True = skip (dir is NOT writable = not exploitable)
  // Return False = keep (dir IS writable = hijackable)
  TempFilePath := TPath.Combine(TPath.GetDirectoryName(FilePath), TempFileName);
  try
    FS := TFile.Create(TempFilePath);
    try
      Result := False;
    finally
      FS.Free;
      TFile.Delete(TempFilePath);
    end;
  except
    Result := True;
  end;
end;

function SystemDirs: TArray<string>;
var
  Buf: array[0..MAX_PATH] of Char;
  WinDir: string;
begin
  GetWindowsDirectory(Buf, MAX_PATH);
  WinDir := IncludeTrailingPathDelimiter(Buf);
  Result := [WinDir + 'System32\', WinDir + 'SysWOW64\', WinDir + 'System\'];
end;

procedure StripSystemDLLs(DLLs: TStrings; const SysDirs: TArray<string>);
var
  i: Integer;
  Dir: string;
  IsSystem: Boolean;
begin
  for i := DLLs.Count - 1 downto 0 do
  begin
    IsSystem := False;
    for Dir in SysDirs do
      if FileExists(Dir + DLLs[i]) then
      begin
        IsSystem := True;
        Break;
      end;
    if IsSystem then
      DLLs.Delete(i);
  end;
end;

procedure TScanThread.Execute;
var
  FileList: TStringDynArray;
  EachFile, DLLName: string;
  PEFile: TDLLHijack;
  Signature: TDigitalSignature;
  ImportDLLs, Methods: TStringList;
  IsSigned: Boolean;
  HijackRate: THijackRate;
  Res: TScanResult;
  DLLInfo: TDLLScanInfo;
  DLLInfoList: TList<TDLLScanInfo>;
  i: Integer;
  SysDirs: TArray<string>;
begin
  SysDirs := SystemDirs;

  FileList := TDirectory.GetFiles(FOptions.SearchPath, '*.exe',
    TSearchOption.soAllDirectories);

  FSyncTotal := Length(FileList);
  FSyncCurrent := 0;
  FSyncCancelled := False;

  for EachFile in FileList do
  begin
    if Terminated then
    begin
      FSyncCancelled := True;
      Break;
    end;

    Inc(FSyncCurrent);
    FSyncFileName := EachFile;
    Synchronize(DoProgress);

    try
      ImportDLLs := TStringList.Create;
      PEFile := TDLLHijack.Create(EachFile);
      Signature := TDigitalSignature.Create(EachFile);
      try
        PEFile.GetHijackableImportedDLL(ImportDLLs);
        StripSystemDLLs(ImportDLLs, SysDirs);
        if ImportDLLs.Count = 0 then
          Continue;

        HijackRate := PEFile.GetHijackRate(
          FOptions.BestChoiceDLLCount, FOptions.BestChoiceExeSize,
          FOptions.GoodChoiceDLLCount, FOptions.GoodChoiceExeSize);

        if FilterHijackRate(HijackRate) then Continue;
        if FilterImageType(PEFile.IsX86Image) then Continue;

        IsSigned := Signature.IsCodeSigned;
        if FilterSign(IsSigned) then Continue;
        if FilterWritePerm(EachFile) then Continue;

        // Build result record
        Res.ExePath        := EachFile;
        Res.FileSize       := PEFile.GetFileSize;
        Res.IsX86          := PEFile.IsX86Image;
        Res.IsSigned       := IsSigned;
        Res.SignerCompany  := Signature.SignerCompany;
        Res.HijackRate     := HijackRate;
        Res.ExecutionLevel := GetExecutionLevel(EachFile);

        // Collect DLLs and their methods in one pass
        Methods := TStringList.Create;
        DLLInfoList := TList<TDLLScanInfo>.Create;
        try
          for DLLName in ImportDLLs do
          begin
            Methods.Clear;
            PEFile.GetDLLMethods(DLLName, Methods);
            DLLInfo.Name := DLLName;
            SetLength(DLLInfo.Methods, Methods.Count);
            for i := 0 to Methods.Count - 1 do
              DLLInfo.Methods[i] := Methods[i];
            DLLInfoList.Add(DLLInfo);
          end;
          Res.DLLs := DLLInfoList.ToArray;
        finally
          Methods.Free;
          DLLInfoList.Free;
        end;

        FSyncResult := Res;
        Synchronize(DoResult);

      finally
        Signature.Free;
        ImportDLLs.Free;
        PEFile.Free;
      end;
    except
      // Skip files we can't read (access denied, corrupt PE, etc.)
    end;
  end;

  Synchronize(DoDone);
end;

end.
