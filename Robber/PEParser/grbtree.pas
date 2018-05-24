{
  Generic Red-Black Tree
}

unit grbtree;

interface

uses
  System.SysUtils,
  System.Generics.Defaults,
  System.Generics.Collections;

Type
  TNodeKind = (NODE_RED, NODE_BLACK);

  TRBTree<T> = class(TEnumerable<T>)

    { Public Types }

  public type

    TCompareLessFunc = reference to function(const A, B: T): Boolean;

    TRBNodePtr = ^TRBNode;
    PRBNodePtr = ^TRBNodePtr;

    TRBNode = record
      K: T;                            // key
      Left, Right, Parent: TRBNodePtr; // <, >, ^
      Kind: TNodeKind;                 // node kind
    end;
  private type

    { Enumerator }

    TRBTreeEnumerator = class(TEnumerator<T>)
    private
      FRBTree: TRBTree<T>;
      FCurrentPtr: TRBNodePtr;
      function GetCurrent: T;
    protected
      function DoGetCurrent: T; override;
      function DoMoveNext: Boolean; override;
    public
      constructor Create(ARBTree: TRBTree<T>);
      property Current: T read GetCurrent;
      function MoveNext: Boolean;
    end;

  private
  var
    // Cache (1 item).
    FUseCache: Boolean;
    FCacheRec: TRBNodePtr;
    procedure InvalidateCache; inline;
    function IsCacheValid: Boolean; inline;
    function FindInCache(const Key: T; out Node: TRBNodePtr): Boolean; // inline;
    procedure UpdateCache(const Key: T; Node: TRBNodePtr); // inline;
  private
    FRoot, FFirst, FLast: TRBNodePtr;
    FCompare: TCompareLessFunc;
    FCount: Integer;

    FOnNotify: TCollectionNotifyEvent<T>;

    procedure RotateLeft(var x: TRBNodePtr);
    procedure RotateRight(var x: TRBNodePtr);
    function Minimum(var x: TRBNodePtr): TRBNodePtr;
    function Maximum(var x: TRBNodePtr): TRBNodePtr;
    procedure QuickErase(x: TRBNodePtr);
    procedure SetUseCache(const Value: Boolean);
  protected
    function DoGetEnumerator: TEnumerator<T>; override;
    procedure Notify(const Item: T; Action: TCollectionNotification); virtual;
    procedure ClearQuick;
    procedure ClearFull;

    function DoCompareLess(const A, B: T): Boolean; virtual;
  public
    constructor Create(Less: TCompareLessFunc);
    destructor Destroy(); override;

    procedure Clear; virtual;

    function Exists(const Key: T): Boolean; inline; // deprecated;
    function ContainsKey(const Key: T): Boolean; inline;

    function Find(const Key: T): TRBNodePtr;

    // Find first item lesser than Key (or nil if none).
    function FindLesser(const Key: T): TRBNodePtr;

    // Find first item gereater or equal to Key.
    function FindGreaterOrEqual(const Key: T): TRBNodePtr;

    // If Cur item found, result is True.
    function FindEx(const Key: T; out Prev, Cur, Next: TRBNodePtr): Boolean; overload;
    function FindEx(const Key: T; Prev, Cur, Next: PRBNodePtr): Boolean; overload;

    // Add new item or return existing.
    function Add(const Key: T; SendNotification: Boolean = True): TRBNodePtr; virtual;

    // Delete old key and add new key.
    function Replace(const OldKey, NewKey: T): TRBNodePtr;

    // Delete
    procedure Delete(z: TRBNodePtr; SendNotification: Boolean = True); overload; virtual;

    // Return True if item was found and removed.
    function Remove(const Key: T; SendNotification: Boolean = True): Boolean;

    function Next(var x: TRBNodePtr): Boolean;
    function Prev(var x: TRBNodePtr): Boolean;

    function GetNext(x: TRBNodePtr): TRBNodePtr; inline;
    function GetPrev(x: TRBNodePtr): TRBNodePtr; inline;

    { Properites }
    property Count: Integer read FCount;
    property Root: TRBNodePtr read FRoot;
    property First: TRBNodePtr read FFirst;
    property Last: TRBNodePtr read FLast;

    property OnNotify: TCollectionNotifyEvent<T> read FOnNotify write FOnNotify;

    property UseCache: Boolean read FUseCache write SetUseCache;
  end;

implementation

constructor TRBTree<T>.Create(Less: TCompareLessFunc);
begin
  inherited Create;
  FCount := 0;
  FCompare := Less;
  FRoot := nil;
  FFirst := nil;
  FLast := nil;
  FUseCache := True;
