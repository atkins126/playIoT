{
  �ǽð� ���� ������ ��� ������

  -ä�� �� ������ �ϳ�
}


unit ChThread;

interface

uses Classes, Windows, SysUtils, StdCtrls, Dialogs, Forms, DataList;

type
  TChThread = class(TThread)
  private
    FData: TDataCollection;
    Log: TStrings;
    procedure GetData;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
  end;


implementation

{ TChThread }

constructor TChThread.Create;
begin
  OutputDebugString('TChThread.Create');
  inherited Create(true);

  FreeOnTerminate := true;

  FData := TDataCollection.Create;
end;

destructor TChThread.Destroy;
begin
  OutputDebugString('TSysChkThread.Destroy;');
  FData.Free;
//  inherited;
end;

procedure TChThread.Execute;
begin
  inherited;

  try
    //while not Terminated do
    while true do
      begin
        OutputDebugString('TChThread.Execute');

        InsertDataToDB;
        try
          WaitForSingleObject(Handle, 500);   // 1�� �ֱ�� ����
        except
        end;
        Application.ProcessMessages;
      end;
  except
  end;
  OutputDebugString('End of TChThread.Execute');
end;

procedure TChThread.GetData;
begin

end;


end.
