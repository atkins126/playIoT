// *******************************************************
//
// Real Singleton Templete
//
// Copyright(c) 2020.
//
// jsf3rd@nate.com
//
// *******************************************************

unit JdcSingleton;

interface

uses System.Classes, System.SysUtils;

type
  // ������ �ܺ� ���� ����
  // Constructor Block external access
  THideConstructor = class abstract
  strict protected
    constructor Create; virtual; abstract;
  end;

  // ������ Overload�� ���ؼ� Create; �Լ� ������ TObject���� THideConstructor�� ��ȯ
  // Create�Լ��� procedure�� �����ؼ� class ȣ�� ���� - TMySingle.Create('string') ȣ�� �Ұ�

  // Switching the access to the Create function THideConstructor in TObject through the constructor Overloading
  // Declaring Create Method as a procedure to prevent class call-TMySingle.Create('string') call impossible
  TOverloadConstructor = class(THideConstructor)
  public
    procedure Create(s: string); reintroduce; overload; deprecated 'null method';
  end;

  TMySingleton = class sealed(TOverloadConstructor)
  private
    class var MyObj: TMySingleton;
  strict protected
    // TOberloadConstructor.Create(s: string); ����
    // THideConstructor.Create ��üȭ

    // Hiding TOberloadConstructor.Create(s: string);
    // Implement THideConstructor.Create
    constructor Create; override;
  public
    class function Obj: TMySingleton;
    function Echo(const value: string): String;
  end;

implementation

{ TMySingleton }

constructor TMySingleton.Create;
begin
  // TODO
end;

function TMySingleton.Echo(const value: string): String;
begin
  result := value;
end;

class function TMySingleton.Obj: TMySingleton;
begin
  if MyObj = nil then
    MyObj := Self.Create;
  result := MyObj;
end;

{ TOverloadContructor }

procedure TOverloadConstructor.Create(s: string);
begin
  // null method
end;

initialization

TMySingleton.MyObj := nil;

finalization

if Assigned(TMySingleton.MyObj) then
  FreeAndNil(TMySingleton.MyObj);

end.
