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
  System.Rtti,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.RegularExpressions,
  Sophora.Utils,
  Sophora.Common,
  Sophora.Messages,
  Sophora.Inference;

const
  { WebSearch API Key environment variable name }
  CsoWebSearchApiKeyEnvVar = 'TAVILY_API_KEY';

  CsoDeepThinkID    = 'DeepThink';
  CsoToolCallID     = 'ToolCall';
  CsoToolResponseID = 'ToolResponse';
  CsoVectorSearchID = 'VectorSearchResponse';

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
    procedure Clear();
    function  Count(): Integer;
    function  Load(const APrompts: TsoPromptDatabase): Boolean;
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

  { TsoParamArg }
  TsoParamArg = TPair<string, string>;

  { TsoParams }
  TsoParams = TDictionary<string, string>;

  { TsoToolCall }
  TsoToolCall = class
  private
    FFuncName: string;
    FParams: TsoParams;
    FClass: TClass;
  public
    constructor Create(const AFuncName: string);
    destructor Destroy(); override;
    procedure SetClass(const AClass: TClass);
    function  GetClass(): TClass;
    property FuncName: string read FFuncName;
    property Params: TsoParams read FParams;
  end;

  { TsoToolCalls }
  TsoToolCalls = TArray<TsoToolCall>;

  TsoTools = class;

  { TsoToolCallEvent }
  TsoToolCallEvent = reference to procedure(const ATools: TsoTools; const AMessages: TsoMessages; const AInference: TsoInference; const AFunctionCall: TsoToolCall);

  { TsoTools }
  TsoTools = class(TsoBaseObject)
  protected type
    TTool = record
      Name: string;
      Schema: string;
      ToolCallEvent: TsoToolCallEvent;
      Class_: TClass;
    end;
  protected
    FList: TDictionary<string, TTool>;
    FPrompts: TsoPromptDatabase;
    function  ParseToolCalls(const AInput: string): TsoToolCalls;
    procedure FreeFunctionCalls(var AFuncCalls: TsoToolCalls);
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function  GetPrompts(): TsoPromptDatabase;
    procedure SetPrompts(const APrompts: TsoPromptDatabase);
    procedure Clear();
    function  Add(const AClass: TClass; const AMethodName: string; const AToolcallEvent: TsoToolCallEvent): Boolean;
    function  Count(): Integer;
    function  CallPrompt(): string;
    function  ResponsePrompt(const AQuestion, AResponse: string): string;
    procedure Call(const AMessages: TsoMessages; const AInference: TsoInference; const AInput: string);
    function  CallTool(const AClass: TClass; const AMethodName: string; const AArgs: array of TValue): TValue;

    function  WebSearch(const AQuestion: string): string;
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

procedure TsoPromptDatabase.Clear();
begin
  FPrompts.Clear();
end;

function  TsoPromptDatabase.Count(): Integer;
begin
  Result := FPrompts.Count;
end;

function  TsoPromptDatabase.Load(const APrompts: TsoPromptDatabase): Boolean;
var
  LPrompts: TArray<TsoPrompt>;
  LPrompt: TsoPrompt;
begin
  Result := False;
  if not Assigned(APrompts) then Exit;
  if APrompts.Count() = 0 then Exit;

  Clear();

  LPrompts := APrompts.GetPrompts();

  for LPrompt in LPrompts do
  begin
    AddPrompt(LPrompt.ID, LPrompt.Description, LPrompt.Prompt);
  end;

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

{ TsoToolCall }
constructor TsoToolCall.Create(const AFuncName: string);
begin
  FFuncName := AFuncName;
  FParams := TDictionary<string, string>.Create;
end;

destructor TsoToolCall.Destroy;
begin
  FParams.Free;
  inherited;
end;

procedure TsoToolCall.SetClass(const AClass: TClass);
begin
  FClass := AClass;
end;

function  TsoToolCall.GetClass(): TClass;
begin
  Result := FClass;
end;

{ TsoTools }
function  TsoTools.ParseToolCalls(const AInput: string): TsoToolCalls;
var
  LRegex, LParamRegex: TRegEx;
  LMatches, LParamMatches: TMatchCollection;
  LMatch, LParamMatch: TMatch;
  LFuncList: TList<TsoToolCall>;
  LFuncCall: TsoToolCall;
  LParamStr, LParamKey, LParamValue: string;
  LParams: TStringList;
