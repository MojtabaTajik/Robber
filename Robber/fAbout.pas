unit fAbout;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Imaging.pngimage,
  Vcl.ExtCtrls;

type
  TfrmAbout = class(TForm)
    imgLogo: TImage;
    tScrollAbout: TTimer;
    lblAppTitle: TLabel;
    lblVersion: TLabel;
    GroupBox1: TGroupBox;
    lblLicense: TLabel;
    procedure tScrollAboutTimer(Sender: TObject);
    procedure FormClick(Sender: TObject);
  private
    function GetVersionInfo: string;
  public
    ///	<summary>
    ///	  Create an instance of TfrmAbout &amp; show it modally , finally free
    ///	  it after close
    ///	</summary>
    ///	<returns>
    ///	  Determine user select OK button to exit
    ///	</returns>
    ///	<remarks>
    ///	  The file version of application get using GetVersioninfo function
    ///	</remarks>
    class function Execute: Boolean;
  end;

var
  frmAbout: TfrmAbout;

implementation

{$R *.dfm}
{ TfrmAbout }

class function TfrmAbout.Execute: Boolean;
begin
  with TfrmAbout.Create(Application) do
    try
      lblVersion.Caption:= Format('Version : %s', [GetVersionInfo]);
      Result := (ShowModal = mrOk);
    finally
      Free;;
    end;
end;

procedure TfrmAbout.FormClick(Sender: TObject);
begin
  Self.ModalResult:= mrOk;
end;

function TfrmAbout.GetVersionInfo: string;
type
  PLandCodepage = ^TLandCodepage;

  TLandCodepage = record
    wLanguage, wCodePage: word;
  end;
var
  dummy, Len: cardinal;
  Buf, pntr: pointer;
  Language: string;
begin
  Len := GetFileVersionInfoSize(PChar(ParamStr(0)), dummy);
  if Len = 0 then
    Exit;
  GetMem(Buf, Len);
  try
    if not GetFileVersionInfo(PChar(ParamStr(0)), 0, Len, Buf) then
      Exit;

    if not VerQueryValue(Buf, '\VarFileInfo\Translation\', pntr, Len) then
      Exit;

    Language := Format('%.4x%.4x', [PLandCodepage(pntr)^.wLanguage,
      PLandCodepage(pntr)^.wCodePage]);

    if VerQueryValue(Buf, PChar('\StringFileInfo\' + Language + '\FileVersion'),
      pntr, Len) { and (@len <> nil) } then
      Result := PChar(pntr);
  finally
    FreeMem(Buf);
  end;
end;

procedure TfrmAbout.tScrollAboutTimer(Sender: TObject);
begin
  lblLicense.Top := lblLicense.Top - 1;
  if ((lblLicense.Top + lblLicense.Height) <= 0) then
    Self.ModalResult:= mrOk;
end;

end.
