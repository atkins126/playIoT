// *******************************************************
//
// Micron Optics x55 Protocol Common Library
//
// Copyright(c) 2019 playIoT.
//
// jsf3rd@playiot.biz
//
// http://www.micronoptics.com/product/optical-sensing-instrument-si255/#tab-software
//
// *******************************************************

unit JdcSIx55.Common;

interface

uses System.Classes, System.SysUtils, IdGlobal, JdcGlobal;

const
  H_MAX_NUM_CHANNELS = 16;

  H_CMD_PORT = 51971;
  H_PEAK_STREAM_PORT = 51972;
  H_SPECTRUM_STREAM_PORT = 51973;
  H_DEFAULT_TIMEOUT = 10000;

  H_SUCCESS = 0;

  // ---------- Hyperion Write Command Request Options ----------
  REQUEST_OPT_NONE = 0;
  REQUEST_OPT_SUPPRESS_MSG = 1;
  REQUEST_OPT_SUPPRESS_CONTENT = 2;
  REQUEST_OPT_COMPRESS = 4;

type
  TUInt16Array16 = array [1 .. H_MAX_NUM_CHANNELS] of UInt16;

  {
    header that is written out before every command

    @field requestOption uint8_t containing flags that determine the output format returned from the instrument.
    @field reserved uint8_t reserved for future use.
    @field commandSize uint16_t the number of bytes in the command to be written.
    @field argSize uint32_t the number of bytes in the argument to be written.
  }
  TWriteHeader = packed record
    requestOption: UInt8;
    reserved: UInt8;
    commandSize: UInt16;
    argSize: UInt32;
  end;

  {
    header that is received with every response from the instrument

    @field status uint8_t The status of the command execution.
    @field requestOptionEcho uint8_t A copy of the request option that was originally sent to the instrument when the command was written.
    @field messageLength uint16_t The length of the returned message, in bytes.
    @field contentLength uint32_t The length of the returned content, in bytes.
  }
  TReadHeader = packed record
    status: UInt8;
    requestOptionEcho: UInt8;
    messageLength: UInt16;
    contentLength: UInt32;
  end;

  {
    Encapsulates the returned response from an executed command.

    @field messageLength uint16_t The length of the returned message, in bytes.
    @field message string containing the human-readable message that is returned from the instrument.
    @field contentLength uint32_t The length of the returned content, in bytes.
    @field content Pointer to a buffer containing the returned data.
  }
  TResponse = packed record
    messageLength: UInt16;
    msg: string;
    contentLength: UInt32;
    content: TIdBytes;
  end;

  {
    Header data returned with each call to Hyperion.get_peaks or Hyperion.stream_peaks

    @field length uint16_t The lenght of the header.
    @field version The version of the header implementation.
    @field reserved Reserved for future use.
    @field serialNumber uint64_t Sequential number assigned to each sample of peak data.
    @field timeStampInt Timestamp for data, expressed as number of seconds since 00:00:00, Jan. 1, 1970
    @field timeStampFrac Number of nanoseconds elapsed after timeStampInt
    @field peakCounts Number of peaks detected for each channel
  }
  TPeaksHeader = record
    length: UInt16;
    version: UInt16;
    reserved: UInt32;
    serialNumber: UInt64;
    timeStampInt: UInt32;
    timeStampFrac: UInt32;
    peakCounts: TUInt16Array16;
  end;

  // Peak data returned from a call to Hyperion.get_peaks() or Hyperion.stream_peaks()
  TPeaks = record
    startInds: TUInt16Array16;
    endInds: TUInt16Array16;

    peaks: TArray<Double>;
    numPeaks: UInt16;
    timeStamp: TDateTime;
    serialNumber: UInt64;
    constructor Create(AHeader: TPeaksHeader; AData: TIdBytes);
    function GetChannelData(ANum: Integer): TArray<Double>;
    function GetChannelNum(AIndex: Integer): Integer;
  end;

implementation

{ TPeaks }

constructor TPeaks.Create(AHeader: TPeaksHeader; AData: TIdBytes);
var
  I, J: Integer;
  Index: Integer;
  Stream: TStream;
  tmp: Double;
begin
  serialNumber := AHeader.serialNumber;
  timeStamp := AHeader.timeStampInt + AHeader.timeStampFrac * 1E-9;

  Stream := TBytesStream.Create();
  Stream.WriteBuffer(AData[0], length(AData));
  Stream.Position := 0;

  numPeaks := length(AData) div SizeOf(Double);
  SetLength(peaks, numPeaks);

  Index := 1;
  for I := Low(AHeader.peakCounts) to High(AHeader.peakCounts) do
  begin
    startInds[I] := Index;
    for J := 1 to AHeader.peakCounts[I] do
    begin
      Stream.ReadData(tmp);
      peaks[Index] := tmp;
      Inc(Index);
    end;
    endInds[I] := Index - 1;
  end;
end;

function TPeaks.GetChannelData(ANum: Integer): TArray<Double>;
var
  I: Integer;
begin
  SetLength(result, Self.endInds[ANum] - Self.startInds[ANum] + 1);
  for I := Low(result) to High(result) do
  begin
    result[I] := peaks[Self.startInds[ANum] + I];
  end;
end;

function TPeaks.GetChannelNum(AIndex: Integer): Integer;
var
  I: Integer;
begin
  result := -1;
  for I := 1 to H_MAX_NUM_CHANNELS do
  begin
    if (Self.startInds[I] <= AIndex) and (Self.endInds[I] >= AIndex) then
      result := I;
  end;
end;

end.
