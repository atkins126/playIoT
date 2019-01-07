{ ******************************************************* }
{ }
{ NETPOD ������Ʈ }
{ }
{ Copyright (C) 2007 (��)����Ƽ�ƽ� }
{ by isul }
{ }
{ ******************************************************* }

unit Netpod;

interface

uses
  SysUtils, Classes, Windows, Forms, Messages, Registry, ProcessViewer;

const
  NETPOD_VERSION = '2.0.0.0'; // ������Ʈ ����
  // MAX_SIZE        = 1024 * 100 - 1;     // �� 17�� ���� ����
  MAX_SIZE = 640 * 100 - 1; // �� 10�� ���� ����
  SAMPLE_SIZE = 1024; // �� ���� ����� �ִ� ������ ũ��
  PODMNG = 'PODMNG.EXE';

type
  TChData = packed array [0 .. MAX_SIZE] of Single;
  PChData = ^TChData;

type
  TNetpod = class;
  TBeforeReceiveData = procedure(Sender: TObject) of Object;
  TBeforeReceiveChannelData = procedure(Sender: TObject; Channel: Integer) of Object;
  TAfterReceiveChannelData = procedure(Sender: TObject; Channel: Integer; Data: Pointer;
    SampleNo: Int64; SDate: string; SampleCount: Integer) of Object;
  // TAfterReceiveData = procedure(Sender: TObject; Data: Pointer; SampleNo: Int64; SDate: string) of Object;
  TAfterReceiveData = procedure(Sender: TObject; Data: Pointer) of Object;
  TOnError = procedure(Sender: TObject; ErrMsg: string) of Object;

  TChThread = class(TThread)
  private
    FPod: Integer;
    FChannel: Integer;
    FLength: Integer;
    procedure GetData;
  protected
    procedure Execute; override;
  public
    results: TChData;
    SampleNo: Int64;
    SDateTime: string;
    constructor Create(APod, AChannel, ALength: Integer);
    destructor Destroy; override;
  end;

  TNetpodCollectionItem = class(TCollectionItem)
  private
    FPod: Integer;
    FChannel: Integer;
    FSensorID: Integer;
    FChThread: TChThread;
    FTag: Int64;
    procedure SetPod(const Value: Integer);
    procedure SetChannel(const Value: Integer);
    procedure SetSensorID(const Value: Integer);
    procedure SetTag(const Value: Int64);
  public
    procedure AssignParameter(const APod, AChannel: Integer; ANetpod: TNetpod); virtual;
  published
    destructor Destroy; override;
    property Pod: Integer read FPod write SetPod;
    property Channel: Integer read FChannel write SetChannel;
    property SensorID: Integer read FSensorID write SetSensorID;
    property ChThread: TChThread read FChThread write FChThread;
    property Tag: Int64 read FTag write SetTag;
  end;

  TNetpodCollection = class(TCollection)
  protected
    function GetItem(Index: Integer): TNetpodCollectionItem; virtual;
    procedure SetItem(Index: Integer; Value: TNetpodCollectionItem); virtual;
  public
    constructor Create;
    function IndexOf(const APod, AChannel: Integer): Integer; virtual;
    function IndexOfSensor(const ASensorID: Integer): Integer; virtual;
    function Add: TNetpodCollectionItem;
    procedure AddParameter(const APod, AChannel: Integer; ANetpod: TNetpod);
    procedure DeleteParameter(const idx: Integer); overload;

    property Items[Index: Integer]: TNetpodCollectionItem read GetItem write SetItem;
  end;

  TNetpod = class(TComponent)
  private
    FItems: TNetpodCollection;
    FLength: Integer; // ��ü ������ ũ��(�м���)

    FLocked: Boolean;
    FUseThread: Boolean;
    FData: array of array of Single;
    FOnBeforeReceiveData: TBeforeReceiveData;
    FOnBeforeReceiveChannelData: TBeforeReceiveChannelData;
    FOnAfterReceiveChannelData: TAfterReceiveChannelData;
    FOnAfterReceiveData: TAfterReceiveData;
    FOnError: TOnError;
    FVersion: string;
    FOwner: TComponent;
    FLastSample: array of Int64; // ������ ���� ���� ��ȣ
    function SaveChannelData(const Channel: Integer; PResult: Pointer): Boolean; overload;
    function SaveChannelData(const Channel: Integer; PResult: Pointer; const Count: Integer)
      : Boolean; overload;
    procedure SetFLength(Value: Integer);
    procedure SetUseThread(const Value: Boolean);
    procedure SetVersion(const Value: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function ReceiveLastData: Boolean;
    function ReceiveNextData: Boolean;
    procedure Lock;
    procedure UnLock;
    procedure Scan;
    procedure RunPodMng;
    procedure Stop;
    procedure Run;
    function Scanned: Boolean;
    function IsRunning: Boolean;
    function IsCallback: Boolean;
    function GetBufferCount: Int64;
    procedure ManualScan;
    procedure ConnectNetpod(IP: string);
    procedure ConnectNDACS(IP: string);
    procedure ManualConnect(IsNetpod: Boolean; IP: string);
    procedure KillPodMng;
    procedure CopyItemsFrom(ANetpod: TNetpod);
    function GetAutoScanOnStartupPodmng: Boolean;
    procedure SetAutoScanOnStartupPodmng(const Value: Boolean);

    function PodList: TArray<Integer>;
  published
    property Items: TNetpodCollection read FItems write FItems;
    property Length: Integer read FLength write SetFLength default 1024;
    // property DataLength: Integer read FDataLength write SetFDataLength default 1024;
    property Locked: Boolean read FLocked default false;
    property UseThread: Boolean read FUseThread write SetUseThread default false;
    property Version: string read FVersion write SetVersion;

    property OnBeforeReceiveData: TBeforeReceiveData read FOnBeforeReceiveData
      write FOnBeforeReceiveData;
    property OnBeforeReceiveChannelData: TBeforeReceiveChannelData
      read FOnBeforeReceiveChannelData write FOnBeforeReceiveChannelData;
    property OnAfterReceiveChannelData: TAfterReceiveChannelData
      read FOnAfterReceiveChannelData write FOnAfterReceiveChannelData;
    property OnAfterReceiveData: TAfterReceiveData read FOnAfterReceiveData
      write FOnAfterReceiveData;
    property OnError: TOnError read FOnError write FOnError;
  end;

procedure DebugA(msg: string); overload;
procedure DebugA(const fmt: string; const Args: array of const); overload;

implementation

uses
  Dialogs, DllInc, ScanNetwork;

procedure DebugA(msg: string);
begin
  OutputDebugString(PChar('::TNetpod:: ' + msg));
end;

procedure DebugA(const fmt: string; const Args: array of const);
begin
  DebugA(Format(fmt, Args));
end;

{ TNetpodCollectionItem }

destructor TNetpodCollectionItem.Destroy;
begin
  if FChThread <> nil then
  begin
    FreeAndNil(FChThread);
    DebugA('TNetpod:: ä�� ������[%d-%d] ���� �Ϸ�', [Pod, Channel]);
  end;

  inherited;
end;

procedure TNetpodCollectionItem.AssignParameter(const APod, AChannel: Integer;
  ANetpod: TNetpod);
begin
  Pod := APod;
  Channel := AChannel;

  if ANetpod.UseThread then
  begin
    FChThread := TChThread.Create(APod, AChannel, ANetpod.Length);
    DebugA('TNetpod:: ä�� ������[%d-%d] ���� �Ϸ�', [APod, AChannel]);
  end;
end;

procedure TNetpodCollectionItem.SetPod(const Value: Integer);
begin
  if FPod <> Value then
    FPod := Value;
end;

procedure TNetpodCollectionItem.SetChannel(const Value: Integer);
begin
  if FChannel <> Value then
    FChannel := Value;
end;

procedure TNetpodCollectionItem.SetSensorID(const Value: Integer);
begin
  if FSensorID <> Value then
    FSensorID := Value;
end;

procedure TNetpodCollectionItem.SetTag(const Value: Int64);
begin
  if FTag <> Value then
    FTag := Value;
end;

{ TNetpodCollection }

function TNetpodCollection.Add: TNetpodCollectionItem;
begin
  Result := TNetpodCollectionItem(inherited Add);
end;

procedure TNetpodCollection.AddParameter(const APod, AChannel: Integer; ANetpod: TNetpod);
begin
  Add.AssignParameter(APod, AChannel, ANetpod);
end;

constructor TNetpodCollection.Create;
begin
  inherited Create(TNetpodCollectionItem);
end;

procedure TNetpodCollection.DeleteParameter(const idx: Integer);
begin
  Items[idx].Free;
end;

function TNetpodCollection.GetItem(Index: Integer): TNetpodCollectionItem;
begin
  Result := TNetpodCollectionItem(inherited GetItem(Index));
end;

function TNetpodCollection.IndexOf(const APod, AChannel: Integer): Integer;
begin
  for Result := 0 to Count - 1 do
    if (Items[Result].Pod = APod) and (Items[Result].Channel = AChannel) then
      exit;
  Result := -1;
end;

function TNetpodCollection.IndexOfSensor(const ASensorID: Integer): Integer;
begin
  for Result := 0 to Count - 1 do
    if Items[Result].SensorID = ASensorID then
      exit;
  Result := -1;
end;

procedure TNetpodCollection.SetItem(Index: Integer; Value: TNetpodCollectionItem);
begin
  inherited SetItem(Index, Value);
end;

{ TNetpod }

constructor TNetpod.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FOwner := AOwner;
  FItems := TNetpodCollection.Create;
  FLength := 1024; // �⺻�� ����(������Ÿ��)

  // FLastSample := 0;

  FLocked := false;
  FUseThread := false;
  FVersion := NETPOD_VERSION;
end;

destructor TNetpod.Destroy;
begin
  SetLength(FData, 0);
  FItems.Free;

  inherited;
end;

{ -------------------------------------------------------------------------
  ���� ������ ��� ����
  ------------------------------------------------------------------------- }
function TNetpod.ReceiveLastData: Boolean;
var
  i: Integer;
  Info: TBufParamStruct;
  // results: packed array[0..MAX_SIZE] of Single;
  results: TChData;
  Done: Boolean;
  stime: SYSTEMTIME;
  SDate: string;
  SampleNo: Int64;
begin
  Result := false;

  if FItems.Count = 0 then
    exit;

  if @FOnBeforeReceiveData <> nil then
    FOnBeforeReceiveData(Self); // ������ ����� �̺�Ʈ ȣ��

  try
    SetLength(FData, FItems.Count, FLength);

    // �� ä���� �����͸� ���
    for i := 0 to FItems.Count - 1 do
    begin
      if @FOnBeforeReceiveChannelData <> nil then
        FOnBeforeReceiveChannelData(Self, i); // �� ä�� ������ ����� �̺�Ʈ ȣ��

      if FUseThread then
        FItems.Items[i].ChThread.Resume // ������ ��� ������ ����
      else
      begin
        // ���� ���� �б�
        if NP_GetBufParam(FItems.Items[i].Pod, Info) > 0 then
          // Loop for as many channels there are in a specified Pod
          exit;

        SampleNo := Info.LatestSample - FLength;

        FileTimeToSystemTime(Info.LatestTime, stime);
        SDate := FormatDateTime('yyyy-mm-dd hh:nn:ss:zzz', SystemTimeToDateTime(stime) + 9 /
          24); // ǥ�ؽÿ� 9�ð� ����
        // SDate := inttostr(stime.wYear) + '-' + inttostr(stime.wMonth) + '-' + inttostr(stime.wDay) + ' ' + inttostr(stime.whour + 9) + ':' + inttostr(stime.wMinute) + ':' + inttostr(stime.wSecond) + ':' + inttostr(stime.wMilliseconds);

        // ä���� ������ �б�
        if NP_ChannelBufRead( // Read data
          FItems.Items[i].Pod, FItems.Items[i].Channel, NP_PROC, Info.LatestSample - FLength,
          // ���� �ֱ��� ������ FLength�� �б�
          FLength, @results) > 0 then
          exit;

        // DebugA('TNetpod:: Before FOnAfterReceiveChannelData: ' + FloatToStr(results[FLength - 1]);
        if @FOnAfterReceiveChannelData <> nil then
          FOnAfterReceiveChannelData(Self, i, @results, SampleNo, SDate, FLength);
        // ä�� ������ ��� �̺�Ʈ ȣ��

        // ��ü ä�� �迭�� �ش� ä���� ������ �ֱ�
        SaveChannelData(i, @results);
        Result := true;
      end;

      Application.ProcessMessages;
    end;

    if FUseThread then
    begin
      // ��� ä���� �����尡 �����͸� ��� �Ϸ��� ������ ��ٸ�
      Done := false;
      while not Done do
      begin
        Done := true;
        for i := 0 to FItems.Count - 1 do
          Done := Done and FItems.Items[i].ChThread.Suspended;
        Sleep(10);
        Application.ProcessMessages;
      end;

      SampleNo := FItems.Items[FItems.Count - 1].ChThread.SampleNo;
      SDate := FItems.Items[FItems.Count - 1].ChThread.SDateTime;

      // �� ä���� �����͸� �迭�� ����
      for i := 0 to FItems.Count - 1 do
        SaveChannelData(i, @FItems.Items[i].ChThread.results);
      Result := true;
    end;

    // ------------------------------------------------------------------------------
    // ��ü ������ ��� �Ϸ� �̺�Ʈ ȣ��
    // ------------------------------------------------------------------------------
    DebugA('TNetpod:: Before FOnAfterReceiveData');
    if @FOnAfterReceiveData <> nil then
      // FOnAfterReceiveData(Self, FData, SampleNo, SDate);                         // ��ü ������ ��� �̺�Ʈ ȣ��
      FOnAfterReceiveData(Self, FData); // ��ü ������ ��� �̺�Ʈ ȣ��
  finally
    SetLength(FData, 0, 0);
    SetLength(FData, 0);
  end;
end;

{ -------------------------------------------------------------------------
  ��ü ä�� �迭�� �ش� ä���� ������ �ֱ�
  ------------------------------------------------------------------------- }
function TNetpod.SaveChannelData(const Channel: Integer; PResult: Pointer): Boolean;
begin
  Result := true;

  try
    CopyMemory(FData[Channel], PResult, SizeOf(Single) * FLength);
    // CopyMemory(@FData[Channel][0], PResult, SizeOf(Single) * FLength);
  except
    on E: Exception do
    begin
      Result := false;
      if @FOnError <> nil then
        FOnError(Self, Format('SaveChannelData(Channel=%d; PResult) -> %s',
          [Channel, E.Message])); // ���� �̺�Ʈ ȣ��
    end;
  end;
end;

{ -------------------------------------------------------------------------------
  ���ν���: TNetpod.ReceiveNextData
  ��    ��: isul
  �� �� ��: 2007.09.20
  ��    ��: None
  ��    ��: Boolean
  ��    ��: ������ ���� ���� �����ͺ��� ������ �б�
  ------------------------------------------------------------------------------- }
function TNetpod.ReceiveNextData: Boolean;
var
  i: Integer;
  Info: TBufParamStruct;
  results: TChData;
  stime, ltime: SYSTEMTIME;
  SDate: string;
  { StartSample, } SampleCount: Int64;
begin
  Result := false;

  // ���ۿ� �� ���� ���� ũ�⺸�� �����Ͱ� ���� ������ ���
  if GetBufferCount < SAMPLE_SIZE then
    exit;

  if FItems.Count = 0 then
    exit;

  if @FOnBeforeReceiveData <> nil then
    FOnBeforeReceiveData(Self); // ������ ����� �̺�Ʈ ȣ��

  if High(FData) = -1 then
  begin
    DebugA('FData �޸� �Ҵ�');
    SetLength(FData, FItems.Count, FLength);

    // �迭 �ʱ�ȭ
    for i := 0 to FItems.Count - 1 do
      ZeroMemory(FData[i], SizeOf(FData[i]));
  end;

  if High(FLastSample) = -1 then
  begin
    DebugA('FLastSample �޸� �Ҵ� �� �ʱ�ȭ');
    SetLength(FLastSample, FItems.Count);
    for i := 0 to FItems.Count - 1 do
      FLastSample[i] := 0;
  end;

  Pid := 0;
  // �� ä���� �����͸� ���
  DebugA('FItems.Count: %d', [FItems.Count]);
  for i := 0 to FItems.Count - 1 do
  begin
    if @FOnBeforeReceiveChannelData <> nil then
      FOnBeforeReceiveChannelData(Self, i); // �� ä�� ������ ����� �̺�Ʈ ȣ��

    // ------------------------------------------------------------------------------
    // ���� ���� �б�
    // ------------------------------------------------------------------------------
    if NP_GetBufParam(FItems.Items[i].Pod, Info) > 0 then
      // Loop for as many channels there are in a specified Pod
      exit;

    // ������ ���ϱ�
    FileTimeToSystemTime(Info.LatestTime, stime);
    SDate := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', SystemTimeToDateTime(stime) + 9 / 24);
    // ǥ�ؽÿ� 9�ð� ����

    // ------------------------------------------------------------------------------
    // ä���� ������ �б�
    // ------------------------------------------------------------------------------
    if NP_ChannelBufRead( // Read data
      FItems.Items[i].Pod, FItems.Items[i].Channel, NP_PROC, Info.LatestSample - SAMPLE_SIZE,
      SAMPLE_SIZE, @results) > 0 then
      exit;

    // ------------------------------------------------------------------------------
    // ���� �����Ϳ��� ������ ������ �� ���ϱ�
    // ------------------------------------------------------------------------------
    if FLastSample[i] = 0 then
      SampleCount := SAMPLE_SIZE // �� ó������ ��ü ������ ����
    else
      SampleCount := (Info.LatestSample - FLastSample[i]);

    FLastSample[i] := Info.LatestSample;

    DebugA('%d-%d, SampleCount=%d, FLastSample=%d',
      [FItems.Items[i].Pod, FItems.Items[i].Channel, SampleCount, FLastSample[i]]);

    if SampleCount = 0 then
      Continue;

    // if i = 0 then
    // StartSample := Info.LatestSample - SampleCount;

    // ------------------------------------------------------------------------------
    // ä�� ������ ��� �̺�Ʈ ȣ�� (�ֱ� �����͸� ����)
    // ------------------------------------------------------------------------------
    if @FOnAfterReceiveChannelData <> nil then
    begin
      DebugA('TNetpod:: Before FOnAfterReceiveChannelData(%d): %.6f',
        [i, results[0 { SAMPLE_SIZE - 1 } ]]);
      FOnAfterReceiveChannelData(Self, i, @results[SAMPLE_SIZE - SampleCount],
        Info.LatestSample - SampleCount, SDate, SampleCount); // ä�� ������ ��� �̺�Ʈ ȣ��
    end;

    // ------------------------------------------------------------------------------
    // ��ü ä�� �迭�� �ش� ä���� ������ �ֱ�
    // ------------------------------------------------------------------------------
    SaveChannelData(i, @results[SAMPLE_SIZE - SampleCount], SampleCount);
    Result := true;

    Application.ProcessMessages;
  end;

  // ------------------------------------------------------------------------------
  // ��ü ������ ��� �Ϸ� �̺�Ʈ ȣ��
  // ------------------------------------------------------------------------------
  if (@FOnAfterReceiveData <> nil) then
  begin
    DebugA('Before FOnAfterReceiveData');
    // FOnAfterReceiveData(Self, FData, StartSample, SDate);                         // ��ü ������ ��� �̺�Ʈ ȣ��
    FOnAfterReceiveData(Self, FData); // ��ü ������ ��� �̺�Ʈ ȣ��
  end;
end;

{ -------------------------------------------------------------------------
  ��ü ä�� �迭�� �ش� ä���� ������ �ֱ�
  ------------------------------------------------------------------------- }
function TNetpod.SaveChannelData(const Channel: Integer; PResult: Pointer;
  const Count: Integer): Boolean;
begin
  // DebugA('TNetpod.SaveChannelData(Channel=%d; PResult, Count=%d)', [Channel, Count]);
  Result := true;
  if Count < 0 then
    exit;

  try
    // ������ Count��ŭ ������ �б�
    CopyMemory(@FData[Channel][0], @FData[Channel][Count], SizeOf(Single) * (FLength - Count));

    // �ڿ� ���ο� ������ ���̱�
    CopyMemory(@FData[Channel][FLength - Count], PResult, SizeOf(Single) * Count);
  except
    on E: Exception do
    begin
      Result := false;
      if @FOnError <> nil then
        FOnError(Self, Format('SaveChannelData(Channel=%d; PResult; Count=%d) -> %s',
          [Channel, Count, E.Message])); // ���� �̺�Ʈ ȣ��
    end;
  end;
end;

procedure TNetpod.Lock;
begin
  FLocked := true;
end;

procedure TNetpod.UnLock;
begin
  FLocked := false;
end;

procedure TNetpod.SetFLength(Value: Integer);
begin
  if Value > MAX_SIZE then
  begin
    FLength := MAX_SIZE;
    raise Exception.CreateFmt('���� �߻�: Length�� %d���� �۾ƾߵ˴ϴ�.', [MAX_SIZE]);
  end;

  FLength := Value;
end;

procedure TNetpod.SetUseThread(const Value: Boolean);
begin
  FUseThread := Value;
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
    NP_SetStatus(NP_RUNPODMNG);
end;

{ -------------------------------------------------------------------------
  ������ �˻��Ǿ����� ����
  ------------------------------------------------------------------------- }
function TNetpod.Scanned: Boolean;
begin
  // ���� �� podmng.exe�� ����Ǿ true�� ��ȯ��
  Result := (NP_GetStatus(NP_ISINITSCAN) <> 0);
end;

{ -------------------------------------------------------------------------
  ����Ŵ��� ���� ����
  ------------------------------------------------------------------------- }
function TNetpod.IsRunning: Boolean;
begin
  Result := (NP_GetStatus(NP_ISRUNNING) <> 0) and IsFileActive(UpperCase(PODMNG));
end;

function TNetpod.IsCallback: Boolean;
begin
  Result := NP_GetStatus(NP_ISCALLBACK) <> 0;
end;

{ -------------------------------------------------------------------------
  ���� ����
  ------------------------------------------------------------------------- }
procedure TNetpod.Run;
begin
  NP_SetStatus(NP_STARTRUN);
end;

{ -------------------------------------------------------------------------------
  ���� ����
  ------------------------------------------------------------------------------- }
procedure TNetpod.Stop;
begin
  NP_SetStatus(NP_STOPRUN);
end;

{ -------------------------------------------------------------------------------
  ���� : TNetpod.GetBufferCount
  �ۼ��� : isul
  �ۼ��� : 2007.06.20
  ����   : None
  ���   : Integer
  ����   : ����Ŵ����� ���ۼ� ���ϱ�
  ------------------------------------------------------------------------------- }
function TNetpod.GetBufferCount: Int64;
var
  Info: TBufParamStruct;
begin
  if FItems.Count = 0 then
    raise Exception.Create('no items');

  NP_GetBufParam(FItems.Items[0].Pod, Info);
  Result := Info.LatestSample - Info.StartSample;
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
procedure TNetpod.ManualConnect(IsNetpod: Boolean; IP: string);
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
    PostMessage(h, WM_COMMAND, 22, 0); // spy++�� ����Ŵ����� �޴� Ŭ���ؼ� ã�Ƴ���^^
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
  ManualConnect(true, IP);
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
  SetLength(Result, 100);
  NP_GetPodList(Result);
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
  ���� : TNetpod.CopyItemsFrom
  �ۼ��� : isul
  �ۼ��� : 2007.08.03
  ����   : ANetpodCollection: TNetpodCollection
  ���   : None
  ����   : ������ ����
  ------------------------------------------------------------------------------- }
