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
  System.SysUtils, System.Classes, System.IOUtils,
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

implementation

const
  WriteCheckFile = 'RobberWriteCheck.txt';

function NormDir(const D: string): string;
begin
  Result := LowerCase(IncludeTrailingPathDelimiter(D));
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
      TFile.Delete(TempPath);
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
  Result.Path       := IncludeTrailingPathDelimiter(Dir);
  Result.Label_     := Lbl;
  Result.Writable   := CachedWritable(Dir, Cache);
  Result.ContainsDLL := FileExists(Result.Path + DLLName);
end;

function BuildSearchCache: TDictionary<string, Boolean>;
var
  Cache: TDictionary<string, Boolean>;
  SysBuf, WinBuf: array[0..MAX_PATH] of Char;
  WinDir, PathEnv: string;
  PathParts: TArray<string>;
  Part: string;
begin
  Cache := TDictionary<string, Boolean>.Create(
    TIStringComparer.Ordinal);

  GetSystemDirectory(SysBuf, MAX_PATH);
  GetWindowsDirectory(WinBuf, MAX_PATH);
  WinDir := WinBuf;

  // Pre-populate fixed dirs — these never change between files
  CachedWritable(SysBuf, Cache);
  CachedWritable(WinDir + '\System', Cache);
  CachedWritable(WinDir, Cache);

  // Pre-populate PATH entries
  PathEnv := GetEnvironmentVariable('PATH');
  PathParts := PathEnv.Split([';']);
  for Part in PathParts do
  begin
    Part := Trim(Part);
    if (Part <> '') and DirectoryExists(Part) then
      CachedWritable(Part, Cache);
  end;

  Result := Cache;
end;

function GetDLLSearchOrder(const ExePath, DLLName: string;
  Cache: TDictionary<string, Boolean>): TArray<TSearchEntry>;
var
  Entries: TList<TSearchEntry>;
  SysBuf, WinBuf: array[0..MAX_PATH] of Char;
  WinDir, PathEnv: string;
  PathParts: TArray<string>;
  Part: string;
  Idx: Integer;
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
    PathEnv := GetEnvironmentVariable('PATH');
    PathParts := PathEnv.Split([';']);
    Idx := 0;
    for Part in PathParts do
    begin
      Part := Trim(Part);
      if (Part = '') or not DirectoryExists(Part) then
        Continue;
      Inc(Idx);
      Entries.Add(MakeEntry(Part,
        Format('PATH[%d]: %s', [Idx, Part]), DLLName, Cache));
    end;

    Result := Entries.ToArray;
  finally
    Entries.Free;
  end;
end;

end.
