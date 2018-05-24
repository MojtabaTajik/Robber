unit PE.Parser.Relocs;

interface

uses
  PE.Common,
  PE.Types,
  PE.Types.Directories,
  PE.Types.Relocations;

type
  TPERelocParser = class(TPEParser)
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image;

{ TRelocParser }

function TPERelocParser.Parse: TParserResult;
var
  dir: TImageDataDirectory;
  block: TBaseRelocationBlock;
  blCnt, iBlock: Integer;
  entry: TBaseRelocationEntry;
  r_ofs, r_type: dword;
  r_rva: dword;
  Ofs: dword;
  reloc: TReloc;
  PE: TPEImage;
var
  tmpRVA: TRVA;
begin
  PE := TPEImage(FPE);
  PE.Relocs.Clear;

  if not PE.DataDirectories.Get(DDIR_RELOCATION, @dir) then
    exit(PR_OK);

  if dir.IsEmpty then
    exit(PR_OK);

  if not PE.SeekRVA(dir.VirtualAddress) then
  begin
    PE.Msg.Write(SCategoryRelocs, 'Bad directory RVA (0x%x)', [dir.VirtualAddress]);
    exit(PR_ERROR);
  end;

  Ofs := 0;

  while (Ofs < dir.Size) do
  begin
    tmpRVA := PE.PositionRVA;

    if (not PE.ReadEx(@block, SizeOf(block))) then
      break;

    if Assigned(PE.ParseCallbacks) then
      PE.ParseCallbacks.ParsedRelocationBlockHeader(tmpRVA, block);

    if block.IsEmpty then
      break;

    inc(Ofs, SizeOf(block));

    if block.BlockSize < SizeOf(TBaseRelocationBlock) then
    begin
      PE.Msg.Write(SCategoryRelocs, 'Bad size of block (%d).', [block.BlockSize]);
      continue;
    end;

    blCnt := block.Count;

    for iBlock := 0 to blCnt - 1 do
    begin
      if (Ofs + SizeOf(entry)) > dir.Size then
      begin
        PE.Msg.Write(SCategoryRelocs, 'Relocation is out of table. PageRVA:0x%x #:%d', [block.PageRVA, iBlock]);
        PE.Msg.Write(SCategoryRelocs, 'Skipping next relocs.');
        exit(PR_OK);
      end;

      if not PE.ReadEx(@entry, SizeOf(entry)) then
        exit(PR_ERROR);

      inc(Ofs, SizeOf(entry));
      r_type := entry.GetType;
      r_ofs := entry.GetOffset;
      r_rva := r_ofs + block.PageRVA;
      if r_type <> IMAGE_REL_BASED_ABSOLUTE then
      begin
        reloc.RVA := r_rva;
        reloc.&Type := r_type;
        PE.Relocs.Put(reloc);
      end;
    end;
  end;

  exit(PR_OK);
end;

end.
