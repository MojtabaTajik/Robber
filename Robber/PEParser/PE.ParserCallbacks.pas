unit PE.ParserCallbacks;

interface

uses
  PE.Common,
  PE.Types.Relocations;

type
  IPEParserCallbacks = interface
    procedure ParsedRelocationBlockHeader(RVA: TRVA; const Block: TBaseRelocationBlock);
  end;

implementation

end.
