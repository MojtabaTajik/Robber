unit fMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.ValEdit, Vcl.ComCtrls, FileCtrl, IOUtils,
  Vcl.ImgList, ShellAPI, ClipBrd, DLLHijack, DigitalSignature, Vcl.Menus,
  System.TypInfo, Vcl.ExtCtrls, Vcl.Samples.Spin, PNGImage, System.ImageList,
  Vcl.Themes, System.Types;

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
  private
    procedure ScanHijack();
    procedure ScanImportMethods;
    procedure CollapseALLItems;
    function CheckAbuseCandidateOption(HijackRate: THijackRate): Boolean;
    function CheckImageTypeOption(IsX86Image: Boolean): Boolean;
    function CheckImageSignOption(IsSigned: Boolean): Boolean;
    function CheckWeakWritePermission(FilePath: string): Boolean;
    procedure SetOptionControlsEnableState(EnableState: Boolean);
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
  // Display select directory dialog to perform scan on user selected directory
  SelectDirectory('Select directory : ', '', Dir);
  if (System.SysUtils.DirectoryExists(Dir)) then
    if (DirectoryExists(Dir)) then
    begin
      edSearchPath.Text := Dir;
      btnScan.Enabled := true;
    end;
end;

procedure TfrmMain.btnScanClick(Sender: TObject);
begin
  SetOptionControlsEnableState(False);

  StatusBar1.Panels[0].Text := 'Retrieve file list from disk';

  // Scan for hijackable executables
  ScanHijack();

  // Scan method imports of execut
  StatusBar1.Panels[0].Text := 'Scanning DLL methods';

  ScanImportMethods;

  SetOptionControlsEnableState(true);

  StatusBar1.Panels[0].Text := 'Done';

  MessageDlg('Scan compelete', mtInformation, [mbOK], 0);
end;

procedure TfrmMain.miCopyClick(Sender: TObject);
begin
  // Copy selected item text
  Clipboard.Open;
  try
    Clipboard.AsText := tvApplication.Selected.Text;
  finally
    Clipboard.Close;
  end;
end;

procedure TfrmMain.miOpenPathClick(Sender: TObject);
var
  SelectedAppDirectorey: string;
begin
  // Get selected item
  SelectedAppDirectorey := LowerCase(tvApplication.Selected.Text);

  // Check if selected file is DLL , combine host application directory + DLL name to get DLL path
  if (ExtractFileExt(SelectedAppDirectorey) = '.dll') then
    SelectedAppDirectorey := ExtractFilePath(tvApplication.Selected.Parent.Text)
      + tvApplication.Selected.Text;

  // Check if Selected item exists , explore it's directory in windows explorer and select it int explorer
  if (FileExists(SelectedAppDirectorey)) then
    ShellExecute(0, nil, PChar('explorer.exe'),
      PChar('/select, "' + PChar(SelectedAppDirectorey) + '"'), nil, SW_NORMAL);
end;

function TfrmMain.CheckAbuseCandidateOption(HijackRate: THijackRate): Boolean;
begin
  case rgAbuseCandidate.ItemIndex of
    0:
      exit(False);

    1:
      if (HijackRate = hrBest) then
        exit(False);

    2:
      if (HijackRate = hrGood) then
        exit(False);

    3:
      if (HijackRate = hrBad) then
        exit(False);
  end;

  Result := true;
end;

function TfrmMain.CheckImageSignOption(IsSigned: Boolean): Boolean;
begin
  case rgSignState.ItemIndex of
    0:
      exit(False);

    1:
      if (IsSigned = true) then
        exit(False);
  end;

  Result := true;
end;

function TfrmMain.CheckImageTypeOption(IsX86Image: Boolean): Boolean;
begin
  case rgMustScanImageType.ItemIndex of
    0:
      exit(False);

    1:
      begin
        if (IsX86Image = true) then
          exit(False);
      end;

    2:
      begin
        if (IsX86Image = False) then
          exit(False);
      end;
  end;

  Result := true;
end;

function TfrmMain.CheckWeakWritePermission(FilePath: string): Boolean;
const
  TempFileName: string = 'RobberWriteCheck.txt';
var
  DirPath: string;
  TempFilePath: String;
  FS: TFileStream;
begin
  // Any permission
  if (rgbWritePerm.ItemIndex = 0) then
    exit(False);

  // Check weak permission
  DirPath := TPath.GetDirectoryName(FilePath);
  TempFilePath := TPath.Combine(DirPath, TempFileName);

  try
    FS := TFile.Create(TempFilePath);
    try
      if (FS <> nil) then
        exit(False)
      else
        exit(true);
    finally
      FS.Free;
      TFile.Delete(TempFilePath);
    end;
  except
    on E: Exception do
      exit(true);
  end;
end;

procedure TfrmMain.btnAboutClick(Sender: TObject);
begin
  // Show about form
  TfrmAbout.Execute;
end;

procedure TfrmMain.ScanHijack();
var
  EachFile: string;
  FileSize: Cardinal;
  ImageTypeString: string;
  App, DLLs, Scale, Sign, ImageTypeNode: TTreeNode;
  FileList: TStringDynArray;

  // DLL Hijack
  PEFile: TDLLHijack;
  ImportDLLs: TStringList;
  DLLName: string;

  // Signature
  Signature: TDigitalSignature;
  IsSigned: Boolean;
  SignerCompany: string;
  HijackRate: THijackRate;
