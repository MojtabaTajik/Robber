unit PE.Build.Common;

interface

uses
  System.Classes,
  PE.Common,
  PE.Image,
  NullStream;

type
  // Parent class for any directory builders.
  // Override Build procedure and fill Stream with new dir data.
  TDirectoryBuilder = class
  protected
    FPE: TPEImage;
  public
    constructor Create(PE: TPEImage);

    // Builds bogus directory and return size.
    // Override it if you have better implementation.
    function EstimateTheSize: uint32; virtual;

    // Build directory data and store it to stream.
    // * DirRVA:  RVA of directory start.
    // * Stream:  Stream to store data.
    procedure Build(DirRVA: TRVA; Stream: TStream); virtual; abstract;

    // If new section created, it's called to get the flags.
    class function GetDefaultSectionFlags: uint32; virtual; abstract;

    // If new section created, it's called to get the name.
    class function GetDefaultSectionName: string; virtual; abstract;

    // Return True if need to call Build each time when DirRVA changed.
    class function NeedRebuildingIfRVAChanged: boolean; virtual; abstract;
  end;

  TDirectoryBuilderClass = class of TDirectoryBuilder;

implementation


{ TDirBuilder }

constructor TDirectoryBuilder.Create(PE: TPEImage);
begin
  FPE := PE;
end;

function TDirectoryBuilder.EstimateTheSize: uint32;
var
  tmp: TNullStream;
begin
  tmp := TNullStream.Create;
  try
    Build(0, tmp);
    Result := tmp.Size;
  finally
    tmp.Free;
  end;
end;

end.
