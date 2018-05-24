unit PE.Imports.Func;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  PE.Common;

type
  TPEImportFunction = class
  public
    Ordinal: uint16;
    Name: String;
    procedure Clear; inline;
    constructor CreateEmpty;
    constructor Create(const Name: String; Ordinal: uint16 = 0);
  end;

  TPEImportFunctionDelayed = class(TPEImportFunction)
  public
  end;

  TPEImportFunctions = TObjectList<TPEImportFunction>;

implementation

{ TImportFunction }

procedure TPEImportFunction.Clear;
begin
  self.Ordinal := 0;
  self.Name := '';
end;

constructor TPEImportFunction.Create(const Name: String; Ordinal: uint16);
begin
  self.Name := Name;
  self.Ordinal := Ordinal;
end;

constructor TPEImportFunction.CreateEmpty;
begin
end;

end.
