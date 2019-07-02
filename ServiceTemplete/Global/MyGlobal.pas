unit MyGlobal;

interface

uses
  Classes, SysUtils, IOUtils, JdcGlobal;

const
  PROJECT_CODE = 'playIoT';
  SERVICE_CODE = 'playIoTSvc';
  SERVICE_NAME = 'playIoT Service Application Templete';
  SERVICE_DESCRIPTION = '여기에 Service Application의 설명을 넣으세요.';

type
  TGlobal = class(TGlobalAbstract)
  protected
    procedure SetExeName(const Value: String); override;
  public
    constructor Create; override;
    destructor Destroy; override;

    class function Obj: TGlobal;

    procedure Initialize; override;
    procedure Finalize; override;
  end;

implementation

uses MyOption;

var
  MyObj: TGlobal = nil;

  { TGlobal }

constructor TGlobal.Create;
begin
  inherited;

  // TODO : after create
end;

destructor TGlobal.Destroy;
begin
  // TODO : before Finalize

  inherited;
end;

procedure TGlobal.Finalize;
begin
  if FIsfinalized then
    Exit;


  // Todo :

  inherited;
  FIsfinalized := true;
end;

procedure TGlobal.Initialize;
begin
  if FIsfinalized then
    Exit;
  if FIsInitialized then
    Exit;
  FIsInitialized := true;

  inherited;

  FUseDebug := TOption.Obj.UseDebug;
end;

class function TGlobal.Obj: TGlobal;
begin
  if MyObj = nil then
    MyObj := TGlobal.Create;
  result := MyObj;
end;

procedure TGlobal.SetExeName(const Value: String);
begin
  FExeName := Value;
  FLogName := ChangeFileExt(FExeName, '.log');

  if not TDirectory.Exists(ExtractFilePath(FLogName)) then
    TDirectory.CreateDirectory(ExtractFilePath(FLogName));

  FAppCode := TOption.Obj.AppCode;
  FProjectCode := TOption.Obj.ProjectCode;
  FUseCloudLog := TOption.Obj.UseCloudLog;
  FLogServer := TOption.Obj.LogServer;
end;

initialization

MyObj := TGlobal.Create;

end.
