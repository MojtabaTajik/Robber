unit fMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.ValEdit, Vcl.ComCtrls, FileCtrl, IOUtils,
  Vcl.ImgList, ShellAPI, ClipBrd, DLLHijack, DigitalSignature, Vcl.Menus,
  System.TypInfo, Vcl.ExtCtrls, Vcl.Samples.Spin, PNGImage, System.ImageList,
  Vcl.Themes, System.Types, ScanThread, IniFiles, System.Generics.Collections,
  System.StrUtils, DLLSearchOrder;

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
  if FScanThread <> nil then
    FScanThread.Terminate;
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
      var UACNode := tvApplication.Items.AddChild(App,
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
        var OrderNode := tvApplication.Items.AddChild(DLLNode, 'Search Order');
        OrderNode.ImageIndex := 1;
        OrderNode.SelectedIndex := 1;
        var Pos := 1;
        for var Entry in DLLInfo.SearchOrder do
        begin
          var Flag := '';
          if Entry.ContainsDLL then Flag := Flag + ' [DLL here]';
          if Entry.Writable     then Flag := Flag + ' [WRITABLE]';
          var EntryNode := tvApplication.Items.AddChild(OrderNode,
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

function HijackRateStr(Rate: THijackRate): string;
begin
  case Rate of
    hrBest: Result := 'Best';
    hrGood: Result := 'Good';
    hrBad:  Result := 'Bad';
  else
    Result := '';
  end;
end;

function CSVEscape(const S: string): string;
begin
  if S.Contains(',') or S.Contains('"') or S.Contains(#10) or S.Contains(#13) then
    Result := '"' + S.Replace('"', '""') + '"'
  else
    Result := S;
end;

function JSONEscape(const S: string): string;
begin
  Result := S
    .Replace('\', '\\')
    .Replace('"', '\"')
    .Replace(#13, '\r')
    .Replace(#10, '\n')
    .Replace(#9,  '\t');
end;

procedure TfrmMain.ExportToCSV(const FilePath: string);
var
  Lines: TStringList;
  Res: TScanResult;
  DLL: TDLLScanInfo;
  Method: string;
  Row: string;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('ExePath,FileSize,Architecture,Signed,Signer,HijackRate,UAC,DLL,WritableAttackPaths,Method');

    for Res in FResults do
      for DLL in Res.DLLs do
      begin
        var WritablePaths := '';
        for var SO in DLL.SearchOrder do
          if SO.Writable then
            WritablePaths := WritablePaths + IfThen(WritablePaths = '', '', '; ') + SO.Path;

        if Length(DLL.Methods) = 0 then
        begin
          Row := CSVEscape(Res.ExePath) + ',' +
                 IntToStr(Res.FileSize) + ',' +
                 IfThen(Res.IsX86, 'x86', 'x64') + ',' +
                 IfThen(Res.IsSigned, 'true', 'false') + ',' +
                 CSVEscape(Res.SignerCompany) + ',' +
                 HijackRateStr(Res.HijackRate) + ',' +
                 Res.ExecutionLevel + ',' +
                 CSVEscape(DLL.Name) + ',' +
                 CSVEscape(WritablePaths) + ',';
          Lines.Add(Row);
        end
        else
          for Method in DLL.Methods do
          begin
            Row := CSVEscape(Res.ExePath) + ',' +
                   IntToStr(Res.FileSize) + ',' +
                   IfThen(Res.IsX86, 'x86', 'x64') + ',' +
                   IfThen(Res.IsSigned, 'true', 'false') + ',' +
                   CSVEscape(Res.SignerCompany) + ',' +
                   HijackRateStr(Res.HijackRate) + ',' +
                   Res.ExecutionLevel + ',' +
                   CSVEscape(DLL.Name) + ',' +
                   CSVEscape(WritablePaths) + ',' +
                   CSVEscape(Method);
            Lines.Add(Row);
          end;
      end;

    Lines.SaveToFile(FilePath, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

procedure TfrmMain.ExportToJSON(const FilePath: string);
var
  SB: TStringBuilder;
  Res: TScanResult;
  DLL: TDLLScanInfo;
  Method: string;
  FirstRes, FirstDLL, FirstMethod: Boolean;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('[');
    FirstRes := True;

    for Res in FResults do
    begin
      if not FirstRes then SB.AppendLine(',');
      FirstRes := False;

      SB.AppendLine('  {');
      SB.AppendLine(Format('    "path": "%s",',        [JSONEscape(Res.ExePath)]));
      SB.AppendLine(Format('    "fileSizeKB": %d,',    [Res.FileSize]));
      SB.AppendLine(Format('    "architecture": "%s",', [IfThen(Res.IsX86, 'x86', 'x64')]));
      SB.AppendLine(Format('    "signed": %s,',         [IfThen(Res.IsSigned, 'true', 'false')]));
      SB.AppendLine(Format('    "signer": "%s",',       [JSONEscape(Res.SignerCompany)]));
      SB.AppendLine(Format('    "hijackRate": "%s",',     [HijackRateStr(Res.HijackRate)]));
      SB.AppendLine(Format('    "executionLevel": "%s",', [JSONEscape(Res.ExecutionLevel)]));
      SB.AppendLine('    "dlls": [');

      FirstDLL := True;
      for DLL in Res.DLLs do
      begin
        if not FirstDLL then SB.AppendLine(',');
        FirstDLL := False;

        SB.AppendLine('      {');
        SB.AppendLine(Format('        "name": "%s",', [JSONEscape(DLL.Name)]));

        // Search order
        SB.AppendLine('        "searchOrder": [');
        var FirstSO := True;
        for var SO in DLL.SearchOrder do
        begin
          if not FirstSO then SB.AppendLine(',');
          FirstSO := False;
          SB.Append(Format(
            '          {"path":"%s","label":"%s","writable":%s,"containsDLL":%s}',
            [JSONEscape(SO.Path), JSONEscape(SO.Label_),
             IfThen(SO.Writable, 'true', 'false'),
             IfThen(SO.ContainsDLL, 'true', 'false')]));
        end;
        if Length(DLL.SearchOrder) > 0 then SB.AppendLine('');
        SB.AppendLine('        ],');

        SB.AppendLine('        "methods": [');
        FirstMethod := True;
        for Method in DLL.Methods do
        begin
          if not FirstMethod then SB.AppendLine(',');
          FirstMethod := False;
          SB.Append(Format('          "%s"', [JSONEscape(Method)]));
        end;

        if Length(DLL.Methods) > 0 then SB.AppendLine('');
        SB.AppendLine('        ]');
        SB.Append('      }');
      end;

      if Length(Res.DLLs) > 0 then SB.AppendLine('');
      SB.AppendLine('    ]');
      SB.Append('  }');
    end;

    SB.AppendLine('');
    SB.AppendLine(']');

    TFile.WriteAllText(FilePath, SB.ToString, TEncoding.UTF8);
  finally
    SB.Free;
  end;
end;

end.
