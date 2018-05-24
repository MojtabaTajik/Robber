{
  Unit to manipulate resources in Windows oriented way.

  It means 3 resource levels:
  - Type (RT_...)
  - Name
  - Language
}
unit PE.Resources.Windows;

interface

uses
  System.Classes,
  PE.Image,
  PE.Resources,
  PE.Resources.VersionInfo;

{ Values for Windows PE. }

type
  RSRCID = UInt32;

const
  // The following are the predefined resource types.
  // http://msdn.microsoft.com/en-us/library/windows/desktop/ms648009(v=vs.85).aspx

  RT_CURSOR       = RSRCID(1);                      // Hardware-dependent cursor resource.
  RT_BITMAP       = RSRCID(2);                      // Bitmap resource.
  RT_ICON         = RSRCID(3);                      // Hardware-dependent icon resource.
  RT_MENU         = RSRCID(4);                      // Menu resource.
  RT_DIALOG       = RSRCID(5);                      // Dialog box.
  RT_STRING       = RSRCID(6);                      // String-table entry.
  RT_FONTDIR      = RSRCID(7);                      // Font directory resource.
  RT_FONT         = RSRCID(8);                      // Font resource.
  RT_ACCELERATOR  = RSRCID(9);                      // Accelerator table.
  RT_RCDATA       = RSRCID(10);                     // Application-defined resource (raw data).
  RT_MESSAGETABLE = RSRCID(11);                     // Message-table entry.
  RT_GROUP_CURSOR = RSRCID(UInt32(RT_CURSOR) + 11); // Hardware-independent cursor resource.
  RT_GROUP_ICON   = RSRCID(UInt32(RT_ICON) + 11);   // Hardware-independent icon resource.
  RT_VERSION      = RSRCID(16);                     // Version resource.
  RT_DLGINCLUDE   = RSRCID(17);                     // Allows a resource editing tool to associate a string with an .rc file.
  RT_PLUGPLAY     = RSRCID(19);                     // Plug and Play resource.
  RT_VXD          = RSRCID(20);                     // VXD.
  RT_ANICURSOR    = RSRCID(21);                     // Animated cursor.
  RT_ANIICON      = RSRCID(22);                     // Animated icon.
  RT_HTML         = RSRCID(23);                     // HTML resource.
  RT_MANIFEST     = RSRCID(24);                     // Side-by-Side Assembly Manifest.

  RT_NAMES: array [0 .. 24] of string = (
    '#0',              // 0
    'RT_CURSOR',       // 1
    'RT_BITMAP',       // 2
    'RT_ICON',         // 3
    'RT_MENU',         // 4
    'RT_DIALOG',       // 5
    'RT_STRING',       // 6
    'RT_FONTDIR',      // 7
    'RT_FONT',         // 8
    'RT_ACCELERATOR',  // 9
    'RT_RCDATA',       // 10
    'RT_MESSAGETABLE', // 11
    'RT_GROUP_CURSOR', // 12
    '#13',             // 13
    'RT_GROUP_ICON',   // 14
    '#15',             // 15
    'RT_VERSION',      // 16
    'RT_DLGINCLUDE',   // 17
    '#18',             // 18
    'RT_PLUGPLAY',     // 19
    'RT_VXD',          // 20
    'RT_ANICURSOR',    // 21
    'RT_ANIICON',      // 22
    'RT_HTML',         // 23
    'RT_MANIFEST'      // 24
    );

type
  TWindowsResourceTree = class
  private
    function FindResourceInternal(lpType, lpName: PChar; Language: word; Depth: cardinal): TResourceTreeNode;
  protected
    FResourceTree: TResourceTree;
  public
    constructor Create(ResourceTree: TResourceTree);

    // Find Type-Name-Language leaf.
    function FindResource(lpType, lpName: PChar; Language: word): TResourceTreeLeafNode; overload;
    // Find Type-Name branch.
    function FindResource(lpType, lpName: PChar): TResourceTreeBranchNode; overload;
    // Find Type branch.
    function FindResource(lpType: PChar): TResourceTreeBranchNode; overload;

    // Update resource by full path.
    // lpType, lpName: if <= $FFFF it's ID otherwise it point to Name string.
    // If (lpData=nil) and (cbData=0) then resource is deleted.
    procedure UpdateResource(lpType, lpName: PChar; Language: word;
      lpData: PByte; cbData: UInt32);

    function RemoveResource(lpType, lpName: PChar; Language: word): boolean;
  end;

function IsIntResource(lpszType: PChar): boolean; inline;
function GetIntResource(lpszType: PChar): word; inline;
function MakeIntResource(wInteger: uint16): PChar; inline;

// See Windows GetFileVersionInfo function.
// Find RT_VERSION raw data or nil if failed.
// Don't Free returned stream because it's part of ResourceTree.
function PeGetFileVersionInfo(img: TPEImage): TMemoryStream;

function PeVerQueryValueFixed(stream: TStream; out value: VS_FIXEDFILEINFO): boolean;

implementation

uses
  System.SysUtils;

function IsIntResource(lpszType: PChar): boolean; inline;
begin
  Result := NativeUInt(lpszType) shr 16 = 0;
end;

function GetIntResource(lpszType: PChar): word; // inline;
begin
  Result := NativeUInt(lpszType) and $FFFF;
end;

function MakeIntResource(wInteger: uint16): PChar;
begin
  Result := PChar(wInteger);
end;

