unit PE.Build.Resource;

interface

uses
  System.Classes,
  PE.Build.Common,
  PE.Common,
  PE.Resources,
  PE.Types.Resources;

type
  TRsrcBuilder = class(TDirectoryBuilder)
  private
    // Sizes.
    FSizeOfResourceTables: UInt32;
    FSizeOfDataDesc: UInt32;
    FSizeOfNames: UInt32;
    FSizeOfData: UInt32;
    procedure ClearSizes; inline;
    function CalcSizesCallback(Node: TResourceTreeNode): boolean;
    procedure CalcSizes; inline;
  private
    // Offsets.
    FOfsTables: UInt32;
    FOfsDataDesc: UInt32;
    FOfsNames: UInt32;
    FOfsData: UInt32;
    FOfsEnd: UInt32;
    procedure CalcOffsets;
  private
    FBaseRVA: TRVA;
    FStream: TStream;
    // Write name. Result is position of written name.
    function WriteName(const Name: UnicodeString): UInt32;
    // Write table and update offsets. Result is offset where table was written.
    function WriteBranchNode(Root: TResourceTreeBranchNode): UInt32;
    // Write leaf data and return offset where it was written.
    function WriteLeafData(Node: TResourceTreeLeafNode): UInt32;
    // Write leaf node and return offset where it was written.
    function WriteLeafNode(Node: TResourceTreeLeafNode): UInt32;
  public
    procedure Build(DirRVA: TRVA; Stream: TStream); override;
    class function GetDefaultSectionFlags: Cardinal; override;
    class function GetDefaultSectionName: string; override;
    class function NeedRebuildingIfRVAChanged: boolean; override;
  end;

implementation

uses
  // Expand
  PE.Image,
  //
  PE.Utils;

procedure TRsrcBuilder.Build(DirRVA: TRVA; Stream: TStream);
var
  Root: TResourceTreeBranchNode;
begin
  FBaseRVA := DirRVA;
  CalcSizes;
  CalcOffsets;

  Root := FPE.ResourceTree.Root;

  // If there's no items at root exit.
  if Root.Children.Count = 0 then
    exit;

  // Setup stream.
  FStream := Stream;
  FStream.Size := FOfsEnd;
  // Build nodes starting from root.
  WriteBranchNode(Root);
end;

procedure TRsrcBuilder.CalcSizes;
begin
  ClearSizes;
  FPE.ResourceTree.Root.Traverse(CalcSizesCallback);
end;

function TRsrcBuilder.CalcSizesCallback(Node: TResourceTreeNode): boolean;
var
  Leaf: TResourceTreeLeafNode;
  Branch: TResourceTreeBranchNode;
begin
  if Node.IsLeaf then
  begin
    Leaf := Node as TResourceTreeLeafNode;
    inc(FSizeOfDataDesc, SizeOf(TResourceDataEntry));
    inc(FSizeOfData, Leaf.DataSize);
  end
  else
  begin
    Branch := Node as TResourceTreeBranchNode;
    inc(FSizeOfResourceTables, SizeOf(TResourceDirectoryTable));
    inc(FSizeOfResourceTables, SizeOf(TResourceDirectoryEntry) * Branch.Children.Count);
    if Branch.Name <> '' then
    begin
      inc(FSizeOfNames, 2 + SizeOf(WideChar) * Length(Branch.Name));
    end;
  end;
  Result := True;
end;

procedure TRsrcBuilder.ClearSizes;
begin
  FSizeOfResourceTables := 0;
  FSizeOfDataDesc := 0;
  FSizeOfNames := 0;
  FSizeOfData := 0;
end;

class function TRsrcBuilder.GetDefaultSectionFlags: Cardinal;
begin
  Result := $40000040; // readable + initialized data
end;

class function TRsrcBuilder.GetDefaultSectionName: string;
begin
  Result := '.rsrc';
end;

class function TRsrcBuilder.NeedRebuildingIfRVAChanged: boolean;
begin
  Result := True;
end;

function TRsrcBuilder.WriteLeafData(Node: TResourceTreeLeafNode): UInt32;
var
  Pos: UInt32;
begin
  Result := FOfsData;
  if Node.Data.Size <> 0 then
  begin
    Pos := FStream.Position;
    FStream.Position := FOfsData;
    Node.Data.Position := 0;
    FStream.CopyFrom(Node.Data, Node.Data.Size);
    inc(FOfsData, Node.Data.Size);
    FStream.Position := Pos;
  end;
