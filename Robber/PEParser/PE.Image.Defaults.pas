unit PE.Image.Defaults;

interface

type
  TPEDefaults = record
  private
    FPE: TObject;
  public
    constructor Create(PEImage: TObject);

    procedure SetImageBits;
    procedure SetFileAlignment;
    procedure SetSectionAlignment;
    procedure SetFileHdr;
    procedure SetOptionalHeader;
    procedure SetLFANew;

    procedure SetAll;
  end;

implementation

uses
  // Expand
  PE.Headers,
  //
  PE.Common,
  PE.Image,
  PE.Types.DOSHeader,
  PE.Types.FileHeader;

{ TPEDefaults }

constructor TPEDefaults.Create(PEImage: TObject);
begin
  FPE := PEImage;
end;

procedure TPEDefaults.SetAll;
begin
  SetLFANew;
  SetImageBits;
  SetFileAlignment;
  SetSectionAlignment;
  SetFileHdr;
  SetOptionalHeader;

  TPEImage(FPE).DataDirectories.Put(15, 0, 0); // 16 directories by default
end;

procedure TPEDefaults.SetFileAlignment;
begin
  with TPEImage(FPE) do
    if FileAlignment = 0 then
      FileAlignment := DEFAULT_SECTOR_SIZE;
end;

procedure TPEDefaults.SetFileHdr;
begin
  with TPEImage(FPE).FileHeader^ do
  begin
    if Machine = 0 then
      Machine := IMAGE_FILE_MACHINE_I386;
    if Characteristics = 0 then
      Characteristics := IMAGE_FILE_RELOCS_STRIPPED +
        IMAGE_FILE_EXECUTABLE_IMAGE + IMAGE_FILE_32BIT_MACHINE;
  end;
end;

procedure TPEDefaults.SetImageBits;
begin
  with TPEImage(FPE) do
    if ImageBits = 0 then
      ImageBits := 32;
end;

procedure TPEDefaults.SetLFANew;
begin
  if TPEImage(FPE).LFANew = 0 then
    TPEImage(FPE).LFANew := SizeOf(TImageDosHeader);
end;

procedure TPEDefaults.SetOptionalHeader;
begin
  with TPEImage(FPE).OptionalHeader^ do
  begin
    if MajorSubsystemVersion = 0 then
      MajorSubsystemVersion := 4;
    if SizeOfStackCommit = 0 then
      SizeOfStackCommit := $1000;
    if SizeOfHeapReserve = 0 then
      SizeOfHeapReserve := $100000;
    if Subsystem = 0 then
      Subsystem := IMAGE_SUBSYSTEM_WINDOWS_GUI;
    if ImageBase = 0 then
      ImageBase := $400000;
  end;
end;

procedure TPEDefaults.SetSectionAlignment;
begin
  with TPEImage(FPE) do
    if SectionAlignment = 0 then
      SectionAlignment := DEFAULT_PAGE_SIZE;
end;

end.
