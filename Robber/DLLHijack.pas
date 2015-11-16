unit DLLHijack;

interface

uses
  Windows, SysUtils, Classes, Messages, Winapi.CommDlg;

type
  THijackRate = (hrGood, hrMedium, hrBad);

  /// <summary>
  /// This class can get list of imported DLLs and methods
  /// </summary>
  /// <remarks>
  /// Written by Felony
  /// </remarks>
  TDLLHijack = class
  private
    fFileName: string;
    function RVA2Offset(const Value: DWORD; const FileName: string): DWORD;
    function GetFileInfo: Integer;
  public
    /// <summary>
    /// Create TDLLHijack class for work with pe information of given file
    /// </summary>
    /// <param name="FileName">
    /// Class must get PE information of given file
    /// </param>
    constructor Create(const FileName: string);

    /// <summary>
    /// Return size of given file in KB
    /// </summary>
    /// <returns>
    /// Size of given file
    /// </returns>
    function GetFileSize: Cardinal;

    /// <summary>
    /// Get list of imported DLLs in file , we have name of file in FileName
    /// variable
    /// </summary>
    /// <param name="DLLs">
    /// List of DLLs imported in file
    /// </param>
    procedure GetImportedDLL(DLLs: TStrings);

    /// <summary>
    /// <para>
    /// Get hijack rate of current filer
    /// </para>
    /// <para>
    /// Hijack rate is one of the below value :
    /// </para>
    /// <para>
    /// hrGood = Hijackable DLLs count must 1 or 2
    /// </para>
    /// <para>
    /// hrMedium = Hijackable DLLs count must between 3 and 5
    /// </para>
    /// <para>
    /// hrBad = Hijackable DLLs count is more than 5
    /// </para>
    /// </summary>
    /// <returns>
    /// Hijack rat in THijackRte type
    /// </returns>
    function GetHijackRate: THijackRate;

    /// <summary>
    /// Get list of hijackable imported DLLs
    /// </summary>
    /// <param name="DLLs">
    /// List of hijackable DLLs must return in this parameter
    /// </param>
    /// <remarks>
    /// This method use GetImportedDLL internally , finally it delete items
    /// that contain name of DLL that was not exists inside application
    /// </remarks>
    procedure GetHijackableImportedDLL(DLLs: TStrings);

    /// <summary>
    /// Get list of methods that imported from given DLL
    /// </summary>
    /// <param name="DLLName">
    /// DLL name that we need methods imported from it
    /// </param>
    /// <param name="Methods">
    /// List of methods imported from given DLL
    /// </param>
    procedure GetDLLMethods(DLLName: string; Methods: TStrings);
  end;

implementation

var
  // variable to get section infos -> RVA calculating
  vir_offs, virsize: array [1 .. 20] of DWORD;
  raw_offs, rawsize: array [1 .. 20] of DWORD;
  charac: DWORD;
  which_sec: Integer;
  doshead: DWORD = $00;
  elfanew: DWORD = $00;
  PEheader: DWORD = $00;
  Imagebase: DWORD = $00;
  number_sec: byte;

  // variables for Import table and so on
  ImpdirRVA: DWORD = $00; // Import Directory RVA
  ImpdirSize: DWORD = $00; // Import Directory Size;
  OriFirstThunkRVA: DWORD = $00;
  FirstThunkRVA: DWORD = $00;
  NameRVA: DWORD = $00; // RVA to Name of DLL
  Hint1: WORD = $00;
  ordflag: DWORD = $00; // var to check if function is imported by ordinal

constructor TDLLHijack.Create(const FileName: string);
begin
  fFileName := FileName;
  GetFileInfo;
end;

function TDLLHijack.GetFileInfo: Integer;
var
  FileInfo: TMemoryStream;
  i: Integer;
