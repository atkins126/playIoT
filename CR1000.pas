{ ******************************************************* }
{ }
{ CR1000 ������ ���� }
{ }
{ Copyright (C) 2008 (��)����Ƽ�ƽ�, isul }
{ }
{ ******************************************************* }

unit cr1000;

interface

uses SysUtils, StrUtils, Windows, SPBDLL;

const
  LOGGER_CR1000 = 3;

  RECORD_RECENT = -1;
  RECORD_ALL = 0;

  FN_GET_TABLENAMES = 0;

  RESULT_CODE_OK = 0;
  RESULT_CODE_OK_EX = 1;
  RESULT_CODE_TIME_OUT = -1;
  RESULT_CODE_PORT_CLOSED = -2;

  RESULT_MSG_OK_EX = 'Success but more data to collect.';
  RESULT_MSG_TIME_OUT = 'Communication timed out.';
  RESULT_MSG_PORT_CLOSED = 'Port is not open.';

type
  TCR1000 = class
  private
    Address: Integer;

    FOpenPort: TOpenPort;
    FOpenIPPort: TOpenIPPort;
    FClosePort: TClosePort;
    FCloseIPPort: TCloseIPPort;
    FGetClock: TGetClock;
    FSetClock: TSetClock;
    FGetValue: TGetValue;
    FSetValue: TSetValue;
    FGetData: TGetData;
    FGetDataHeader: TGetDataHeader;
    FGetCommaData: TGetCommaData;
    FFile_Send: TFile_Send;
    FGetAddress: TGetAddress;
    FGetStatus: TGetStatus;
    FGetTableNames: TGetTableNames;
    FGetDLLVersion: TGetDLLVersion;

    FDLLHandle: THandle;
    procedure LoadDLL;
    procedure FreeDLL;

    procedure SetLastError(ReturnCode: Integer; FuncType: Integer = -1);
    procedure Debug(const str: string); overload;
    procedure Debug(const Format: string; const Args: array of const); overload;
  public
    LastError: string;
    PortOpened: Boolean;
    IpPortOpened: Boolean;
    constructor Create;
    destructor Destroy; override;

    function OpenPort(ComPort, BaudRate: Integer): Boolean; overload;
    function OpenPort(Ip: string; Port: Integer): Boolean; overload;
    function ClosePort: Boolean;
    function GetClock(var ATime: PAnsiChar): Boolean;
    function SetClock(var ATime: PAnsiChar): Boolean;
    function GetData(Table, Recrd: Integer; out pData: PAnsiChar): Integer;
    function GetCommaData(Table, Recrd: Integer; out pData: PAnsiChar): Integer;
    function GetStatus: string;
    function GetTableNames(out Tables: PAnsiChar): Boolean;
    function UpdateFirmware(FileName: PAnsiChar; out pData: PAnsiChar): Integer;
    function Opened: Boolean;
  end;

implementation

{ TCR1000 }

{ -------------------------------------------------------------------------------
  ����: TCR1000.Create
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: None
  �����: None
  ��  ��: ������
  ------------------------------------------------------------------------------- }
constructor TCR1000.Create;
begin
  inherited;

  PortOpened := False;
  IpPortOpened := False;

  LoadDLL;
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.Destroy
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: None
  �����: None
  ��  ��: ����
  ------------------------------------------------------------------------------- }
destructor TCR1000.Destroy;
begin
  ClosePort;

  FreeDLL;

  inherited;
end;

procedure TCR1000.FreeDLL;
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

{ -------------------------------------------------------------------------------
  ����: TCR1000.OpenPort
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: ComPort, BaudRate: Integer
  �����: Boolean
  ��  ��: �ø��� ��Ʈ ����
  ------------------------------------------------------------------------------- }
function TCR1000.OpenPort(ComPort, BaudRate: Integer): Boolean;
var
  Data: PAnsiChar;
  str: string;
  Len: Integer;
  Opened: Boolean;