procedure TNetpod.CopyItemsFrom(ANetpod: TNetpod);
var
  i: Integer;
begin
  Self.Items.Clear;
  for i := 0 to ANetpod.Items.Count - 1 do
    with ANetpod.Items.Items[i] do
    begin
      Self.Items.AddParameter(Pod, Channel, ANetpod);
      Self.Items.Items[i].FSensorID := SensorID;
    end;
end;

{ -------------------------------------------------------------------------------
  ���ν���: TNetpod.GetAutoScanOnStartup
  ��    ��: isul
  �� �� ��: 2007.09.20
  ��    ��: None
  ��    ��: Boolean
  ��    ��: ����Ŵ��� ���۽� �ڵ����� ��ĵ���� �����Ǿ� �ִ��� �˻�
  ------------------------------------------------------------------------------- }
function TNetpod.GetAutoScanOnStartupPodmng: Boolean;
var
  reg: TRegistry;
  sl: TStringList;
  i: Integer;
begin
  Result := false;

  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.LazyWrite := false;
    reg.OpenKey('Software\NetPod\InitCommands', true);
    sl := TStringList.Create;
    reg.GetValueNames(sl);
    for i := 0 to sl.Count - 1 do
      if reg.ReadString(sl.Strings[i]) = 'SCANNET D' then
      begin
        Result := true;
        exit;
      end;
  finally
    sl.Free;
    reg.CloseKey;
    reg.Free;
  end;
