unit PE.Sections;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Types.Sections,
  PE.Section;

type
  TPESections = class(TList<TPESection>)
  private
    FPE: TObject;
    procedure ItemNotify(Sender: TObject; const Item: TPESection;
      Action: TCollectionNotification);
  public
    constructor Create(APEImage: TObject);

    function Add(const Sec: TPESection): TPESection;
    procedure Clear;

    // Change section Raw and Virtual size.
    // Virtual size is aligned to section alignment.
    procedure Resize(Sec: TPESection; NewSize: UInt32);

    function CalcNextSectionRVA: TRVA;

    // Create new section but don't add it.
    // See AddNew for list of parameters.
    function CreateNew(const AName: String; ASize, AFlags: UInt32;
      Mem: pointer; ForceVA: TVA = 0): TPESection;

    // Add new named section.
    // If Mem <> nil, data from Mem will be copied to newly allocated block.
    // If Mem = nil, block will be allocated and filled with 0s.
    // Normally Virtual Address of section is calculated to come after previous
    // section (aligned). But if ForceVA is not 0 it is used instead of
    // calculation.
    function AddNew(const AName: String; ASize, AFlags: UInt32;
      Mem: pointer; ForceVA: TVA = 0): TPESection;

    // Add new section using raw data from file.
    function AddNewFromFile(const AFileName: string; const AName: String;
      AFlags: UInt32; ForceVA: TVA = 0): TPESection;

    function SizeOfAllHeaders: UInt32; inline;

    function RVAToOfs(RVA: TRVA; OutOfs: PDword): boolean;
    function RVAToSec(RVA: TRVA; OutSec: PPESection): boolean;

    function FindByName(const AName: String; IgnoreCase: boolean = True): TPESection;

    // Fill section memory with specified byte and return number of bytes
    // actually written.
    function FillMemory(RVA: TRVA; Size: UInt32; FillByte: Byte = 0): UInt32;

    // WholeSizeOrNothing: either write Size bytes or write nothing.
    function FillMemoryEx(RVA: TRVA; Size: UInt32; WholeSizeOrNothing: boolean;
      FillByte: Byte = 0): UInt32;
  end;

implementation

uses
  // Expand
  PE.Types.FileHeader,
  //
  PE.Image,
  PE.Utils;

{ TPESections }

function TPESections.Add(const Sec: TPESection): TPESection;
begin
  inherited Add(Sec);
  Result := Sec;
end;

function TPESections.CreateNew(const AName: String; ASize, AFlags: UInt32;
  Mem: pointer; ForceVA: TVA): TPESection;
var
  PE: TPEImage;
  sh: TImageSectionHeader;
begin
  PE := TPEImage(FPE);

  sh.Clear;
  sh.Name := AName;
  sh.VirtualSize := AlignUp(ASize, PE.SectionAlignment);

  if ForceVA = 0 then
    sh.RVA := CalcNextSectionRVA
  else
    sh.RVA := ForceVA;

  sh.SizeOfRawData := ASize;
  // sh.PointerToRawData will be calculated later during image saving.
  sh.Flags := AFlags;

  Result := TPESection.Create(sh, Mem);
end;

function TPESections.AddNew(const AName: String; ASize, AFlags: UInt32;
  Mem: pointer; ForceVA: TVA): TPESection;
begin
  Result := CreateNew(AName, ASize, AFlags, Mem, ForceVA);
  Add(Result);
end;

function TPESections.AddNewFromFile(const AFileName: string;
  const AName: String; AFlags: UInt32; ForceVA: TVA): TPESection;
var
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create;
  try
    ms.LoadFromFile(AFileName);
    Result := AddNew(AName, ms.Size, AFlags, ms.Memory, ForceVA);
  finally
    ms.Free;
  end;
end;

function TPESections.CalcNextSectionRVA: TRVA;
var
  PE: TPEImage;
begin
  PE := TPEImage(FPE);
  if Count = 0 then
    Result := AlignUp(PE.CalcHeadersSizeNotAligned, PE.SectionAlignment)
  else
    Result := AlignUp(Last.RVA + Last.VirtualSize, PE.SectionAlignment);