end;

function TRBTree<T>.Remove(const Key: T; SendNotification: Boolean): Boolean;
var
  z: TRBNodePtr;
begin
  InvalidateCache;
  z := Find(Key);
  if not Assigned(z) then
    Exit(False);
  Delete(z, SendNotification);
  Exit(True);
end;

destructor TRBTree<T>.Destroy();
begin
  ClearFull;
  inherited;
end;

function TRBTree<T>.DoCompareLess(const A, B: T): Boolean;
begin
  if @FCompare = nil then
    raise Exception.Create('Need comparer function')
  else
    Result := FCompare(A, B);
end;

function TRBTree<T>.DoGetEnumerator: TEnumerator<T>;
begin
  Result := TRBTreeEnumerator.Create(self);
end;

function TRBTree<T>.Exists(const Key: T): Boolean;
begin
  Result := Find(Key) <> nil;
end;

procedure TRBTree<T>.QuickErase(x: TRBNodePtr);
begin
  if x^.Left <> nil then
    QuickErase(x^.Left);
  if x^.Right <> nil then
    QuickErase(x^.Right);

  Notify(x^.K, cnRemoved);
  FreeMem(x);
end;

procedure TRBTree<T>.Clear;
begin
  InvalidateCache;
  ClearFull;
end;

function TRBTree<T>.IsCacheValid: Boolean;
begin
  Result := FCacheRec <> nil;
end;

procedure TRBTree<T>.InvalidateCache;
begin
  FCacheRec := nil;
end;

procedure TRBTree<T>.ClearFull;
begin
  InvalidateCache;
  while FCount <> 0 do
    Delete(First);
end;

procedure TRBTree<T>.ClearQuick;
begin
  InvalidateCache;
  if FRoot <> nil then
  begin
    QuickErase(FRoot);
    FRoot := nil;
  end;
  FFirst := nil;
  FLast := nil;
  FCount := 0;
end;

function TRBTree<T>.ContainsKey(const Key: T): Boolean;
begin
  Result := Exists(Key);
end;

function TRBTree<T>.Find(const Key: T): TRBNodePtr;
begin
  // Try cache.
  if FindInCache(Key, Result) then
    Exit;

  // Normal search.
  Result := FRoot;
  while Result <> nil do
  begin
    if DoCompareLess(Result^.K, Key) then
      Result := Result^.Right
    else if DoCompareLess(Key, Result^.K) then
      Result := Result^.Left
    else
    begin
      // If item found, update cache.
      UpdateCache(Key, Result);
      break;
    end;
  end;
end;

function TRBTree<T>.FindLesser(const Key: T): TRBNodePtr;
var
  Cur: TRBNodePtr;
begin
  Result := nil;
  Cur := FRoot;
  while Cur <> nil do
    if FCompare(Cur^.K, Key) then
    begin
      Result := Cur;
      Cur := Cur^.Right;
    end
    else
      Cur := Cur^.Left;
end;

function TRBTree<T>.FindGreaterOrEqual(const Key: T): TRBNodePtr;
var
  Cur: TRBNodePtr;
begin
  Result := nil;
  Cur := FRoot;
  while Cur <> nil do
    if not FCompare(Cur^.K, Key) then
    begin
      Result := Cur;
      Cur := Cur^.Left;
    end
    else
      Cur := Cur^.Right;
end;

function TRBTree<T>.FindInCache(const Key: T; out Node: TRBNodePtr): Boolean;
begin
  if FUseCache and IsCacheValid then
    if (not DoCompareLess(Key, FCacheRec^.K)) and
      (not DoCompareLess(FCacheRec^.K, Key)) then
    begin
      Node := FCacheRec;
      Exit(True);
    end;
  Exit(False);
end;

function TRBTree<T>.FindEx(const Key: T; Prev, Cur, Next: PRBNodePtr): Boolean;
var
  tPrev, tCur, tNext: TRBNodePtr;
begin
  tCur := FRoot;
  tPrev := nil;
  tNext := nil;
  Result := False;

  while tCur <> nil do
  begin
    if DoCompareLess(tCur^.K, Key) then
    begin
      tPrev := tCur;
      tCur := tCur^.Right;
    end
    else if DoCompareLess(Key, tCur^.K) then
    begin
      tNext := tCur;
      tCur := tCur^.Left;
    end
    else // Found.
    begin
      // Skip if not needed.
      if Prev <> nil then
        tPrev := GetPrev(tCur);
      if Next <> nil then
        tNext := GetNext(tCur);
      Result := True;
      break;
    end;
  end;

  // Store results.
  if Prev <> nil then
    Prev^ := tPrev;
  if Cur <> nil then
    Cur^ := tCur;
  if Next <> nil then
    Next^ := tNext;
