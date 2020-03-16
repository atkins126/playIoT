// *******************************************************
//
// DACO-M 1000P Modbus TCP Protocol
//
// Copyright(c) 2020 DACO.
//
// jsf3rd@e-daco.net
//
// *******************************************************

unit JdcDacoM.Protocol;

interface

uses SysUtils, Classes, JdcGlobal, JdcGlobal.ClassHelper, IdGlobal, Winapi.Windows, Math,
  System.DateUtils, JdcCRC, REST.JSON, System.JSON, JdcDacoM.Common, JdcLogging;

type
  TMBAP = packed record
    TrasactionId: UInt16;
    ProtocolId: UInt16;
    Length: UInt16;
    procedure Reverse;
  end;

  TPhasor = packed record
    X: Single;
    Y: Single;
  end;

  T3Phase = packed record
    A: Single;
    B: Single;
    C: Single;
    function Sum: Double;
    procedure Init;
    procedure Add(const AValue: T3Phase);
    procedure Min(const AValue: T3Phase);
    procedure Max(const AValue: T3Phase);
    function UnitFactor(AValue: Double): T3Phase;

    function CommaText: String;
  end;

  T3PhaseEx = packed record
    Phases: T3Phase;
    Extra: Single;
    procedure Add(const AValue: T3PhaseEx);
    procedure Min(const AValue: T3PhaseEx);
    procedure Max(const AValue: T3PhaseEx);
    procedure Init;
    function UnitFactor(AValue: Double): T3PhaseEx;
  end;

  TAMOUNT = packed record
    Received: Int32;
    Delivered: Int32;
    Sum: Int32;
    Net: Int32;
  end;

  TMBHeader = packed record
    UnitId: Byte;
    FC: Byte;
    Len: Byte;
  end;

  TErrorCode = packed record
    UnitId: Byte;
    FC: Byte; // 0x83
    Msg: Byte; // 0x01
  end;

  THarmoic = array [0 .. 30] of UInt16;

  TPowerData = packed record
    VoltLN: T3PhaseEx; // ����
    VoltLL: T3PhaseEx; // ��������
    VoltFundamental: T3PhaseEx; // �⺻�� ����
    VoltTHD: T3Phase; // ������ �ְ���
    VoltPhasorA: TPhasor; // A��
    VoltPhasorB: TPhasor; // B��
    VoltPhasorC: TPhasor; // C��
    VoltLNUnbalance: Single; // LN ��������
    VoltLLUnbalance: Single; // LL ��������
    VoltU0Unbalance: Single; // U0 ��������
    VoltU2Unbalance: Single; // U2 ��������
    Reserved1: Single;
    Reserved2: Single;
    FrequencyLN: T3Phase; // ���ļ�
    Temperature: Single; // �µ�
    ZeroSequenceComponentVoltage: Single;

    Hramonic: THarmoic; // ������ ������
    RS485: UInt16;
    Modbus: UInt16;
    VoltageRawData: UInt16;
    Current1: UInt16;
    Current2: UInt16;
    Network: UInt16;
    ProductType: UInt16;
    Reserved3: UInt16;
    Reserved4: UInt16;
    Reserved5: UInt16;
    ConnectionMethod: UInt32; // �ἱ���

    PhaseDifferenceAngleA: UInt16;
    PhaseDifferenceAngleB: UInt16;
    PhaseDifferenceAngleC: UInt16;
    PowerFactorInfo: UInt16;
    __Serial: UInt32; // ������
    ProductName: UInt32;
    ManufactureName: UInt32;
    HadwareVersion: UInt32;
    ApplicationVersion: UInt32;
    FirmwareVersion: UInt32;
    EthernetMac1_1: UInt32;
    EthernetMac1_2: UInt32;
    EthernetMac2_1: UInt32;
    EthernetMac2_2: UInt32;
    EthernetMac3_1: UInt32;
    EthernetMac3_2: UInt32;
    BootloaderVersion: UInt32;
    KernelVersion: UInt32;
    AppRevisionNumber: UInt32;

    {
      // Event
      AutoIDSet: UInt32;
      EventCurrentPositon: UInt16;
      EventAllPosition: UInt16;
      ModuleID: UInt16;
      EventNumber: UInt16;
      EventName: UInt16;
      EventPhase: UInt16;
      EventSettingValue: Single;
      EventStartEndValue: Single;
      EventDurationDay: UInt16;
      EventDurationSecHigh: UInt16;
      EventDurationSecLow: UInt16;
      TimeYearMonth: UInt16;
      TimeDayHour: UInt16;
      TimeMinSec: UInt16;
    }
    procedure Reverse;
  end;

  TPowerModule = packed record
    Header: TMBHeader;
    Data: TPowerData;
  end;

  TDataPart1 = packed record
    VoltLN: T3Phase; // ����
    FrequencyLN: T3Phase; // ���ļ�
    Current: T3PhaseEx; // ����
    ZeroCurrent: Single; //
    CurrentFundmental: T3PhaseEx; // �⺻�� ����
    CurrentTHD: T3Phase; // ������ �ְ���
    CurrentTDD: T3Phase; // ���� �ְ���
    CurrentPhsorA: TPhasor; // A��
    CurrentPhsorB: TPhasor; // B��
    CurrentPhsorC: TPhasor; // C��
    CurrentUnbalance: Single;
    CurrentU0Unbalance: Single;
    CurrentU2Unbalance: Single;
    CrestFactor: T3Phase;
    KFactor: T3Phase;
    KW: T3PhaseEx; // ��ȿ����
    KVAR: T3PhaseEx; // ��ȿ����
    KVA: T3PhaseEx; // �ǻ�����
    ZCTCurrent: Single; //
    KWh: TAMOUNT; // ��ȿ���·�
    KVARh: TAMOUNT; // ��ȿ���·�
    KVAh: UInt32; // �ǻ����·�
    procedure Reverse;
  end;

  TModulePart1 = packed record
    Header: TMBHeader;
    Data: TDataPart1;
    function UnitId: Byte;
  end;

  TDataPart2 = packed record
    DemandKW: T3PhaseEx; // ��ȿ���� ��ǵ�
    DemandKWTotalPrediction: Single; // ��ȿ���� ��ǵ� ������
    DemandCurrent: T3PhaseEx; // ���� ��ǵ�
    DemandKWCurrentPrediction: Single; // ������� ��ǵ� ������
    PowerFactor: T3PhaseEx; // ����

    Hramonic: THarmoic; // ������ ������
    Reserved1: UInt16;
    Reserved2: UInt16;
    Reserved3: UInt16;
    Reserved4: UInt16;
    Reserved5: UInt16;
    Reserved6: UInt16;
    Reserved7: UInt16;
    Reserved8: UInt16;
    Reserved9: UInt16;
    Reserved10: UInt16;
    __Serial: UInt32; // SN
    ConnectionDirection: UInt16; // �ἱ����
    OrderWiring: UInt16; // �ἱ����
    Reserved11: UInt16;
    ProductRation: UInt16;
    PFInfoA: UInt16;
    PFInfoB: UInt16;
    PFInfoC: UInt16;

    // 1000E
    // VoltageLL: T3PhaseEx;

    procedure Reverse;
  end;

  TModulePart2 = packed record
    Header: TMBHeader;
    Data: TDataPart2;
    function UnitId: Byte;
  end;

  TModuleData = packed record
    UnitId: Integer;
    Part1: TDataPart1;
    Part2: TDataPart2;
    function ToStrings: TStrings;
  end;

  TModuleArray = array [1 .. MAX_UNIT_ID] of TModuleData;

  TIDTable = packed record
    Header: TMBHeader;
    ID: TIDArray40;
  end;

