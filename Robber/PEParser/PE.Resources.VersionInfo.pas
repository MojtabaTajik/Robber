{
  RT_VERSION resource
  http://msdn.microsoft.com/en-us/library/aa381058.aspx
}
unit PE.Resources.VersionInfo;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,

  PE.Common,
  PE.Utils;

{$i 'VerRsrc.inc'}

type
  TBlock = class;
  TBlockList = TObjectList<TBlock>;
  TBlockClass = class of TBlock;

  TRootBlock = class
  public
    Name: string;
    Parent: TRootBlock;
    Children: TBlockList;
    constructor Create(Parent: TRootBlock);
    destructor Destroy; override;
  end;

  TBlock = class(TRootBlock)
  private
    Size: integer;
    Offset: TFileOffset;
    ValueOffset: TFileOffset;
    ValueSize: integer;
    function GetBlockEndOffset: TFileOffset; inline;
  end;

  TBlockVersionInfo = class(TBlock)
  public
    FixedInfo: VS_FIXEDFILEINFO;
  end;

  TBlockStringInfo = class(TBlock)
  end;

  TBlockStringInfoNode = class(TBlockStringInfo)
  public
    Lang: word;
    Charset: word;
  end;

  TBlockStringInfoItems = TList<TPair<string, string>>;

  TBlockStringInfoPair = class(TBlock)
  public
    Value: string;
    property Key: string read Name;
  end;

  TBlockVarInfo = class(TBlock);

  TBlockVarTranslationInfo = class(TBlock)
  public
    langID: word;
    charsetID: word;
  end;

  TPrintFunc = reference to procedure(const Text: string);

  TPEVersionInfo = class
  private
    procedure ProcessBlocks(Stream: TStream; Blocks: TBlockList);
    procedure PrintTreeEx(n: TRootBlock; PrintFn: TPrintFunc; Indent: integer);
  public
    Root: TRootBlock;

    constructor Create;
    destructor Destroy; override;

    procedure LoadFromStream(Stream: TStream);
    procedure PrintTree(PrintFn: TPrintFunc; Indent: integer = 0);
  end;

implementation

type
  TVersionInfoBlockHeader = packed record
    Length: uint16;      // block length w/o padding
    ValueLength: uint16; // value length (optional)
    &Type: uint16;       // Value type (0: binary; 1: text)

    // Here goes value name (UTF-16, 0-terminated)
  end;

  { TPEVersionInfo }

procedure ReadStringInfoItems(Stream: TStream; EndOffset: TFileOffset);
var
  blockHdr: TVersionInfoBlockHeader;
  Key, Value: string;
  Offset: TFileOffset;
begin
  Offset := Stream.Position;
  while (Offset < EndOffset) and StreamSeek(Stream, Offset) do
  begin
    if not StreamRead(Stream, blockHdr, SizeOf(blockHdr)) then
      break;
    StreamReadStringW(Stream, Key);
    StreamSeekAlign(Stream, 4);

    if blockHdr.ValueLength <> 0 then
      StreamReadStringW(Stream, Value)
    else
      Value := '';

    Offset := AlignUp(Offset + blockHdr.Length, 4);
  end;
end;

function CreateBlockByName(const BlockName: string; Parent: TRootBlock): TBlock;
begin
  if Parent.ClassType = TBlockVarInfo then
  begin
    if BlockName = 'Translation' then
      Exit(TBlockVarTranslationInfo.Create(Parent));
  end;

  if BlockName = 'VS_VERSION_INFO' then
    Exit(TBlockVersionInfo.Create(Parent))
  else if BlockName = 'StringFileInfo' then
    Exit(TBlockStringInfo.Create(Parent))
  else if BlockName = 'VarFileInfo' then
    Exit(TBlockVarInfo.Create(Parent))
  else
    Exit(TBlock.Create(Parent));
end;

procedure ReadLevelOfBlocks(Stream: TStream; Offset, EndOffset: TFileOffset;
  var List: TBlockList;
  Parent: TRootBlock;
  BlockClass: TBlockClass = nil);
var
  blockHdr: TVersionInfoBlockHeader;
  BlockName: string;
  block: TBlock;
begin
  List.Clear;

  while (Offset < EndOffset) and StreamSeek(Stream, Offset) do
  begin
    if not StreamRead(Stream, blockHdr, SizeOf(blockHdr)) then
      break;

    if not StreamReadStringW(Stream, BlockName) then
      break;

    StreamSeekAlign(Stream, 4); // align 4

    if BlockClass = nil then
      block := CreateBlockByName(BlockName, Parent)
    else
      block := BlockClass.Create(Parent);

    block.Size := blockHdr.Length;
    block.Offset := Offset;
    block.ValueOffset := Stream.Position;
    block.ValueSize := blockHdr.ValueLength;
    block.Name := BlockName;

    List.Add(block);

    // Next block.
    Offset := AlignUp(Offset + blockHdr.Length, 4);
  end;
end;

constructor TPEVersionInfo.Create;
begin
  inherited;
  self.Root := TRootBlock.Create(nil);
end;

destructor TPEVersionInfo.Destroy;
begin
  self.Root.Free;
  inherited;
end;