end;

function TRsrcBuilder.WriteLeafNode(Node: TResourceTreeLeafNode): UInt32;
var
  DataEntry: TResourceDataEntry;
  Pos: UInt32;
begin
  Result := FOfsDataDesc;
  Pos := FStream.Position;
  FStream.Position := FOfsDataDesc; // store pos
  // Write data and make data desc.
  DataEntry.DataRVA := WriteLeafData(Node) + FBaseRVA;
  DataEntry.Size := Node.DataSize;
  DataEntry.Codepage := Node.Codepage;
  DataEntry.Reserved := 0;
  // Write data.
  FStream.Write(DataEntry, SizeOf(DataEntry));
  inc(FOfsDataDesc, SizeOf(DataEntry));
  FStream.Position := Pos; // restore pos
end;

function TRsrcBuilder.WriteBranchNode(Root: TResourceTreeBranchNode): UInt32;
type
  TSimpleEntry = packed record
    IdOrNameOfs: UInt32;
    ChildOfs: UInt32;
  end;

  PSimpleEntry = ^TSimpleEntry;
var
  Table: TResourceDirectoryTable;
  Node: TResourceTreeNode;
  Entries: array of TSimpleEntry;
  Entry: PSimpleEntry;
  Pos: UInt32;
begin
  if Root.Children.Count = 0 then
    exit(0);

  Pos := FStream.Position;

  Result := FOfsTables;

  // Prepare table.
  Table.Characteristics := Root.Characteristics;
  Table.TimeDateStamp := Root.TimeDateStamp;
  Table.MajorVersion := Root.MajorVersion;
  Table.MinorVersion := Root.MinorVersion;

  Table.NumberOfNameEntries := 0;
  Table.NumberOfIDEntries := 0;

  for Node in Root.Children do
    if Node.IsNamed then
      inc(Table.NumberOfNameEntries)
    else
      inc(Table.NumberOfIDEntries);

  // Write table.
  FStream.Position := FOfsTables;
  FStream.Write(Table, SizeOf(Table));
  // Update FOfsTables.
  inc(FOfsTables, SizeOf(TResourceDirectoryTable));
  inc(FOfsTables, SizeOf(TResourceDirectoryEntry) * Root.Children.Count);
  // Entries.

  // Prepare entries.
  SetLength(Entries, Root.Children.Count);
  Entry := @Entries[0];

  for Node in Root.Children do
  begin
    // Set Id or Name.
    if Node.IsNamed then
      Entry.IdOrNameOfs := WriteName(Node.Name) or $80000000 // Named
    else
      Entry.IdOrNameOfs := Node.Id; // ID
    // Set child offset.
    if Node.IsLeaf then
      Entry.ChildOfs := WriteLeafNode(TResourceTreeLeafNode(Node))
    else
      Entry.ChildOfs := WriteBranchNode(TResourceTreeBranchNode(Node)) or $80000000;
    // Next entry.
    inc(Entry);
  end;
  // Write entries.
  FStream.Write(Entries[0], Length(Entries) * SizeOf(Entries[0]));
  FStream.Position := Pos; // resotre pos
end;

function TRsrcBuilder.WriteName(const Name: UnicodeString): UInt32;
var
  Len: word;
  Pos: UInt32;
begin
  // Align offset up 2 bytes.
  if (FOfsNames mod 2) <> 0 then
    inc(FOfsNames);
  Pos := FStream.Position; // store pos
  Result := FOfsNames;
  FStream.Position := FOfsNames;
  Len := Length(Name);
  FStream.Write(Len, 2);
  FStream.Write(Name[1], Length(Name) * SizeOf(Name[1]));
  FOfsNames := FStream.Position;
  FStream.Position := Pos; // restore pos
end;

procedure TRsrcBuilder.CalcOffsets;
var
  MachineWord: Byte;
begin
  MachineWord := FPE.GetImageBits div 8;
  FOfsTables := 0;
  FOfsDataDesc := FOfsTables + FSizeOfResourceTables;
  FOfsNames := FOfsDataDesc + FSizeOfDataDesc;
  FOfsData := AlignUp(FOfsNames + FSizeOfNames, MachineWord);
  FOfsEnd := FOfsData + FSizeOfData;
end;

end.
