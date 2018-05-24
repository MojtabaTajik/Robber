unit WinHelper;

interface

uses
  System.Generics.Collections,
  System.SysUtils,

  WinApi.TlHelp32,
  WinApi.Windows;

type
  TProcessRec = record
    PID: DWORD;
    Name: string;
    constructor Create(PID: DWORD; const Name: string);
  end;

  TProcessRecList = TList<TProcessRec>;

  TModuleRec = TModuleEntry32;

  TModuleRecList = TList<TModuleRec>;

  // return True to continue enumeration or False to stop it.
  TEnumProcessesCallback = reference to function(const pe: TProcessEntry32): boolean;
  TEnumModulesCallback = reference to function(const me: TModuleEntry32): boolean;

  // Enumerate processes with callback. Result is False if there was error.
function EnumProcesses(cb: TEnumProcessesCallback): boolean;

// Enumerate processes to list. Result is False if there was error.
function EnumProcessesToList(List: TProcessRecList): boolean;

type
  // Used to compare strings.
  TStringMatchKind = (
    MATCH_STRING_WHOLE, // string equals to X
    MATCH_STRING_START, // string starts with X
    MATCH_STRING_END,   // string ends with X
    MATCH_STRING_PART   // string contains X
    );

function FindPIDByProcessName(
  const Name: string;
  out PID: DWORD;
  Match: TStringMatchKind = MATCH_STRING_WHOLE): boolean;

// Enumerate modules with callback. Result is False if there was error.
function EnumModules(PID: DWORD; cb: TEnumModulesCallback): boolean;

// Enumerate modules to list. Result is False if there was error.
function EnumModulesToList(PID: DWORD; List: TModuleRecList): boolean;

type
  // Used in FindModule to test if this is the module we search.
  // Return True on match.
  TFindModuleChecker = reference to function(const me: TModuleEntry32): boolean;

  // Find module by custom condition.
function FindModule(PID: DWORD; out value: TModuleEntry32; Checker: TFindModuleChecker): boolean;

// Find module by address that belongs to this module.
function FindModuleByAddress(PID: DWORD; Addr: NativeUInt; out me: TModuleEntry32): boolean;

// Find module by module name.
function FindModuleByName(PID: DWORD; const Name: string): boolean;

// Find main process module (exe).
function FindMainModule(PID: DWORD; out me: TModuleEntry32): boolean;

function SetPrivilegeByName(const Name: string; State: boolean): boolean;

function SetDebugPrivilege(State: boolean): boolean;

implementation

function EnumProcesses(cb: TEnumProcessesCallback): boolean;
var
  hShot, hShotMod: THandle;
  pe: TProcessEntry32;
begin
  // Create process snapshot.
  hShot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if hShot = INVALID_HANDLE_VALUE then
    exit(false);

  // Traverse it.
  try
    ZeroMemory(@pe, SizeOf(pe));
    pe.dwSize := SizeOf(pe);

    if not Process32First(hShot, pe) then
      exit(false);

    repeat
      // Add process only if we can query its module list.
      hShotMod := CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, pe.th32ProcessID);
      if hShotMod <> INVALID_HANDLE_VALUE then
      begin
        CloseHandle(hShotMod);
        if not cb(pe) then
          break;
      end;
    until not Process32Next(hShot, pe);

    exit(True);
  finally
    CloseHandle(hShot);
  end;
end;

function EnumProcessesToList(List: TProcessRecList): boolean;
begin
  List.Clear;
  result := EnumProcesses(
    function(const pe: TProcessEntry32): boolean
    begin
      List.Add(TProcessRec.Create(pe.th32ProcessID, pe.szExeFile));
      result := True;
    end);
end;

function CompareStringsWithMachKind(const s1, s2: string; kind: TStringMatchKind): boolean;
begin
  case kind of
    MATCH_STRING_WHOLE:
      result := s1.Equals(s2);
    MATCH_STRING_START:
      result := s1.StartsWith(s2);
    MATCH_STRING_END:
      result := s1.EndsWith(s2);
    MATCH_STRING_PART:
      result := s1.Contains(s2);
  else
    result := false;
  end;
end;

function FindPIDByProcessName(const Name: string; out PID: DWORD; Match: TStringMatchKind): boolean;
var
  tmpName: string;
  foundPID: DWORD;
