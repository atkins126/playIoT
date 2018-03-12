// *******************************************************
//
// playIoT Global Library
//
// Copyright(c) 2016 playIoT.
//
// jsf3rd@playiot.biz
//
//
// *******************************************************

unit JdcGlobal;

interface

uses
  Classes, SysUtils, Windows, ZLib, IdGlobal, IOUtils, JclFileUtils, Vcl.ExtCtrls,
  IdUDPClient, JclSysInfo, psAPI, IdContext, Vcl.StdCtrls, JclSvcCtrl, Vcl.ActnList,
  Vcl.Dialogs, WinApi.Shellapi, UITypes;

type
  IExecuteFunc<T> = Interface
    ['{48E4B912-AE21-4201-88E0-4835432FEE69}']
    function Execute(AValue: String): T;
  End;

  IExecuteProc<T> = Interface
    ['{48E4B912-AE21-4201-88E0-4835432FEE69}']
    procedure Execute(AValue: T);
  End;

  TMessageType = (msDebug, msInfo, msError, msWarning, msUnknown);

  TLogProc = procedure(const AType: TMessageType; const ATitle: String;
    const AMessage: String = '') of object;

  TOnMessageEvent = procedure(const Sender: TObject; const AName: string;
    const AMessage: string = '') of object;

  TMsgOutput = (moDebugView, moLogFile, moCloudMessage);
  TMsgOutputs = set of TMsgOutput;

  TConnInfo = record
    StringValue: string;
    IntegerValue: integer;
    constructor Create(AString: string; AInteger: integer);
    function ToString: string;
    function Equals(const ConnInfo: TConnInfo): boolean;
  end;

  TClientInfo = record
    Version: string;
    Url: string;
  end;

  TGlobalAbstract = class abstract
  strict protected
    FProjectCode: string;
    FAppCode: string;

    FIsInitialized: boolean;
    FIsFinalized: boolean;
    FExeName: String;
    FLogName: string;
    FUseCloudLog: boolean;

    FStartTime: TDateTime;

    FLogServer: TConnInfo;
    procedure SetExeName(const Value: String); virtual; abstract;

    procedure _ApplicationMessage(const AType: string; const ATitle: string;
      const AMessage: String; const AOutputs: TMsgOutputs = [moDebugView, moLogFile,
      moCloudMessage]); virtual;

    function GetErrorLogName: string; virtual;
    function GetLogName: string; virtual;
  public
    constructor Create; virtual;

    procedure Initialize; virtual;
    procedure Finalize; virtual;

    procedure ApplicationMessage(const AType: TMessageType; const ATitle: String;
      const AMessage: String = ''); overload; virtual;
    procedure ApplicationMessage(const AType: TMessageType; const ATitle: String;
      const AFormat: String; const Args: array of const); overload;

    property ExeName: String read FExeName write SetExeName;
    property LogName: string read GetLogName;
    property ErrorLogName: string read GetErrorLogName;

    property LogServer: TConnInfo read FLogServer write FLogServer;

  const
    MESSAGE_TYPE_INFO = 'INFO';
    MESSAGE_TYPE_ERROR = 'ERROR';
    MESSAGE_TYPE_DEBUG = 'DEBUG';
    MESSAGE_TYPE_WARNING = 'WARNING';
    MESSAGE_TYPE_UNKNOWN = 'UNKNOWN';
  end;

  // �α� ���..
procedure PrintLog(const AFile: string; AMessage: String = ''); overload;
procedure PrintLog(AMemo: TMemo; const AMsg: String = ''); overload;

procedure PrintDebug(const Format: string; const Args: array of const); overload;
procedure PrintDebug(const str: string); overload;

function CurrentProcessMemory: Cardinal;
function FileVersion(const FileName: String): String;
procedure CloudMessage(const ProjectCode, AppCode, TypeCode, ATitle, AMessage,
  AVersion: String; const AServer: TConnInfo);

// ������ ����..
function CompressStream(Stream: TStream; OutStream: TStream; OnProgress: TNotifyEvent)
  : boolean;

// ������ ���� ����..
function DeCompressStream(Stream: TStream; OutStream: TStream;
  OnProgress: TNotifyEvent): boolean;

// ���� �˻�..
function Contains(Contents: string; const str: array of const): boolean;
function IsGoodResponse(Text, Command: string; Response: array of const): boolean;

