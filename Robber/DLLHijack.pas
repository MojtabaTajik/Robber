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

constructor TDLLHijack.Create(const FileName: string);
begin
  fFileName := FileName;
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

procedure TDLLHijack.GetImportedDLL(DLLs: TStrings);
var
  Lib: TPEImportLibrary;
  Fn: TPEImportFunction;
  rva: TRVA;
  Img: TPEImage;
begin
  DLLs.Clear;

  Img := TPEImage.Create;
  try
    Img.LoadFromFile(fFileName);

    for Lib in Img.Imports.Libs do
    begin
      DLLs.Add(Lib.Name);

      rva := Lib.IatRva;

      inc(rva, Img.ImageWordSize); // null
    end;
  finally
    Img.Free;
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
  Lib: TPEImportLibrary;
  Fn: TPEImportFunction;
  rva: TRVA;
  Img: TPEImage;
begin
  Methods.Clear;

  Img := TPEImage.Create;
  try
    Img.LoadFromFile(fFileName);

    for Lib in Img.Imports.Libs do
    begin
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
  finally
    Img.Free;
  end;
end;

end.