begin
  Result := False;
  Opened := FOpenPort(ComPort, BaudRate) = 0;
  Debug('OpenPort() -> %s', [IfThen(Opened, 'Success', 'Fail')]);
  if Opened then
  begin
    Result := FGetAddress(LOGGER_CR1000, Data, Len) = 0;
    Debug('GetAddress(ComPort=%d, BaudRate=%d) -> %s',
      [ComPort, BaudRate, IfThen(Result, 'Success', 'Fail')]);
    if Result then
    begin
      str := string(Data);
      Address := StrToIntDef(Copy(str, Pos('=', str) + 1, Length(str)), 1);
      Debug('Address -> %d', [Address]);
      PortOpened := True;
    end
    else if Opened then
    begin
      PortOpened := True;
      ClosePort;
    end;
  end;
end;

function TCR1000.OpenPort(Ip: string; Port: Integer): Boolean;
var
  Data: PAnsiChar;
  Len: Integer;
  Opened: Boolean;
begin
  Result := False;
  Opened := FOpenIPPort(PAnsiChar(AnsiString(Ip)), Port) = 0;
  Debug('OpenIPPort(Ip=%s, Port=%d) -> %s', [Ip, Port, IfThen(Opened, 'Success', 'Fail')]);
  if Opened then
  begin
    Result := FGetAddress(LOGGER_CR1000, Data, Len) = 0;
    Debug('GetAddress() -> %s', [IfThen(Result, 'Success', 'Fail')]);
    if Result then
    begin
      Address := StrToIntDef(Copy(String(Data), Pos('=', String(Data)) + 1, Length(Data)), 1);
      Debug('Address -> %d', [Address]);
      IpPortOpened := True;
    end
    else if Opened then
    begin
      IpPortOpened := True;
      FCloseIPPort;
    end;
  end;
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.ClosePort
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: None
  �����: Boolean
  ��  ��: �ø��� ��Ʈ �ݱ�
  ------------------------------------------------------------------------------- }
function TCR1000.ClosePort: Boolean;
begin
  Result := False;
  if PortOpened then
  begin
    Debug('ClosePort()');
    Result := FClosePort = 0;
    PortOpened := False;
  end

  else if IpPortOpened then
  begin
    Debug('ClosePort()');
    Result := FCloseIPPort = 0;
    IpPortOpened := False;
  end;
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.GetClock
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: Address: Integer; var ErrMsg: string
  �����: Boolean
  ��  ��: �ΰ��� ���� �ð� ���ϱ�
  ------------------------------------------------------------------------------- }
function TCR1000.GetClock(var ATime: PAnsiChar): Boolean;
var
  Len: Integer;
  ReturnCode: Integer;
begin
  ReturnCode := FGetClock(Address, LOGGER_CR1000, ATime, Len);
  SetLastError(ReturnCode);
  Result := ReturnCode = 0;
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.SetClock
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: Address, Device: Integer; out pData: PAnsiChar; out pLgh: Integer; var ErrMsg: string
  �����: Boolean
  ��  ��: PC�� �ΰ� �ð� ����ȭ
  ------------------------------------------------------------------------------- }
function TCR1000.SetClock(var ATime: PAnsiChar): Boolean;
var
  Len: Integer;
  ReturnCode: Integer;
begin
  ReturnCode := FSetClock(Address, LOGGER_CR1000, ATime, Len);
  SetLastError(ReturnCode);
  Result := ReturnCode = 0;
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.GetErrorMessage
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: ReturnCode: Integer
  �����: string
  ��  ��: ���� �޽��� ���ϱ�
  ------------------------------------------------------------------------------- }
procedure TCR1000.SetLastError(ReturnCode: Integer; FuncType: Integer);
begin
  if ReturnCode = -1 then
    LastError := 'Communication fail.'
  else if ReturnCode = -2 then
    LastError := 'Serial port closed.'
  else
    LastError := '';

  case FuncType of
    FN_GET_TABLENAMES:
      begin
        if ReturnCode = -2 then
          LastError := 'Can not read table info from data logger.';
      end;
  end;
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.GetData
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: Address, Table, Recrd: Integer; out pData: PAnsiChar
  �����: Integer
  ��  ��: ������ ���
  ------------------------------------------------------------------------------- }
function TCR1000.GetData(Table, Recrd: Integer; out pData: PAnsiChar): Integer;
var
  Len: Integer;
begin
  Result := FGetData(Address, LOGGER_CR1000, Table, Recrd, pData, Len);
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.GetCommaData
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: Address, Table, Recrd: Integer; out pData: PAnsiChar
  �����: Integer
  ��  ��: �޸��� �и��� ������ �������� ������ ���
  ------------------------------------------------------------------------------- }
