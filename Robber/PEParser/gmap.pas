{
  Generic Key-Value Map class. Items are ordered by Key.
}

unit gmap;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  grbtree;

type
  TMap<TKey, TValue> = class(TEnumerable < TPair < TKey, TValue >> )
  public type
    TCompareLess = reference to function(const A, B: TKey): boolean;
  private const
    SKeyDoesNotExist = 'Key does not exist.';
  private type
    TItem = record
      Pair: TPair<TKey, TValue>;
      Owner: TMap<TKey, TValue>;
      constructor Create(const K: TKey; const V: TValue;
        const Owner: TMap<TKey, TValue>);
    end;

    TItemTree = TRBTree<TItem>;

    TPairEnumerator = class(TEnumerator < TPair < TKey, TValue >> )
    private
      FMap: TMap<TKey, TValue>;
      FNode: TItemTree.TRBNodePtr;
    protected
      function DoGetCurrent: TPair<TKey, TValue>; override;
      function DoMoveNext: boolean; override;
    public
      constructor Create(const Map: TMap<TKey, TValue>);
    end;

    TKeyEnumerator = class(TEnumerator<TKey>)
    private
      FPairEnum: TPairEnumerator;
    protected
      function DoGetCurrent: TKey; override;
      function DoMoveNext: boolean; override;
    public
      constructor Create(const Map: TMap<TKey, TValue>);
      destructor Destroy; override;
    end;

    TValueEnumerator = class(TEnumerator<TValue>)
    private
      FPairEnum: TPairEnumerator;
    protected
      function DoGetCurrent: TValue; override;
      function DoMoveNext: boolean; override;
    public
      constructor Create(const Map: TMap<TKey, TValue>);
      destructor Destroy; override;
    end;

    TKeyCollection = class(TEnumerable<TKey>)
    private
      FMap: TMap<TKey, TValue>;
    protected
      function DoGetEnumerator: TEnumerator<TKey>; override;
    public
      constructor Create(Map: TMap<TKey, TValue>);
    end;

    TValueCollection = class(TEnumerable<TValue>)
    private
      FMap: TMap<TKey, TValue>;
    protected
      function DoGetEnumerator: TEnumerator<TValue>; override;
    public
      constructor Create(Map: TMap<TKey, TValue>);
    end;

  private
    FKeyComparer: TCompareLess;
    FItems: TItemTree;
    FOnKeyNotify: TCollectionNotifyEvent<TKey>;
    FOnValueNotify: TCollectionNotifyEvent<TValue>;
    FKeyCollection: TKeyCollection;
    FValueCollection: TValueCollection;
    class function CompareItem(const A, B: TItem): boolean; static; inline;

    // Add new Key-Value pair or update existing Key with Value.
    procedure &Set(const Key: TKey; const Value: TValue);

    // Get Value by key.
    function Get(const Key: TKey): TValue;

    // Find node of item in RBTRree.
    function FindNodePtr(const Key: TKey): TItemTree.TRBNodePtr; inline;

    function GetCount: integer; inline;

    procedure ItemTreeNotify(Sender: TObject; const Item: TItem;
      Action: TCollectionNotification);

    function GetKeys: TKeyCollection;
    function GetValues: TValueCollection;
  protected
    function DoGetEnumerator: TEnumerator<TPair<TKey, TValue>>; override;
  public
    constructor Create(const Comparer: TCompareLess);
    destructor Destroy; override;

    // Add new item.
    procedure Add(const Key: TKey; const Value: TValue); inline;
    procedure Clear; inline;
    function ContainsKey(const Key: TKey): boolean; inline;
    function TryGetValue(const Key: TKey; out Value: TValue): boolean;
    function TryGetKeyAndValue(const Key: TKey; out OutKey: TKey; out OutValue: TValue): boolean;
    procedure Remove(const Key: TKey);

    function FirstKey: TKey; inline;
    function FirstValue: TValue; inline;

    function LastKey: TKey; inline;
    function LastValue: TValue; inline;

    property Items[const Key: TKey]: TValue read Get write &Set; default;
    property Keys: TKeyCollection read GetKeys;
    property Values: TValueCollection read GetValues;
    property Count: integer read GetCount;
    property OnKeyNotify: TCollectionNotifyEvent<TKey> read FOnKeyNotify write FOnKeyNotify;
    property OnValueNotify: TCollectionNotifyEvent<TValue> read FOnValueNotify write FOnValueNotify;
  end;