constructor TWindowsResourceTree.Create(ResourceTree: TResourceTree);
begin
  FResourceTree := ResourceTree;
end;

// Find or create node.
// IsBranch: Is fetched node must be branch (or leaf).
// lpName: Name or ID (intresource)
function FetchNode(
  Parent: TResourceTreeBranchNode;
  IsBranch: boolean;
  CreateIfNotExists: boolean;
  lpName: PChar): TResourceTreeNode;
var
  bIntRsrc: boolean;
begin
  bIntRsrc := IsIntResource(lpName);
  // Check if node with such Name/Id already exists.
  if bIntRsrc then
    Result := Parent.FindByID(GetIntResource(lpName))
  else
    Result := Parent.FindByName(lpName);
  // If not exists, create it.
  if Result = nil then
  begin
    if CreateIfNotExists then
    begin
      // Create sub-node.
      if IsBranch then
        Result := Parent.AddNewBranch
      else
        Result := Parent.AddNewLeaf;
      // Set Id/Name
      if bIntRsrc then
        Result.Id := GetIntResource(lpName)
      else
        Result.Name := lpName;
    end;
  end
  else
  // If exists, check if branch/leaf.
  begin
    if not(Result.IsBranch = IsBranch) then
      raise Exception.Create('Node type mismatch.');
  end;
end;

function TWindowsResourceTree.RemoveResource(lpType, lpName: PChar; Language: word): boolean;
var
  n: TResourceTreeNode;
begin
  n := FindResourceInternal(lpType, lpName, Language, 2);
  if not assigned(n) then
    exit(false);

  n.Parent.Remove(n);
  exit(true);
end;

function TWindowsResourceTree.FindResource(lpType, lpName: PChar; Language: word): TResourceTreeLeafNode;
begin
  Result := TResourceTreeLeafNode(FindResourceInternal(lpType, lpName, Language, 2));
end;

function TWindowsResourceTree.FindResource(lpType, lpName: PChar):
  TResourceTreeBranchNode;
begin
  Result := TResourceTreeBranchNode(FindResourceInternal(lpType, lpName, 0, 1));
end;

function TWindowsResourceTree.FindResource(lpType: PChar): TResourceTreeBranchNode;
begin
  Result := TResourceTreeBranchNode(FindResourceInternal(lpType, nil, 0, 0));
end;

function TWindowsResourceTree.FindResourceInternal(lpType, lpName: PChar;
  Language: word; Depth: cardinal): TResourceTreeNode;
const
  IsBranches: array [0 .. 2] of boolean = (true, true, false);
var
  i: integer;
  n: TResourceTreeNode;
  val: PChar;
begin
  if Depth > 2 then
    Depth := 2;
  n := FResourceTree.Root;
  val := nil; // compiler friendly
  for i := 0 to Depth do
  begin
    case i of
      0:
        val := lpType;
      1:
        val := lpName;
      2:
        val := PChar(Language);
    end;
    n := FetchNode(TResourceTreeBranchNode(n), IsBranches[i], false, val);
    if n = nil then
      exit(nil);
  end;
  Result := n;
end;

procedure TWindowsResourceTree.UpdateResource(lpType, lpName: PChar;
  Language: word; lpData: PByte; cbData: UInt32);
var
  nRoot, nType, nName: TResourceTreeBranchNode;
  nLang: TResourceTreeLeafNode;
begin
  if (lpData = nil) and (cbData = 0) then
  begin
    RemoveResource(lpType, lpName, Language);
    exit;
  end;
  nRoot := FResourceTree.Root;
  nType := FetchNode(nRoot, true, true, lpType) as TResourceTreeBranchNode;
  nName := FetchNode(nType, true, true, lpName) as TResourceTreeBranchNode;
  nLang := FetchNode(nName, false, true, PChar(Language)) as TResourceTreeLeafNode;
  nLang.UpdateData(lpData, cbData);
end;

function PeGetFileVersionInfo(img: TPEImage): TMemoryStream;
var
  rt: TWindowsResourceTree;
  versionBranch: TResourceTreeBranchNode;
  versionLeaf: TResourceTreeLeafNode;
begin
  rt := TWindowsResourceTree.Create(img.ResourceTree);
  try
    versionBranch := rt.FindResource(MakeIntResource(RT_VERSION));
    if assigned(versionBranch) and versionBranch.IsBranch and (versionBranch.Children.Count > 0) then
    begin
      versionBranch := TResourceTreeBranchNode(versionBranch.Children.First);
      if assigned(versionBranch) and versionBranch.IsBranch and (versionBranch.Children.Count > 0) then
      begin
        versionLeaf := TResourceTreeLeafNode(versionBranch.Children.First);
        if assigned(versionLeaf) and versionLeaf.IsLeaf then
        begin
          exit(versionLeaf.Data);
        end;
      end;
    end;
    exit(nil);
  finally
    rt.Free;
  end;
end;

function PeVerQueryValueFixed(stream: TStream; out value: VS_FIXEDFILEINFO): boolean;
var
  verInfo: TPEVersionInfo;
  block: TBlock;
begin
  verInfo := TPEVersionInfo.Create;
  try
    verInfo.LoadFromStream(stream);

    if assigned(verInfo.Root) then
      for block in verInfo.Root.Children do
        if block.ClassType = TBlockVersionInfo then
        begin
          value := TBlockVersionInfo(block).FixedInfo;
          exit(true);
        end;

    exit(false);
  finally
    verInfo.Free;
  end;
end;

end.
