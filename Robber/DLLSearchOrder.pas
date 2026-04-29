unit DLLSearchOrder;

// Computes the Windows DLL search order for a given executable and checks
// which directories in that order are writable. Based on SafeDllSearchMode
// (enabled by default since XP SP2), the order is:
//   1. Directory of the executable
//   2. System directory (System32 / SysWOW64)
//   3. 16-bit system directory (Windows\System)
//   4. Windows directory
//   5. Directories in %PATH%
//
// The current working directory (position 5 in the spec) is intentionally
// omitted — it's unknowable at scan time and varies per launch context.

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Types,
  System.Generics.Collections, Winapi.Windows;

type
  TSearchEntry = record
    Path: string;       // normalised, includes trailing backslash
    Label_: string;     // human-readable label for display
    Writable: Boolean;
    ContainsDLL: Boolean;
  end;

// Build a writability cache for directories that are constant across all
// scanned files (system dirs + PATH). Call once before the scan loop.
function BuildSearchCache: TDictionary<string, Boolean>;

// Returns the DLL search order for ExePath / DLLName.
// Cache covers system + PATH dirs; exe dir is checked fresh each call.
function GetDLLSearchOrder(const ExePath, DLLName: string;
  Cache: TDictionary<string, Boolean>): TArray<TSearchEntry>;

// Returns the standard Windows system directories (System32 / SysWOW64 /
// 16-bit System). Used to identify "real" system DLLs that aren't candidates
// for hijacking via search-order abuse.
function GetSystemDirs: TArray<string>;

// Removes any DLL from the list that is found in one of the SysDirs.
procedure StripSystemDLLs(DLLs: TStrings; const SysDirs: TArray<string>);

// Recurse manually so a single inaccessible directory (e.g. System Volume
// Information when scanning a drive root unelevated) doesn't abort the
// whole enumeration the way TDirectory.GetFiles(..., soAllDirectories) does.
procedure CollectExeFiles(const Dir: string; Results: TList<string>; Depth: Integer = 0);

implementation

const
  WriteCheckFile = 'RobberWriteCheck.txt';

function NormDir(const D: string): string;
begin
  Result := LowerCase(IncludeTrailingPathDelimiter(D));
end;