end;

function TRBTree<T>.FindEx(const Key: T; out Prev, Cur, Next: TRBNodePtr): Boolean;
begin
  Result := False;
  Cur := FRoot;
  Prev := nil;
  Next := nil;
  while Cur <> nil do
  begin
    if DoCompareLess(Cur^.K, Key) then
    begin
      Prev := Cur;
      Cur := Cur^.Right;
    end
    else if DoCompareLess(Key, Cur^.K) then
    begin
      Next := Cur;
      Cur := Cur^.Left;
    end
    else
    begin
      Prev := GetPrev(Cur);
      Next := GetNext(Cur);
      Result := True;
      break; // Found.
    end;
  end;
end;

function TRBTree<T>.GetNext(x: TRBNodePtr): TRBNodePtr;
begin
  Result := x;
  if x <> nil then
    Next(Result);
end;

function TRBTree<T>.GetPrev(x: TRBNodePtr): TRBNodePtr;
begin
  Result := x;
  if x <> nil then
    Prev(Result);
end;

procedure TRBTree<T>.RotateLeft(var x: TRBNodePtr);
var
  y: TRBNodePtr;
begin
  y := x^.Right;
  x^.Right := y^.Left;
  if (y^.Left <> nil) then
    y^.Left^.Parent := x;
  y^.Parent := x^.Parent;
  if (x = FRoot) then
    FRoot := y
  else if (x = x^.Parent^.Left) then
    x^.Parent^.Left := y
  else
    x^.Parent^.Right := y;
  y^.Left := x;
  x^.Parent := y;
end;

procedure TRBTree<T>.RotateRight(var x: TRBNodePtr);
var
  y: TRBNodePtr;
begin
  y := x^.Left;
  x^.Left := y^.Right;
  if (y^.Right <> nil) then
    y^.Right^.Parent := x;
  y^.Parent := x^.Parent;
  if (x = FRoot) then
    FRoot := y
  else if (x = x^.Parent^.Right) then
    x^.Parent^.Right := y
  else
    x^.Parent^.Left := y;
  y^.Right := x;
  x^.Parent := y;
end;

procedure TRBTree<T>.SetUseCache(const Value: Boolean);
begin
  FUseCache := Value;
  InvalidateCache;
end;

procedure TRBTree<T>.UpdateCache(const Key: T; Node: TRBNodePtr);
begin
  if FUseCache then
  begin
    FCacheRec := Node;
  end;
end;

function TRBTree<T>.Minimum(var x: TRBNodePtr): TRBNodePtr;
begin
  Result := x;
  while (Result^.Left <> nil) do
    Result := Result^.Left;
end;

function TRBTree<T>.Maximum(var x: TRBNodePtr): TRBNodePtr;
begin
  Result := x;
  while (Result^.Right <> nil) do
    Result := Result^.Right;
end;

function TRBTree<T>.Add(const Key: T; SendNotification: Boolean = True): TRBNodePtr;
var
  x, y, z, zpp: TRBNodePtr;
