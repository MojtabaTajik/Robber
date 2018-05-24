unit PE.Parser.TLS;

interface

uses
  System.SysUtils,

  PE.Common,
  PE.Types,
  PE.Types.Directories,
  PE.Types.TLS,
  PE.TLS;

type
  TPETLSParser = class(TPEParser)
  public
    function Parse: TParserResult; override;
  end;

implementation

uses
  PE.Image;

{ TPETLSParser }

function TPETLSParser.Parse: TParserResult;
var
  PE: TPEImage;
var
  Dir: TImageDataDirectory;
  TLSDir: TTLSDirectory;
  AddressofCallbacks: TVA;
  CurRVA, CallbackVA: uint64;
  bRead: boolean;
begin
  PE := TPEImage(FPE);

  if not PE.DataDirectories.Get(DDIR_TLS, @Dir) then
    exit(PR_OK);
  if Dir.IsEmpty then
    exit(PR_OK);

  if not PE.SeekRVA(Dir.VirtualAddress) then
  begin
    PE.Msg.Write(SCategoryTLS, 'Incorrect directory RVA.');
    exit(PR_ERROR);
  end;

  case PE.ImageBits of
    32:
      begin
        bRead := PE.ReadEx(TLSDir.tls32, SizeOf(TLSDir.tls32));
        AddressofCallbacks := TLSDir.tls32.AddressofCallbacks;
      end;
    64:
      begin
        bRead := PE.ReadEx(TLSDir.tls64, SizeOf(TLSDir.tls64));
        AddressofCallbacks := TLSDir.tls64.AddressofCallbacks;
      end;
  else
    exit(PR_ERROR);
  end;

  if not bRead then
  begin
    PE.Msg.Write(SCategoryTLS, 'Failed to read directory.');
    exit(PR_ERROR);
  end;

  // Assign dir.
  PE.TLS.Dir := TLSDir;

  // Try to read callback addresses if available.

  // It's ok if there's no callbacks.
  if AddressofCallbacks = 0 then
    exit(PR_OK);

  if not PE.SeekVA(AddressofCallbacks) then
  begin
    PE.Msg.Write(SCategoryTLS, 'Incorrect address of callbacks.');
    exit(PR_OK);
  end;

  while True do
  begin
    CurRVA := PE.PositionRVA;

    // Try to read callback address.
    if not PE.ReadWordEx(0, @CallbackVA) then
    begin
      PE.Msg.Write(SCategoryTLS, 'Failed to read callback address at RVA: 0x%x. Probably malformed data.', [CurRVA]);
      break;
    end;

    // Is it terminator?
    if CallbackVA = 0 then
      break;

    // Does the address exist?
    if not PE.VAExists(CallbackVA) then
    begin
      PE.Msg.Write(SCategoryTLS, 'Bad callback address (0x%x) at RVA: 0x%x', [CallbackVA, CurRVA]);
      break;
    end;

    // Add existing address.
    PE.TLS.CallbackRVAs.Add(PE.VAToRVA(CallbackVA))
  end;

  exit(PR_OK);
end;

end.
