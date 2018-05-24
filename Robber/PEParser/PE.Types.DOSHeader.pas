unit PE.Types.DOSHeader;

interface

type
  TDOSMagic = packed record
  public
    function IsMZ: boolean; inline;
    procedure SetMZ; inline;
  public
    case integer of
      0:
        (chars: array [0 .. 1] of AnsiChar);
  end;

type
  TImageDOSHeader = packed record
    e_magic: TDOSMagic;               // Magic number.
    e_cblp: uint16;                   // Bytes on last page of file.
    e_cp: uint16;                     // Pages in file.
    e_crlc: uint16;                   // Relocations.
    e_cparhdr: uint16;                // Size of header in paragraphs.
    e_minalloc: uint16;               // Minimum extra paragraphs needed.
    e_maxalloc: uint16;               // Maximum extra paragraphs needed.
    e_ss: uint16;                     // Initial (relative) SS value.
    e_sp: uint16;                     // Initial SP value.
    e_csum: uint16;                   // Checksum.
    e_ip: uint16;                     // Initial IP value.
    e_cs: uint16;                     // Initial (relative) CS value.
    e_lfarlc: uint16;                 // File address of relocation table.
    e_ovno: uint16;                   // Overlay number.
    e_res: array [0 .. 3] of uint16;  // Reserved words.
    e_oemid: uint16;                  // OEM identifier (for e_oeminfo).
    e_oeminfo: uint16;                // OEM information; e_oemid specific.
    e_res2: array [0 .. 9] of uint16; // Reserved words.
    e_lfanew: uint32;                 // File address of new exe header.
  end;

  PImageDOSHeader = ^TImageDOSHeader;

const
  DOSSTUB: packed array [0 .. 56] of byte = ($0E, $1F, $BA, $0E, $00, $B4, $09,
    $CD, $21, $B8, $01, $4C, $CD, $21, $54, $68, $69, $73, $20, $70, $72, $6F,
    $67, $72, $61, $6D, $20, $63, $61, $6E, $6E, $6F, $74, $20, $62, $65, $20,
    $72, $75, $6E, $20, $69, $6E, $20, $44, $4F, $53, $20, $6D, $6F, $64, $65,
    $2E, $0D, $0D, $0A, $24);

implementation

{ TDOSMagic }

function TDOSMagic.IsMZ: boolean;
begin
  result := self.chars = 'MZ';
end;

procedure TDOSMagic.SetMZ;
begin
  self.chars[0] := 'M';
  self.chars[1] := 'Z';
end;

end.
