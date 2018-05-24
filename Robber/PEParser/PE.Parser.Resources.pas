unit PE.Parser.Resources;

interface

uses
  System.SysUtils,
  PE.Common,
  PE.Types,
  PE.Types.Directories,
  PE.Types.Resources,
  PE.Resources;

type
  TPEResourcesParser = class(TPEParser)
  protected
    FBaseRVA: TRVA; // RVA of RSRC section base
    FTree: TResourceTree;

    // Read resource node entry.
    function ReadEntry(
      ParentNode: TResourceTreeBranchNode;
      RVA: TRVA;
      Index: integer;
      RDT: PResourceDirectoryTable): TResourceTreeNode;

    // Read resource node.
    function ReadNode(
      ParentNode: TResourceTreeBranchNode;
      RVA: TRVA): TParserResult;

    function LogInvalidResourceSizesTraverse(Node: TResourceTreeNode): boolean;
    procedure LogInvalidResourceSizes;
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image;

{ TPEResourcesParser }

procedure TPEResourcesParser.LogInvalidResourceSizes;
begin
  FTree.Root.Traverse(LogInvalidResourceSizesTraverse);
end;

function TPEResourcesParser.LogInvalidResourceSizesTraverse(Node: TResourceTreeNode): boolean;
begin
  if Node.IsLeaf then
    if not TResourceTreeLeafNode(Node).ValidSize then
      TPEImage(FPE).Msg.Write(SCategoryResources, 'Bad size of resource (probably packed): %s', [Node.GetPath]);

  Result := True;
end;

function TPEResourcesParser.Parse: TParserResult;
var
  Img: TPEImage;
  dir: TImageDataDirectory;
begin
  Img := TPEImage(FPE);

  // Check if directory present.
  if not Img.DataDirectories.Get(DDIR_RESOURCE, @dir) then
    exit(PR_OK);

  if dir.IsEmpty then
    exit(PR_OK);

  // Store base RVA.
  FBaseRVA := dir.VirtualAddress;

  // Try to seek resource dir.
  if not Img.SeekRVA(FBaseRVA) then
    exit(PR_ERROR);

  // Read root and children.
  FTree := Img.ResourceTree;
  ReadNode(FTree.Root, FBaseRVA);

  // Log invalid leaf nodes.
  LogInvalidResourceSizes;

  exit(PR_OK);
end;

function TPEResourcesParser.ReadEntry(
  ParentNode: TResourceTreeBranchNode;
  RVA: TRVA;
  Index: integer;
  RDT: PResourceDirectoryTable): TResourceTreeNode;
var
  Img: TPEImage;
  Entry: TResourceDirectoryEntry;
  DataEntry: TResourceDataEntry;
  SubRVA, DataRVA, NameRVA: TRVA;
  LeafNode: TResourceTreeLeafNode;
  BranchNode: TResourceTreeBranchNode;
  EntryName: string;
begin
  Result := nil;
  Img := TPEImage(FPE);

  // Try to read entry.
  if not Img.SeekRVA(RVA + Index * SizeOf(Entry)) then
  begin
    Img.Msg.Write(SCategoryResources, 'Bad resource entry RVA.');
    exit;
  end;

  if not Img.ReadEx(@Entry, SizeOf(Entry)) then
  begin
    Img.Msg.Write(SCategoryResources, 'Bad resource entry.');
    exit;
  end;

  // Prepare entry name.
  EntryName := '';
  if Entry.EntryType = ResourceEntryByName then
  begin
    NameRVA := FBaseRVA + Entry.NameRVA;
    if not Img.SeekRVA(NameRVA) then
    begin
      Img.Msg.Write(SCategoryResources, 'Bad entry name RVA (0x%x)', [NameRVA]);
      exit;
    end;
    EntryName := Img.ReadUnicodeStringLenPfx2;
  end;

  // Check if RVA of child is correct.
  DataRVA := Entry.DataEntryRVA + FBaseRVA;
  if not Img.RVAExists(DataRVA) then
  begin
    Img.Msg.Write(SCategoryResources, 'Bad entry RVA (0x%x)', [DataRVA]);
    exit;
  end;

  // Handle Leaf or Branch.
  if Entry.IsDataEntryRVA then
  begin
    {
      Leaf node
    }

    DataRVA := Entry.DataEntryRVA + FBaseRVA;
    if not(Img.SeekRVA(DataRVA) and Img.ReadEx(@DataEntry, SizeOf(DataEntry))) then
    begin
      Img.Msg.Write(SCategoryResources, 'Bad resource leaf node.');
      exit;
    end;
    LeafNode := TResourceTreeLeafNode.CreateFromEntry(FPE, DataEntry);
    Result := LeafNode;
  end
  else
  begin
    {
      Branch Node.
    }

    // Alloc and fill node.
    BranchNode := TResourceTreeBranchNode.Create;
    if RDT <> nil then
    begin
      BranchNode.Characteristics := RDT^.Characteristics;
      BranchNode.TimeDateStamp := RDT^.TimeDateStamp;
      BranchNode.MajorVersion := RDT^.MajorVersion;
      BranchNode.MinorVersion := RDT^.MinorVersion;
    end;
    // Get sub-level RVA.
    SubRVA := Entry.SubdirectoryRVA + FBaseRVA;
    // Read children.
    ReadNode(BranchNode, SubRVA);
    Result := BranchNode;
  end;

  // Set id or name.
  if Entry.EntryType = ResourceEntryById then
    Result.Id := Entry.IntegerID
  else
    Result.Name := EntryName;

  // Add node.
  ParentNode.Add(Result);
end;

function TPEResourcesParser.ReadNode(ParentNode: TResourceTreeBranchNode; RVA: TRVA): TParserResult;
var
  Img: TPEImage;
  RDT: TResourceDirectoryTable;
  i, Total: integer;
begin
  Img := TPEImage(FPE);

  if not Img.SeekRVA(RVA) then
  begin
    Img.Msg.Write(SCategoryResources, 'Bad resource directory table RVA (0x%x)', [RVA]);
    exit(PR_ERROR);
  end;

  // Read Directory Table.
  if not Img.ReadEx(@RDT, SizeOf(RDT)) then
  begin
    Img.Msg.Write(SCategoryResources, 'Failed to read resource directory table.');
    exit(PR_ERROR);
  end;

  inc(RVA, SizeOf(RDT));

  if (RDT.NumberOfNameEntries = 0) and (RDT.NumberOfIDEntries = 0) then
  begin
    Img.Msg.Write(SCategoryResources, 'Node have no name/id entries.');
    exit(PR_ERROR);
  end;

  // Total number of entries.
  Total := RDT.NumberOfNameEntries + RDT.NumberOfIDEntries;

  // Read entries.
  for i := 0 to Total - 1 do
    if ReadEntry(ParentNode, RVA, i, @RDT) = nil then
      exit(PR_ERROR);

  exit(PR_OK);
end;

end.
