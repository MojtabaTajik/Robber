unit PE.Build.Relocs;

interface

uses
  System.Classes,
  PE.Common,
  PE.Build.Common,
  PE.Types.Relocations,
  PE.Utils;

type
  TRelocBuilder = class(TDirectoryBuilder)
  public
    procedure Build(DirRVA: TRVA; Stream: TStream); override;
    class function GetDefaultSectionFlags: uint32; override;
    class function GetDefaultSectionName: string; override;
    class function NeedRebuildingIfRVAChanged: boolean; override;
  end;

implementation

const
  RELOC_BLOCK_ALIGN = $1000;

  { TRelocBuilder }

function CalcBaseRVA(RVA: TRVA): TRVA; inline;
begin
  Result := AlignDown(RVA, RELOC_BLOCK_ALIGN);
end;

procedure TRelocBuilder.Build(DirRVA: TRVA; Stream: TStream);
var
  Block: TBaseRelocationBlock;
  Cur: TRelocTree.TRBNodePtr;
  NextBlockRVA: TRVA;
  Pos0, Pos1: UInt64;
  Entry: TBaseRelocationEntry;
begin
  if FPE.Relocs.Count = 0 then
    Exit;
  // Relocations are already sorted by RVA.
  Cur := FPE.Relocs.Items.First;
  while (Cur <> nil) do
  begin
    // New block.
    Pos0 := Stream.Position;
    Stream.Position := Pos0 + SizeOf(Block);
    Block.PageRVA := CalcBaseRVA(Cur^.K.RVA);
    NextBlockRVA := Block.PageRVA + RELOC_BLOCK_ALIGN;
    // Entries.
    while (Cur <> nil) and (Cur^.K.RVA < NextBlockRVA) do
    begin
      Entry.raw := (Cur^.K.RVA and $0FFF) or (Cur^.K.&Type shl 12);
      Stream.Write(Entry, SizeOf(Entry));
      Cur := FPE.Relocs.Items.GetNext(Cur);
    end;
    // If not last block, check if need align for next block.
    if (Cur <> nil) then
    begin
      // Each block must start on a 32-bit boundary.
      Entry.raw := 0;
      while (Stream.Position mod 4) <> 0 do
        Stream.Write(Entry, SizeOf(Entry));
    end;
    // Write block header.
    Pos1 := Stream.Position;
    Block.BlockSize := Pos1 - Pos0;
    // Write block record.
    Stream.Position := Pos0;
    Stream.Write(Block, SizeOf(Block));
    Stream.Position := Pos1;
  end;
end;

class function TRelocBuilder.GetDefaultSectionFlags: uint32;
begin
  Result := $42000040; // Readable, Discardable, Initialized data.
end;

class function TRelocBuilder.GetDefaultSectionName: string;
begin
  Result := '.reloc';
end;

class function TRelocBuilder.NeedRebuildingIfRVAChanged: boolean;
begin
  Result := False;
end;

end.
