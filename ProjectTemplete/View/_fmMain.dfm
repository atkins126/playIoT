object fmMain: TfmMain
  Left = 0
  Top = 0
  Caption = 'Templete Form'
  ClientHeight = 462
  ClientWidth = 684
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ActionList: TActionList
    Left = 56
    Top = 24
    object actAbout: TAction
      Caption = '&About'
      OnExecute = actAboutExecute
    end
  end
end
