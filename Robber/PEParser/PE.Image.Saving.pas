{$WARN COMBINING_SIGNED_UNSIGNED OFF}
unit PE.Image.Saving;

interface

uses
  System.Classes,
  System.SysUtils;

// If SavingModifiedImage is True some fields like header size and image size
// are recalculated and updated. If it's False it's assumed image is already
// built (or just loaded) and only headers writing done.
function SaveHeaders(APE: TObject; AStream: TStream; SavingModifiedImage: boolean): boolean;

function SaveImageToStream(APE: TObject; AStream: TStream): boolean;

implementation

uses
  // To expand.
  PE.Headers,
  PE.Common,
  PE.DataDirectories,
  //
  PE.Types.DOSHeader,
  PE.Types.FileHeader,
  PE.Types.NTHeaders,
  PE.Types.OptionalHeader,
  PE.Types.Directories,
  PE.Types.Sections,
  PE.Image,
  PE.Section,
  PE.Sections,
  PE.Utils,

  PE.Build.Export;

{ DOS }

function DoDosHdr(PE: TPEImage; AStream: TStream): boolean;
var
  h: PImageDOSHeader;
  DosBlockSize: integer;
begin
  h := PE.DOSHeader;
  h^.e_magic.SetMZ;
  h^.e_lfanew := PE.LFANew;

  // Write DOS header.
  Result := StreamWrite(AStream, h^, SizeOf(h^));

  // Write DOS block.
  DosBlockSize := Length(PE.DosBlock);
  if DosBlockSize <> 0 then
    StreamWrite(AStream, PE.DosBlock[0], DosBlockSize);
end;

{ NT }

function DoFileHdr(PE: TPEImage; AStream: TStream): boolean;
begin
  if StreamWrite(AStream, PE00_SIGNATURE, SizeOf(PE00_SIGNATURE)) then
    if StreamWrite(AStream, PE.FileHeader^, SizeOf(PE.FileHeader^)) then
      exit(true);
  exit(false);
end;

{ Optional }

function DoOptHdrAndDirs(PE: TPEImage; AStream: TStream): boolean;
var
  OptHdrSize: integer;
  DDirSize: integer;
begin
  // Update # of dirs.
  PE.OptionalHeader.NumberOfRvaAndSizes := PE.DataDirectories.Count;
  // Write optional header.
  OptHdrSize := PE.OptionalHeader.WriteToStream(AStream, PE.ImageBits, -1);
  // Write dirs.
  DDirSize := PE.DataDirectories.SaveDirectoriesToStream(AStream);
  // Update size of opt. hdr.
  PE.FileHeader.SizeOfOptionalHeader := OptHdrSize + DDirSize;

  Result := PE.FileHeader.SizeOfOptionalHeader <> 0;
end;

{ Sec Hdr }

procedure FillSecHdrRawOfs(PE: TPEImage; ofsSecHdr: uint32);
var
  sec: TPESection;
  ofs: uint64;
begin
  ofs := ofsSecHdr + PE.Sections.Count * SizeOf(TImageSectionHeader);
  for sec in PE.Sections do
  begin
    // Process only TPESection.
    if sec.ClassType <> TPESection then
      continue;

    ofs := AlignUp(ofs, PE.FileAlignment);
    sec.RawOffset := ofs;
    inc(ofs, sec.RawSize);
  end;
end;

function DoSecHdr(PE: TPEImage; AStream: TStream): boolean;
var
  Sec: TPESection;
  h: TImageSectionHeader;
begin
  for Sec in PE.Sections do
  begin
    // Process only TPESection.
    if sec.ClassType <> TPESection then
      continue;

    h := Sec.ImageSectionHeader;
    if not StreamWrite(AStream, h, SizeOf(h)) then
      exit(False);
  end;
  exit(true);
end;

function DoSecHdrGap(PE: TPEImage; AStream: TStream): boolean;
var
  size: integer;
begin
  size := Length(PE.SecHdrGap);
  if size <> 0 then
    if not StreamWrite(AStream, PE.SecHdrGap[0], size) then
      exit(False);
  exit(true);
end;

procedure DoSecData(PE: TPEImage; AStream: TStream);
var
  sec: TPESection;
  SizeToWrite: uint32;
  PaddingSize: uint32;
begin
  for sec in PE.Sections do
  begin
    // Process only TPESection.
    if sec.ClassType <> TPESection then
      continue;

    StreamSeekWithPadding(AStream, sec.RawOffset);

    if sec.RawSize > sec.VirtualSize then
    begin
      SizeToWrite := sec.VirtualSize;
      PaddingSize := sec.RawSize - sec.VirtualSize;
    end
    else
    begin
      SizeToWrite := sec.RawSize;
      PaddingSize := 0;
    end;

    AStream.Write(sec.Mem^, SizeToWrite);
    WritePattern(AStream, PaddingSize, nil, 0);
  end;
end;

function SaveHeaders(APE: TObject; AStream: TStream; SavingModifiedImage: boolean): boolean;
var
  PE: TPEImage;
  ofsFileHdr, ofsSecHdr: uint32;
begin
  Result := False;

  PE := TPEImage(APE);

  // save dos
  if not DoDosHdr(PE, AStream) then
    exit;

  ofsFileHdr := PE.LFANew;

  // skip file header now
  if not StreamSeek(AStream, ofsFileHdr + SizeOf(TImageFileHeader) + 4) then
    exit;

  if SavingModifiedImage then
  begin
    // update size of image header
    PE.FixSizeOfImage;

    // update size of headers
    PE.FixSizeOfHeaders;
  end;

  // save optional
  if not DoOptHdrAndDirs(PE, AStream) then
    exit;

  ofsSecHdr := AStream.Position;

  // now write file header
  if not StreamSeek(AStream, ofsFileHdr) then
    exit;
  if not DoFileHdr(PE, AStream) then
    exit;

  // go back to sec hdr
  if not StreamSeek(AStream, ofsSecHdr) then
    exit;

  if SavingModifiedImage then
  begin
    // Fill RawData offsets for Section Headers.
    FillSecHdrRawOfs(PE, ofsSecHdr);
  end;

  // write sec hdr
  if not DoSecHdr(PE, AStream) then
    exit;

  exit(true);
end;

function SaveImageToStream(APE: TObject; AStream: TStream): boolean;
var
  PE: TPEImage;
begin
  Result := False;

  PE := TPEImage(APE);

  // Ensure we have all needed values set.
  PE.Defaults.SetAll;

  if not SaveHeaders(PE, AStream, true) then
    exit;

  // write sec hdr gap
  DoSecHdrGap(PE, AStream);

  // write sec data
  DoSecData(PE, AStream);

  Result := true;
end;

end.