begin
  InvalidateCache;

  z := AllocMem(sizeof(TRBNode));

  z^.K := Key;
  z^.Kind := NODE_RED;

  Result := z;

  if (FFirst = nil) or (DoCompareLess(Key, FFirst^.K)) then
    FFirst := z;

  if (FLast = nil) or (DoCompareLess(FLast^.K, Key)) then
    FLast := z;

  y := nil;
  x := FRoot;
  while (x <> nil) do
  begin
    y := x;
    if DoCompareLess(Key, x^.K) then
      x := x^.Left
    else if DoCompareLess(x^.K, Key) then
      x := x^.Right
    else
    begin
      // Already exists.
      // Destroy newly created item.
      // Notify(z^.K, cnRemoved);
      FreeMem(z);
      raise Exception.Create('Duplicate key.');
      Exit;
    end;
  end;

  z^.Parent := y;
  if (y = nil) then
    FRoot := z
  else if (DoCompareLess(Key, y^.K)) then
    y^.Left := z
  else
    y^.Right := z;

  // Rebalance
  while ((z <> FRoot) and (z^.Parent^.Kind = NODE_RED)) do
  begin
    zpp := z^.Parent^.Parent;
    if (z^.Parent = zpp^.Left) then
    begin
      y := zpp^.Right;
      if ((y <> nil) and (y^.Kind = NODE_RED)) then
      begin
        z^.Parent^.Kind := NODE_BLACK;
        y^.Kind := NODE_BLACK;
        zpp^.Kind := NODE_RED;
        z := zpp;
      end
      else
      begin
        if (z = z^.Parent^.Right) then
        begin
          z := z^.Parent;
          RotateLeft(z);
        end;
        z^.Parent^.Kind := NODE_BLACK;
        zpp^.Kind := NODE_RED;
        RotateRight(zpp);
      end;
    end
    else
    begin
      y := zpp^.Left;
      if ((y <> nil) and (y^.Kind = NODE_RED)) then
      begin
        z^.Parent^.Kind := NODE_BLACK;
        y^.Kind := NODE_BLACK;
        zpp^.Kind := NODE_RED;
        z := zpp;
      end
      else
      begin
        if (z = z^.Parent^.Left) then
        begin
          z := z^.Parent;
          RotateRight(z);
        end;
        z^.Parent^.Kind := NODE_BLACK;
        zpp^.Kind := NODE_RED;
        RotateLeft(zpp);
      end;
    end;
  end;
  FRoot^.Kind := NODE_BLACK;

  inc(FCount);

  if SendNotification then
    Notify(Result^.K, cnAdded);
end;

procedure TRBTree<T>.Delete(z: TRBNodePtr; SendNotification: Boolean);
var
  w, x, y, x_parent: TRBNodePtr;
  tmpcol: TNodeKind;
  OldKey: T;
begin
  InvalidateCache;

  if SendNotification then
    OldKey := z^.K; // store it for notification in the end

  z^.K := Default (T); // finalize key
{$REGION 'delete'}
  y := z;
  x := nil;
  x_parent := nil;

  if (y^.Left = nil) then
    x := y^.Right
  else
  begin
    if (y^.Right = nil) then
      x := y^.Left
    else
    begin
      y := y^.Right;
      while (y^.Left <> nil) do
        y := y^.Left;
      x := y^.Right;
    end;
  end;

  if (y <> z) then
  begin
    z^.Left^.Parent := y;
    y^.Left := z^.Left;
    if (y <> z^.Right) then
    begin
      x_parent := y^.Parent;
      if (x <> nil) then
        x^.Parent := y^.Parent;
      y^.Parent^.Left := x;
      y^.Right := z^.Right;
      z^.Right^.Parent := y;
    end
    else
      x_parent := y;
    if (FRoot = z) then
      FRoot := y
    else if (z^.Parent^.Left = z) then
      z^.Parent^.Left := y
    else
      z^.Parent^.Right := y;
    y^.Parent := z^.Parent;
    tmpcol := y^.Kind;
    y^.Kind := z^.Kind;
    z^.Kind := tmpcol;
    y := z;
  end
  else
  begin { y = z }
    x_parent := y^.Parent;
    if (x <> nil) then
      x^.Parent := y^.Parent;
    if (FRoot = z) then
      FRoot := x
    else
    begin
      if (z^.Parent^.Left = z) then
        z^.Parent^.Left := x
      else
        z^.Parent^.Right := x;
    end;
    if (FFirst = z) then
    begin
      if (z^.Right = nil) then
        FFirst := z^.Parent
      else
        FFirst := Minimum(x);
    end;
    if (FLast = z) then
    begin
      if (z^.Left = nil) then
        FLast := z^.Parent
      else { x = z^.left }
        FLast := Maximum(x);
    end;
  end;
{$ENDREGION 'delete'}
{$REGION 'rebalance'}
  // Rebalance tree
  if (y^.Kind = NODE_BLACK) then
  begin
    while ((x <> FRoot) and ((x = nil) or (x^.Kind = NODE_BLACK))) do
    begin
      if (x = x_parent^.Left) then
      begin
        w := x_parent^.Right;
        if (w^.Kind = NODE_RED) then
        begin
          w^.Kind := NODE_BLACK;
          x_parent^.Kind := NODE_RED;
          RotateLeft(x_parent);
          w := x_parent^.Right;
        end;
        if (((w^.Left = nil) or
          (w^.Left^.Kind = NODE_BLACK)) and
          ((w^.Right = nil) or
          (w^.Right^.Kind = NODE_BLACK))) then
        begin
          w^.Kind := NODE_RED;
          x := x_parent;
          x_parent := x_parent^.Parent;
        end
        else
        begin
          if ((w^.Right = nil) or (w^.Right^.Kind = NODE_BLACK)) then
          begin
            w^.Left^.Kind := NODE_BLACK;
            w^.Kind := NODE_RED;
            RotateRight(w);
            w := x_parent^.Right;
          end;
          w^.Kind := x_parent^.Kind;
          x_parent^.Kind := NODE_BLACK;
          if (w^.Right <> nil) then
            w^.Right^.Kind := NODE_BLACK;
          RotateLeft(x_parent);
          x := FRoot; { break; }
        end
      end
      else
      begin
        w := x_parent^.Left;
        if (w^.Kind = NODE_RED) then
        begin
          w^.Kind := NODE_BLACK;
          x_parent^.Kind := NODE_RED;
          RotateRight(x_parent);
          w := x_parent^.Left;
        end;
        if (((w^.Right = nil) or
          (w^.Right^.Kind = NODE_BLACK)) and
          ((w^.Left = nil) or
          (w^.Left^.Kind = NODE_BLACK))) then
        begin
          w^.Kind := NODE_RED;
          x := x_parent;
          x_parent := x_parent^.Parent;
        end
        else
        begin
          if ((w^.Left = nil) or (w^.Left^.Kind = NODE_BLACK)) then
          begin
            w^.Right^.Kind := NODE_BLACK;
            w^.Kind := NODE_RED;
            RotateLeft(w);
            w := x_parent^.Left;
          end;
          w^.Kind := x_parent^.Kind;
          x_parent^.Kind := NODE_BLACK;
          if (w^.Left <> nil) then
            w^.Left^.Kind := NODE_BLACK;
          RotateRight(x_parent);
          x := FRoot;
        end;
      end;
    end;
    if (x <> nil) then
      x^.Kind := NODE_BLACK;
  end;
{$ENDREGION 'rebalance'}
  dec(FCount);

  if SendNotification then
    Notify(OldKey, cnRemoved);

  FreeMem(y);
