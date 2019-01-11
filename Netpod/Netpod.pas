{ ******************************************************* }
{ }
{ NETPOD ������Ʈ }
{ }
{ Copyright (C) 2019 playIoT }
{ by jsf3rd }
{ }
{ ******************************************************* }

unit Netpod;

interface

uses
  SysUtils, Classes, Windows, Messages, Registry, ProcessViewer,
  System.Generics.Collections, Math, DllInc, System.DateUtils;

const
  NETPOD_VERSION = '2.1.0.0'; // ������Ʈ ����
  PODMNG = 'PODMNG.EXE';

type
  TPodData = array of array of Single;

  TNetpod = class;
  TBeforeReceiveData = procedure(Sender: TObject; const Pid: Integer) of Object;
  TAfterReceiveData = procedure(Sender: TObject; const Pid: Integer; const SDate: TDateTime;
    const Data: TPodData; const SampleCount: Integer; var Accept: boolean) of Object;
  TOnLog = procedure(Sender: TObject; AType: string; AMsg: string) of Object;

  TNetpod = class(TComponent)
  private
    FDLLHandle: THandle;

    FVersion: string;
    FOwner: TComponent;
    FLatestSample: TDictionary<Integer, Int64>; // ������ ���� ���� ��ȣ

    FNP_GetStatus: TNP_GetStatus;
    FNP_SetStatus: TNP_SetStatus;
    FNP_GetPodInfo: TNP_GetPodInfo;
    FNP_GetChannelInfo: TNP_GetChannelInfo;
    FNP_GetPodList: TNP_GetPodList;
    FNP_ChannelBufRead: TNP_ChannelBufRead;
    FNP_GetBufParam: TNP_GetBufParam;

    FLocked: boolean;
    FSampleRate: Integer;
    FOnBeforeReceiveData: TBeforeReceiveData;
    FOnAfterReceiveData: TAfterReceiveData;
    FOnLog: TOnLog;

    procedure SetVersion(const Value: string);

    procedure LoadDLL;
    procedure FreeDLL;

    procedure _OnLog(AType: string; AMsg: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ReceiveNextData(Pid: Integer; Count: Integer);
    procedure ReceiveManual(Pid, ChCount: Integer; DateTime: TDateTime; LateSample: Int64;
      SampleCount: Integer);
    function GetBufInfo(Pid: Integer): TBufParamStruct;

    procedure Lock;
    procedure UnLock;
    procedure Scan;
    procedure RunPodMng;
    procedure Stop;
    procedure Run;
    function Scanned: boolean;
    function IsRunning: boolean;
    function IsCallback: boolean;
    procedure ManualScan;
    procedure ConnectNetpod(IP: string);
    procedure ConnectNDACS(IP: string);
    procedure ManualConnect(IsNetpod: boolean; IP: string);
    procedure KillPodMng;
    function GetAutoScanOnStartupPodmng: boolean;
    procedure SetAutoScanOnStartupPodmng(const Value: boolean);
    function SetStatus(stat: Integer): Integer;
    function GetStatus(stat: Integer): Integer;

    function PodList: TArray<Integer>;

  published
    property Locked: boolean read FLocked default false;
    property Version: string read FVersion write SetVersion;
    property SampleRate: Integer read FSampleRate write FSampleRate;

    property OnBeforeReceiveData: TBeforeReceiveData read FOnBeforeReceiveData
      write FOnBeforeReceiveData;
    property OnAfterReceiveData: TAfterReceiveData read FOnAfterReceiveData
      write FOnAfterReceiveData;
    property OnLog: TOnLog read FOnLog write FOnLog;

  end;

implementation

uses
  Dialogs, ScanNetwork;

{ TNetpod }

constructor TNetpod.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FOwner := AOwner;
  FLatestSample := TDictionary<Integer, Int64>.Create;

  FLocked := false;
  FVersion := NETPOD_VERSION;
  FSampleRate := 100;

  LoadDLL;
end;

destructor TNetpod.Destroy;
begin
  FreeDLL;

  inherited;
end;

procedure TNetpod.FreeDLL;
begin
  if FDLLHandle <> 0 then
  begin
    try
      FDLLHandle := 0;
    except
      on E: Exception do
    end;
  end;
end;

function TNetpod.GetBufInfo(Pid: Integer): TBufParamStruct;
begin
  FNP_GetBufParam(Pid, result);
end;

{ -------------------------------------------------------------------------
  ���� ������ ��� ����
  ------------------------------------------------------------------------- }
procedure TNetpod.ReceiveManual(Pid, ChCount: Integer; DateTime: TDateTime; LateSample: Int64;
  SampleCount: Integer);
var
  i, rlt: Integer;
  Data: TPodData;
  Accept: boolean;
begin
  SetLength(Data, ChCount, SampleCount);

  for i := 0 to ChCount - 1 do
  begin
    // ------------------------------------------------------------------------------
    // ä���� ������ �б�
    // ------------------------------------------------------------------------------
    rlt := FNP_ChannelBufRead( // Read data
      Pid, i, NP_PROC, LateSample - SampleCount, SampleCount, Data[i]);
    if rlt > 0 then
      exit;
  end;

  // ------------------------------------------------------------------------------
  // ��ü ������ ��� �Ϸ� �̺�Ʈ ȣ��
  // ------------------------------------------------------------------------------
  if Assigned(@FOnAfterReceiveData) then
    FOnAfterReceiveData(Self, Pid, DateTime, Data, SampleCount, Accept);
end;

procedure TNetpod.ReceiveNextData(Pid: Integer; Count: Integer);

  function HexTimesValue(Value: Int64): Int64; // ���� ����� 16�� ���
  begin
    result := ((Value div 16) + 1) * 16;
  end;

var
  i: Integer;
  Info: TBufParamStruct;
  SampleCount: Int64;
  Data: TPodData;
  rlt: Integer;

  Accept: boolean;
begin
  // result := false;

  if Count = 0 then
  begin
    _OnLog('WARNING', 'No Channel');
    exit;
  end;

  // ------------------------------------------------------------------------------
  // ���� ���� �б�
  // ------------------------------------------------------------------------------
  FNP_GetBufParam(Pid, Info);
  {
    if rlt > 0 then
    begin
    _OnLog('ERROR', 'FNP_GetBufParam=' + rlt.ToString+','+Info.ToString);
    exit;
    end;
  }
  _OnLog('ERROR', 'FNP_GetBufParam=' + Info.ToString);

  if FLatestSample.ContainsKey(Pid) then
    SampleCount := Info.LatestSample - FLatestSample.Items[Pid]
  else
  begin
    FLatestSample.Add(Pid, Info.LatestSample - HexTimesValue(FSampleRate));
    SampleCount := Min(Info.SampleCount, HexTimesValue(FSampleRate));
  end;

  if (SampleCount mod 16) <> 0 then
    SampleCount := Min(Info.SampleCount, HexTimesValue(SampleCount));

  if SampleCount = 0 then
    exit;

  SetLength(Data, Count, SampleCount);
  // �迭 �ʱ�ȭ
  for i := 0 to Count - 1 do
    ZeroMemory(Data[i], SizeOf(Data[i]));

  // ������ ����� �̺�Ʈ ȣ��
  if @FOnBeforeReceiveData <> nil then
    FOnBeforeReceiveData(Self, Pid);

  // �� ä���� �����͸� ���
  _OnLog('DEBUG', Format('Pid=%d,Latest=%d,Count=%d,Date=%s', [Pid, Info.LatestSample,
    SampleCount, Info.LatestDateTimeStr]));

  for i := 0 to Count - 1 do
  begin
    // ------------------------------------------------------------------------------
    // ä���� ������ �б�
    // ------------------------------------------------------------------------------
    rlt := FNP_ChannelBufRead( // Read data
      Pid, i, NP_PROC, Info.LatestSample - SampleCount, SampleCount, Data[i]);
    if rlt > 0 then
    begin
      _OnLog('ERROR', 'FNP_ChannelBufRead=' + rlt.ToString);
      exit;
    end;
  end;

  // ------------------------------------------------------------------------------
  // ��ü ������ ��� �Ϸ� �̺�Ʈ ȣ��
  // ------------------------------------------------------------------------------
  if Assigned(@FOnAfterReceiveData) then
    FOnAfterReceiveData(Self, Pid, Info.LatestDateTime, Data, SampleCount, Accept);
  // ��ü ������ ��� �̺�Ʈ ȣ��

  if Accept then
    FLatestSample.Items[Pid] := Info.LatestSample
  else
    _OnLog('ERROR', 'Denyed, ' + Info.LatestDateTimeStr);
end;

procedure TNetpod.LoadDLL;
begin
  FDLLHandle := LoadLibrary(NETPOD_DLL);
  if FDLLHandle < 32 then
    raise Exception.Create('Load DLL Exception');

  @FNP_GetStatus := GetProcAddress(FDLLHandle, 'NP_GetStatus');
  @FNP_SetStatus := GetProcAddress(FDLLHandle, 'NP_SetStatus');
  @FNP_GetPodInfo := GetProcAddress(FDLLHandle, 'NP_GetPodInfo');
  @FNP_GetChannelInfo := GetProcAddress(FDLLHandle, 'NP_GetChannelInfo');
  @FNP_GetPodList := GetProcAddress(FDLLHandle, 'NP_GetPodList');
  @FNP_ChannelBufRead := GetProcAddress(FDLLHandle, 'NP_ChannelBufRead');
  @FNP_GetBufParam := GetProcAddress(FDLLHandle, 'NP_GetBufParam');
end;

procedure TNetpod.Lock;
begin
  FLocked := True;
end;

procedure TNetpod.UnLock;
begin
  FLocked := false;
end;

procedure TNetpod._OnLog(AType, AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, AType, AMsg);
end;

{ -------------------------------------------------------------------------
  ��Ʈ��ũ���� ������ �˻�
  ------------------------------------------------------------------------- }
procedure TNetpod.Scan;
begin
  frmScanNetwork := TfrmScanNetwork.Create(Self);
  try
    frmScanNetwork.ShowModal;
  finally
    if Assigned(frmScanNetwork) then
      frmScanNetwork.Free;
  end;
end;

{ -------------------------------------------------------------------------
  ����Ŵ��� ����
  ------------------------------------------------------------------------- }
procedure TNetpod.RunPodMng;
begin
  if not IsRunning then
    FNP_SetStatus(NP_RUNPODMNG);
end;

{ -------------------------------------------------------------------------
  ������ �˻��Ǿ����� ����
  ------------------------------------------------------------------------- }
function TNetpod.Scanned: boolean;
begin
  // ���� �� podmng.exe�� ����Ǿ true�� ��ȯ��
  result := (FNP_GetStatus(NP_ISINITSCAN) <> 0);
end;

{ -------------------------------------------------------------------------
  ����Ŵ��� ���� ����
  ------------------------------------------------------------------------- }
function TNetpod.IsRunning: boolean;
begin
  result := (FNP_GetStatus(NP_ISRUNNING) <> 0) and IsFileActive(UpperCase(PODMNG));
end;

function TNetpod.IsCallback: boolean;
begin
  result := FNP_GetStatus(NP_ISCALLBACK) <> 0;
end;

{ -------------------------------------------------------------------------
  ���� ����
  ------------------------------------------------------------------------- }
procedure TNetpod.Run;
begin
  FNP_SetStatus(NP_STARTRUN);
end;

{ -------------------------------------------------------------------------------
  ���� ����
  ------------------------------------------------------------------------------- }
procedure TNetpod.Stop;
begin
  FNP_SetStatus(NP_STOPRUN);
end;

procedure TNetpod.SetVersion(const Value: string);
begin
end;

{ -------------------------------------------------------------------------------
  ���� : TNetpod.ConnectNDACS
  �ۼ��� : isul
  �ۼ��� : 2007.06.19
  ����   : IP: string
  ���   : None
  ����   : ����Ŵ����� �̿��Ͽ� Netpod �Ǵ� NDACS�� IP�� �����ϱ�
  ------------------------------------------------------------------------------- }
procedure TNetpod.ManualConnect(IsNetpod: boolean; IP: string);
var
  h, c: HWND;
begin
  // ------------------------------------------------------------------------------
  // �⺻ ���� â ã��
  // ------------------------------------------------------------------------------
  h := FindWindow(nil, 'NetPod Configuration');

  if h = 0 then
    exit;

  // ------------------------------------------------------------------------------
  // IP�� �����ϴ� â ����
  // ------------------------------------------------------------------------------
  if IsNetpod then
  begin
    PostMessage(h, WM_COMMAND, 22, 0);
    // spy++�� ����Ŵ����� �޴� Ŭ���ؼ� ã�Ƴ���^^
    Sleep(300);
    h := FindWindow(nil, 'ConHost');
  end
  else
  begin
    PostMessage(h, WM_COMMAND, 23, 0); // spy++�� ����Ŵ����� �޴� Ŭ���ؼ� ã�Ƴ���^^
    Sleep(300);
    h := FindWindow(nil, 'Connect to Instrument');
  end;

  // ------------------------------------------------------------------------------
  // ������ �Է�
  // ------------------------------------------------------------------------------
  c := FindWindowEx(h, 0, 'TEdit', nil);
  if c = 0 then
    exit;

  SendMessage(c, WM_SETTEXT, 0, LongInt(PChar(IP)));

  // ------------------------------------------------------------------------------
  // Ȯ�� ��ư Ŭ��
  // ------------------------------------------------------------------------------
  Sleep(100);

  c := FindWindowEx(h, 0, 'TButton', 'Connect');
  if c = 0 then
    exit;

  PostMessage(c, WM_LBUTTONDOWN, 10, 10);
  Sleep(100);
  PostMessage(c, WM_LBUTTONUP, 10, 10);
end;

{ -------------------------------------------------------------------------------
  ���� : TNetpod.ConnectNDACS
  �ۼ��� : isul
  �ۼ��� : 2007.06.19
  ����   : IP: string
  ���   : None
  ����   : ����Ŵ����� �̿��Ͽ� NDACS�� IP�� �����ϱ�
  ------------------------------------------------------------------------------- }
procedure TNetpod.ConnectNDACS(IP: string);
begin
  ManualConnect(false, IP);
end;

{ -------------------------------------------------------------------------------
  ���� : TNetpod.ConnectNDACS
  �ۼ��� : isul
  �ۼ��� : 2007.06.19
  ����   : IP: string
  ���   : None
  ����   : ����Ŵ����� �̿��Ͽ� Netpod�� IP�� �����ϱ�
  ------------------------------------------------------------------------------- }
procedure TNetpod.ConnectNetpod(IP: string);
begin
  ManualConnect(True, IP);
end;

{ -------------------------------------------------------------------------------
  ���� : TNetpod.ManualScan
  �ۼ��� : isul
  �ۼ��� : 2007.06.19
  ����   : None
  ���   : None
  ����   : ����Ŵ����� �̿��� ������ ��ĵ
  ------------------------------------------------------------------------------- }
procedure TNetpod.ManualScan;
var
  h: HWND;
begin
  h := FindWindow(nil, 'NetPod Configuration');

  if h = 0 then
    exit;

  PostMessage(h, WM_COMMAND, 18, 0); // spy++�� ã����^^
end;

function TNetpod.PodList: TArray<Integer>;
begin
  SetLength(result, 100);
  FNP_GetPodList(result);
end;

{ -------------------------------------------------------------------------------
  ���� : TNetpod.KillPodMng
  �ۼ��� : isul
  �ۼ��� : 2007.06.19
  ����   : None
  ���   : None
  ����   : ���� �Ŵ��� ���� ����
  ------------------------------------------------------------------------------- }
procedure TNetpod.KillPodMng;
var
  h: HWND;
begin
  {
    if FOwner is TForm then
    begin

    h := FindWindow(nil, PChar((FOwner as TForm).Caption));
    if h <> 0 then
    PostMessage(h, WM_QUIT, 0, 0);
    end;
  }

  h := FindWindow('PodMngClass', 'Pod Manager');
  if h = 0 then
    exit;

  PostMessage(h, WM_CLOSE, 0, 0);
  PostMessage(h, WM_QUIT, 0, 0);
end;

{ -------------------------------------------------------------------------------
  ���ν���: TNetpod.GetAutoScanOnStartup
  ��    ��: isul
  �� �� ��: 2007.09.20
  ��    ��: None
  ��    ��: Boolean
  ��    ��: ����Ŵ��� ���۽� �ڵ����� ��ĵ���� �����Ǿ� �ִ��� �˻�
  ------------------------------------------------------------------------------- }
function TNetpod.GetAutoScanOnStartupPodmng: boolean;
var
  reg: TRegistry;
  sl: TStringList;
  i: Integer;
begin
  result := false;

  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.LazyWrite := false;
    reg.OpenKey('Software\NetPod\InitCommands', True);
    sl := TStringList.Create;
    reg.GetValueNames(sl);
    for i := 0 to sl.Count - 1 do
      if reg.ReadString(sl.Strings[i]) = 'SCANNET D' then
      begin
        result := True;
        exit;
      end;
    sl.Free;
  finally
    reg.CloseKey;
    reg.Free;
  end;
end;

function TNetpod.GetStatus(stat: Integer): Integer;
begin
  result := FNP_GetStatus(stat);
end;

{ -------------------------------------------------------------------------------
  ���ν���: TNetpod.SetAutoScanOnStartup
  ��    ��: isul
  �� �� ��: 2007.09.20
  ��    ��: const Value: Boolean
  ��    ��: None
  ��    ��: ����Ŵ��� ���۽� �ڵ����� ��ĵ�ϵ��� ����
  ------------------------------------------------------------------------------- }
procedure TNetpod.SetAutoScanOnStartupPodmng(const Value: boolean);
var
  reg: TRegistry;
  sl: TStringList;
  i: Integer;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.LazyWrite := false;
    reg.OpenKey('Software\NetPod\InitCommands', True);
    sl := TStringList.Create;
    reg.GetValueNames(sl);
    for i := 0 to sl.Count - 1 do
      if reg.ReadString(sl.Strings[i]) = 'SCANNET D' then
        exit;

    if Value then
      reg.WriteString('Command' + IntToStr(sl.Count), 'SCANNET D');
    sl.Free;
  finally
    reg.CloseKey;
    reg.Free;
  end;
end;

function TNetpod.SetStatus(stat: Integer): Integer;
begin
  result := FNP_SetStatus(stat);
end;

end.
