{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvDlg.PAS, released on 2002-07-04.

The Initial Developers of the Original Code are: Andrei Prygounkov <a.prygounkov@gmx.de>
Copyright (c) 1999, 2002 Andrei Prygounkov
All Rights Reserved.

Contributor(s):                
Zinvob
boerema

Last Modified: 2003-03-17

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://jvcl.sourceforge.net

components  : TProgressForm
description : dialog components

Known Issues:
-----------------------------------------------------------------------------}

{$I JVCL.INC}

unit JvProgressComponent;

interface

uses
  Windows, Messages, SysUtils, Classes,
  Controls, Forms, StdCtrls, ComCtrls,
  JvComponent;

type
  TJvProgressComponent = class(TJvComponent)
  private
    FForm: TForm;
    FProgressBar: TProgressBar;
    FLabel1: TLabel;
    FCaption: TCaption;
    FInfoLabel: TCaption;
    FOnShow: TNotifyEvent;
    FCancel: Boolean;
    FProgressMin: Integer;
    FProgressMax: Integer;
    FProgressStep: Integer;
    FProgressPosition: Integer;
    FException: Exception;
    procedure SetCaption(ACaption: TCaption);
    procedure SetInfoLabel(ACaption: TCaption);
    procedure FormOnShow(Sender: TObject);
    procedure FormOnCancel(Sender: TObject);
    procedure SetProgress(Index: Integer; AValue: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Execute;
    procedure ProgressStepIt;
    property Cancel: Boolean read FCancel;
  published
    property Caption: TCaption read FCaption write SetCaption;
    property InfoLabel: TCaption read FInfoLabel write SetInfoLabel;
    property ProgressMin: Integer index 0 read FProgressMin write SetProgress default 0;
    property ProgressMax: Integer index 1 read FProgressMax write SetProgress default 100;
    property ProgressStep: Integer index 2 read FProgressStep write SetProgress default 1;
    property ProgressPosition: Integer index 3 read FProgressPosition write SetProgress default 0;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
  end;

implementation

uses
  JvResources;

type
  TJvProgressForm = class(TForm)
  private
    procedure WMUser1(var Msg: TMessage); message WM_USER + 1;
  end;

function ChangeTopException(E: TObject): TObject;
type
  PRaiseFrame = ^TRaiseFrame;
  TRaiseFrame = record
    NextRaise: PRaiseFrame;
    ExceptAddr: Pointer;
    ExceptObject: TObject;
    //ExceptionRecord: PExceptionRecord;
  end;
begin
  { C++ Builder 3 Warning !}
  { if linker error occured with message "unresolved external 'System::RaiseList'" try
    comment this function implementation, compile,
    then uncomment and compile again. }
  {$IFDEF VCL}
  {$IFDEF COMPILER6_UP}
  {$WARN SYMBOL_DEPRECATED OFF}
  {$ENDIF}
  if RaiseList <> nil then
  begin
    Result := PRaiseFrame(RaiseList)^.ExceptObject;
    PRaiseFrame(RaiseList)^.ExceptObject := E
  end
  else
    Result := nil;
  {$ENDIF VCL}
  {$IFDEF LINUX}
  // XXX: changing exception in stack frame is not supported on Kylix
  Writeln('ChangeTopException');
  Result := E;
  {$ENDIF LINUX}
end;

//=== TJvProgressComponent ===================================================

constructor TJvProgressComponent.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProgressMin := 0;
  FProgressMax := 100;
  FProgressStep := 1;
  FProgressPosition := 0;
end;

destructor TJvProgressComponent.Destroy;
begin
  FForm.Free;
  inherited Destroy;
end;

procedure TJvProgressComponent.Execute;
begin
  {$IFDEF BCB}
  if not Assigned(FForm) then
    FForm := TJvProgressForm.CreateNew(Self, 1);
  {$ELSE}
  if not Assigned(FForm) then
    FForm := TJvProgressForm.CreateNew(Self);
  {$ENDIF BCB}
  try
    FForm.Caption := Caption;
    with FForm do
    begin
      ClientWidth := 307;
      ClientHeight := 98;
      BorderStyle := bsDialog;
      Position := poScreenCenter;
      FProgressBar := TProgressBar.Create(FForm);
    end;
    with FProgressBar do
    begin
      Parent := FForm;
      if FProgressMin > Max then
      begin
        Max := FProgressMax;
        Min := FProgressMin;
      end
      else
      begin
        Min := FProgressMin;
        Max := FProgressMax;
      end;
      SetBounds(8, 38, 292, 18);
      if FProgressStep = 0 then
        FProgressStep := 1;
      Step := FProgressStep;
      Position := FProgressPosition;
    end;
    FLabel1 := TLabel.Create(FForm);
    with FLabel1 do
    begin
      Parent := FForm;
      Caption := InfoLabel;
      AutoSize := False;
      SetBounds(8, 8, 293, 13);
    end;
    with TButton.Create(FForm) do
    begin
      Parent := FForm;
      Caption := RsButtonCancelCaption;
      SetBounds(116, 67, 75, 23);
      OnClick := FormOnCancel;
    end;
    FCancel := False;
    if Assigned(FOnShow) then
    begin
      FForm.OnShow := FormOnShow;
      FException := nil;
      FForm.ShowModal;
      if FException <> nil then
        raise FException;
    end
    else
      FForm.Show;
  finally
    if Assigned(FOnShow) then
      FreeAndNil(FForm);
  end;
end;

procedure TJvProgressComponent.FormOnShow(Sender: TObject);
begin
  PostMessage(FForm.Handle, WM_USER + 1, Integer(Self), 0);
end;

procedure TJvProgressComponent.FormOnCancel(Sender: TObject);
begin
  FCancel := True;
end;

procedure TJvProgressForm.WMUser1(var Msg: TMessage);
begin
  Application.ProcessMessages;
  try
    try
      (TJvProgressComponent(Msg.WParam)).FOnShow(Self);
//      (Owner as TJvProgressComponent).FOnShow(Self);
    except
      on E: Exception do
      begin
        (Owner as TJvProgressComponent).FException := E;
        ChangeTopException(nil);
      end;
    end;
  finally
    ModalResult := mrOk;
  end;
end;

procedure TJvProgressComponent.SetCaption(ACaption: TCaption);
begin
  FCaption := ACaption;
  if FForm <> nil then
    FForm.Caption := FCaption;
end;

procedure TJvProgressComponent.SetInfoLabel(ACaption: TCaption);
begin
  FInfoLabel := ACaption;
  if FForm <> nil then
    FLabel1.Caption := ACaption;
end;

procedure TJvProgressComponent.SetProgress(Index: Integer; AValue: Integer);
begin
  case Index of
    0:
      begin
        FProgressMin := AValue;
        if FForm <> nil then
          FProgressBar.Min := FProgressMin;
      end;
    1:
      begin
        FProgressMax := AValue;
        if FForm <> nil then
          FProgressBar.Max := FProgressMax;
      end;
    2:
      begin
        FProgressStep := AValue;
        if FForm <> nil then
          FProgressBar.Step := FProgressStep;
      end;
    3:
      begin
        FProgressPosition := AValue;
        if FForm <> nil then
          FProgressBar.Position := FProgressPosition;
      end;
  end;
end;

procedure TJvProgressComponent.ProgressStepIt;
begin
  if FForm <> nil then
    FProgressBar.StepIt;
end;

end.

