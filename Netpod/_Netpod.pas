{ ******************************************************* }
{ }
{ NETPOD ������Ʈ }
{ }
{ Copyright (C) 2019 playIoT }
{ by jsf3rd }
{ }
{ ******************************************************* }

unit _Netpod;

interface

uses
  SysUtils, Classes, Windows, Messages, Registry, ProcessViewer,
  System.Generics.Collections, Math, DllInc, System.DateUtils;

const
  NETPOD_VERSION = '2.1.0.0'; // ������Ʈ ����
  PODMNG = 'PODMNG.EXE';

type
  TPodData = array of array of Single;

  TNetPod = class;
  TBeforeReceiveData = procedure(Sender: TObject; const Pid: Integer) of Object;
  TAfterReceiveData = procedure(Sender: TObject; const Pid: Integer; const SDate: TDateTime;
    const Data: TPodData; const SampleCount: Integer; var Accept: boolean) of Object;
  TOnLog = procedure(Sender: TObject; AType: string; AMsg: string) of Object;

  TNetPod = class(TComponent)
  private
    FDLLHandle: THandle;

    FVersion: string;
    FOwner: TComponent;
    FLastSample: TDictionary<Integer, Int64>; // ������ ���� ���� ��ȣ

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
    procedure ScanNet;
    function Scanned: boolean;
    function IsRunning: boolean;
    function IsCallback: boolean;
    procedure ManualScan;
    procedure ConnectNetpod(IP: string);
    procedure ConnectNDACS(IP: string);
    procedure ManualConnect(IsNetpod: boolean; IP: string);
    function IsAlivePodMng: boolean;
    procedure KillPodMng;

    function GetInitCommand(const Index: Integer): String;
    procedure SetInitCommand(const Index: Integer; const Value: String);

    function GetAccess: string;
    procedure SetAccess(const Value: string);

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

constructor TNetPod.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FOwner := AOwner;
  FLastSample := TDictionary<Integer, Int64>.Create;

  FLocked := false;
  FVersion := NETPOD_VERSION;
  FSampleRate := 100;

  LoadDLL;
end;

destructor TNetPod.Destroy;
begin
  FreeDLL;
  inherited;
end;

procedure TNetPod.FreeDLL;
begin
  if FDLLHandle <> 0 then
  begin
    try
      FreeLibrary(FDLLHandle);
      FDLLHandle := 0;
    except
      on E: Exception do
    end;
  end;
end;

function TNetPod.GetBufInfo(Pid: Integer): TBufParamStruct;
begin
  FNP_GetBufParam(Pid, result);
end;

function TNetPod.GetInitCommand(const Index: Integer): String;
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.LazyWrite := false;
    reg.OpenKey('Software\NetPod\InitCommands', True);
    result := reg.ReadString('Command' + Index.ToString);
  finally
    reg.CloseKey;
    reg.Free;
  end;
end;

{ -------------------------------------------------------------------------
  ���� ������ ��� ����
  ------------------------------------------------------------------------- }
