{
  Classes to represent resource data.
}
unit PE.Resources;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Types.Resources;

type
  { Nodes }

  TResourceTreeNode = class;
  TResourceTreeBranchNode = class;

  // Return False to stop traversing or True to continue.
  TResourceTraverseMethod = function(Node: TResourceTreeNode): boolean of object;

  // Base node.
  TResourceTreeNode = class
  private
    // Either ID or Name.
    FId: uint32;
    FName: UnicodeString;
    procedure SetId(const Value: uint32); inline;
    procedure SetName(const Value: UnicodeString);inline;
  public
    Parent: TResourceTreeBranchNode;

    procedure Traverse(TraverseMethod: TResourceTraverseMethod); inline;

    // Check if node is named. Otherwise it's ID.
    function IsNamed: boolean; inline;

    function IsBranch: boolean; inline;
    function IsLeaf: boolean; inline;

    // Find resource by Name or Id.
    function FindByName(const Name: string): TResourceTreeNode; inline;
    function FindByID(Id: uint32): TResourceTreeNode; inline;

    // By Name/Id.
    function FindNode(Node: TResourceTreeNode): TResourceTreeNode;

    // Find either by name or by id.
    function FindByNameOrId(const Name: string; Id: uint32): TResourceTreeNode;

    function GetNameOrId: string;

    function GetPath: string;

    property Id: uint32 read FId write SetId;
    property Name: UnicodeString read FName write SetName;
  end;

  TResourceTreeNodes = TObjectList<TResourceTreeNode>;

  // Leaf node (data).
  TResourceTreeLeafNode = class(TResourceTreeNode)
  private
    FDataRVA: TRVA; // RVA of data in original image.
    FCodepage: uint32;
    FData: TMemoryStream;
    FOriginalDataSize: uint32;
    FValidSize: boolean;
    function GetDataSize: uint32; inline;
  public
    constructor Create;
    constructor CreateFromRVA(PE: TPEImageObject; DataRVA: TRVA; DataSize: uint32; CodePage: uint32);
    constructor CreateFromEntry(PE: TPEImageObject; const Entry: TResourceDataEntry);
    constructor CreateFromStream(Stream: TStream; Pos: UInt64 = 0; Size: UInt64 = 0);

    destructor Destroy; override;

    procedure UpdateData(Buffer: PByte; Size: uint32);

    property Data: TMemoryStream read FData;
    property DataRVA: TRVA read FDataRVA;
    property DataSize: uint32 read GetDataSize;
    property CodePage: uint32 read FCodepage write FCodepage;

    // Original Size is set when node created.
    // For example it is size of parsed leaf node data. But if executable is
    // packed and not all raw size available or modified then OriginalSize is
    // not equal to DataSize (DataSize = 0).
    property OriginalDataSize: uint32 read FOriginalDataSize;

    // Leaf can be invalid if data size in parsed header doesn't match actual
    // size that can be read from section. For example if executable is packed.
    // See OriginalSize for parsed size of data.
    // By default created leaf is valid.
    // Valid size doesn't mean content is also valid, i.e. in right format.
    // For example it can be RT_BITMAP resource but contain non-bitmap info.
    property ValidSize: boolean read FValidSize;
  end;

  // Branch node.
  TResourceTreeBranchNode = class(TResourceTreeNode)
  private
    // 5.9.2. Resource Directory Entries
    // ...
    // All the Name entries precede all the ID entries for the table.
    // All entries for the table are sorted in ascending order:
    // Name entries by case-insensitive string and the ID entries by numeric value.
    FChildren: TResourceTreeNodes;
  public
    Characteristics: uint32;
    TimeDateStamp: uint32;
    MajorVersion: uint16;
    MinorVersion: uint16;

    constructor Create();
    destructor Destroy; override;

    // Get either Name or Id as string.
    function GetSafeName: string; inline;

    // Add node to children. Result is added node.
    function Add(Node: TResourceTreeNode): TResourceTreeNode;
    function AddNewBranch: TResourceTreeBranchNode;
    function AddNewLeaf: TResourceTreeLeafNode;

    // Remove node.
    procedure Remove(Node: TResourceTreeNode; RemoveSelfIfNoChildren: boolean = False);

    property Children: TResourceTreeNodes read FChildren;
  end;

  { Tree }

  TResourceTree = class
  protected
    FRoot: TResourceTreeBranchNode;
    procedure CreateDummyRoot;
  public
    constructor Create;
    destructor Destroy; override;

    // Clear all nodes.
    procedure Clear;

    property Root: TResourceTreeBranchNode read FRoot;
  end;

