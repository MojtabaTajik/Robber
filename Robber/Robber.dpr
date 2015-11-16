program Robber;

uses
  Vcl.Forms,
  fMain in 'fMain.pas' {frmMain},
  DLLHijack in 'DLLHijack.pas',
  Vcl.Themes,
  Vcl.Styles,
  fAbout in 'fAbout.pas' {frmAbout},
  DigitalSignature in 'DigitalSignature.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown:= True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Carbon');
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