// Reverse 2Btyes..
function Rev2Bytes(w: WORD): WORD;

// Reverse 4Btyes..
function Rev4Bytes(Value: LongInt): LongInt;

// Reverse 4Btyes..
function Rev4BytesF(Value: LongInt): Single;

// Big endian
function WordToBytes(AValue: WORD): TIdBytes;

// Big endian
function DWordToBytes(AValue: DWORD): TIdBytes;

// little endian
function HexStrToWord(const ASource: string; const AIndex: integer = 1): WORD;

function HexStrToByte(const ASource: String; const AIndex: integer = 1): Byte;
function HexStrToBytes(const ASource: string; const AIndex: integer = 1): TIdBytes;

function IdBytesToHex(const AValue: TIdBytes; const ASpliter: String = ' '): String;
function BytesToHex(const AValue: TBytes; const ASpliter: String = ' '): String;

function IdBytesPos(const SubIdBytes, IdBytes: TIdBytes; const AIndex: integer = 0): integer;

function DefaultFormatSettings: TFormatSettings;

function StrDefault(str: string; Default: string): string;

// Thread Safe
procedure ThreadSafe(AMethod: TThreadMethod); overload;
procedure ThreadSafe(AThreadProc: TThreadProcedure); overload;

function GetPeerInfo(AContext: TIdContext): string;

// ���� ����
procedure StartService(const ServiceName: String; var OldStatus: TJclServiceState;
  StartAction: TAction);
procedure StopService(const ServiceName: String; var OldStatus: TJclServiceState;
  StopAction: TAction; hnd: HWND);
procedure UpdateServiceStatus(const ServiceName: String; var OldStatus: TJclServiceState;
  StartAction, StopAction: TAction; StatusEdit: TLabeledEdit);

const
  LOCAL_SERVER = '\\localhost';
  LOG_SERVER = 'cloudlog.iccs.co.kr';

implementation

uses JdcGlobal.ClassHelper;

procedure StartService(const ServiceName: String; var OldStatus: TJclServiceState;
  StartAction: TAction);
begin
  OldStatus := ssUnknown;

  StartAction.Enabled := False;
  if StartServiceByName(LOCAL_SERVER, ServiceName) then
    Exit;

  MessageDlg('���񽺸� �������� ���߽��ϴ�.', TMsgDlgType.mtWarning, [mbOK], 0);
  StartAction.Enabled := true;
end;

procedure StopService(const ServiceName: String; var OldStatus: TJclServiceState;
  StopAction: TAction; hnd: HWND);
begin
  OldStatus := ssUnknown;
  StopAction.Enabled := False;
  if StopServiceByName(LOCAL_SERVER, ServiceName) then
    Exit;

  if MessageDlg('�˸� : ���񽺸� �������� ���߽��ϴ�.' + #13#10 + '������ �����Ͻðڽ��ϱ�?', TMsgDlgType.mtConfirmation,
    [mbYes, mbNo], 0) = mrYes then
    ShellExecute(hnd, 'open', 'taskkill', PWideChar(' -f -im ' + ServiceName + '.exe'),
      nil, SW_HIDE);
end;

procedure UpdateServiceStatus(const ServiceName: String; var OldStatus: TJclServiceState;
  StartAction, StopAction: TAction; StatusEdit: TLabeledEdit);
var
  Status: TJclServiceState;
begin
  Status := GetServiceStatusByName(LOCAL_SERVER, ServiceName);

  if OldStatus = Status then
    Exit;

  OldStatus := Status;
  StartAction.Enabled := False;
  StopAction.Enabled := False;
  case Status of
    ssUnknown:
      StatusEdit.Text := '�˼�����(��ϵ� ���񽺰� �����ϴ�).';
    ssStopped:
      begin
        StatusEdit.Text := '������.';
        StartAction.Enabled := true;
      end;
    ssStartPending:
      StatusEdit.Text := '���� ��...';
    ssStopPending:
      StatusEdit.Text := '���ߴ� ��...';
    ssRunning:
      begin
        StatusEdit.Text := '���۵�.';
        StopAction.Enabled := true;
      end;
    ssContinuePending:
      StatusEdit.Text := '��� ��...';
    ssPausePending:
      StatusEdit.Text := '�Ͻ����� ��...';
    ssPaused:
      StatusEdit.Text := '�Ͻ�������.';
  end;