implementation

uses
  PE.Image;

function TreeNodeCompareLess(const A, B: TResourceTreeNode): boolean;
var
  NamedA, NamedB: boolean;
  n1, n2: string;
begin
  NamedA := A.IsNamed;
  NamedB := B.IsNamed;
  if NamedA and NamedB then // Compare named.
  begin
    n1 := UpperCase(A.Name);
    n2 := UpperCase(B.Name);
    exit(CompareStr(n1, n2) < 0);
  end;
  if (not NamedA) and (not NamedB) then // Compare by ID.
    Result := A.Id < B.Id
  else // Compare Named vs ID (named must go first).
    Result := NamedA and (not NamedB);
end;

{ TResourceTreeNode }

function TResourceTreeBranchNode.Add(Node: TResourceTreeNode): TResourceTreeNode;
begin
  Result := Node;
  if Assigned(Node) then
  begin
    Node.Parent := Self;
    FChildren.Add(Node);
  end;
end;

function TResourceTreeBranchNode.AddNewBranch: TResourceTreeBranchNode;
begin
  Result := TResourceTreeBranchNode.Create;
  Add(Result);
end;

function TResourceTreeBranchNode.AddNewLeaf: TResourceTreeLeafNode;
begin
  Result := TResourceTreeLeafNode.Create;
  Add(Result);
end;

constructor TResourceTreeBranchNode.Create();
begin
  inherited;
  FChildren := TResourceTreeNodes.Create(True);
end;

procedure TResourceTreeBranchNode.Remove(Node: TResourceTreeNode; RemoveSelfIfNoChildren: boolean);
begin
  FChildren.Remove(Node);
  if RemoveSelfIfNoChildren and (Self.FChildren.Count = 0) and Assigned(Parent) then
    Self.Parent.Remove(Self, True);
end;

destructor TResourceTreeBranchNode.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TResourceTreeBranchNode.GetSafeName: string;
begin
  if IsNamed then
    Result := name
  else
    Result := Format('#%d', [Id])
end;

{ TResourceTreeNode }

function TResourceTreeNode.FindByName(const Name: string): TResourceTreeNode;
begin
  Result := FindByNameOrId(Name, 0);
end;

function TResourceTreeNode.FindByID(Id: uint32): TResourceTreeNode;
begin
  Result := FindByNameOrId('', Id);
end;

function TResourceTreeNode.FindByNameOrId(const Name: string; Id: uint32): TResourceTreeNode;
var
  tmp: TResourceTreeNode;
begin
  Result := nil;

  if not IsBranch then
    exit;

  for tmp in TResourceTreeBranchNode(Self).FChildren do
  begin
    if (tmp.Name <> '') then
    begin
      if tmp.Name = Name then
        exit(tmp);
    end
    else
    begin
      if tmp.Id = Id then
        exit(tmp);
    end;
  end;
end;

function TResourceTreeNode.FindNode(Node: TResourceTreeNode): TResourceTreeNode;
var
  tmp: TResourceTreeNode;
begin
  Result := nil;
  if not IsBranch then
    exit;

  for tmp in TResourceTreeBranchNode(Self).FChildren do
  begin
    if tmp = node then
      exit(tmp);
  end;
end;

function TResourceTreeNode.GetNameOrId: string;
begin
  if FName <> '' then
    Result := FName
  else
    Result := Format('#%d', [FId]);
end;

function TResourceTreeNode.GetPath: string;
var
  Cur: TResourceTreeNode;
  Separator: string;