procedure TPEVersionInfo.LoadFromStream;
begin
  self.Root.Children.Clear;
  ReadLevelOfBlocks(Stream, 0, Stream.Size, self.Root.Children, self.Root);
  ProcessBlocks(Stream, self.Root.Children);
end;

procedure TPEVersionInfo.PrintTree(PrintFn: TPrintFunc; Indent: integer);
begin
  PrintTreeEx(self.Root, PrintFn, Indent);
end;

procedure TPEVersionInfo.PrintTreeEx(n: TRootBlock; PrintFn: TPrintFunc;
  Indent: integer);
var
  sIndent: string;
  c: TRootBlock;
begin
  sIndent := string.Create(' ', Indent);

  if n.ClassType = TRootBlock then
    PrintFn(sIndent + 'Root')
  else if n.ClassType = TBlockVersionInfo then
    PrintFn(sIndent + 'VersionInfo')
  else if n.ClassType = TBlockStringInfo then
    PrintFn(sIndent + 'StringInfo')
  else if n.ClassType = TBlockStringInfoNode then
  begin
    PrintFn(Format('%sStringInfoNode (lang: %4.4x; charset: %4.4x)', [
      sIndent, TBlockStringInfoNode(n).Lang, TBlockStringInfoNode(n).Charset]));
  end
  else if n.ClassType = TBlockStringInfoPair then
  begin
    PrintFn(Format('%s"%s" = "%s"', [sIndent, TBlockStringInfoPair(n).Key, TBlockStringInfoPair(n).Value]));
  end
  else if n.ClassType = TBlockVarInfo then
    PrintFn(sIndent + 'VarInfo')
  else if n.ClassType = TBlockVarTranslationInfo then
    PrintFn(Format('%sTranslation, landID=%x, charsetID=%x', [
      sIndent, TBlockVarTranslationInfo(n).langID, TBlockVarTranslationInfo(n).charsetID]))
  else
    PrintFn(Format('%s%s(%s)', [sIndent, n.Name, n.ClassName]));

  for c in n.Children do
    PrintTreeEx(c, PrintFn, Indent + 2);
end;

procedure TPEVersionInfo.ProcessBlocks(Stream: TStream; Blocks: TBlockList);
var
  n: TBlock;
begin
  for n in Blocks do
  begin
    if n.ClassType = TBlockVersionInfo then
    begin
      // value
      if n.ValueSize < SizeOf(VS_FIXEDFILEINFO) then
        raise Exception.Create('Version Info resource: size for VS_FIXEDFILEINFO is too low.');
      if not StreamSeek(Stream, n.ValueOffset) then
        raise Exception.Create('Failed to seek offset of VS_FIXEDFILEINFO.');
      if not StreamRead(Stream, TBlockVersionInfo(n).FixedInfo, SizeOf(VS_FIXEDFILEINFO)) then
        raise Exception.Create('Failed to read VS_FIXEDFILEINFO.');

      // sub-nodes
      ReadLevelOfBlocks(Stream, AlignUp(Stream.Position, 4), n.GetBlockEndOffset, n.Children, n);
      ProcessBlocks(Stream, n.Children);
    end
    else if n.ClassType = TBlockStringInfo then
    begin
      ReadLevelOfBlocks(Stream, AlignUp(n.ValueOffset, 4), n.GetBlockEndOffset, n.Children, n, TBlockStringInfoNode);
      ProcessBlocks(Stream, n.Children);
    end
    else if n.ClassType = TBlockStringInfoNode then
    begin
      // lang
      TBlockStringInfoNode(n).Lang := StrToInt('$' + copy(n.Name, 1, 4));
      // charset
      TBlockStringInfoNode(n).Charset := StrToInt('$' + copy(n.Name, 5, 4));
      // sub-nodes
      ReadLevelOfBlocks(Stream, AlignUp(n.ValueOffset, 4), n.GetBlockEndOffset, n.Children, n, TBlockStringInfoPair);
      ProcessBlocks(Stream, n.Children);
    end
    else if n.ClassType = TBlockStringInfoPair then
    begin
      if n.ValueSize <> 0 then
      begin
        Stream.Position := n.ValueOffset;
        StreamReadStringW(Stream, TBlockStringInfoPair(n).Value);
      end;
    end
    else if n.ClassType = TBlockVarInfo then
    begin
      ReadLevelOfBlocks(Stream, AlignUp(n.ValueOffset, 4), n.GetBlockEndOffset, n.Children, n);
      ProcessBlocks(Stream, n.Children);
    end
    else if n.ClassType = TBlockVarTranslationInfo then
    begin
      if n.ValueSize >= 4 then
      begin
        Stream.Position := n.ValueOffset;
        StreamRead(Stream, TBlockVarTranslationInfo(n).langID, 2);
        StreamRead(Stream, TBlockVarTranslationInfo(n).charsetID, 2);
      end;
    end
    else
      ProcessBlocks(Stream, n.Children);
  end;
end;

{ TRootBlock }

constructor TRootBlock.Create(Parent: TRootBlock);
begin
  inherited Create;
  self.Parent := Parent;
  self.Children := TBlockList.Create;
end;

destructor TRootBlock.Destroy;
begin
  self.Children.Free;
  inherited;
end;

{ TBlock }

function TBlock.GetBlockEndOffset: TFileOffset;
begin
  result := self.Offset + self.Size;
end;

end.
