program QscdServer;

uses
  Vcl.Forms,
  _fmMain in 'View\_fmMain.pas' {fmMain};

{$R *.res}

begin
  {
    // �ߺ� ������ �������� Ȱ��ȭ �Ͻÿ�.
    if not JclAppInstances.CheckInstance(1) then
    begin
    MessageBox(0, '���α׷��� �̹� �������Դϴ�.', 'Ȯ��', MB_ICONEXCLAMATION);
    JclAppInstances.SwitchTo(0);
    JclAppInstances.KillInstance;
    end;
  }

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfmMain, fmMain);
  Application.Run;

end.
