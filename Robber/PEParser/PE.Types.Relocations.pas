unit PE.Types.Relocations;

interface

uses
{$IFDEF DEBUG}
  System.SysUtils,
{$ENDIF}
  System.Generics.Collections,
  PE.Common,
  gRBTree;

{$I 'PE.Types.Relocations.inc'} // Include constants.

type

  { TBaseRelocationBlock }

  TBaseRelocationBlock = packed record
    // The image base plus the page RVA is added to each offset
    // to create the VA where the base relocation must be applied.
    PageRVA: UInt32;

    // The total number of bytes in the base relocation block, including the
    // Page RVA and Block Size fields and the Type/Offset fields that follow.
    BlockSize: UInt32;

    // Get count of relocation elements (entries).
    function Count: integer; {$IFNDEF DEBUG} inline; {$ENDIF}
    // Check if this block's size:0 or rva:0.
    function IsEmpty: Boolean; inline;
  end;

  { TBaseRelocationEntry }

  TBaseRelocationEntry = packed record
    raw: uint16;
    function GetOffset: uint16;
    function GetType: byte;
  end;

  { TReloc }

  TReloc = packed record
    RVA: uint64;    // relocatable rva
    &Type: integer; // see 5.6.2. Base Relocation Types (IMAGE_REL_BASED_...)
  end;

  PReloc = ^TReloc;

  { TRelocs }

  TRelocTree = TRBTree<TReloc>;

  TRelocs = class
  private
    FItems: TRelocTree;
    // Find relocation. Result is pointer to relocation otherwise it's nil.
    function FindReloc(RVA: TRVA): PReloc; overload;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    function Count: integer;

    function Find(RVA: TRVA; out Reloc: TReloc): Boolean;

    // Add non-existing item, or update existing item.
    procedure Put(const Value: TReloc); overload;
    procedure Put(RVA: TRVA; &Type: integer); overload;

    // Result is True if reloc was found and removed.
    function Remove(RVA: TRVA): Boolean;

    property Items: TRelocTree read FItems;
  end;

implementation

uses
  PE.Utils;

{ TBaseRelocationBlock }

function TBaseRelocationBlock.Count: integer;
begin
{$IFDEF DEBUG}
  if BlockSize < SizeOf(TBaseRelocationBlock) then
    raise Exception.Create('Relocation block is too small.');
{$ENDIF}
  result := (BlockSize - SizeOf(TBaseRelocationBlock)) div SizeOf(TBaseRelocationEntry);
end;

function TBaseRelocationBlock.IsEmpty: Boolean;
begin
  result := (PageRVA = 0) or (BlockSize = 0);
end;

{ TBaseRelocationEntry }

function TBaseRelocationEntry.GetOffset: uint16;
begin
  result := raw and $0FFF;
end;

function TBaseRelocationEntry.GetType: byte;
begin
  result := raw shr 12;
end;

{ TRelocs }

procedure TRelocs.Put(const Value: TReloc);
var
  p: PReloc;
begin
  p := FindReloc(Value.RVA);
  // If item exists, modify it.
  if p <> nil then
    // This will modify type, rva will stay same.
    // If we'll modify rva, tree will be corrupted.
    p^ := Value
  else
    // If not yet exists, add it.
    FItems.Add(Value);
end;

function TRelocs.Remove(RVA: TRVA): Boolean;
var
  r: TReloc;
begin
  r.RVA := RVA;
  r.&Type := 0; // don't care
  result := FItems.Remove(r);
end;

procedure TRelocs.Clear;
begin
  FItems.Clear;
end;

function TRelocs.Count: integer;
begin
  result := FItems.Count;
end;

constructor TRelocs.Create;
begin
  FItems := TRelocTree.Create(
    function(const A, B: TReloc): Boolean
    begin
      result := A.RVA < B.RVA;
    end);
end;

destructor TRelocs.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TRelocs.Find(RVA: TRVA; out Reloc: TReloc): Boolean;
var
  r: TReloc;
  p: TRelocTree.TRBNodePtr;
begin
  r.RVA := RVA;
  r.&Type := 0; // don't care
  p := FItems.Find(r);
  if p = nil then
    Exit(False);
  Reloc := p^.K;
  Exit(True);
end;

function TRelocs.FindReloc(RVA: TRVA): PReloc;
var
  r: TReloc;
  p: TRelocTree.TRBNodePtr;
begin
  r.RVA := RVA;
  r.&Type := 0; // don't care
  p := FItems.Find(r);
  if p = nil then
    Exit(nil);
  Exit(@p^.K);
end;

procedure TRelocs.Put(RVA: TRVA; &Type: integer);
var
  r: TReloc;
begin
  r.RVA := RVA;
  r.&Type := &Type;
  Put(r);
end;

end.