begin
  FileList := TDirectory.GetFiles(edSearchPath.Text, '*.exe',
    TSearchOption.soAllDirectories);

  AnalyzeProgress.Position := 0;
  AnalyzeProgress.Max := Length(FileList);

  for EachFile in FileList do
  begin
    try
      AnalyzeProgress.Position := AnalyzeProgress.Position + 1;
      StatusBar1.Panels[0].Text := Format('Analyze file [%d] of [%d]',
        [AnalyzeProgress.Position, AnalyzeProgress.Max]);

      Application.ProcessMessages;

      // Init
      IsSigned := False;
      ImportDLLs := TStringList.Create;
      PEFile := TDLLHijack.Create(EachFile);
      Signature := TDigitalSignature.Create(EachFile);

      try
        PEFile.GetHijackableImportedDLL(ImportDLLs);

        // Check any import exists
        if (ImportDLLs.Count = 0) then
          Continue;

        // Rate the image for hijack
        HijackRate := PEFile.GetHijackRate(sedBestChoiceDLLCount.Value,
          sedBestChoiceExeSize.Value, sedGoodChoiceDLLCount.Value,
          sedGoodChoiceExeSize.Value);

        // Check abuse candidate based on user selected options
        if (CheckAbuseCandidateOption(HijackRate)) then
          Continue;

        // Check image type based on user selected options
        if (CheckImageTypeOption(PEFile.IsX86Image)) then
          Continue;

        // Scan signed applications or all applications
        IsSigned := Signature.IsCodeSigned;
        if (CheckImageSignOption(IsSigned)) then
          Continue;

        // Scan weak write permission dirs
        if (CheckWeakWritePermission(EachFile)) then
          Continue;

        // Add image to list
        App := tvApplication.Items.Add(nil, EachFile);

        FileSize := PEFile.GetFileSize;
        Scale := tvApplication.Items.AddChild(App, Format('File Size : %d KB',
          [FileSize]));
        Scale.ImageIndex := 1;
        Scale.SelectedIndex := Scale.ImageIndex;

        // Image type (x86, x64)
        if (PEFile.IsX86Image = true) then
          ImageTypeString := 'x86'
        else
          ImageTypeString := 'x64';

        ImageTypeNode := tvApplication.Items.AddChild(App,
          Format('ImageType : %s', [ImageTypeString]));
        ImageTypeNode.ImageIndex := 8;
        ImageTypeNode.SelectedIndex := ImageTypeNode.ImageIndex;

        // Add sign info to treeview
        SignerCompany := Signature.SignerCompany;
        if (Trim(SignerCompany) <> '') then
        begin
          Sign := tvApplication.Items.AddChild(App,
            Format('Sign by : %s', [SignerCompany]));
          Sign.ImageIndex := 7;
          Sign.SelectedIndex := Sign.ImageIndex;
        end;

        // Assign choice icon
        case HijackRate of
          hrBest:
            App.ImageIndex := 4;
          hrGood:
            App.ImageIndex := 5;
          hrBad:
            App.ImageIndex := 6;
        end;
        App.SelectedIndex := App.ImageIndex;

        // Check DLL is inside current application , if exists show it
        for DLLName in ImportDLLs do
          if (FileExists(ExtractFilePath(EachFile) + DLLName)) then
          begin
            DLLs := tvApplication.Items.AddChild(App, DLLName);
            DLLs.ImageIndex := 2;
            DLLs.SelectedIndex := DLLs.ImageIndex;

            Application.ProcessMessages;
          end;
      finally
        Signature.Free;
        ImportDLLs.Free;
        PEFile.Free;
      end;
    except
      // Handle any exception like AccessDenied here
    end;
    Application.ProcessMessages;
  end;
end;

procedure TfrmMain.ScanImportMethods;
var
  PEFile: TDLLHijack;
  Methods: TStringList;
  TreeViewIndex: Integer;
  EachDLL: Integer;
  DLLName, MethodName: string;
  Method: TTreeNode;
begin
  TreeViewIndex := 0;

  Methods := TStringList.Create;
  try
    for EachDLL := tvApplication.Items.Count - 1 downto 0 do
    begin
      DLLName := tvApplication.Items[EachDLL].Text;
      if (ExtractFileExt(DLLName) <> '.dll') then
        Continue
      else
      begin
        TreeViewIndex := EachDLL;
        tvApplication.Select(tvApplication.Items[TreeViewIndex]);

        PEFile := TDLLHijack.Create(tvApplication.Selected.Parent.Text);
        try
          PEFile.GetDLLMethods(DLLName, Methods);

          // List DLL names
          for MethodName in Methods do
          begin
            Method := tvApplication.Items.AddChild(tvApplication.Selected,
              MethodName);
            Method.ImageIndex := 3;
            Method.SelectedIndex := Method.ImageIndex;
          end;
        finally
          PEFile.Free;
        end;
      end;

      Application.ProcessMessages;
    end;
  finally
    Methods.Free;
  end;

  // Collapse all items
  CollapseALLItems();
end;

procedure TfrmMain.sedGoodChoiceDLLCountChange(Sender: TObject);
begin
  lblBadChoice.Caption := Format('DLL Count > %d , EXE Size > %d',
    [sedGoodChoiceDLLCount.Value, sedGoodChoiceExeSize.Value]);
end;

procedure TfrmMain.SetOptionControlsEnableState(EnableState: Boolean);
begin
  GOptions.Enabled := EnableState;

  // Clear last scan result to start new scan
  if (EnableState = False) then
  begin
    tvApplication.Items.BeginUpdate;
    try
      tvApplication.Items.Clear;
    finally
      tvApplication.Items.EndUpdate;
    end;
  end;
end;

procedure TfrmMain.CollapseALLItems;
var
  ItemCount: Integer;
begin
  for ItemCount := 0 to tvApplication.Items.Count - 1 do
    tvApplication.Items[ItemCount].Collapse(true);
end;

end.