end;

function GetPeerInfo(AContext: TIdContext): string;
begin
  result := AContext.Connection.Socket.Binding.PeerIP + ':' +
    AContext.Connection.Socket.Binding.PeerPort.ToString;
end;

procedure ThreadSafe(AMethod: TThreadMethod); overload;
begin
  if TThread.CurrentThread.ThreadID = MainThreadID then
    AMethod
  else
    TThread.Queue(nil, AMethod);
end;

procedure ThreadSafe(AThreadProc: TThreadProcedure); overload;
begin
  if TThread.CurrentThread.ThreadID = MainThreadID then
    AThreadProc
  else
    TThread.Queue(nil, AThreadProc);
end;

function DefaultFormatSettings: TFormatSettings;
begin
{$WARN SYMBOL_PLATFORM OFF}
  result := TFormatSettings.Create(GetThreadLocale);
{$WARN SYMBOL_PLATFORM ON}
  result.ShortDateFormat := 'YYYY-MM-DD';
  result.LongDateFormat := 'YYYY-MM-DD';
  result.ShortTimeFormat := 'hh:mm:ss';
  result.LongTimeFormat := 'hh:mm:ss';
  result.DateSeparator := '-';
  result.TimeSeparator := ':';
end;

function IdBytesPos(const SubIdBytes, IdBytes: TIdBytes; const AIndex: integer = 0): integer;
var
  Index: integer;
  I: integer;
begin
  Index := ByteIndex(SubIdBytes[0], IdBytes, AIndex);
  if Index = -1 then
    Exit(-1);

  for I := 0 to Length(SubIdBytes) - 1 do
  begin
    if IdBytes[Index + I] <> SubIdBytes[I] then
      Exit(IdBytesPos(SubIdBytes, IdBytes, Index + I));
  end;
  result := Index;
end;

function IdBytesToHex(const AValue: TIdBytes; const ASpliter: String): String;
var
  I: integer;
begin
  result := '';
  for I := 0 to Length(AValue) - 1 do
  begin
    result := result + ByteToHex(AValue[I]) + ASpliter;
  end;
end;

function BytesToHex(const AValue: TBytes; const ASpliter: String): String;
var
  I: integer;
begin
  result := '';
  for I := 0 to Length(AValue) - 1 do
  begin
    result := result + ByteToHex(AValue[I]) + ASpliter;
  end;
end;

procedure PrintLog(AMemo: TMemo; const AMsg: String);
begin
  ThreadSafe(
    procedure
    begin
      if AMemo.Lines.Count > 5000 then
        AMemo.Lines.Clear;

      if AMsg.IsEmpty then
        AMemo.Lines.Add('')
      else
        AMemo.Lines.Add(FormatDateTime('YYYY-MM-DD HH:NN:SS.zzz, ', now) + AMsg);
    end);
end;

procedure PrintLog(const AFile: string; AMessage: String);
var
  Stream: TStreamWriter;
  FileName: String;
begin
  FileName := AFile;

  if FileExists(FileName) then
  begin
    if JclFileUtils.FileGetSize(FileName) > 1024 * 1024 * 5 then
    begin
      try
        FileMove(AFile, ChangeFileExt(FileName, FormatDateTime('_YYYYMMDD_HHNNSS', now) +
          '.bak'), true);
      except
        on E: Exception do
          FileName := ChangeFileExt(FileName, FormatDateTime('_YYYYMMDD', now) + '.tmp');
      end;
    end;
  end;

  try
    Stream := TFile.AppendText(FileName);
    try
      if AMessage.IsEmpty then
        Stream.WriteLine
      else
        Stream.WriteLine(FormatDateTime('YYYY-MM-DD, HH:NN:SS.zzz, ', now) + AMessage);
    finally
      FreeAndNil(Stream);
    end;
  except
    on E: Exception do
    begin
      if ExtractFileExt(FileName) = '.tmp' then
      begin
        PrintDebug(E.Message + ', ' + AMessage);
        Exit;
      end
      else
        PrintLog(FileName + '.tmp', AMessage);
    end;
  end;

end;

procedure PrintDebug(const Format: string; const Args: array of const); overload;
var
  str: string;
begin
  FmtStr(str, Format, Args);
  PrintDebug(str);
end;

procedure PrintDebug(const str: string); overload;
begin
  OutputDebugString(PChar('[JDC] ' + str));