begin
  tmpName := Name.ToUpper;
  foundPID := 0;

  EnumProcesses(
    function(const pe: TProcessEntry32): boolean
    begin
      if CompareStringsWithMachKind(string(pe.szExeFile).ToUpper, tmpName, Match) then
      begin
        foundPID := pe.th32ProcessID;
        exit(false); // don't continue search, already found
      end;
      exit(True); // continue search
    end);

  PID := foundPID;
  result := foundPID <> 0;
end;

function EnumModules(PID: DWORD; cb: TEnumModulesCallback): boolean;
var
  hShot: THandle;
  me: TModuleEntry32;
begin
  hShot := CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, PID);
  if hShot = INVALID_HANDLE_VALUE then
    exit(false);

  try
    ZeroMemory(@me, SizeOf(me));
    me.dwSize := SizeOf(me);

    if not Module32First(hShot, me) then
      exit(false);

    repeat
      if not cb(me) then
        break;
    until not Module32Next(hShot, me);

    exit(True);
  finally
    CloseHandle(hShot);
  end;
end;

function EnumModulesToList(PID: DWORD; List: TModuleRecList): boolean;
begin
  List.Clear;
  result := EnumModules(PID,
    function(const me: TModuleEntry32): boolean
    begin
      List.Add(me);
      exit(True);
    end);
end;

function FindModule(PID: DWORD; out value: TModuleEntry32; Checker: TFindModuleChecker): boolean;
var
  found: boolean;
  tmp: TModuleEntry32;
begin
  found := false;
  EnumModules(PID,
    function(const me: TModuleEntry32): boolean
    begin
      if Checker(me) then
      begin
        tmp := me;
        found := True;
        exit(false);
      end;
      exit(True);
    end);

  if found then
    value := tmp
  else
    fillchar(value, SizeOf(value), 0);

  exit(found);
end;

function FindModuleByAddress(PID: DWORD; Addr: NativeUInt; out me: TModuleEntry32): boolean;
begin
  result := FindModule(PID, me,
    function(const me: TModuleEntry32): boolean
    begin
      result :=
        (Addr >= NativeUInt(me.modBaseAddr)) and
        (Addr < NativeUInt(me.modBaseAddr + me.modBaseSize));
    end);
end;

function FindModuleByName(PID: DWORD; const Name: string): boolean;
var
  tmpName: string;
  me: TModuleEntry32;
begin
  tmpName := name.ToUpper;
  result := FindModule(PID, me,
    function(const me: TModuleEntry32): boolean
    begin
      result := string(me.szModule).ToUpper.Equals(tmpName);
    end);
end;

function FindMainModule(PID: DWORD; out me: TModuleEntry32): boolean;
begin
  result := FindModule(PID, me,
    function(const me: TModuleEntry32): boolean
    begin
      result := True; // first module is main one
    end);
end;

// http://msdn.microsoft.com/en-us/library/windows/desktop/aa446619(v=vs.85).aspx
function SetPrivilege(
  hToken: THandle;      // access token handle
lpszPrivilege: LPCTSTR; // name of privilege to enable/disable
bEnablePrivilege: BOOL  // to enable or disable privilege
  ): boolean;
var
  tp: TOKEN_PRIVILEGES;
  luid: int64;
  Status: DWORD;
  ReturnLength: DWORD;
begin
  if LookupPrivilegeValue(
    nil,         // lookup privilege on local system
  lpszPrivilege, // privilege to lookup
  luid)          // receives LUID of privilege
  then
  begin
    tp.PrivilegeCount := 1;
    tp.Privileges[0].luid := luid;
    if bEnablePrivilege then
      tp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED
    else
      tp.Privileges[0].Attributes := 0;

    // Enable the privilege or disable all privileges.
    if AdjustTokenPrivileges(hToken, false, tp, SizeOf(TOKEN_PRIVILEGES), nil, ReturnLength) then
    begin
      Status := GetLastError();
      if Status = ERROR_SUCCESS then
        exit(True);
    end;
  end;

  exit(false);
end;

function SetPrivilegeByName(const Name: string; State: boolean): boolean;
var
  hToken: THandle;
begin
  if not OpenProcessToken(GetCurrentProcess, TOKEN_QUERY or TOKEN_ADJUST_PRIVILEGES, hToken) then
    exit(false);
  result := SetPrivilege(hToken, LPCTSTR(Name), State);
  CloseHandle(hToken);
end;

function SetDebugPrivilege(State: boolean): boolean;
begin
  result := SetPrivilegeByName('SeDebugPrivilege', State);
end;

{ TProcessRec }

constructor TProcessRec.Create(PID: DWORD; const Name: string);
begin
  self.PID := PID;
  self.Name := Name;
end;

end.
