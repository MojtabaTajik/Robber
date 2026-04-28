unit fMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.ValEdit, Vcl.ComCtrls, FileCtrl, IOUtils,
  Vcl.ImgList, ShellAPI, ClipBrd, DLLHijack, DigitalSignature, Vcl.Menus,
  System.TypInfo, Vcl.ExtCtrls, Vcl.Samples.Spin, PNGImage, System.ImageList,
  Vcl.Themes, System.Types, ScanThread, IniFiles, System.Generics.Collections,
  System.StrUtils, DLLSearchOrder, ScanExport;

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
    btnExport: TButton;
    procedure btnBrowsePathClick(Sender: TObject);
    procedure btnAboutClick(Sender: TObject);
    procedure miCopyClick(Sender: TObject);
    procedure miOpenPathClick(Sender: TObject);
    procedure btnScanClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure sedGoodChoiceDLLCountChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FScanThread: TScanThread;
    FResults: TList<TScanResult>;
    function SettingsPath: string;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure StartScan;
    procedure CancelScan;
    procedure CollapseAllItems;
    procedure SetOptionControlsEnableState(EnableState: Boolean);
    procedure OnScanProgress(Current, Total: Integer; const FileName: string);
    procedure OnScanResult(const Result: TScanResult);
    procedure OnScanDone(Cancelled: Boolean);
    procedure ExportToCSV(const FilePath: string);
    procedure ExportToJSON(const FilePath: string);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  fAbout;

function TfrmMain.SettingsPath: string;
begin
  Result := ChangeFileExt(Application.ExeName, '.ini');
end;

procedure TfrmMain.LoadSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(SettingsPath);
  try
    edSearchPath.Text                  := Ini.ReadString ('Scan',    'LastPath',          '');
    rgMustScanImageType.ItemIndex      := Ini.ReadInteger('Filters', 'ImageType',          0);
    rgSignState.ItemIndex              := Ini.ReadInteger('Filters', 'SignState',           0);
    rgAbuseCandidate.ItemIndex         := Ini.ReadInteger('Filters', 'AbuseCandidate',      0);
    rgbWritePerm.ItemIndex             := Ini.ReadInteger('Filters', 'WritePerm',           0);
    sedBestChoiceDLLCount.Value        := Ini.ReadInteger('Rules',   'BestChoiceDLLCount',  2);
    sedBestChoiceExeSize.Value         := Ini.ReadInteger('Rules',   'BestChoiceExeSize',  10240);
    sedGoodChoiceDLLCount.Value        := Ini.ReadInteger('Rules',   'GoodChoiceDLLCount',  5);
    sedGoodChoiceExeSize.Value         := Ini.ReadInteger('Rules',   'GoodChoiceExeSize',  51200);
  finally
    Ini.Free;
  end;

  btnScan.Enabled := edSearchPath.Text <> '';
end;

procedure TfrmMain.SaveSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(SettingsPath);
  try
    Ini.WriteString ('Scan',    'LastPath',          edSearchPath.Text);
    Ini.WriteInteger('Filters', 'ImageType',          rgMustScanImageType.ItemIndex);
    Ini.WriteInteger('Filters', 'SignState',           rgSignState.ItemIndex);
    Ini.WriteInteger('Filters', 'AbuseCandidate',      rgAbuseCandidate.ItemIndex);
    Ini.WriteInteger('Filters', 'WritePerm',           rgbWritePerm.ItemIndex);
    Ini.WriteInteger('Rules',   'BestChoiceDLLCount',  sedBestChoiceDLLCount.Value);
    Ini.WriteInteger('Rules',   'BestChoiceExeSize',   sedBestChoiceExeSize.Value);
    Ini.WriteInteger('Rules',   'GoodChoiceDLLCount',  sedGoodChoiceDLLCount.Value);
    Ini.WriteInteger('Rules',   'GoodChoiceExeSize',   sedGoodChoiceExeSize.Value);
  finally
    Ini.Free;
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FResults := TList<TScanResult>.Create;
  LoadSettings;
end;

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
  // Detach callbacks first so any in-flight Synchronize calls become
  // no-ops and don't try to access this form after we've started tearing
  // it down. The thread is FreeOnTerminate, so we just signal Terminate
  // and let it finish on its own.
  if FScanThread <> nil then
  begin
    FScanThread.ClearCallbacks;
    FScanThread.Terminate;
  end;
  SaveSettings;
  FResults.Free;
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
  Caption := 'Robber — Scanning...';
  FResults.Clear;
  btnExport.Enabled := False;

  FScanThread := TScanThread.Create(Options, OnScanProgress, OnScanResult, OnScanDone);