begin
  FileInfo := TMemoryStream.Create;
  try
    FileInfo.LoadFromFile(fFileName);
    FileInfo.Seek(0, soFromBeginning);
    FileInfo.ReadData(doshead, 2);

    // Not a valid PE File
    if doshead <> $5A4D then
      Exit(0);

    // File address of new Exe header
    FileInfo.Seek($3C, soFromBeginning);
    FileInfo.ReadData(elfanew, 4);

    // PE Header
    FileInfo.Seek(elfanew, soFromBeginning);
    FileInfo.ReadData(PEheader, 2);

    // Not a valid PE File
    if not(PEheader = $4550) then
      Exit(0);

    // Number of Sections
    FileInfo.Seek(4, sofromcurrent);
    FileInfo.ReadData(number_sec, 2);

    // Imagebase
    FileInfo.Seek($2C, sofromcurrent);
    FileInfo.ReadData(Imagebase, 4);

    // Section Info
    FileInfo.Seek(elfanew + $F8, soFromBeginning);
    for i := 1 to number_sec do
    begin
      FileInfo.Seek(8, sofromcurrent);
      // Vir_size
      FileInfo.ReadData(virsize[i], 4);
      // Virtual Adress
      FileInfo.ReadData(vir_offs[i], 4);
      // Raw size
      FileInfo.ReadData(rawsize[i], 4);
      // Raw Offset
      FileInfo.ReadData(raw_offs[i], 4);
      // Characteristics
      FileInfo.Seek(12, sofromcurrent);
      FileInfo.ReadData(charac, 4);
    end;
    Result := 1;
  finally
    FileInfo.Free;
  end;
end;

function TDLLHijack.GetFileSize: Cardinal;
var
  MyFile: TMemoryStream;
begin
  // Get given file size in KB scale
  MyFile := TMemoryStream.Create;
  try
    MyFile.LoadFromFile(fFileName);
    Result := MyFile.Size div 1024;
  finally
    MyFile.Free;
  end;
end;

function TDLLHijack.RVA2Offset(const Value: DWORD;
  const FileName: string): DWORD;
var
  i: Integer;
begin
  which_sec := 0;
  for i := 1 to number_sec do
  begin
    if (Value >= vir_offs[i]) and (Value < vir_offs[i + 1]) then
    begin
      which_sec := i;
      break;
    end;
    if i = number_sec then
      if (Value <= (vir_offs[i] + virsize[i])) and (Value >= vir_offs[1]) then
        which_sec := i
      else
      begin
        // MessageBox(0, pchar('Not in file!'), pchar('Error'), mb_ok);
      end;
  end;
  Result := Value - vir_offs[which_sec] + raw_offs[which_sec];
end;

procedure TDLLHijack.GetImportedDLL(DLLs: TStrings);
var
  SourceFile: TMemoryStream;
  d: DWORD; // just a help variable
  Count_DLL, temp: Integer;
  DLLName: string;
begin
  DLLs.Clear;

  SourceFile := TMemoryStream.Create;
  try
    SourceFile.LoadFromFile(fFileName);
    SourceFile.Seek(elfanew + $80, soFromBeginning);
    SourceFile.ReadData(ImpdirRVA, 4);
    SourceFile.ReadData(ImpdirSize, 4);

    Count_DLL := -1;

    // Loop through every data directory
    repeat
      Count_DLL := Count_DLL + 1;

      // Name of DLL
      SourceFile.Position := RVA2Offset(ImpdirRVA, fFileName) + $C + $14 *
        Count_DLL;
      SourceFile.ReadData(NameRVA, 4);

      if NameRVA = 0 then
        break;

      SourceFile.Seek(RVA2Offset(NameRVA, fFileName), soFromBeginning);

      // Get current DLL name
      DLLName := '';
      repeat
        SourceFile.ReadData(temp, 1);
        DLLName := UTF8ToString(DLLName + Char(temp));
      until temp = 0;

      // Delete #0 character from end of DLL name
      DLLName := Copy(DLLName, 0, Length(DLLName) - 1);

      if (LowerCase(ExtractFileExt(DLLName)) = '.dll') then
        DLLs.Add(UTF8ToString(DLLName));
    until (NameRVA = 0);
  finally
    SourceFile.Free;
  end;
end;

procedure TDLLHijack.GetHijackableImportedDLL(DLLs: TStrings);
var
  DLLCount: Integer;
begin
  GetImportedDLL(DLLs);
  for DLLCount := DLLs.Count - 1 downto 0 do
    if not(FileExists(ExtractFilePath(fFileName) + DLLs[DLLCount])) then
      DLLs.Delete(DLLCount);
end;

function TDLLHijack.GetHijackRate: THijackRate;
var
  DLLCount: Integer;
  ImportedDLL: TStringList;
  PESize: Cardinal;
