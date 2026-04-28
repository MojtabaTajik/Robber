unit UAC;

interface

// Returns the requestedExecutionLevel from the embedded manifest:
//   'requireAdministrator'  — must run elevated
//   'highestAvailable'      — elevates if the user is an admin
//   'asInvoker'             — runs at caller's level (default)
//   ''                      — no manifest found
function GetExecutionLevel(const FileName: string): string;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes;

const
  // XE2's Winapi.Windows may not declare these — define them locally.
  LOAD_LIBRARY_AS_IMAGE_RESOURCE = $00000020;

function ContainsLevel(const XMLLower, Level: string): Boolean;
begin
  Result := (Pos('level="' + Level + '"', XMLLower) > 0) or
            (Pos('level=''' + Level + '''', XMLLower) > 0);
end;

function GetExecutionLevel(const FileName: string): string;
const
  RT_MANIFEST_ID = 24;
  EXE_MANIFEST   = 1;
var
  hMod: HMODULE;
  hRes: HRSRC;
  hData: HGLOBAL;
  pData: Pointer;
  Size: DWORD;
  Bytes: TBytes;
  XML: string;
begin
  Result := '';

  hMod := LoadLibraryEx(PChar(FileName), 0,
    LOAD_LIBRARY_AS_DATAFILE or LOAD_LIBRARY_AS_IMAGE_RESOURCE);
  if hMod = 0 then Exit;
  try
    hRes := FindResource(hMod, MAKEINTRESOURCE(EXE_MANIFEST),
                               MAKEINTRESOURCE(RT_MANIFEST_ID));
    if hRes = 0 then Exit;

    hData := LoadResource(hMod, hRes);
    if hData = 0 then Exit;

    pData := LockResource(hData);
    Size  := SizeofResource(hMod, hRes);
    if (pData = nil) or (Size = 0) then Exit;

    SetLength(Bytes, Size);
    Move(pData^, Bytes[0], Size);

    // Manifest is UTF-8 XML; fall back to ASCII if decode fails
    try
      XML := TEncoding.UTF8.GetString(Bytes);
    except
      XML := TEncoding.ASCII.GetString(Bytes);
    end;

    XML := LowerCase(XML);

    if ContainsLevel(XML, 'requireadministrator') then
      Result := 'requireAdministrator'
    else if ContainsLevel(XML, 'highestavailable') then
      Result := 'highestAvailable'
    else if ContainsLevel(XML, 'asinvoker') then
      Result := 'asInvoker';
  finally
    FreeLibrary(hMod);
  end;
end;

end.
