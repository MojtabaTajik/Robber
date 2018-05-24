unit PE.Types;

interface

uses
  System.Generics.Collections,
  PE.Common;

type
  TRVAs = TList<TRVA>;

  TPEParser = class
    FPE: TObject;
    constructor Create(PEImage: TObject);
    function Parse: TParserResult; virtual; abstract;
  end;

  TPEParserClass = class of TPEParser;

implementation

{ TPEParser }

constructor TPEParser.Create(PEImage: TObject);
begin
  FPE := PEImage;
end;

end.
