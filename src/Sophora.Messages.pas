{===============================================================================
  ___           _
 / __| ___ _ __| |_  ___ _ _ __ _ ™
 \__ \/ _ \ '_ \ ' \/ _ \ '_/ _` |
 |___/\___/ .__/_||_\___/_| \__,_|
          |_|
 AI Reasoning, Function-calling &
       Knowledge Retrieval

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/Sophora

 See LICENSE file for license information
===============================================================================}

unit Sophora.Messages;

{$I Sophora.Defines.inc}

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  Sophora.CLibs,
  Sophora.Utils,
  Sophora.Common;

const
  soSystem    = 'system';
  soUser      = 'user';
  soAssistant = 'assistant';
  soTool      = 'tool';

type

  { TsoMessages }
  TsoMessages = class(TsoBaseObject)
  protected
    FList: TStringList;
    FLastUser: string;
    FAddEnd: Boolean;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Clear(); virtual;
    procedure AddRaw(const AContent: string); virtual;
    procedure Add(const ARole, AContent: string); virtual;
    procedure AddEnd(); virtual;
    function  Prompt(): string; virtual;
    function  IsEmpty: Boolean; virtual;
    function  LastUser(): string;
  end;

implementation

{ TsoMessages }
constructor TsoMessages.Create();
begin
  inherited;
  FList := TStringList.Create();
end;

destructor TsoMessages.Destroy();
begin
  FList.Free();
  inherited;
end;

procedure TsoMessages.Clear();
begin
  FList.Clear();
  FLastUser := '';
  FAddEnd := False;
end;

procedure TsoMessages.AddRaw(const AContent: string);
var
  LContent: string;
begin
  LContent := AContent.Trim();
  if LContent.IsEmpty then Exit;

  FList.Add(AContent.Trim);
end;

procedure TsoMessages.Add(const ARole, AContent: string);
var
  LRole: string;
  LContent: string;
  LMsg: string;
begin
  LRole := ARole.Trim();
  LContent := AContent.Trim();

  if LRole.IsEmpty then Exit;
  if LContent.IsEmpty then Exit;

  if SameText(LRole, soSystem) then
    begin
      LMsg := '<|start_header_id|>system<|end_header_id|>\n' + LContent + '<|eot_id|>';
      FAddEnd := False;
    end
  else
  if SameText(LRole, soUser) then
    begin
      LMsg := '<|start_header_id|>user<|end_header_id|>\n' + LContent + '<|eot_id|>';
      FLastUser := LContent;
      FAddEnd := True;
    end
  else
  if SameText(LRole, soAssistant) then
    begin
      LMsg := '<|start_header_id|>assistant<|end_header_id|>\n' + LContent + '<|eot_id|>';
      FAddEnd := False;
    end
  else
  if SameText(LRole, soTool) then
    begin
      LMsg := '<|start_header_id|>tool<|end_header_id|>\n' + LContent + '<|eot_id|>';
      FAddEnd := True;
    end;

  AddRaw(LMsg);
end;

procedure TsoMessages.AddEnd();
begin
  if FAddEnd then
    AddRaw('<|start_header_id|>assistant<|end_header_id|>');
end;

function  TsoMessages.Prompt(): string;
var
  LItem: string;
begin
  Result := '';
  for LItem in FList do
  begin
    Result := Result + LItem + ' ';
  end;
  Result := Result.Trim();
end;

function  TsoMessages.IsEmpty: Boolean;
begin
  Result := Prompt().IsEmpty;
end;

function  TsoMessages.LastUser(): string;
begin
  Result := FLastUser;
end;


end.