// Strip a single layer of surrounding double-quotes from a PATH entry.
// Windows allows entries like "C:\Program Files\Foo" in PATH.
function StripQuotes(const S: string): string;
begin
  Result := S;
  if (Length(Result) >= 2) and (Result[1] = '"') and
     (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function IsDirWritable(const Dir: string): Boolean;
var
  TempPath: string;
  FS: TFileStream;
begin
  TempPath := IncludeTrailingPathDelimiter(Dir) + WriteCheckFile;
  try
    FS := TFile.Create(TempPath);
    try
      Result := True;
    finally
      FS.Free;
      // Best-effort cleanup — never let a delete failure signal "not writable".
      try TFile.Delete(TempPath); except end;
    end;
  except
    Result := False;
  end;
end;

function CachedWritable(const Dir: string;
  Cache: TDictionary<string, Boolean>): Boolean;
var
  Key: string;
begin
  Key := NormDir(Dir);
  if not Cache.TryGetValue(Key, Result) then
  begin
    Result := IsDirWritable(Dir);
    Cache.Add(Key, Result);
  end;
end;

function MakeEntry(const Dir, Lbl, DLLName: string;
  Cache: TDictionary<string, Boolean>): TSearchEntry;
begin
  Result.Path        := IncludeTrailingPathDelimiter(Dir);
  Result.Label_      := Lbl;
  Result.Writable    := CachedWritable(Dir, Cache);
  Result.ContainsDLL := FileExists(Result.Path + DLLName);
end;

// Split a semicolon-delimited string. Uses TStringList with StrictDelimiter
// so that spaces inside entries are preserved (XE2-compatible).
function SplitBySemicolon(const S: string): TStringList;
begin
  Result := TStringList.Create;
  Result.Delimiter       := ';';
  Result.StrictDelimiter := True;
  Result.DelimitedText   := S;
end;

function BuildSearchCache: TDictionary<string, Boolean>;
var
  Cache: TDictionary<string, Boolean>;
  SysBuf, WinBuf: array[0..MAX_PATH] of Char;
  WinDir, PathEnv, P: string;
  PathList: TStringList;
  i: Integer;
begin
  // Keys are normalised via NormDir (lowercased), so a plain comparer suffices.
  Cache := TDictionary<string, Boolean>.Create;

  GetSystemDirectory(SysBuf, MAX_PATH);
  GetWindowsDirectory(WinBuf, MAX_PATH);
  WinDir := WinBuf;

  // Pre-populate fixed dirs — these never change between files
  CachedWritable(SysBuf, Cache);
  CachedWritable(WinDir + '\System', Cache);
  CachedWritable(WinDir, Cache);

  // Pre-populate PATH entries
  PathEnv  := GetEnvironmentVariable('PATH');
  PathList := SplitBySemicolon(PathEnv);
  try
    for i := 0 to PathList.Count - 1 do
    begin
      P := StripQuotes(Trim(PathList[i]));
      if (P <> '') and DirectoryExists(P) then
        CachedWritable(P, Cache);
    end;
  finally
    PathList.Free;
  end;

  Result := Cache;
end;

function GetDLLSearchOrder(const ExePath, DLLName: string;
  Cache: TDictionary<string, Boolean>): TArray<TSearchEntry>;
var
  Entries: TList<TSearchEntry>;
  SysBuf, WinBuf: array[0..MAX_PATH] of Char;
  WinDir, PathEnv, P: string;
  PathList: TStringList;
  Idx, i: Integer;
begin
  Entries := TList<TSearchEntry>.Create;
  try
    GetSystemDirectory(SysBuf, MAX_PATH);
    GetWindowsDirectory(WinBuf, MAX_PATH);
    WinDir := WinBuf;

    // 1. Exe directory (checked fresh — unique per file)
    Entries.Add(MakeEntry(ExtractFilePath(ExePath),
      'Application directory', DLLName, Cache));

    // 2. System directory
    Entries.Add(MakeEntry(SysBuf,
      'System directory (System32)', DLLName, Cache));

    // 3. 16-bit system directory
    Entries.Add(MakeEntry(WinDir + '\System',
      'Windows\System', DLLName, Cache));

    // 4. Windows directory
    Entries.Add(MakeEntry(WinDir,
      'Windows directory', DLLName, Cache));

    // 5. PATH entries (only those that exist on disk)
    PathEnv  := GetEnvironmentVariable('PATH');
    PathList := SplitBySemicolon(PathEnv);
    try
      Idx := 0;
      for i := 0 to PathList.Count - 1 do
      begin
        P := StripQuotes(Trim(PathList[i]));
        if (P = '') or not DirectoryExists(P) then
          Continue;
        Inc(Idx);
        Entries.Add(MakeEntry(P,
          Format('PATH[%d]: %s', [Idx, P]), DLLName, Cache));
      end;
    finally
      PathList.Free;
    end;

    Result := Entries.ToArray;
  finally
    Entries.Free;
  end;
end;

function GetSystemDirs: TArray<string>;
var
  Buf: array[0..MAX_PATH] of Char;
  WinDir: string;
begin
  GetWindowsDirectory(Buf, MAX_PATH);
  WinDir := IncludeTrailingPathDelimiter(Buf);
  SetLength(Result, 3);
  Result[0] := WinDir + 'System32\';
  Result[1] := WinDir + 'SysWOW64\';
  Result[2] := WinDir + 'System\';
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

procedure CollectExeFiles(const Dir: string; Results: TList<string>; Depth: Integer = 0);
const
  MaxDepth = 64;
var
  Files, SubDirs: TStringDynArray;
  F, Sub: string;
  Attr: DWORD;
begin
  if Depth > MaxDepth then Exit;
  try
    Files := TDirectory.GetFiles(Dir, '*.exe', TSearchOption.soTopDirectoryOnly);
    for F in Files do
      Results.Add(F);
    SubDirs := TDirectory.GetDirectories(Dir);
  except
    on Exception do Exit;
  end;
  for Sub in SubDirs do
  begin
    Attr := GetFileAttributes(PChar(Sub));
    if (Attr <> INVALID_FILE_ATTRIBUTES) and
       ((Attr and FILE_ATTRIBUTE_REPARSE_POINT) = 0) then
      CollectExeFiles(Sub, Results, Depth + 1);
  end;
end;

end.
