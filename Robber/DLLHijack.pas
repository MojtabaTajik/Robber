unit DLLHijack;

interface

uses
  Windows, SysUtils, Classes, Messages, Winapi.CommDlg,
  PE.Common,
  PE.Image,
  PE.ExportSym,
  PE.Imports.Lib,
  PE.Imports.Func;

type
  THijackRate = (hrBest, hrGood, hrBad);

  /// <summary>
  /// This class can get list of imported DLLs and methods
  /// </summary>
  /// <remarks>
  /// Written by Felony
  /// </remarks>
  TDLLHijack = class
  private
    _FileName: string;
    Img: TPEImage;
  public
    /// <summary>
    /// Create TDLLHijack class for work with pe information of given file
    /// </summary>
    /// <param name="FileName">
    /// Class must get PE information of given file
    /// </param>
    constructor Create(const FileName: string);
    destructor Destroy; override;

    function IsX86Image: Boolean;

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
    function GetHijackRate(BestChoiceDLLCount, BestChoiceExeSize,
      GoodChiceDLLCount, GoodChoiceExeSize: Integer): THijackRate;

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

constructor TDLLHijack.Create(const FileName: string);
begin
  _FileName := FileName;

  Img := TPEImage.Create;
  Img.LoadFromFile(FileName);
end;

destructor TDLLHijack.Destroy;
begin
  if (Img <> nil) then
    FreeAndNil(Img);
end;

function TDLLHijack.GetFileSize: Cardinal;
begin
  Result := Img.SizeOfImage div 1024;
end;

procedure TDLLHijack.GetImportedDLL(DLLs: TStrings);
var
  Lib: TPEImportLibrary;
  Fn: TPEImportFunction;
  rva: TRVA;
begin
  DLLs.Clear;

  for Lib in Img.Imports.Libs do
  begin
    DLLs.Add(Lib.Name);

    rva := Lib.IatRva;

    inc(rva, Img.ImageWordSize); // null
  end;
end;

function TDLLHijack.IsX86Image: Boolean;
begin
  if (Img.Is32bit) then
    Exit(True);

  Exit(False);
end;

procedure TDLLHijack.GetHijackableImportedDLL(DLLs: TStrings);
var
  DLLCount: Integer;
begin
  GetImportedDLL(DLLs);
  for DLLCount := DLLs.Count - 1 downto 0 do
    if not(FileExists(ExtractFilePath(_FileName) + DLLs[DLLCount])) then
      DLLs.Delete(DLLCount);
end;

function TDLLHijack.GetHijackRate(BestChoiceDLLCount, BestChoiceExeSize,
  GoodChiceDLLCount, GoodChoiceExeSize: Integer): THijackRate;
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
    if (DLLCount <= BestChoiceDLLCount) AND (PESize <= BestChoiceExeSize) then
      Exit(hrBest);

    if (DLLCount <= GoodChiceDLLCount) AND (PESize <= GoodChoiceExeSize) then
      Exit(hrGood);

    Exit(hrBad);
  finally
    ImportedDLL.Free;
  end;
end;

procedure TDLLHijack.GetDLLMethods(DLLName: string; Methods: TStrings);
var
  Lib: TPEImportLibrary;
  Fn: TPEImportFunction;
  rva: TRVA;
begin
  Methods.Clear;

  for Lib in Img.Imports.Libs do
  begin
    if (Lib.Name <> DLLName) then
      Continue;

    rva := Lib.IatRva;

    for Fn in Lib.Functions do
    begin

      if Fn.Name <> '' then
        Methods.Add(Fn.Name)
      else
        Methods.Add(IntTOStr(Fn.Ordinal));

      inc(rva, Img.ImageWordSize);
    end;

    inc(rva, Img.ImageWordSize); // null
  end;
end;

end.
