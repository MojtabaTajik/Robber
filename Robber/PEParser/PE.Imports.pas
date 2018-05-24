unit PE.Imports;

interface

uses
  System.Generics.Collections,
  System.SysUtils,

  PE.Common,
  PE.Imports.Func,
  PE.Imports.Lib;

type
  TPEImportLibraryObjectList = TObjectList<TPEImportLibrary>;

  TPEImport = class
  private
    FLibs: TPEImportLibraryObjectList;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    function Add(Lib: TPEImportLibrary): TPEImportLibrary; inline;
    function NewLib(const Name: string): TPEImportLibrary;

    property Libs: TPEImportLibraryObjectList read FLibs;
  end;

implementation

{ TPEImports }

constructor TPEImport.Create;
begin
  inherited Create;
  FLibs := TPEImportLibraryObjectList.Create;
end;

destructor TPEImport.Destroy;
begin
  FLibs.Free;
  inherited;
end;

function TPEImport.NewLib(const Name: string): TPEImportLibrary;
begin
  result := Add(TPEImportLibrary.Create(Name));
end;

procedure TPEImport.Clear;
begin
  FLibs.Clear;
end;

function TPEImport.Add(Lib: TPEImportLibrary): TPEImportLibrary;
begin
  FLibs.Add(Lib);
  result := Lib;
end;

end.