begin
  LRegex := TRegEx.Create('(\w+)\(([^)]*)\)');
  LParamRegex := TRegEx.Create('(\w+)\s*=\s*"?([^"]+?)"?(?=,|$)');
  LMatches := LRegex.Matches(AInput);
  LFuncList := TList<TsoToolCall>.Create;

  for LMatch in LMatches do
  begin
    LFuncCall := TsoToolCall.Create(LMatch.Groups[1].Value);
    LParams := TStringList.Create;
    try
      LParamStr := LMatch.Groups[2].Value;
      LParamMatches := LParamRegex.Matches(LParamStr);

  for LParamMatch in LParamMatches do
      begin
        LParamKey := LParamMatch.Groups[1].Value;
        LParamValue := LParamMatch.Groups[2].Value;
        LFuncCall.FParams.Add(LParamKey, LParamValue);
      end;
      LFuncList.Add(LFuncCall);
    except
      LFuncCall.Free;
    end;
    LParams.Free;
  end;

  Result := LFuncList.ToArray;
  LFuncList.Free;
end;

procedure TsoTools.FreeFunctionCalls(var AFuncCalls: TsoToolCalls);
var
  I: Integer;
begin
  for I := Low(AFuncCalls) to High(AFuncCalls) do
    AFuncCalls[I].Free;
  SetLength(AFuncCalls, 0);
end;

constructor TsoTools.Create();
begin
  inherited;
  FList := TDictionary<string, TTool>.Create();
  FPrompts := TsoPromptDatabase.Create();
end;

destructor TsoTools.Destroy();
begin
  FPrompts.Free();
  FList.Free();
  inherited;
end;

function  TsoTools.GetPrompts(): TsoPromptDatabase;
begin
  Result := FPrompts;
end;

procedure TsoTools.SetPrompts(const APrompts: TsoPromptDatabase);
begin
  FPrompts.Load(APrompts);
end;

procedure TsoTools.Clear();
begin
  FList.Clear();
end;

function  TsoTools.Add(const AClass: TClass; const AMethodName: string; const AToolcallEvent: TsoToolCallEvent): Boolean;
var
  LTool: TTool;
begin
  Result := False;

  if not Assigned(AClass) then Exit;
  if AMethodName.IsEmpty then Exit;
  if not Assigned(AToolcallEvent) then Exit;

  LTool := Default(TTool);

  LTool.Schema := soUtils.GetJsonSchema(AClass, AMethodName).Trim();
  if LTool.Schema.IsEmpty then Exit;

  LTool.Name := AMethodName;
  LTool.ToolCallEvent := AToolcallEvent;
  LTool.Class_ := AClass;

  Result := FList.TryAdd(AMethodName, LTool);
end;

function  TsoTools.Count(): Integer;
begin
  Result := FList.Count;
end;

function  TsoTools.CallPrompt(): string;
var
  LPair: TPair<string, TTool>;
  LSchemes: string;
  I: Integer;
  LPrompt: TsoPrompt;
begin
  Result := '';

  LSchemes := '';

  for LPair in FList do
  begin
    LSchemes := LSchemes + LPair.Value.Schema + ',' + #10#13;
  end;

  if LSchemes.EndsWith(','+#10#13) then
  begin
    I := LSchemes.LastIndexOf(','+#10#13);
    LSchemes := LSchemes.Remove(I, 3);
  end;

  FPrompts.GetPrompt(CsoToolCallID, LPrompt);
  Result := Format(LPrompt.Prompt, [soUtils.GetLocalDateTime(), LSchemes]);
end;

function  TsoTools.ResponsePrompt(const AQuestion, AResponse: string): string;
var
  LPrompt: TsoPrompt;
begin
  FPrompts.GetPrompt(CsoToolResponseID, LPrompt);
  Result := Format(LPrompt.Prompt, [AQuestion, AResponse]);
end;

procedure TsoTools.Call(const AMessages: TsoMessages; const AInference: TsoInference; const AInput: string);
var
  LTool: TTool;
  LToolCalls: TsoToolCalls;
  LItem: TsoToolCall;
  LToolCall: TsoToolCall;
begin
  if not Assigned(AMessages) then Exit;
  if not Assigned(AInference) then Exit;

  if AInput.IsEmpty then Exit;

  LToolCalls := ParseToolCalls(AInput);
  try
    for LItem in LToolCalls do
    begin
      if FList.TryGetValue(LItem.FuncName, LTool) then
      begin
        LToolCall := LItem;
        LToolCall.SetClass(LTool.Class_);
        LTool.ToolCallEvent(Self, AMessages, AInference, LToolCall);
      end;
    end;
  finally
    FreeFunctionCalls(LToolCalls);
  end;
end;

function  TsoTools.CallTool(const AClass: TClass; const AMethodName: string; const AArgs: array of TValue): TValue;
begin
  Result := soUtils.CallStaticMethod(AClass, AMethodName, AArgs);
end;

function  TsoTools.WebSearch(const AQuestion: string): string;
var
  LWebSearch: TsoWebSearch;

begin
  LWebSearch := TsoWebSearch.Create();
  try
    if LWebSearch.Query(AQuestion) then
    begin
      Result := ResponsePrompt(AQuestion, LWebSearch.Response());
    end;
  finally
    LWebSearch.Free();
  end;
end;

end.