begin
  Cur := Self;

  if Cur.IsLeaf then
  begin
    Result := Format('(%d)', [TResourceTreeLeafNode(Cur).FCodepage]);
  end;

  // All parent nodes are branches.
  // Go up excluding root node.
  while (Cur.Parent <> nil) and (Cur.Parent.Parent <> nil) do
  begin
    // Leaf node don't need PathDelim.
    if Cur = Self then
      Separator := ''
    else
      Separator := PathDelim;
    Result := Format('%s%s%s', [TResourceTreeBranchNode(Cur.Parent).GetSafeName,
      Separator, Result]);
    Cur := Cur.Parent;
  end;
end;

function TResourceTreeNode.IsBranch: boolean;
begin
  Result := (Self is TResourceTreeBranchNode);
end;

function TResourceTreeNode.IsLeaf: boolean;
begin
  Result := (Self is TResourceTreeLeafNode);
end;

function TResourceTreeNode.IsNamed: boolean;
begin
  Result := Name <> '';
end;

procedure TResourceTreeNode.SetId(const Value: uint32);
begin
  FId := Value;
  FName := '';
end;

procedure TResourceTreeNode.SetName(const Value: UnicodeString);
begin
  FId := 0;
  FName := Value;
end;

procedure TResourceTreeNode.Traverse(TraverseMethod: TResourceTraverseMethod);
const
  WANT_MORE_NODES = True;
var
  n: TResourceTreeNode;
begin
  if Assigned(TraverseMethod) and (Assigned(Self)) then
  begin
    // Visit node.
    if TraverseMethod(Self) = WANT_MORE_NODES then
    begin
      // If branch, visit children.
      if Self.IsBranch then
        for n in TResourceTreeBranchNode(Self).FChildren do
          n.Traverse(TraverseMethod)
    end;
  end;
end;

{ TResourceTree }

procedure TResourceTree.Clear;
begin
  FRoot.Free; // To destroy all children.
  CreateDummyRoot;
end;

constructor TResourceTree.Create;
begin
  inherited;
  CreateDummyRoot;
end;

procedure TResourceTree.CreateDummyRoot;
begin
  FRoot := TResourceTreeBranchNode.Create;
end;

destructor TResourceTree.Destroy;
begin
  FRoot.Free;
  inherited;
end;

{ TResourceTreeLeafNode }

constructor TResourceTreeLeafNode.Create;
begin
  inherited Create;
  FValidSize := True; // valid by default
  FData := TMemoryStream.Create;
end;

constructor TResourceTreeLeafNode.CreateFromRVA(PE: TPEImageObject;
  DataRVA: TRVA; DataSize: uint32; CodePage: uint32);
begin
  Create;

  FDataRVA := DataRVA;
  FCodepage := CodePage;
  FOriginalDataSize := DataSize;

  // Copy data from image.
  if DataSize <> 0 then
  begin
    // Check if we can't read whole raw size then this section either packed or
    // spoiled and mark it as invalid without reading any data.
    if not TPEImage(PE).RegionExistsRaw(DataRVA, DataSize) then
    begin
      FValidSize := False;
    end
    else
    begin
      // Otherwise leaf is valid and contain whole size.
      // Though it's not guaranteed that data is in right format anyway :)
      FData.Size := DataSize;
      TPEImage(PE).SaveRegionToStream(FData, DataRVA, DataSize);
    end;
  end;
end;

constructor TResourceTreeLeafNode.CreateFromStream(
  Stream: TStream;
  Pos, Size: UInt64);
begin
  Create;

  Stream.Position := Pos;

  if Size = 0 then
    Size := Stream.Size - Pos;

  FOriginalDataSize := Size;

  FData.CopyFrom(Stream, Size);
end;

constructor TResourceTreeLeafNode.CreateFromEntry(
  PE: TPEImageObject;
  const Entry: TResourceDataEntry);
begin
  CreateFromRVA(PE, Entry.DataRVA, Entry.Size, Entry.CodePage);
end;

destructor TResourceTreeLeafNode.Destroy;
begin
  FData.Free;
  inherited;
end;

function TResourceTreeLeafNode.GetDataSize: uint32;
begin
  Result := FData.Size;
end;

procedure TResourceTreeLeafNode.UpdateData(Buffer: PByte; Size: uint32);
begin
  if (Buffer = nil) or (Size = 0) then
  begin
    FData.Clear;
    exit;
  end;
  FData.Size := Size;
  Move(Buffer^, FData.Memory^, Size);
end;

end.
