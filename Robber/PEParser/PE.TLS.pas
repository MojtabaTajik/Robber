unit PE.TLS;

interface

uses
  PE.Types,
  PE.Types.TLS;

type
  TTLS = class
  public
    Dir: TTLSDirectory;
    CallbackRVAs: TRVAs;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
  end;

implementation

procedure TTLS.Clear;
begin
  FillChar(Dir, SizeOf(Dir), 0);
  CallbackRVAs.Clear;
end;

constructor TTLS.Create;
begin
  CallbackRVAs := TRVAs.Create;
end;

destructor TTLS.Destroy;
begin
  CallbackRVAs.Free;
  inherited Destroy;
end;

end.