function TCR1000.GetCommaData(Table, Recrd: Integer; out pData: PAnsiChar): Integer;
var
  Len: Integer;
begin
  Result := FGetCommaData(Address, LOGGER_CR1000, Table, Recrd, pData, Len);
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.GetStatus
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: None
  �����: string
  ��  ��: �ΰ� ���� ǥ��
  ------------------------------------------------------------------------------- }
function TCR1000.GetStatus: string;
var
  Data: PAnsiChar;
  Len: Integer;
  ReturnCode: Integer;
begin
  ReturnCode := FGetStatus(Address, LOGGER_CR1000, Data, Len);
  SetLastError(ReturnCode);
  Result := String(Data);
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.GetTableNames
  �ۼ���: isul
  �ۼ���: 2008.02.11
  ��  ��: out Tables: PAnsiChar
  �����: Boolean
  ��  ��: ���̺�� ���ϱ�
  ------------------------------------------------------------------------------- }
function TCR1000.GetTableNames(out Tables: PAnsiChar): Boolean;
var
  Len: Integer;
  ReturnCode: Integer;
begin
  ReturnCode := FGetTableNames(Address, LOGGER_CR1000, Tables, Len);
  Result := ReturnCode = 0;
  if not Result then
    SetLastError(ReturnCode, FN_GET_TABLENAMES);
end;

procedure TCR1000.LoadDLL;
begin
  FDLLHandle := LoadLibrary(SIMPLEPB_DLL);
  if FDLLHandle < 32 then
    raise Exception.Create('Load DLL Exception');

  @FOpenPort := GetProcAddress(FDLLHandle, 'OpenPort');
  @FOpenIPPort := GetProcAddress(FDLLHandle, 'OpenIPPort');
  @FClosePort := GetProcAddress(FDLLHandle, 'ClosePort');
  @FCloseIPPort := GetProcAddress(FDLLHandle, 'CloseIPPort');
  @FGetClock := GetProcAddress(FDLLHandle, 'GetClock');
  @FSetClock := GetProcAddress(FDLLHandle, 'SetClock');
  @FGetValue := GetProcAddress(FDLLHandle, 'GetValue');
  @FSetValue := GetProcAddress(FDLLHandle, 'SetValue');
  @FGetData := GetProcAddress(FDLLHandle, 'GetData');
  @FGetDataHeader := GetProcAddress(FDLLHandle, 'GetDataHeader');
  @FGetCommaData := GetProcAddress(FDLLHandle, 'GetCommaData');
  @FFile_Send := GetProcAddress(FDLLHandle, 'File_Send');
  @FGetAddress := GetProcAddress(FDLLHandle, 'GetAddress');
  @FGetStatus := GetProcAddress(FDLLHandle, 'GetStatus');
  @FGetTableNames := GetProcAddress(FDLLHandle, 'GetTableNames');
  @FGetDLLVersion := GetProcAddress(FDLLHandle, 'GetDLLVersion');

end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.UpdateFirmware
  �ۼ���: isul
  �ۼ���: 2008.02.14
  ��  ��: FileName: PAnsiChar; out pData: PAnsiChar
  �����: Integer
  ��  ��: �߿��� ������Ʈ
  ------------------------------------------------------------------------------- }
function TCR1000.UpdateFirmware(FileName: PAnsiChar; out pData: PAnsiChar): Integer;
var
  Len: Integer;
begin
  Result := FFile_Send(Address, LOGGER_CR1000, FileName, pData, Len);
end;

{ -------------------------------------------------------------------------------
  ����: TCR1000.Opened
  �ۼ���: isul
  �ۼ���: 2008.02.14
  ��  ��: None
  �����: Boolean
  ��  ��: �ø��� ��Ʈ ���� ����
  ------------------------------------------------------------------------------- }
function TCR1000.Opened: Boolean;
begin
  Result := PortOpened;
end;

procedure TCR1000.Debug(const str: string);
begin
  Debug(str, []);
end;

procedure TCR1000.Debug(const Format: string; const Args: array of const);
var
  str: string;
begin
  FmtStr(str, Format, Args);
  OutputDebugString(PChar('::CR1000:: ' + str));
end;

end.
