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

unit Sophora.Inference;

{$I Sophora.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.Classes,
  System.Math,
  Sophora.CLibs,
  Sophora.Utils,
  Sophora.Common,
  Sophora.Messages,
  Sophora.Console;

type
  { TsoBaseLLMModel }
  TsoBaseLLMModel = class(TsoBaseObject)
  protected
    FModel: Pllama_model;
    FModelPath: string;
    FModelFilename: string;
    procedure OnInfo(const ALevel: Integer; const AText: string); virtual;
    function  OnLoadModelProgress(const AModelFilename: string; const AProgress: Single): Boolean; virtual;
    procedure OnLoadModel(const AModelFilename: string; const ASuccess: Boolean); virtual;

  public
    constructor Create(); override;
    destructor Destroy(); override;
    function  GetModelPath(): string; virtual;
    procedure SetModelPath(const APath: string=CsoDefaultModelPath); virtual;
    function  LoadModel(const AMainGPU: Integer=-1; const AGPULayers: Integer=-1; const AFilename: string=CsoGeneralLLMFilename): Boolean; virtual;
    function  ModelLoaded(): Boolean; virtual;
    procedure UnloadModel(); virtual;
  end;

  { Events }
  TsoEvent          = reference to procedure();
  TsoCancelEvent    = reference to function(): Boolean;
  TsoNextTokenEvent = reference to procedure(const AToken: string);

  { TsoInference }
  TsoInference = class(TsoBaseLLMModel)
  protected
    FActive: Boolean;
    FPrompt: string;
    FResponse: string;
    FTokenSpeed: Double;
    FInputTokens: Int32;
    FOutputTokens: Int32;

    FStream: Boolean;

    FTokenResponse: TsoTokenResponse;

    FOnNextTokenEvent: TsoNextTokenEvent;
    FOnCancelEvent: TsoCancelEvent;
    FOnStartEvent: TsoEvent;
    FOnEndEvent: TsoEvent;

    FThinking: Boolean;
    FShowThinking: Boolean;
    FOnThinkStartEvent: TsoEvent;
    FOnThinkEndEvent: TsoEvent;

    function  TokenToPiece(const AVocab: Pllama_vocab; const AContext: Pllama_context; const AToken: llama_token; const ASpecial: Boolean): string;
    procedure CalcPerformance(const AContext: Pllama_context);

    procedure DoOnNextToken(const AToken: string); virtual;
    procedure OnNextToken(const AToken: string); virtual;
    procedure OnStart(); virtual;
    procedure OnEnd(); virtual;
    function  OnCancel(): Boolean; virtual;
    procedure OnThinkStart(); virtual;
    procedure OnThinkEnd(); virtual;

    function  GetTokenRightMargin(): Integer;
    procedure SetTokenRightMargin(const AValue: Integer);
    function  GetTokenMaxLineLength(): Integer;
    procedure SetTokenMaxLineLength(const AValue: Integer);
  public
    constructor Create(); override;
    destructor Destroy(); override;

    function  LoadModel(const AMainGPU: Integer=-1; const AGPULayers: Integer=-1; const AFilename: string=CsoGeneralLLMFilename): Boolean; override;
    function  ModelLoaded(): Boolean; override;

    function  Run(const AMessages: TsoMessages; const AMaxContext: Cardinal=1024*4; const AMaxThreads: Integer=-1): Boolean;
    function  Response(): string;
    procedure Performance(const AlInputTokens: PInteger; AOutputTokens: PInteger; ATokenSpeed: PSingle);
    procedure ClearTokenResponse();

    property  TokenRightMargin: Integer read GetTokenRightMargin write SetTokenRightMargin;
    property  TokenMaxLineLength: Integer read GetTokenMaxLineLength write SetTokenMaxLineLength;

    property  Stream: Boolean read FStream write FStream;

    property  NextTokenEvent: TsoNextTokenEvent read FOnNextTokenEvent write FOnNextTokenEvent;
    property  CancelEvent: TsoCancelEvent read FOnCancelEvent write FOnCancelEvent;
    property  StartEvent: TsoEvent read FOnStartEvent write FOnStartEvent;
    property  EndEvent: TsoEvent read FOnEndEvent write FOnEndEvent;

    property  Thinking: Boolean read FThinking;
    property  ShowThinking: Boolean read FShowThinking write FShowThinking;
    property  ThinkStartEvent: TsoEvent read FOnThinkStartEvent write FOnThinkStartEvent;
    property  ThinkEndEvent: TsoEvent read FOnThinkEndEvent write FOnThinkEndEvent;
  end;

implementation

procedure TsoBaseLLMModel_CErrCallback(const AText: PUTF8Char; AUserData: Pointer); cdecl;
begin
end;

procedure TsoBaseLLMModel_LogCallback(ALevel: ggml_log_level; const AText: PUTF8Char; AUserData: Pointer); cdecl;
begin
  if Assigned(AUserData) then
    TsoBaseLLMModel(AUserData).OnInfo(ALevel, Utf8ToString(AText));
end;

function TsoBaseLLMModel_ProgressCallback(AProgress: single; AUserData: pointer): Boolean; cdecl;
var
  LBaseLLMModel: TsoBaseLLMModel;
begin
  LBaseLLMModel := AUserData;
  if Assigned(LBaseLLMModel) then
    Result := LBaseLLMModel.OnLoadModelProgress(LBaseLLMModel.FModelFilename, AProgress)
  else
    Result := True;
end;

{ TsoBaseLLMModel }
procedure TsoBaseLLMModel.OnInfo(const ALevel: Integer; const AText: string);
begin
  //atConsole.Print(AText);
end;

function  TsoBaseLLMModel.OnLoadModelProgress(const AModelFilename: string; const AProgress: Single): Boolean;
begin
  Result := True;

  //atConsole.Print(#13+'Loading model "%s" (%3.2f%s)...', [AModelFilename, AProgress*100, '%']);
end;

procedure TsoBaseLLMModel.OnLoadModel(const AModelFilename: string; const ASuccess: Boolean);
begin
end;

constructor TsoBaseLLMModel.Create();
begin
  inherited;
  FModelPath := CsoDefaultModelPath;
end;

destructor TsoBaseLLMModel.Destroy();
begin
  UnloadModel();
  inherited;
end;

function  TsoBaseLLMModel.GetModelPath(): string;
begin
  Result := FModelPath;
end;

procedure TsoBaseLLMModel.SetModelPath(const APath: string);
begin
  FModelPath := APath;
end;

function  TsoBaseLLMModel.LoadModel(const AMainGPU: Integer; const AGPULayers: Integer; const AFilename: string): Boolean;
var
  LModelParams: llama_model_params;
  LFilename: string;
begin
  Result := False;

  if ModelLoaded() then Exit(True);

  LFilename := TPath.Combine(FModelPath, TPath.ChangeExtension(TPath.GetFileName(AFilename), 'gguf'));
  LFilename := LFilename.Replace('\', '/');
  if not TFIle.Exists(LFilename) then
  begin
    SetError('Model file was not found: "%s"', [LFilename]);
  end;

  FModel := nil;
  FModelFilename := '';

  llama_log_set(TsoBaseLLMModel_LogCallback, Self);

  LModelParams := llama_model_default_params();

  LModelParams.progress_callback := TsoBaseLLMModel_ProgressCallback;
  LModelParams.progress_callback_user_data := Self;
  LModelParams.main_gpu := AMainGPU;

  if AGPULayers < 0 then
    LModelParams.n_gpu_layers := MaxInt
  else
    LModelParams.n_gpu_layers := AGPULayers;

  FModelFilename := LFilename;

  FModel := llama_model_load_from_file(soUtils.AsUtf8(FModelFilename), LModelParams);
  if not Assigned(FModel) then
  begin
    OnLoadModel(FModelFilename, False);
    SetError('Failed to load model: "%s"', [FModelFilename]);
    Exit;
  end;
  OnLoadModel(FModelFilename, True);

  Result := True;
end;

function  TsoBaseLLMModel.ModelLoaded(): Boolean;
begin
  Result := False;
  if not Assigned(FModel) then Exit;

  Result := True;
end;

procedure TsoBaseLLMModel.UnloadModel();
begin
  if not ModelLoaded() then Exit;
  llama_free_model(FModel);

  FModel := nil;
  FModelFilename := '';
end;

{ TsoInference }
function TsoInference.TokenToPiece(const AVocab: Pllama_vocab; const AContext: Pllama_context; const AToken: llama_token; const ASpecial: Boolean): string;
var
  LTokens: Int32;
  LCheck: Int32;
  LBuffer: TArray<UTF8Char>;
begin
  try
    SetLength(LBuffer, 9);
    LTokens := llama_token_to_piece(AVocab, AToken, @LBuffer[0], 8, 0, ASpecial);
    if LTokens < 0 then
      begin
        SetLength(LBuffer, (-LTokens)+1);
        LCheck := llama_token_to_piece(AVocab, AToken, @LBuffer[0], -LTokens, 0, ASpecial);
        Assert(LCheck = -LTokens);
        LBuffer[-LTokens] := #0;
      end
    else
      begin
        LBuffer[LTokens] := #0;
      end;
    Result := UTF8ToString(@LBuffer[0]);
  except
    on E: Exception do
    begin
      SetError(E.Message, []);
      Exit;
    end;
  end;
end;

procedure TsoInference.CalcPerformance(const AContext: Pllama_context);
var
  LTotalTimeSec: Double;
  APerfData: llama_perf_context_data;
begin
  APerfData := llama_perf_context(AContext);

  // Convert milliseconds to seconds
  LTotalTimeSec := APerfData.t_eval_ms / 1000;

  // Total input tokens (n_p_eval assumed to be input tokens)
  FInputTokens := APerfData.n_p_eval;

  // Total output tokens (n_eval assumed to be output tokens)
  FOutputTokens := APerfData.n_eval;

  // Calculate tokens per second (total tokens / time in seconds)
  if LTotalTimeSec > 0 then
    FTokenSpeed := (FInputTokens + FOutputTokens) / LTotalTimeSec
  else
    FTokenSpeed := 0;
end;

(*
procedure TsoInference.OnInfo(const ALevel: Integer; const AText: string);
begin
  //atConsole.Print(AText);
end;

function  TsoInference.OnLoadModelProgress(const AModelFilename: string; const AProgress: Single): Boolean;
begin
  Result := True;

  //atConsole.Print(#13+'Loading model "%s" (%3.2f%s)...', [AModelFilename, AProgress*100, '%']);
end;

procedure TsoInference.OnLoadModel(const AModelFilename: string; const ASuccess: Boolean);
begin
end;
*)

procedure TsoInference.DoOnNextToken(const AToken: string);
var
  LToken: string;
begin
  LToken := AToken;
  LToken := soUtils.SanitizeFromJson(LToken);

  FResponse := FResponse + LToken;

  if LToken.StartsWith('<think>') then
    begin
      LToken := '';
      FThinking := True;
      OnThinkStart();
    end
  else
  if LToken.StartsWith('</think>') then
    begin
      LToken := '';
      FThinking := False;
      OnThinkEnd();
    end;

  if FThinking then
  begin
    if not FShowThinking then Exit;
  end;

  OnNextToken(LToken);
end;

procedure TsoInference.OnNextToken(const AToken: string);
begin
  begin
    if Assigned(FOnNextTokenEvent) then
      FOnNextTokenEvent(AToken)
    else
      soConsole.Print(AToken);
  end;
end;

procedure TsoInference.OnStart();
begin
  if Assigned(FOnStartEvent) then
    FOnStartEvent();
end;

procedure TsoInference.OnEnd();
begin
  if Assigned(FOnEndEvent) then
    FOnEndEvent();
end;

function  TsoInference.OnCancel(): Boolean;
begin
  if Assigned(FOnCancelEvent) then
    Result := FOnCancelEvent()
  else
    Result := Boolean(GetAsyncKeyState(VK_ESCAPE) <> 0);
end;

procedure TsoInference.OnThinkStart();
begin
  if Assigned(FOnThinkStartEvent) then
    begin
      FOnThinkStartEvent();
    end
  else
    begin
      OnNextToken('<think>'+soCRLF);
    end;
end;

procedure TsoInference.OnThinkEnd();
begin
  if Assigned(FOnThinkEndEvent) then
    begin
      FOnThinkEndEvent();
    end
  else
    begin
      OnNextToken('</think>'+soCRLF);
    end;
end;


function  TsoInference.GetTokenRightMargin(): Integer;
begin
  Result := FTokenResponse.GetRightMargin();
end;

procedure TsoInference.SetTokenRightMargin(const AValue: Integer);
begin
  FTokenResponse.SetRightMargin(AValue);
end;

function  TsoInference.GetTokenMaxLineLength(): Integer;
begin
  Result := FTokenResponse.GetMaxLineLength();
end;

procedure TsoInference.SetTokenMaxLineLength(const AValue: Integer);
begin
  FTokenResponse.SetMaxLineLength(AValue);
end;

constructor TsoInference.Create();
begin
  inherited;
  FTokenResponse.Initialize;
  FStream := True;
  FShowThinking := True;
end;

destructor TsoInference.Destroy();
begin
  inherited;
end;

function  TsoInference.LoadModel(const AMainGPU: Integer; const AGPULayers: Integer; const AFilename: string): Boolean;
begin
  FActive := False;
  FPrompt := '';
  FResponse := '';
  FTokenSpeed := 0;
  FInputTokens := 0;
  FOutputTokens := 0;

  Result := Inherited;
end;

function  TsoInference.ModelLoaded(): Boolean;
begin
  Result := inherited;
  FActive := False;
  FPrompt := '';
  FResponse := '';
  FTokenSpeed := 0;
  FInputTokens := 0;
  FOutputTokens := 0;
end;

function  TsoInference.Run(const AMessages: TsoMessages; const AMaxContext: Cardinal; const AMaxThreads: Integer): Boolean;
var
  LNumPrompt: Integer;
  LPromptTokens: TArray<llama_token>;
  LCtxParams: llama_context_params;
  LNumPredict: integer;
  LCtx: Pllama_context;
  LSmplrParams: llama_sampler_chain_params;
  LSmplr: Pllama_sampler;
  N: Integer;
  LTokenStr: string;
  LBatch: llama_batch;
  LNewTokenId: llama_token;
  LNumPos: Integer;
  LPrompt: UTF8String;
  LFirstToken: Boolean;
  V: Int32;
  LBuf: array[0..255] of UTF8Char;
  LKey: string;
  LMaxContext: Cardinal;
  LVocab: Pllama_vocab;
begin
  Result := False;

  // check if inference is already runnig
  if FActive then
  begin
    SetError('[%s] Inference already active', ['RunInference']);
    Exit;
  end;

  // check if model not loaded
  if not ModelLoaded() then
  begin
    SetError('[%s] Model not loaded', ['RunInference']);
    Exit;
  end;

  if not AMessages.IsEmpty then
    AMessages.AddEnd();

  FPrompt := AMessages.Prompt();

  if FPrompt.IsEmpty then
  begin
    SetError('Not messages was found', []);
    Exit(False);
  end;

  FActive := True;
  FResponse := '';

  FError := '';
  LFirstToken := True;
  LMaxContext := 0;

  for V := 0 to llama_model_meta_count(FModel)-1 do
  begin
    llama_model_meta_key_by_index(FModel, V, @LBuf[0], length(LBuf));
    LKey := string(LBuf);
    if LKey.Contains('context_length') then
    begin
      llama_model_meta_val_str_by_index(FModel, V, @LBuf[0], length(LBuf));
      LKey := string(LBuf);
      LMaxContext :=  LKey.ToInteger;
      break;
    end;
  end;

  if LMaxContext > 0 then
    LNumPredict := EnsureRange(AMaxContext, 512, LMaxContext)
  else
    LNumPredict := 512;

  LVocab := llama_model_get_vocab(FModel);

  LPrompt := UTF8String(FPrompt);

  LNumPrompt := -llama_tokenize(LVocab, PUTF8Char(LPrompt), Length(LPrompt), nil, 0, true, true);

  SetLength(LPromptTokens, LNumPrompt);

  if llama_tokenize(LVocab, PUTF8Char(LPrompt), Length(LPrompt), @LPromptTokens[0], Length(LPromptTokens), true, true) < 0 then
  begin
    SetError('Failed to tokenize prompt', []);
  end;

  LCtxParams := llama_context_default_params();
  LCtxParams.n_ctx := LNumPrompt + LNumPredict - 1;
  LCtxParams.n_batch := LNumPrompt;
  LCtxParams.no_perf := false;
  if AMaxThreads = -1 then
    LCtxParams.n_threads := soUtils.GetPhysicalProcessorCount()
  else
    LCtxParams.n_threads := EnsureRange(AMaxThreads, 1, soUtils.GetPhysicalProcessorCount());
  LCtxParams.n_threads_batch := LCtxParams.n_threads;
  LCtxParams.flash_attn := False;

  LCtx := llama_new_context_with_model(FModel, LCtxParams);
  if LCtx = nil then
  begin
    SetError('Failed to create inference context', []);
    llama_free_model(FModel);
    exit;
  end;

  LSmplrParams := llama_sampler_chain_default_params();
  LSmplr := llama_sampler_chain_init(LSmplrParams);
  llama_sampler_chain_add(LSmplr, llama_sampler_init_greedy());

  LBatch := llama_batch_get_one(@LPromptTokens[0], Length(LPromptTokens));

  LNumPos := 0;

  FOutputTokens := 0;
  FInputTokens := 0;
  FTokenSpeed := 0;

  OnStart();

  llama_perf_context_reset(LCtx);

  while LNumPos + LBatch.n_tokens < LNumPrompt + LNumPredict do
  begin
    if OnCancel() then Break;

    N := llama_decode(LCtx, LBatch);
    if N <> 0 then
    begin
      SetError('Failed to decode context', []);
      llama_sampler_free(LSmplr);
      llama_free(LCtx);
      llama_free_model(FModel);
      Exit;
    end;

    LNumPos := LNumPos + LBatch.n_tokens;

    LNewTokenId := llama_sampler_sample(LSmplr, LCtx, -1);

    if llama_token_is_eog(LVocab, LNewTokenId) then
    begin
      break;
    end;

    if llama_vocab_is_eog(LVocab, LNewTokenId) then
    begin
      break;
    end;

    LTokenStr := TokenToPiece(LVocab, LCtx, LNewTokenId, false);

    if LFirstToken then
    begin
      LTokenStr := LTokenStr.Trim();
      LFirstToken := False;
    end;

    case FTokenResponse.AddToken(LTokenStr) of
      tpaWait:
      begin
      end;

      tpaAppend:
      begin
        DoOnNextToken(FTokenResponse.LastWord(False));
      end;

      tpaNewline:
      begin
        DoOnNextToken(#10);
        DoOnNextToken(FTokenResponse.LastWord(True));
      end;
    end;

    LBatch := llama_batch_get_one(@LNewTokenId, 1);
  end;

  if FTokenResponse.Finalize then
  begin
    case FTokenResponse.AddToken('') of
      tpaWait:
      begin
      end;

      tpaAppend:
      begin
        DoOnNextToken(FTokenResponse.LastWord(False));
      end;

      tpaNewline:
      begin
        DoOnNextToken(#10);
        DoOnNextToken(FTokenResponse.LastWord(True));
      end;
    end;
  end;

  OnEnd();

  CalcPerformance(LCtx);

  llama_sampler_free(LSmplr);
  llama_free(LCtx);

  FActive := False;
  FTokenResponse.Clear();

  Result := True;
end;

function  TsoInference.Response(): string;
begin
  Result := FResponse;
end;

procedure TsoInference.Performance(const AlInputTokens: PInteger; AOutputTokens: PInteger; ATokenSpeed: PSingle);
begin
  if Assigned(AlInputTokens) then
    AlInputTokens^ := FInputTokens;

  if Assigned(AOutputTokens) then
    AOutputTokens^ := FOutputTokens;

  if Assigned(ATokenSpeed) then
    ATokenSpeed^ := FTokenSpeed;
end;

procedure TsoInference.ClearTokenResponse();
begin
  FTokenResponse.Clear();
end;

initialization
begin
  redirect_cerr_to_callback(TsoBaseLLMModel_CErrCallback, nil);
  llama_backend_init();
  llama_numa_init(GGML_NUMA_STRATEGY_DISABLED);
end;

finalization
begin
  llama_backend_free();
  restore_cerr();
end;

end.