implementation

{ TMap<TKey, TValue> }

procedure TMap<TKey, TValue>.Add(const Key: TKey; const Value: TValue);
begin
  FItems.Add(TItem.Create(Key, Value, self));
end;

procedure TMap<TKey, TValue>.Clear;
begin
  FItems.Clear;
end;

class function TMap<TKey, TValue>.CompareItem(const A, B: TItem): boolean;
begin
  Result := A.Owner.FKeyComparer(A.Pair.Key, B.Pair.Key);
end;

constructor TMap<TKey, TValue>.Create(const Comparer: TCompareLess);
begin
  inherited Create;
  FKeyComparer := Comparer;
  FItems := TItemTree.Create(CompareItem);
  FItems.OnNotify := ItemTreeNotify;
end;

destructor TMap<TKey, TValue>.Destroy;
begin
  FKeyCollection.Free;
  FValueCollection.Free;
  FItems.Free;
  inherited;
end;

function TMap<TKey, TValue>.DoGetEnumerator: TEnumerator<TPair<TKey, TValue>>;
begin
  Result := TPairEnumerator.Create(self);
end;

function TMap<TKey, TValue>.FindNodePtr(const Key: TKey): TItemTree.TRBNodePtr;
begin
  Result := FItems.Find(TItem.Create(Key, Default (TValue), self));
end;

function TMap<TKey, TValue>.FirstKey: TKey;
begin
  Result := FItems.First.K.Pair.Key;
end;

function TMap<TKey, TValue>.FirstValue: TValue;
begin
  Result := FItems.First.K.Pair.Value;
end;

function TMap<TKey, TValue>.LastKey: TKey;
begin
  Result := FItems.Last.K.Pair.Key;
end;

function TMap<TKey, TValue>.LastValue: TValue;
begin
  Result := FItems.Last.K.Pair.Value;
end;

function TMap<TKey, TValue>.Get(const Key: TKey): TValue;
var
  Ptr: TItemTree.TRBNodePtr;
begin
  Ptr := FindNodePtr(Key);
  if Assigned(Ptr) then
    Result := Ptr^.K.Pair.Value
  else
    raise Exception.Create(SKeyDoesNotExist);
end;

function TMap<TKey, TValue>.GetCount: integer;
begin
  Result := FItems.Count;
end;

function TMap<TKey, TValue>.GetKeys: TKeyCollection;
begin
  if FKeyCollection = nil then
    FKeyCollection := TKeyCollection.Create(self);
  Result := FKeyCollection;
end;

function TMap<TKey, TValue>.GetValues: TValueCollection;
begin
  if FValueCollection = nil then
    FValueCollection := TValueCollection.Create(self);
  Result := FValueCollection;
end;

procedure TMap<TKey, TValue>.ItemTreeNotify(Sender: TObject; const Item: TItem;
  Action: TCollectionNotification);
begin
  if Assigned(FOnKeyNotify) then
    FOnKeyNotify(self, Item.Pair.Key, Action);
  if Assigned(FOnValueNotify) then
    FOnValueNotify(self, Item.Pair.Value, Action);
end;

procedure TMap<TKey, TValue>.Remove(const Key: TKey);
var
  Ptr: TItemTree.TRBNodePtr;
begin
  Ptr := FindNodePtr(Key);
  if Assigned(Ptr) then
    FItems.Delete(Ptr);
end;

procedure TMap<TKey, TValue>.&Set(const Key: TKey; const Value: TValue);
var
  Ptr: TItemTree.TRBNodePtr;
begin
  Ptr := FindNodePtr(Key);
  if Assigned(Ptr) then
    Ptr^.K.Pair.Value := Value
  else
    Add(Key, Value);
end;

function TMap<TKey, TValue>.ContainsKey(const Key: TKey): boolean;
begin
  Result := FindNodePtr(Key) <> nil;
end;