procedure TNetPod.ReceiveManual(Pid, ChCount: Integer; DateTime: TDateTime; LateSample: Int64;
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

procedure TNetPod.ReceiveNextData(Pid: Integer; Count: Integer);

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
  if Count = 0 then
  begin
    _OnLog('WARNING', 'No Channel');
    exit;
  end;

  // ------------------------------------------------------------------------------
  // ���� ���� �б�
  // ------------------------------------------------------------------------------
  rlt := FNP_GetBufParam(Pid, Info);
  if rlt > 0 then
  begin
    _OnLog('ERROR', 'FNP_GetBufParam=' + rlt.ToString + ',' + Info.ToString);
    exit;
  end;

  if FLastSample.ContainsKey(Pid) then
  begin
    SampleCount := Info.LatestSample - FLastSample.Items[Pid];
    SampleCount := Min(SampleCount, Info.TotalCount);
  end
  else
  begin
    SampleCount := Min(Info.TotalCount, HexTimesValue(FSampleRate));
    FLastSample.Add(Pid, Info.LatestSample - SampleCount);
  end;

  if (SampleCount mod 16) <> 0 then
    SampleCount := Min(Info.TotalCount, HexTimesValue(SampleCount));

  // _OnLog('DEBUG', Format('Pid=%d,Count=%d,Info=%s', [Pid, SampleCount, Info.ToString]));

  if SampleCount = 0 then
    exit;

  try
    // �迭 �ʱ�ȭ
    SetLength(Data, Count, SampleCount);
    for i := 0 to Count - 1 do
      ZeroMemory(Data[i], SizeOf(Data[i]));
  except
    on E: Exception do
    begin
      FLastSample.Items[Pid] := 0;
      raise Exception.Create(Format('E=%s,Pid=%d,SampleCount=%d,LastSample=%d,Info=%s',
        [E.Message, Pid, SampleCount, FLastSample.Items[Pid], Info.ToString]));
    end;
  end;

  // ������ ����� �̺�Ʈ ȣ��
  if @FOnBeforeReceiveData <> nil then
    FOnBeforeReceiveData(Self, Pid);

  // �� ä���� �����͸� ���
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
    FLastSample.Items[Pid] := Info.LatestSample
  else
    _OnLog('DEBUG', 'Denyed, ' + Info.LatestDateTimeStr);
end;

procedure TNetPod.LoadDLL;
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

procedure TNetPod.Lock;
begin
  FLocked := True;
end;

procedure TNetPod.UnLock;
begin
  FLocked := false;
end;

procedure TNetPod._OnLog(AType, AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, AType, AMsg);
end;

{ -------------------------------------------------------------------------
  ��Ʈ��ũ���� ������ �˻�
  ------------------------------------------------------------------------- }
procedure TNetPod.Scan;
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
procedure TNetPod.RunPodMng;
var
  rlt: Integer;
begin
  if not IsRunning then
  begin
    rlt := FNP_SetStatus(NP_RUNPODMNG);
    _OnLog('DEBUG', 'NP_RUNPODMNG=' + rlt.ToString);
  end;
end;

{ -------------------------------------------------------------------------
  ������ �˻��Ǿ����� ����
  ------------------------------------------------------------------------- }
function TNetPod.Scanned: boolean;
begin
  // ���� �� podmng.exe�� ����Ǿ true�� ��ȯ��
  result := (FNP_GetStatus(NP_ISINITSCAN) <> 0);
end;

procedure TNetPod.ScanNet;
var
  rlt: Integer;
begin
  rlt := FNP_SetStatus(NP_SCANNET);
  _OnLog('DEBUG', 'NP_SCANNET=' + rlt.ToString);
end;

{ -------------------------------------------------------------------------
  ����Ŵ��� ���� ����
  ------------------------------------------------------------------------- }
function TNetPod.IsRunning: boolean;
var
  rlt: Integer;
begin
  rlt := FNP_GetStatus(NP_ISRUNNING);
  result := rlt <> 0;
  // _OnLog('DEBUG', 'NP_ISRUNNING=' + rlt.ToString);
end;

function TNetPod.IsAlivePodMng: boolean;
begin
  result := IsFileActive(UpperCase(PODMNG));
end;

function TNetPod.IsCallback: boolean;
begin
  result := FNP_GetStatus(NP_ISCALLBACK) <> 0;
end;

{ -------------------------------------------------------------------------
  ���� ����
  ------------------------------------------------------------------------- }
procedure TNetPod.Run;
var
  rlt: Integer;
begin
  rlt := FNP_SetStatus(NP_STARTRUN);
  _OnLog('DEBUG', 'NP_STARTRUN=' + rlt.ToString);
end;

{ -------------------------------------------------------------------------------
  ���� ����
  ------------------------------------------------------------------------------- }
procedure TNetPod.Stop;
var
  rlt: Integer;
begin
  rlt := FNP_SetStatus(NP_STOPRUN);
  _OnLog('DEBUG', 'NP_STOPRUN=' + rlt.ToString);
end;

procedure TNetPod.SetVersion(const Value: string);
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
procedure TNetPod.ManualConnect(IsNetpod: boolean; IP: string);
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
procedure TNetPod.ConnectNDACS(IP: string);
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
procedure TNetPod.ConnectNetpod(IP: string);
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
procedure TNetPod.ManualScan;
var
  h: HWND;
begin
  h := FindWindow(nil, 'NetPod Configuration');

  if h = 0 then
    exit;

  PostMessage(h, WM_COMMAND, 18, 0); // spy++�� ã����^^
end;

function TNetPod.PodList: TArray<Integer>;
var
  _List: TArray<Integer>;
  MyElem: Integer;
begin
  SetLength(_List, 100);
  FNP_GetPodList(_List);

  SetLength(result, 0);
  for MyElem in _List do
  begin
    if MyElem > 0 then
      result := result + [MyElem]
  end;

end;

{ -------------------------------------------------------------------------------
  ���� : TNetpod.KillPodMng
  �ۼ��� : isul
  �ۼ��� : 2007.06.19
  ����   : None
  ���   : None
  ����   : ���� �Ŵ��� ���� ����
  ------------------------------------------------------------------------------- }
procedure TNetPod.KillPodMng;
var
  h: HWND;
begin
  h := FindWindow('PodMngClass', 'Pod Manager');
  if h = 0 then
    exit;

  if Self.IsRunning then
    Self.Stop;

  _OnLog('DEBUG', 'KillPodMng - WM_CLOSE');
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
function TNetPod.GetAccess: string;
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.LazyWrite := false;
    reg.OpenKey('Software\NetPod', True);
    result := reg.ReadString('Access');
  finally
    reg.CloseKey;
    reg.Free;
  end;
end;

function TNetPod.GetStatus(stat: Integer): Integer;
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
procedure TNetPod.SetAccess(const Value: string);
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.LazyWrite := false;
    reg.OpenKey('Software\NetPod', True);
    reg.WriteString('Access', Value);
  finally
    reg.CloseKey;
    reg.Free;
  end;

end;

procedure TNetPod.SetInitCommand(const Index: Integer; const Value: String);
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.LazyWrite := false;
    reg.OpenKey('Software\NetPod\InitCommands', True);
    reg.WriteString('Command' + Index.ToString, Value);
  finally
    reg.CloseKey;
    reg.Free;
  end;
end;

function TNetPod.SetStatus(stat: Integer): Integer;
begin
  result := FNP_SetStatus(stat);
end;

end.