end;

{ -------------------------------------------------------------------------------
  ���ν���: TNetpod.SetAutoScanOnStartup
  ��    ��: isul
  �� �� ��: 2007.09.20
  ��    ��: const Value: Boolean
  ��    ��: None
  ��    ��: ����Ŵ��� ���۽� �ڵ����� ��ĵ�ϵ��� ����
  ------------------------------------------------------------------------------- }
procedure TNetpod.SetAutoScanOnStartupPodmng(const Value: Boolean);
var
  reg: TRegistry;
  sl: TStringList;
  i: Integer;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.LazyWrite := false;
    reg.OpenKey('Software\NetPod\InitCommands', true);
    sl := TStringList.Create;
    reg.GetValueNames(sl);
    i := 0;
    for i := 0 to sl.Count - 1 do
      if reg.ReadString(sl.Strings[i]) = 'SCANNET D' then
        exit;

    if Value then
      reg.WriteString('Command' + IntToStr(i), 'SCANNET D');
  finally
    sl.Free;
    reg.CloseKey;
    reg.Free;
  end;
end;

{ TChThread }

constructor TChThread.Create(APod, AChannel, ALength: Integer);
begin
  inherited Create(true);

  FPod := APod;
  FChannel := AChannel;
  FLength := ALength;
end;

destructor TChThread.Destroy;
begin

  inherited;
end;

procedure TChThread.Execute;
begin
  inherited;

  while not Terminated do
  begin
    GetData;
    Suspend;
    WaitForSingleObject(Handle, 100);
  end;
end;

procedure TChThread.GetData;
var
  Info: TBufParamStruct;
  stime: SYSTEMTIME;
begin
  NP_GetBufParam(FPod, Info);

  SampleNo := Info.LatestSample;
  FileTimeToSystemTime(Info.LatestTime, stime);
  SDateTime := FormatDateTime('yyyy-mm-dd hh:nn:ss:zzz', SystemTimeToDateTime(stime) + 9 / 24);
  // ǥ�ؽÿ� 9�ð� ����
  // SDateTime := inttostr(stime.wYear) + '-' + inttostr(stime.wMonth) + '-' + inttostr(stime.wDay) + ' ' + inttostr(stime.whour + 9) + ':' + inttostr(stime.wMinute) + ':' + inttostr(stime.wSecond) + ':' + inttostr(stime.wMilliseconds);

  NP_ChannelBufRead( // Read data
    FPod, FChannel, NP_PROC, Info.LatestSample - FLength, FLength, @results);
end;

end.