type
  TRequestParam = record
    ID: Byte;
    Addr: UInt16;
    Len: UInt16;
    constructor Create(AID: Byte; AAddr, ALen: UInt16);
    function GetCommand(FC: Byte): TIdBytes;
  end;

  TModbus = class
  const
    ZERO_ADDRESS = $2C25; // 11301;
    MODULE_OFFSET = 300;

    MAIN_UNIT_ID = $01;

    IDTABLE_ADDRESS = $66BD; // 26301
    IDTABLE_UNITID = $FD; // 253

    POWER_ADDRESS = $2B5D; // 11101;
    POWER_UNIT_ID = $FE; // 254

    ERROR_CODE = $83; //

    MBAP: array [0 .. 5] of Byte = ($00, $00, $00, $00, $00, $06);
    READ_REGISTER = $03;

    WORD_COUNT_POWER = SizeOf(TPowerData) div 2;
    WORD_COUNT_PART1 = SizeOf(TDataPart1) div 2;
    WORD_COUNT_PART2 = SizeOf(TDataPart2) div 2;
    WORD_COUNT_IDTABLE = SizeOf(TIDArray40) div 2;
  public
    // DACO-M 1000(A,P,S) �ּ� ���
    class function GetAddress(AID: Byte; ADevice: String): UInt16;

    class function InvalidDataLen(ALen: Integer): Boolean;
    class function TcpCommand(const AParam: TRequestParam): TIdBytes;
    class function SerialCommand(const AParam: TRequestParam): TIdBytes;

    class function GetProtocolType(const ABuff: TIdBytes): TProtocolType;
    class function CheckCRC(const ABuff: TIdBytes): Boolean;
  end;