end;

procedure TfrmMain.CancelScan;
begin
  if FScanThread <> nil then
  begin
    FScanThread.Terminate;
    StatusBar1.Panels[0].Text := 'Cancelling...';
    Caption := 'Robber — Cancelling...';
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
  UACNode, OrderNode, EntryNode: TTreeNode;
  DLLInfo: TDLLScanInfo;
  Entry: TSearchEntry;
  MethodName, ImageTypeString, Flag: string;
  Pos, j: Integer;
begin
  FResults.Add(Result);

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

    if (Result.ExecutionLevel = 'requireAdministrator') or
       (Result.ExecutionLevel = 'highestAvailable') then
    begin
      UACNode := tvApplication.Items.AddChild(App,
        Format('UAC : %s', [Result.ExecutionLevel]));
      UACNode.ImageIndex := 7;
      UACNode.SelectedIndex := 7;
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

      // Search order sub-tree
      if Length(DLLInfo.SearchOrder) > 0 then
      begin
        OrderNode := tvApplication.Items.AddChild(DLLNode, 'Search Order');
        OrderNode.ImageIndex := 1;
        OrderNode.SelectedIndex := 1;
        Pos := 1;
        for j := 0 to High(DLLInfo.SearchOrder) do
        begin
          Entry := DLLInfo.SearchOrder[j];
          Flag := '';
          if Entry.ContainsDLL then Flag := Flag + ' [DLL here]';
          if Entry.Writable     then Flag := Flag + ' [WRITABLE]';
          EntryNode := tvApplication.Items.AddChild(OrderNode,
            Format('[%d] %s%s', [Pos, Entry.Label_, Flag]));
          EntryNode.ImageIndex := 3;
          EntryNode.SelectedIndex := 3;
          Inc(Pos);
        end;
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
  btnExport.Enabled := FResults.Count > 0;
  CollapseAllItems;

  Caption := 'Robber — DLL Hijack Scanner';
  if Cancelled then
    StatusBar1.Panels[0].Text := 'Scan cancelled'
  else
  begin
    StatusBar1.Panels[0].Text := Format('Scan complete — %d vulnerabilit%s found',
      [FResults.Count, IfThen(FResults.Count = 1, 'y', 'ies')]);
    MessageDlg(Format('Scan complete'#13#10'%d vulnerable executable%s found.',
      [FResults.Count, IfThen(FResults.Count = 1, '', 's')]),
      mtInformation, [mbOK], 0);
  end;
end;

procedure TfrmMain.miCopyClick(Sender: TObject);
begin
  if tvApplication.Selected = nil then
    Exit;
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
  if tvApplication.Selected = nil then
    Exit;

  SelectedPath := LowerCase(tvApplication.Selected.Text);

  if ExtractFileExt(SelectedPath) = '.dll' then
  begin
    if tvApplication.Selected.Parent = nil then
      Exit;
    SelectedPath := ExtractFilePath(tvApplication.Selected.Parent.Text)
      + tvApplication.Selected.Text;
  end;

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

procedure TfrmMain.btnExportClick(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  if FResults.Count = 0 then
    Exit;

  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Export results';
    Dlg.Filter := 'JSON file (*.json)|*.json|CSV file (*.csv)|*.csv';
    Dlg.FilterIndex := 1;
    Dlg.DefaultExt := 'json';
    Dlg.Options := [ofOverwritePrompt, ofPathMustExist];

    if not Dlg.Execute then
      Exit;

    if Dlg.FilterIndex = 1 then
      ExportToJSON(Dlg.FileName)
    else
      ExportToCSV(Dlg.FileName);

    StatusBar1.Panels[0].Text := Format('Exported %d results to %s',
      [FResults.Count, ExtractFileName(Dlg.FileName)]);
  finally
    Dlg.Free;
  end;
end;

procedure TfrmMain.ExportToCSV(const FilePath: string);
var
  Csv: string;
begin
  // Convert the TList to a plain array — ScanExport works on arrays so it
  // can serve both the GUI (TList<TScanResult>) and CLI (TArray<TScanResult>)
  // without coupling to either container type.
  Csv := ScanExport.BuildCSV(FResults.ToArray);
  TFile.WriteAllText(FilePath, Csv, TEncoding.UTF8);
end;

procedure TfrmMain.ExportToJSON(const FilePath: string);
var
  Json: string;
begin
  Json := ScanExport.BuildJSON(FResults.ToArray);
  TFile.WriteAllText(FilePath, Json, TEncoding.UTF8);
end;

end.