end;

function CurrentProcessMemory: Cardinal;
var
  MemCounters: TProcessMemoryCounters;
begin
  MemCounters.cb := SizeOf(MemCounters);
  if GetProcessMemoryInfo(GetCurrentProcess, @MemCounters, SizeOf(MemCounters)) then
    result := MemCounters.WorkingSetSize
  else
    result := 0;
end;

function FileVersion(const FileName: String): String;
var
  VerInfoSize: Cardinal;
  VerValueSize: Cardinal;
  Dummy: Cardinal;
  PVerInfo: Pointer;
  PVerValue: PVSFixedFileInfo;
begin
  result := '';

  if not TFile.Exists(FileName) then
    Exit;

  VerInfoSize := GetFileVersionInfoSize(PChar(FileName), Dummy);
  GetMem(PVerInfo, VerInfoSize);
  try
    if GetFileVersionInfo(PChar(FileName), 0, VerInfoSize, PVerInfo) then
      if VerQueryValue(PVerInfo, '\', Pointer(PVerValue), VerValueSize) then
        with PVerValue^ do
          result := Format('v%d.%d.%d', [HiWord(dwFileVersionMS),
          // Major
          LoWord(dwFileVersionMS), // Minor
          HiWord(dwFileVersionLS) // Release
            ]);
  finally
    FreeMem(PVerInfo, VerInfoSize);
  end;
end;

procedure CloudMessage(const ProjectCode, AppCode, TypeCode, ATitle, AMessage,
  AVersion: String; const AServer: TConnInfo);
var
  UDPClient: TIdUDPClient;
  SysInfo, Msg, DiskInfo: String;
  MBFactor, GBFactor: double;
  _Title: string;
begin
{$IFDEF DEBUG}
//  Exit;
{$ENDIF}
  MBFactor := 1024 * 1024;
  GBFactor := MBFactor * 1024;

  SysInfo := Format('OS=%s,MemUsage=%.2fMB,TotalMem=%.2fGB,FreeMem=%.2fGB,IPAddress=%s',
    [GetOSVersionString, CurrentProcessMemory / MBFactor, GetTotalPhysicalMemory / GBFactor,
    GetFreePhysicalMemory / GBFactor, GetIPAddress(GetLocalComputerName)]);

  DiskInfo := Format('C_Free=%.2fGB,C_Size=%.2fGB,D_Free=%.2fGB,D_Size=%.2fGB',
    [DiskFree(3) / GBFactor, DiskSize(3) / GBFactor, DiskFree(4) / GBFactor,
    DiskSize(4) / GBFactor]);

  _Title := ATitle.Replace(' ', '_', [rfReplaceAll]);
  Msg := Format
    ('CloudLog,ProjectCode=%s,AppCode=%s,TypeCode=%s,ComputerName=%s,Title=%s Version="%s",LogMessage="%s",SysInfo="%s",DiskInfo="%s"',
    [ProjectCode, AppCode, TypeCode, GetLocalComputerName, _Title, AVersion, AMessage, SysInfo,
    DiskInfo]);

  UDPClient := TIdUDPClient.Create(nil);
  try
    try
      UDPClient.Send(AServer.StringValue, AServer.IntegerValue, Msg, IndyTextEncoding_UTF8);
      PrintDebug('<%s> [%s] %s=%s,Host=%s', [TypeCode, AppCode, _Title, Msg,
        AServer.StringValue]);
    except
      on E: Exception do
    end;
  finally
    UDPClient.Free;
  end;
end;

function CompressStream(Stream: TStream; OutStream: TStream; OnProgress: TNotifyEvent)
  : boolean;
var
  CS: TZCompressionStream;
begin
  CS := TZCompressionStream.Create(OutStream); // ��Ʈ�� ����
  try
    if Assigned(OnProgress) then
      CS.OnProgress := OnProgress;
    CS.CopyFrom(Stream, Stream.Size); // ���⼭ ������ �����
    // �׽�Ʈ ��� ����Ϸ�� �̺�Ʈ�� �߻����� �ʱ� ������
    // �Ϸ�� �ѹ� �� �̺�Ʈ�� �ҷ��ش�.
    if Assigned(OnProgress) then
      OnProgress(CS);
    result := true;
  finally
    CS.Free;
  end;
end;

function Contains(Contents: string; const str: array of const): boolean;
var
  I: integer;
begin
  result := False;

  for I := 0 to High(str) do
  begin
    if Pos(str[I].VPWideChar, Contents) = 0 then
      Exit;
  end;

  result := true;
end;

function IsGoodResponse(Text, Command: string; Response: array of const): boolean;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := Text;

    result := (SL.Strings[0] = Command) and (Contains(Text, Response));
  finally
    SL.Free;
  end;
end;

function DeCompressStream(Stream: TStream; OutStream: TStream;
OnProgress: TNotifyEvent): boolean;
const
  BuffSize = 65535; // ���� ������
var
  DS: TZDeCompressionStream;
  Buff: PChar; // �ӽ� ����
  ReadSize: integer; // ���� ũ��
begin
  if Stream = OutStream then
    // �Է� ��Ʈ���� ��½�Ʈ���� ������ ������ �߻��Ѵ�
    raise Exception.Create('�Է� ��Ʈ���� ��� ��Ʈ���� �����ϴ�');
  Stream.Position := 0;
  // ��Ʈ�� Ŀ�� �ʱ�ȭ
  OutStream.Position := 0;
  // ��ǲ ��Ʈ���� �ɼ����� ��ü ����.
  DS := TZDeCompressionStream.Create(Stream);
  try
    if Assigned(OnProgress) then
      DS.OnProgress := OnProgress;
    GetMem(Buff, BuffSize);
    try
      // ���� �����ŭ �о�´�. Read�Լ��� �θ��� ������ Ǯ���� �ȴ�.
      repeat
        ReadSize := DS.Read(Buff^, BuffSize);
        if ReadSize <> 0 then
          OutStream.Write(Buff^, ReadSize);
      until ReadSize < BuffSize;
      if Assigned(OnProgress) then
        OnProgress(DS);
      // Compress�� ��������
      result := true;
    finally
      FreeMem(Buff)
    end;
  finally
    DS.Free;
  end;
end;

function Rev2Bytes(w: WORD): WORD;
asm
  XCHG   AL, AH
end;

function Rev4Bytes(Value: LongInt): LongInt; assembler;
asm
  MOV EAX, Value;
  BSWAP    EAX;
end;

function Rev4BytesF(Value: LongInt): Single;
var
  tmp: LongInt;
begin
  tmp := Rev4Bytes(Value);
  CopyMemory(@result, @tmp, SizeOf(tmp));
end;

function CheckHexStr(ASource: String): String;
begin
  if (Length(ASource) mod 2) = 0 then
    result := ASource
  else
    result := '0' + ASource;
end;

function HexStrToByte(const ASource: String; const AIndex: integer): Byte;
var
  str: String;
  tmp: TIdBytes;
begin
  str := CheckHexStr(ASource);

  if Length(str) < AIndex + 1 then
  begin
    result := $00;
    Exit;
  end;

  str := Copy(str, AIndex, 2);
  tmp := HexStrToBytes(str);
  CopyMemory(@result, tmp, 1);
end;

function WordToBytes(AValue: WORD): TIdBytes;
begin
  result := ToBytes(Rev2Bytes(AValue));
end;

function DWordToBytes(AValue: DWORD): TIdBytes;
begin
  result := ToBytes(Rev4Bytes(AValue));
end;

function HexStrToWord(const ASource: string; const AIndex: integer): WORD;
var
  str: string;
begin
  str := CheckHexStr(ASource);

  if Length(str) = 2 then
    str := '00' + str;

  if Length(str) < AIndex + 3 then
  begin
    result := $00;
    Exit;
  end;

  str := Copy(str, AIndex, 4);

{$IF CompilerVersion  > 28} // Ver28 = XE7
  result := BytesToUInt16(HexStrToBytes(str));
{$ELSE}
  result := BytesToWord(HexStrToBytes(str));
{$ENDIF}
end;

function HexStrToBytes(const ASource: string; const AIndex: integer): TIdBytes;
var
  I, j, n: integer;
  c: char;
  b: Byte;
  str: string;
begin
  str := CheckHexStr(ASource);

  SetLength(result, 0);

  j := 0;
  b := 0;
  n := 0;

  for I := AIndex to Length(str) do
  begin
    c := ASource[I];
    case c of
      '0' .. '9':
        n := ord(c) - ord('0');
      'A' .. 'F':
        n := ord(c) - ord('A') + 10;
      'a' .. 'f':
        n := ord(c) - ord('a') + 10;
    else
      Continue;
    end;

    if j = 0 then
    begin
      b := n;
      j := 1;
    end
    else
    begin
      b := (b shl 4) + n;
      j := 0;

      AppendBytes(result, ToBytes(b));
    end
  end;

  if j <> 0 then
    raise Exception.Create('Input contains an odd number of hexadecimal digits.[' + ASource +
      '/' + IntToStr(AIndex) + ']');
end;

{ TGlobalAbstract }

procedure TGlobalAbstract.ApplicationMessage(const AType: TMessageType; const ATitle: string;
const AMessage: String);
begin
  case AType of
    msDebug:
      _ApplicationMessage(MESSAGE_TYPE_DEBUG, ATitle, AMessage, [moDebugView, moLogFile]);
    msInfo:
      _ApplicationMessage(MESSAGE_TYPE_INFO, ATitle, AMessage);
    msError:
      _ApplicationMessage(MESSAGE_TYPE_ERROR, ATitle, AMessage);
    msWarning:
      _ApplicationMessage(MESSAGE_TYPE_WARNING, ATitle, AMessage);
  else
    _ApplicationMessage(MESSAGE_TYPE_UNKNOWN, ATitle, AMessage);
  end;
end;

procedure TGlobalAbstract.ApplicationMessage(const AType: TMessageType; const ATitle: string;
const AFormat: String; const Args: array of const);
var
  str: string;
begin
  FmtStr(str, AFormat, Args);
  ApplicationMessage(AType, ATitle, str);
end;

constructor TGlobalAbstract.Create;
begin
  FExeName := '';
  FLogName := '';
  FLogServer.StringValue := LOG_SERVER;
  FLogServer.IntegerValue := 8092;
  FIsInitialized := False;
  FIsFinalized := False;
  FUseCloudLog := False;
end;

procedure TGlobalAbstract.Finalize;
begin
  ApplicationMessage(msInfo, 'Stop', 'StartTime=' + FStartTime.ToString);
end;

function TGlobalAbstract.GetErrorLogName: string;
begin
  result := ChangeFileExt(FLogName, FormatDateTime('_YYYYMMDD', now) + '.err');
end;

function TGlobalAbstract.GetLogName: string;
begin
  result := ChangeFileExt(FLogName, FormatDateTime('_YYYYMMDD', now) + '.log');
end;

procedure TGlobalAbstract.Initialize;
begin
  FStartTime := now;
{$IFDEF WIN32}
  ApplicationMessage(msInfo, 'Start', '(x86)' + FExeName);
{$ENDIF}
{$IFDEF WIN64}
  ApplicationMessage(msInfo, 'Start', '(x64)' + FExeName);
{$ENDIF}
end;

procedure TGlobalAbstract._ApplicationMessage(const AType: string; const ATitle: string;
const AMessage: String; const AOutputs: TMsgOutputs);
var
  splitter: string;
begin
  if AMessage.IsEmpty then
    splitter := ''
  else
    splitter := ' - ';

  if moDebugView in AOutputs then
    PrintDebug('<%s> [%s] %s%s%s', [AType, FAppCode, ATitle, splitter, AMessage]);

  if moLogFile in AOutputs then
    PrintLog(FLogName, Format('<%s> %s%s%s', [AType, ATitle, splitter, AMessage]));

  if (moCloudMessage in AOutputs) and FUseCloudLog then
    CloudMessage(FProjectCode, FAppCode, AType, ATitle, AMessage, FileVersion(FExeName),
      FLogServer);
end;

{ TConnInfo }

constructor TConnInfo.Create(AString: string; AInteger: integer);
begin
  Self.StringValue := AString;
  Self.IntegerValue := AInteger;
end;

function TConnInfo.Equals(const ConnInfo: TConnInfo): boolean;
begin
  result := Self.StringValue.Equals(ConnInfo.StringValue) and
    (Self.IntegerValue = ConnInfo.IntegerValue);
end;

function TConnInfo.ToString: string;
begin
  result := Self.StringValue + ':' + Self.IntegerValue.ToString;
end;

function StrDefault(str: string; Default: string): string;
begin
  if str.IsEmpty then
    result := Default
  else
    result := str;
end;

end.