implementation

{ TModulePart1 }

function TModulePart1.UnitId: Byte;
begin
  result := Self.Header.UnitId;
end;

{ TModulePart2 }

function TModulePart2.UnitId: Byte;
begin
  result := Self.Header.UnitId;
end;

{ T3Phase }

procedure T3Phase.Add(const AValue: T3Phase);
begin
  Self.A := Self.A + AValue.A;
  Self.B := Self.B + AValue.B;
  Self.C := Self.C + AValue.C;
end;

function T3Phase.CommaText: String;
begin
  result := Format('%f,%f,%f', [Self.A, Self.B, Self.C]);
end;

procedure T3Phase.Init;
begin
  Self.A := 0;
  Self.B := 0;
  Self.C := 0;
end;

procedure T3Phase.Max(const AValue: T3Phase);
begin
  Self.A := Math.Max(Self.A, AValue.A);
  Self.B := Math.Max(Self.B, AValue.B);
  Self.C := Math.Max(Self.C, AValue.C);
end;

procedure T3Phase.Min(const AValue: T3Phase);
begin
  Self.A := Math.Min(Self.A, AValue.A);
  Self.B := Math.Min(Self.B, AValue.B);
  Self.C := Math.Min(Self.C, AValue.C);
end;

function T3Phase.Sum: Double;
begin
  result := Self.A + Self.B + Self.C;
end;

function T3Phase.UnitFactor(AValue: Double): T3Phase;
begin
  result.A := Self.A * AValue;
  result.B := Self.B * AValue;
  result.C := Self.C * AValue;
end;

{ T3PhaseEx }

procedure T3PhaseEx.Init;
begin
  Self.Phases.Init;
  Self.Extra := 0;
end;

procedure T3PhaseEx.Max(const AValue: T3PhaseEx);
begin
  Self.Phases.Max(AValue.Phases);
  Self.Extra := Math.Max(Self.Extra, AValue.Extra);
end;

procedure T3PhaseEx.Min(const AValue: T3PhaseEx);
begin
  Self.Phases.Min(AValue.Phases);
  Self.Extra := Math.Min(Self.Extra, AValue.Extra);
end;

function T3PhaseEx.UnitFactor(AValue: Double): T3PhaseEx;
begin
  result.Phases := Self.Phases.UnitFactor(AValue);
  result.Extra := Self.Extra * AValue;
end;

procedure T3PhaseEx.Add(const AValue: T3PhaseEx);
begin
  Self.Phases.Add(AValue.Phases);
  Self.Extra := Self.Extra + AValue.Extra;
end;

{ TModule }

function TModuleData.ToStrings: TStrings;
var
  JsonObject: TJSONObject;
begin
  result := TStringList.Create;
  JsonObject := TJson.RecordToJsonObject(Self.Part1);
  ExtractValues(result, JsonObject);
  JsonObject.Free;

  JsonObject := TJson.RecordToJsonObject(Self.Part2);
  ExtractValues(result, JsonObject);
  JsonObject.Free;
end;

{ TModbusUtil }

class function TModbus.CheckCRC(const ABuff: TIdBytes): Boolean;
var
  buff: TIdBytes;
  MyCRC, ReceivedCRC: UInt16;
begin
  SetLength(buff, Length(ABuff) - 2);
  CopyTIdBytes(ABuff, 0, buff, 0, Length(buff));
  MyCRC := ModbusCRC16(buff);
  ReceivedCRC := BytesToUInt16(ABuff, Length(buff));

  // AProc(msDebug, 'DATA', IdBytesToHex(buff));
  // AProc(msDebug, 'CRC', ToHex(ABuff, 2, Length(buff)));
  if MyCRC <> ReceivedCRC then
    TLogging.Obj.ApplicationMessage(msWarning, 'Wrong CRC', Format('MyCRC=%d,Received=%d',
      [MyCRC, ReceivedCRC]));

  result := MyCRC = ReceivedCRC;
