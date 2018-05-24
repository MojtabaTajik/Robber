unit PE.Resources.Windows.Bitmap;

interface

uses
  System.Classes,
  System.SysUtils,

  PE.Utils;

// Parse RT_BITMAP into BMP stream.
function ParseBitmapResource(const Stream: TStream): TStream;

implementation

{$ALIGN 1}


type
  TBitmapFileHeader = record
    bfType: uint16;      // BM
    bfSize: uint32;      // Size of bitmap file/stream.
    bfReserved1: uint16; //
    bfReserved2: uint16; //
    bfOffBits: uint32;   // Offset of pixels.
  end;

  TBitmapInfoHeader = record
    biSize: uint32;
    biWidth: int32;
    biHeight: int32;
    biPlanes: uint16;
    biBitCount: uint16;
    biCompression: uint32;
    biSizeImage: uint32;
    biXPelsPerMeter: int32;
    biYPelsPerMeter: int32;
    biClrUsed: uint32;
    biClrImportant: uint32;
  end;

function ParseBitmapResource(const Stream: TStream): TStream;
var
  BmpHdr: TBitmapFileHeader;
  InfoHdr: TBitmapInfoHeader;
begin
  if not StreamRead(Stream, InfoHdr, SizeOf(InfoHdr)) then
    raise Exception.Create('Stream too small.');

  BmpHdr.bfType := $4D42; // BM
  BmpHdr.bfSize := SizeOf(TBitmapFileHeader) + Stream.Size;
  BmpHdr.bfReserved1 := 0;
  BmpHdr.bfReserved2 := 0;
  BmpHdr.bfOffBits := 0; // Nowadays viewers are smart enough to calc this offset themselves.

  // Create bitmap.
  Stream.Position := 0;
  Result := TMemoryStream.Create;
  Result.Write(BmpHdr, SizeOf(BmpHdr));
  Result.CopyFrom(Stream, Stream.Size);

  Result.Position := 0;
end;

end.
