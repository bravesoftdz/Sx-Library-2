object fSplash: TfSplash
  Left = 427
  Top = 333
  Cursor = crHourGlass
  HorzScrollBar.Tracking = True
  HorzScrollBar.Visible = False
  VertScrollBar.Tracking = True
  VertScrollBar.Visible = False
  BorderIcons = []
  BorderStyle = bsNone
  ClientHeight = 384
  ClientWidth = 512
  Color = clBtnFace
  ParentFont = True
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnHide = FormHide
  OnMouseDown = FormMouseDown
  OnMouseMove = FormMouseMove
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object LabelState: TSxLabel
    Left = 0
    Top = 0
    Width = 3
    Height = 13
    Transparent = True
  end
  object Timer1: TTimer
    Interval = 40
    OnTimer = Timer1Timer
    Left = 16
    Top = 8
  end
end