unit PE.Types.NTHeaders;

interface

uses
  PE.Types.FileHeader,
  PE.Types.OptionalHeader;

type
{
  TImageNTHeaders32 = packed record
    Signature: uint32;
    FileHeader: TImageFileHeader;
    OptionalHeader: TImageOptionalHeader32;
  end;

  PImageNTHeaders32 = ^TImageNTHeaders32;

  TImageNTHeaders64 = packed record
    Signature: uint32;
    FileHeader: TImageFileHeader;
    OptionalHeader: TImageOptionalHeader64;
  end;

  PImageNTHeaders64 = ^TImageNTHeaders64;
}

  TNTSignature = record
  public
    function IsPE00: boolean; inline;
  public
    case integer of
      0:
        (chars: array [0 .. 3] of AnsiChar);
  end;

  TImageNTHeaders = packed record
    Signature: TNTSignature;
    FileHeader: TImageFileHeader;
    OptionalHeader: TImageOptionalHeader;
  end;

  PImageNTHeaders = ^TImageNTHeaders;

const
  PE00_SIGNATURE: TNTSignature = (chars: 'PE'#0#0);

implementation

{ TNTSignature }

function TNTSignature.IsPE00: boolean;
begin
  result := self.chars = PE00_SIGNATURE.chars;
end;

end.