end;

function TRBTree<T>.Next(var x: TRBNodePtr): Boolean;
var
  y: TRBNodePtr;
begin
  if x = Last then
  begin
    x := nil;
    Exit(False);
  end;

  if (x^.Right <> nil) then
  begin
    x := x^.Right;
    while (x^.Left <> nil) do
      x := x^.Left;
  end
  else
  begin
    y := x^.Parent;
    while (x = y^.Right) do
    begin
      x := y;
      y := y^.Parent;
    end;
    if (x^.Right <> y) then
      x := y;
  end;
  Exit(True);
end;

procedure TRBTree<T>.Notify(const Item: T; Action: TCollectionNotification);
begin
  if Assigned(FOnNotify) then
    FOnNotify(self, Item, Action);
end;

function TRBTree<T>.Prev(var x: TRBNodePtr): Boolean;
var
  y: TRBNodePtr;
begin
  if x = First then
  begin
    x := nil;
    Exit(False);
  end;
  if (x^.Left <> nil) then
  begin
    y := x^.Left;
    while (y^.Right <> nil) do
      y := y^.Right;
    x := y;
  end
  else
  begin
    y := x^.Parent;
    while (x = y^.Left) do
    begin
      x := y;
      y := y^.Parent;
    end;
    x := y;
  end;
  Exit(True);
end;

function TRBTree<T>.Replace(const OldKey, NewKey: T): TRBNodePtr;
begin
  InvalidateCache;
  Remove(OldKey);
  Result := Add(NewKey);
end;

{ TRBTree<T>.TValueEnumerator }

constructor TRBTree<T>.TRBTreeEnumerator.Create(ARBTree: TRBTree<T>);
begin
  inherited Create;
  FCurrentPtr := nil;
  FRBTree := ARBTree;
end;

function TRBTree<T>.TRBTreeEnumerator.DoGetCurrent: T;
begin
  Result := GetCurrent;
end;

function TRBTree<T>.TRBTreeEnumerator.DoMoveNext: Boolean;
begin
  Result := MoveNext;
end;

function TRBTree<T>.TRBTreeEnumerator.GetCurrent: T;
begin
  Result := FCurrentPtr^.K;
end;

function TRBTree<T>.TRBTreeEnumerator.MoveNext: Boolean;
begin
  if not Assigned(FCurrentPtr) then
  begin
    FCurrentPtr := FRBTree.First;
    Exit(Assigned(FCurrentPtr));
  end
  else if (FCurrentPtr <> FRBTree.Last) then
  begin
    FRBTree.Next(FCurrentPtr);
    Exit(True);
  end;
  Exit(False);
end;

end.
