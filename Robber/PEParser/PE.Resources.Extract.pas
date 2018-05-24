unit PE.Resources.Extract;

interface

uses
  PE.Common,
  PE.Resources;

// Extract raw resource data from Root node and save it to Dir folder.
// If Root is nil, the main root is taken.
// Result is number of resources extracted.
function ExtractRawResources(Img: TPEImageObject; const Dir: string;
  Root: TResourceTreeNode = nil): integer;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  PE.Image;

type

  { TExtractor }

  TExtractor = class
  private
    FImg: TPEImage;
    FDir: string;
    FCount: integer;
    function Callback(Node: TResourceTreeNode): boolean;
  public
    function Extract(Img: TPEImage; const Dir: string; Root: TResourceTreeNode): integer;
  end;

function TExtractor.Callback(Node: TResourceTreeNode): boolean;
var
  Leaf: TResourceTreeLeafNode;
  FileName: string;
  Path: string;
begin
  if Node.IsLeaf then
  begin
    Leaf := Node as TResourceTreeLeafNode;
    // Make filename and path.
    FileName := Format('%s\%s', [FDir, Leaf.GetPath]);
    Path := ExtractFilePath(FileName);
    // Create path and save file.
    TDirectory.CreateDirectory(Path);
    Leaf.Data.SaveToFile(FileName);
    inc(FCount);
  end;
  Result := True; // continue
end;

function ExtractRawResources(Img: TPEImageObject; const Dir: string; Root: TResourceTreeNode = nil): integer;
var
  Extractor: TExtractor;
begin
  Extractor := TExtractor.Create;
  try
    Result := Extractor.Extract(Img as TPEImage,
      ExcludeTrailingPathDelimiter(Dir), Root);
  finally
    Extractor.Free;
  end;
end;

function TExtractor.Extract(Img: TPEImage; const Dir: string;
  Root: TResourceTreeNode): integer;
begin
  FImg := Img;
  FDir := Dir;
  FCount := 0;
  if Root = nil then
    Root := Img.ResourceTree.Root;
  if Root = nil then
    Exit(0);
  TDirectory.CreateDirectory(Dir);
  Img.ResourceTree.Root.Traverse(Callback);
  Exit(FCount);
end;

end.

