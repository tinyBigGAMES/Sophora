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

unit Sophora.Tools;

{$I Sophora.Defines.inc}

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Sophora.Utils,
  Sophora.Common;

const
  { WebSearch API Key environment variable name }
  CsoWebSearchApiKeyEnvVar = 'TAVILY_API_KEY';

type
  { TsoPrompt }
  TsoPrompt = record
    ID: string;
    Description: string;
    Prompt: string;
  end;

  { TsoPromptDatabase }
  TsoPromptDatabase = class(TsoBaseObject)
  protected
    FPrompts: TDictionary<string, TsoPrompt>;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function  LoadFromFile(const AFilename: string): Boolean;
    function  SaveToFile(const AFilename: string): Boolean;
    procedure AddPrompt(const AID, ADescription, APrompt: string);
    function  GetPrompt(const AID: string; out APrompt: TsoPrompt): Boolean;
    function  GetPrompts(): TArray<TsoPrompt>;
    procedure RemovePrompt(const AID: string);
  end;

  { TsoWebSearch }
  TsoWebSearch = class(TsoBaseObject)
  protected
  var
    FResponse: string;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function Query(const AQuery: string): Boolean;
    function Response(): string;
  end;

implementation

{ TsoPromptDatabase }
constructor TsoPromptDatabase.Create();
begin
  inherited;

  FPrompts := TDictionary<string, TsoPrompt>.Create;
end;

destructor TsoPromptDatabase.Destroy;
begin
  FPrompts.Free;

  inherited;
end;

function TsoPromptDatabase.LoadFromFile(const AFilename: string): Boolean;
var
  LFilename: string;
  LStringList: TStringList;
  LItem, LLine: string;
  LPrompt: TsoPrompt;
  LIsReadingPrompt: Boolean;
begin
  Result := False;

  LFilename := TPath.ChangeExtension(AFilename, 'txt');

  if not TFile.Exists(LFilename) then Exit;

  LStringList := TStringList.Create();
  try
    LStringList.LoadFromFile(LFilename, TEncoding.UTF8);
    FPrompts.Clear;
    LIsReadingPrompt := False;
    LPrompt.ID := '';
    LPrompt.Description := '';
    LPrompt.Prompt := '';

    for LItem in LStringList do
    begin
      LLine := LItem.Trim; // Assign trimmed value to Line

      // Ignore comments and empty lines
      if (not LIsReadingPrompt) and (LLine.IsEmpty)  then
        continue;

      if LLine.StartsWith(';') then
        continue;

      if LLine = '---' then
      begin
        if (LPrompt.ID <> '') and (LPrompt.Description <> '') then
          FPrompts.AddOrSetValue(LPrompt.ID, LPrompt); // Store previous record

        LPrompt.ID := '';
        LPrompt.Description := '';
        LPrompt.Prompt := '';
        LIsReadingPrompt := False;
      end
      else if LLine.StartsWith('ID: ') then
      begin
        LPrompt.ID := Copy(LLine, 5, Length(LLine)).Trim(); // Extract ID
        LIsReadingPrompt := False;
      end
      else if LLine.StartsWith('Description: ') then
      begin
        LPrompt.Description := Copy(LLine, 13, Length(LLine)).Trim(); // Extract description
        LIsReadingPrompt := False;
      end
      else if LLine.StartsWith('Prompt: |') then
      begin
        LIsReadingPrompt := True;
        LPrompt.Prompt := '';
      end
      else if LIsReadingPrompt then
      begin
        if LPrompt.Prompt <> '' then
          LPrompt.Prompt := LPrompt.Prompt + sLineBreak;
        LPrompt.Prompt := LPrompt.Prompt + LLine;
      end;
    end;

    // Add last record if valid
    if (LPrompt.ID <> '') and (LPrompt.Description <> '') then
      FPrompts.AddOrSetValue(LPrompt.ID, LPrompt);

    Result := True;

  finally
    LStringList.Free();
  end;
end;

function TsoPromptDatabase.SaveToFile(const AFilename: string): Boolean;
var
  LFilename: string;
  LStringList: TStringList;
  LPrompt: TsoPrompt;
begin
  Result := False;

  if AFilename.IsEmpty then Exit;

  LFilename := TPath.ChangeExtension(AFilename, 'txt');

  LStringList := TStringList.Create;
  try
    for LPrompt in FPrompts.Values do
    begin
      LStringList.Add('---');
      LStringList.Add('ID: ' + LPrompt.ID);
      LStringList.Add('Description: ' + LPrompt.Description);
      LStringList.Add('Prompt: |');
      LStringList.Add(LPrompt.Prompt);
      LStringList.Add('');
    end;

    LStringList.SaveToFile(LFilename, TEncoding.UTF8);

    Result := TFile.Exists(LFilename);
  finally
    LStringList.Free;
  end;
end;

procedure TsoPromptDatabase.AddPrompt(const AID, ADescription, APrompt: string);
var
  LPrompt: TsoPrompt;
begin
  LPrompt.ID := AID;
  LPrompt.Description := ADescription;
  LPrompt.Prompt := APrompt;
  FPrompts.AddOrSetValue(AID, LPrompt);
end;

function TsoPromptDatabase.GetPrompt(const AID: string; out APrompt: TsoPrompt): Boolean;
begin
  Result := FPrompts.TryGetValue(AID, APrompt);
end;

function TsoPromptDatabase.GetPrompts: TArray<TsoPrompt>;
begin
  Result := FPrompts.Values.ToArray;
end;

procedure TsoPromptDatabase.RemovePrompt(const AID: string);
begin
  if not FPrompts.ContainsKey(AID) then
  begin
    SetError('Prompt with ID %s not found.', [AID]);
    Exit;
  end;

  FPrompts.Remove(AID);
end;

{ TsoWebSearch }
constructor TsoWebSearch.Create();
begin
  inherited;
end;

destructor TsoWebSearch.Destroy();
begin
  inherited;
end;

function TsoWebSearch.Query(const AQuery: string): Boolean;
var
  LApiKey: string;
  LResponse: string;
begin
  Result := False;

  LApiKey := soUtils.GetEnvVarValue(CsoWebSearchApiKeyEnvVar);
  if LApiKey.IsEmpty then
  begin
    SetError('WebSearch API key is empty', []);
    Exit;
  end;

  LResponse := soUtils.TavilyWebSearch(LApiKey, AQuery);
  if LResponse.IsEmpty then
  begin
    SetError('No websearch response', []);
    Exit;
  end;

  FResponse := LResponse;

  Result := True;
end;

function TsoWebSearch.Response(): string;
begin
  Result := FResponse;
end;

end.