function TMap<TKey, TValue>.TryGetValue(const Key: TKey; out Value: TValue): boolean;
var
  Ptr: TItemTree.TRBNodePtr;
begin
  Ptr := FindNodePtr(Key);
  if Assigned(Ptr) then
  begin
    Value := Ptr^.K.Pair.Value;
    exit(true);
  end;
  Value := Default (TValue);
  exit(false);
end;

function TMap<TKey, TValue>.TryGetKeyAndValue(const Key: TKey; out OutKey: TKey; out OutValue: TValue): boolean;
var
  Ptr: TItemTree.TRBNodePtr;
begin
  Ptr := FindNodePtr(Key);
  if Assigned(Ptr) then
  begin
    OutKey := Ptr^.K.Pair.Key;
    OutValue := Ptr^.K.Pair.Value;
    exit(true);
  end;
  OutKey := Default (TKey);
  OutValue := Default (TValue);
  exit(false);
end;

{ TMap<TKey, TValue>.TItem }

constructor TMap<TKey, TValue>.TItem.Create(const K: TKey; const V: TValue;
  const Owner: TMap<TKey, TValue>);
begin
  self.Pair.Key := K;
  self.Pair.Value := V;
  self.Owner := Owner;
end;

{ TMap<TKey, TValue>.TPairEnumerator }

constructor TMap<TKey, TValue>.TPairEnumerator.Create(
  const Map: TMap<TKey, TValue>);
begin
  FMap := Map;
  FNode := nil;
end;

function TMap<TKey, TValue>.TPairEnumerator.DoGetCurrent: TPair<TKey, TValue>;
begin
  Result := FNode^.K.Pair;
end;

function TMap<TKey, TValue>.TPairEnumerator.DoMoveNext: boolean;
begin
  if FNode = nil then
  begin
    FNode := FMap.FItems.First;
    exit(FNode <> nil);
  end;
  Result := FMap.FItems.Next(FNode);
end;

{ TMap<TKey, TValue>.TKeyCollection }

constructor TMap<TKey, TValue>.TKeyCollection.Create(Map: TMap<TKey, TValue>);
begin
  FMap := Map;
end;

function TMap<TKey, TValue>.TKeyCollection.DoGetEnumerator: TEnumerator<TKey>;
begin
  Result := TKeyEnumerator.Create(FMap);
end;

{ TMap<TKey, TValue>.TValueCollection }

constructor TMap<TKey, TValue>.TValueCollection.Create(Map: TMap<TKey, TValue>);
begin
  FMap := Map;
end;

function TMap<TKey, TValue>.TValueCollection.DoGetEnumerator: TEnumerator<TValue>;
begin
  Result := TValueEnumerator.Create(FMap);
end;

{ TMap<TKey, TValue>.TKeyEnumerator }

constructor TMap<TKey, TValue>.TKeyEnumerator.Create(
  const Map: TMap<TKey, TValue>);
begin
  FPairEnum := TPairEnumerator.Create(Map);
end;

destructor TMap<TKey, TValue>.TKeyEnumerator.Destroy;
begin
  FPairEnum.Free;
  inherited;
end;

function TMap<TKey, TValue>.TKeyEnumerator.DoGetCurrent: TKey;
begin
  Result := FPairEnum.DoGetCurrent.Key;
end;

function TMap<TKey, TValue>.TKeyEnumerator.DoMoveNext: boolean;
begin
  Result := FPairEnum.DoMoveNext;
end;

{ TMap<TKey, TValue>.TValueEnumerator }

constructor TMap<TKey, TValue>.TValueEnumerator.Create(const Map: TMap<TKey, TValue>);
begin
  FPairEnum := TPairEnumerator.Create(Map);
end;

destructor TMap<TKey, TValue>.TValueEnumerator.Destroy;
begin
  FPairEnum.Free;
  inherited;
end;

function TMap<TKey, TValue>.TValueEnumerator.DoGetCurrent: TValue;
begin
  Result := FPairEnum.DoGetCurrent.Value;
end;

function TMap<TKey, TValue>.TValueEnumerator.DoMoveNext: boolean;
begin
  Result := FPairEnum.DoMoveNext;
end;

end.