end;

// DACO-M 1000(A,P,S) �ּ� ���
class function TModbus.GetAddress(AID: Byte; ADevice: String): UInt16;
var
  Index: Integer;
begin
  // DACO-M 1000E �ּ� ���
  if ADevice = TDacoM.DEVICE_1000E then
    result := TModbus.ZERO_ADDRESS + (TModbus.MODULE_OFFSET * (AID - 1)) // ���� ���
  else if ADevice = TDacoM.DEVICE_1000APS then
  begin
    // 1,4,7...55,58
    // 128,131...182,185
    Index := (AID div 3);
    if AID >= 128 then
      Index := Index - 22;
    result := TModbus.ZERO_ADDRESS + (TModbus.MODULE_OFFSET * Index);
  end
  else
    raise Exception.Create('Unknown Device,' + ADevice);
end;

class function TModbus.GetProtocolType(const ABuff: TIdBytes): TProtocolType;
var
  ByteCount: Integer;
  Received: Integer;
begin
  result := ptUnknown;
  if Length(ABuff) < 2 then
    Exit;

  Received := Length(ABuff);
  ByteCount := ABuff[2];

  if (ABuff[0] = TModbus.IDTABLE_UNITID) and (Received >= SizeOf(TIDTable)) then
    result := ptIDTable
  else if (ABuff[0] = TModbus.POWER_UNIT_ID) and (Received >= SizeOf(TPowerModule)) then
    result := ptPowerModule
  else if (ByteCount = SizeOf(TDataPart1)) and (Received >= SizeOf(TModulePart1)) then
    result := ptModulePart1
  else if (ByteCount = SizeOf(TDataPart2)) and (Received >= SizeOf(TModulePart2)) then
    result := ptModulePart2
  else if (ByteCount = SizeOf(TIDArray40)) and (Received >= SizeOf(TIDTable)) then
    result := ptCheck // ReadConfig���� ���
  else if (ABuff[1] = TModbus.ERROR_CODE) and (Received >= SizeOf(TErrorCode)) then
    result := ptError;

end;

class function TModbus.InvalidDataLen(ALen: Integer): Boolean;
begin
  result := (ALen <> SizeOf(TIDTable)) and (ALen <> SizeOf(TModulePart1)) //
    and (ALen <> SizeOf(TModulePart2)) and (ALen <> SizeOf(TPowerModule)) //
    and (ALen <> SizeOf(TErrorCode));
end;

class function TModbus.TcpCommand(const AParam: TRequestParam): TIdBytes;
begin
  SetLength(result, Length(MBAP));
  CopyMemory(@result[0], @MBAP[0], Length(MBAP));
  AppendBytes(result, AParam.GetCommand(READ_REGISTER));
end;

class function TModbus.SerialCommand(const AParam: TRequestParam): TIdBytes;
var
  MyCRC: UInt16;
begin
  result := AParam.GetCommand(READ_REGISTER);
  MyCRC := ModbusCRC16(result);
  AppendBytes(result, ToBytes(MyCRC));
end;

{ TRequestParam }

constructor TRequestParam.Create(AID: Byte; AAddr, ALen: UInt16);
begin
  Self.ID := AID;
  Self.Addr := AAddr;
  Self.Len := ALen;
end;

function TRequestParam.GetCommand(FC: Byte): TIdBytes;
begin
  SetLength(result, 0);
  AppendByte(result, Self.ID); // unit_id
  AppendByte(result, FC); // FC
  AppendBytes(result, ToBytes(Rev2Bytes(Self.Addr))); // �����ּ�
  AppendBytes(result, ToBytes(Rev2Bytes(Self.Len))); // ����
end;

{ TPowerData }

procedure TPowerData.Reverse;
begin
  RevEveryWord(@Self, SizeOf(Self));
end;

{ TDataPart1 }

procedure TDataPart1.Reverse;
begin
  RevEveryWord(@Self, SizeOf(Self));
end;

{ TDataPart2 }

procedure TDataPart2.Reverse;
begin
  RevEveryWord(@Self, SizeOf(Self));
end;

{ TMBAP }

procedure TMBAP.Reverse;
begin
  RevEveryWord(@Self, SizeOf(Self));
end;

end.