end;

procedure TPESections.Clear;
begin
  inherited Clear;
  TPEImage(FPE).FileHeader^.NumberOfSections := 0;
end;

constructor TPESections.Create(APEImage: TObject);
begin
  inherited Create;
  FPE := APEImage;
  self.OnNotify := ItemNotify;
end;

function TPESections.FillMemory(RVA: TRVA; Size: UInt32;
  FillByte: Byte): UInt32;
begin
  Result := FillMemoryEx(RVA, Size, False, FillByte);
end;

function TPESections.FillMemoryEx(RVA: TRVA; Size: UInt32;
  WholeSizeOrNothing: boolean; FillByte: Byte): UInt32;
var
  Sec: TPESection;
  Ofs, CanWrite: UInt32;
  p: PByte;
begin
  if not RVAToSec(RVA, @Sec) then
    Exit(0);
  Ofs := RVA - Sec.RVA;                   // offset of RVA in section
  CanWrite := Sec.GetAllocatedSize - Ofs; // max we can write before section end
  if CanWrite < Size then
  begin
    if WholeSizeOrNothing then
      Exit(0); //
    Result := CanWrite;
  end
  else
    Result := Size;
  p := Sec.Mem + Ofs;
  System.FillChar(p^, Result, FillByte);
end;

function TPESections.FindByName(const AName: String; IgnoreCase: boolean): TPESection;
var
  a, b: string;
begin
  if IgnoreCase then
    a := AName.ToLower
  else
    a := AName;
  for Result in self do
  begin
    if IgnoreCase then
      b := Result.Name.ToLower
    else
      b := Result.Name;
    if a = b then
      Exit;
  end;
  Exit(nil);
end;

procedure TPESections.ItemNotify(Sender: TObject; const Item: TPESection;
  Action: TCollectionNotification);
begin
  case Action of
    cnAdded:
      inc(TPEImage(FPE).FileHeader^.NumberOfSections);
    cnRemoved:
      begin
        dec(TPEImage(FPE).FileHeader^.NumberOfSections);
        if Item <> nil then
          Item.Free;
      end;
    cnExtracted:
      dec(TPEImage(FPE).FileHeader^.NumberOfSections);
  end;
end;

procedure TPESections.Resize(Sec: TPESection; NewSize: UInt32);
var
  NewVirtualSize: UInt32;
  LastRVA: TRVA;
begin
  // Last section can be changed freely, other sections must be checked.
  if Sec <> self.Last then
  begin
    if NewSize = 0 then
    begin
      Remove(Sec);
    end
    else
    begin
      // Get new size and rva for this section.
      NewVirtualSize := AlignUp(NewSize, TPEImage(FPE).SectionAlignment);
      LastRVA := Sec.RVA + NewVirtualSize - 1;
      // Check if new section end would be already occupied.
      if RVAToSec(LastRVA, nil) then
        raise Exception.Create('Cannot resize section: size is too big');
    end;
  end;
  Sec.Resize(NewSize);
end;

function TPESections.RVAToOfs(RVA: TRVA; OutOfs: PDword): boolean;
var
  Sec: TPESection;
begin
  for Sec in self do
  begin
    if Sec.ContainRVA(RVA) then
    begin
      if Assigned(OutOfs) then
        OutOfs^ := (RVA - Sec.RVA) + Sec.RawOffset;
      Exit(True);
    end;
  end;
  Exit(False);
end;

function TPESections.RVAToSec(RVA: TRVA; OutSec: PPESection): boolean;
var
  Sec: TPESection;
begin
  for Sec in self do
    if Sec.ContainRVA(RVA) then
    begin
      if OutSec <> nil then
        OutSec^ := Sec;
      Exit(True);
    end;
  Result := False;
end;

function TPESections.SizeOfAllHeaders: UInt32;
begin
  Result := Count * sizeof(TImageSectionHeader)
end;

end.