begin
  ImportedDLL := TStringList.Create;
  try
    // Get hijackable DLL count
    GetHijackableImportedDLL(ImportedDLL);
    DLLCount := ImportedDLL.Count;

    // Get file size
    PESize := GetFileSize;

    // Check rate using DLL Count & File Size
    // Good
    if (DLLCount <= 2) AND (PESize <= 200) then
      Exit(hrGood);

    // Medium
    if (DLLCount <= 4) AND (PESize <= 400) then
      Exit(hrMedium);

    // Otherwise its bad to hijack
    Exit(hrBad);
  finally
    ImportedDLL.Free;
  end;
end;

procedure TDLLHijack.GetDLLMethods(DLLName: string; Methods: TStrings);
var
  SourceFile: TMemoryStream;
  d: DWORD; // just a help variable
  Count_DLL, Count_API, temp: Integer;
  CurrentAPIName, CurrentDLLName: string;
begin
  Methods.Clear;

  SourceFile := TMemoryStream.Create;
  try
    SourceFile.LoadFromFile(fFileName);
    SourceFile.Position := elfanew + $80;
    SourceFile.ReadData(ImpdirRVA, 4);
    SourceFile.ReadData(ImpdirSize, 4);

    Count_DLL := -1;

    // Loop through every data directory
    repeat
      Count_DLL := Count_DLL + 1;

      // Name of DLL
      SourceFile.Seek(RVA2Offset(ImpdirRVA, fFileName) + $C + $14 * Count_DLL,
        soFromBeginning);
      SourceFile.ReadData(NameRVA, 4);

      if NameRVA = 0 then
        break;

      SourceFile.Seek(RVA2Offset(NameRVA, fFileName), soFromBeginning);

      // Get current DLL name
      CurrentDLLName := '';
      repeat
        SourceFile.ReadData(temp, 1);
        CurrentDLLName := UTF8ToString(CurrentDLLName + Chr(temp));
      until temp = 0;

      // Delete #0 character from end of DLL name
      CurrentDLLName := Copy(CurrentDLLName, 0, Length(CurrentDLLName) - 1);

      // Check current DLL = User given name
      if (CurrentDLLName <> DLLName) then
        Continue;

      // At First read OriginalFirstThunk and FirstThunk
      SourceFile.Seek(RVA2Offset(ImpdirRVA, fFileName) + 0 + $14 * Count_DLL,
        soFromBeginning);
      SourceFile.ReadData(OriFirstThunkRVA, 4);
      SourceFile.Seek(RVA2Offset(ImpdirRVA, fFileName) + $10 + $14 * Count_DLL,
        soFromBeginning);

      SourceFile.ReadData(FirstThunkRVA, 4);

      // OriginalFirstThunk is available, so use it!
      if OriFirstThunkRVA <> 0 then
      begin
        FirstThunkRVA := OriFirstThunkRVA;
      end;

      Count_API := -1;
      repeat
        // All Functions from DLL
        Count_API := Count_API + 1;
        SourceFile.Seek(RVA2Offset(FirstThunkRVA, fFileName) + Count_API * 4,
          soFromBeginning);

        SourceFile.ReadData(d, 4);
        if d = $00000000 then
          break;

        ordflag := $00000000;

        // Check for ordinal import
        SourceFile.Seek(RVA2Offset(FirstThunkRVA, fFileName) + Count_API * 4 +
          2, soFromBeginning);
        SourceFile.ReadData(ordflag, 2);

        // If was ordinal import , add ordinal number to imported methods
        if ordflag = $8000 then
        begin
          SourceFile.Seek(RVA2Offset(FirstThunkRVA, fFileName) + Count_API * 4,
            soFromBeginning);
          SourceFile.ReadData(Hint1, 2);

          Methods.Add(Format('Ordinal Import : %d', [Hint1]));
        end
        else // If not ordinal import , get the method name
        begin
          SourceFile.Seek(RVA2Offset(d, fFileName), soFromBeginning);
          SourceFile.ReadData(Hint1, 2);

          // Get given DLL methods
          CurrentAPIName := '';
          repeat
            SourceFile.ReadData(temp, 1);
            CurrentAPIName := CurrentAPIName + Chr(temp);
          until temp = 0;

          // Delete #0 character from end of method name
          Delete(CurrentAPIName, Length(CurrentAPIName), 1);

          // Check API name not empty
          if (CurrentAPIName <> '') then
            Methods.Add(UTF8ToString(CurrentAPIName));
        end;
      until d = $0000;
    until (NameRVA = 0);
  finally
    SourceFile.Free;
  end;
end;

end.
