unit fMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.ValEdit, Vcl.ComCtrls, FileCtrl, IOUtils,
  Vcl.ImgList, ShellAPI, ClipBrd, DLLHijack, DigitalSignature, Vcl.Menus,
  System.TypInfo, Vcl.ExtCtrls, Vcl.Samples.Spin, PNGImage, System.ImageList,
  Vcl.Themes, System.Types, ScanThread;

type
  TfrmMain = class(TForm)
    pumTree: TPopupMenu;
    miCopy: TMenuItem;
    imglMain: TImageList;
    miOpenPath: TMenuItem;
    tvApplication: TTreeView;
    GOptions: TGroupBox;
    rgMustScanImageType: TRadioGroup;
    edSearchPath: TEdit;
    rgSignState: TRadioGroup;
    rgAbuseCandidate: TRadioGroup;
    gbColorConfig: TGroupBox;
    lblBestChoice: TLabel;
    lblGoodChoice: TLabel;
    iBestChoice: TImage;
    iGoodChoice: TImage;
    sedBestChoiceDLLCount: TSpinEdit;
    sedGoodChoiceExeSize: TSpinEdit;
    sedGoodChoiceDLLCount: TSpinEdit;
    sedBestChoiceExeSize: TSpinEdit;
    btnBrowsePath: TButton;
    btnScan: TButton;
    btnAbout: TButton;
    iBadChoice: TImage;
    lblBadChoice: TLabel;
    StatusBar1: TStatusBar;
    AnalyzeProgress: TProgressBar;
    rgbWritePerm: TRadioGroup;
    procedure btnBrowsePathClick(Sender: TObject);
    procedure btnAboutClick(Sender: TObject);
    procedure miCopyClick(Sender: TObject);
    procedure miOpenPathClick(Sender: TObject);
    procedure btnScanClick(Sender: TObject);
    procedure sedGoodChoiceDLLCountChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FScanThread: TScanThread;
    procedure StartScan;
    procedure CancelScan;
    procedure CollapseAllItems;
    procedure SetOptionControlsEnableState(EnableState: Boolean);
    procedure OnScanProgress(Current, Total: Integer; const FileName: string);
    procedure OnScanResult(const Result: TScanResult);
    procedure OnScanDone(Cancelled: Boolean);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  fAbout;

procedure TfrmMain.btnBrowsePathClick(Sender: TObject);
var
  Dir: string;
begin
  SelectDirectory('Select directory : ', '', Dir);
  if DirectoryExists(Dir) then
  begin
    edSearchPath.Text := Dir;
    btnScan.Enabled := True;
  end;
end;

procedure TfrmMain.btnScanClick(Sender: TObject);
begin
  if FScanThread <> nil then
    CancelScan
  else
    StartScan;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FScanThread <> nil then
    FScanThread.Terminate;
end;

procedure TfrmMain.StartScan;
var
  Options: TScanOptions;
begin
  SetOptionControlsEnableState(False);
  btnScan.Caption := 'Cancel';
  btnScan.Enabled := True;

  Options.SearchPath := edSearchPath.Text;
  Options.ImageTypeFilter := rgMustScanImageType.ItemIndex;
  Options.SignFilter := rgSignState.ItemIndex;
  Options.AbuseCandidateFilter := rgAbuseCandidate.ItemIndex;
  Options.WritePermFilter := rgbWritePerm.ItemIndex;
  Options.BestChoiceDLLCount := sedBestChoiceDLLCount.Value;
  Options.BestChoiceExeSize := sedBestChoiceExeSize.Value;
  Options.GoodChoiceDLLCount := sedGoodChoiceDLLCount.Value;
  Options.GoodChoiceExeSize := sedGoodChoiceExeSize.Value;

  AnalyzeProgress.Position := 0;
  StatusBar1.Panels[0].Text := 'Starting scan...';

  FScanThread := TScanThread.Create(Options, OnScanProgress, OnScanResult, OnScanDone);
end;

procedure TfrmMain.CancelScan;
begin
  if FScanThread <> nil then
  begin
    FScanThread.Terminate;
    StatusBar1.Panels[0].Text := 'Cancelling...';
    btnScan.Enabled := False;
  end;
end;

procedure TfrmMain.OnScanProgress(Current, Total: Integer; const FileName: string);
begin
  AnalyzeProgress.Max := Total;
  AnalyzeProgress.Position := Current;
  StatusBar1.Panels[0].Text := Format('Scanning [%d/%d]: %s',
    [Current, Total, ExtractFileName(FileName)]);
end;

procedure TfrmMain.OnScanResult(const Result: TScanResult);
var
  App, DLLNode, Scale, Sign, ImageTypeNode, Method: TTreeNode;
  DLLInfo: TDLLScanInfo;
  MethodName, ImageTypeString: string;
begin
  tvApplication.Items.BeginUpdate;
  try
    App := tvApplication.Items.Add(nil, Result.ExePath);

    Scale := tvApplication.Items.AddChild(App,
      Format('File Size : %d KB', [Result.FileSize]));
    Scale.ImageIndex := 1;
    Scale.SelectedIndex := 1;

    if Result.IsX86 then ImageTypeString := 'x86' else ImageTypeString := 'x64';
    ImageTypeNode := tvApplication.Items.AddChild(App,
      Format('ImageType : %s', [ImageTypeString]));
    ImageTypeNode.ImageIndex := 8;
    ImageTypeNode.SelectedIndex := 8;

    if Trim(Result.SignerCompany) <> '' then
    begin
      Sign := tvApplication.Items.AddChild(App,
        Format('Sign by : %s', [Result.SignerCompany]));
      Sign.ImageIndex := 7;
      Sign.SelectedIndex := 7;
    end;

    case Result.HijackRate of
      hrBest: App.ImageIndex := 4;
      hrGood: App.ImageIndex := 5;
      hrBad:  App.ImageIndex := 6;
    end;
    App.SelectedIndex := App.ImageIndex;

    for DLLInfo in Result.DLLs do
    begin
      DLLNode := tvApplication.Items.AddChild(App, DLLInfo.Name);
      DLLNode.ImageIndex := 2;
      DLLNode.SelectedIndex := 2;

      for MethodName in DLLInfo.Methods do
      begin
        Method := tvApplication.Items.AddChild(DLLNode, MethodName);
        Method.ImageIndex := 3;
        Method.SelectedIndex := 3;
      end;
    end;
  finally
    tvApplication.Items.EndUpdate;
  end;
end;

procedure TfrmMain.OnScanDone(Cancelled: Boolean);
begin
  FScanThread := nil;
  AnalyzeProgress.Position := 0;
  SetOptionControlsEnableState(True);
  btnScan.Caption := 'Scan';
  CollapseAllItems;

  if Cancelled then
    StatusBar1.Panels[0].Text := 'Scan cancelled'
  else
  begin
    StatusBar1.Panels[0].Text := 'Done';
    MessageDlg('Scan complete', mtInformation, [mbOK], 0);
  end;
end;

procedure TfrmMain.miCopyClick(Sender: TObject);
begin
  Clipboard.Open;
  try
    Clipboard.AsText := tvApplication.Selected.Text;
  finally
    Clipboard.Close;
  end;
end;

procedure TfrmMain.miOpenPathClick(Sender: TObject);
var
  SelectedPath: string;
begin
  SelectedPath := LowerCase(tvApplication.Selected.Text);

  if ExtractFileExt(SelectedPath) = '.dll' then
    SelectedPath := ExtractFilePath(tvApplication.Selected.Parent.Text)
      + tvApplication.Selected.Text;

  if FileExists(SelectedPath) then
    ShellExecute(0, nil, PChar('explorer.exe'),
      PChar('/select, "' + SelectedPath + '"'), nil, SW_NORMAL);
end;

procedure TfrmMain.btnAboutClick(Sender: TObject);
begin
  TfrmAbout.Execute;
end;

procedure TfrmMain.sedGoodChoiceDLLCountChange(Sender: TObject);
begin
  lblBadChoice.Caption := Format('DLL Count > %d , EXE Size > %d',
    [sedGoodChoiceDLLCount.Value, sedGoodChoiceExeSize.Value]);
end;

procedure TfrmMain.SetOptionControlsEnableState(EnableState: Boolean);
begin
  GOptions.Enabled := EnableState;

  if not EnableState then
  begin
    tvApplication.Items.BeginUpdate;
    try
      tvApplication.Items.Clear;
    finally
      tvApplication.Items.EndUpdate;
    end;
  end;
end;

procedure TfrmMain.CollapseAllItems;
var
  i: Integer;
begin
  for i := 0 to tvApplication.Items.Count - 1 do
    tvApplication.Items[i].Collapse(True);
end;

end.
