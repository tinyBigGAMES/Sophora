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

unit Sophora.RAG;

{$I Sophora.Defines.inc}

interface

uses
  System.SysUtils,
  Sophora.CLibs,
  Sophora.Utils,
  Sophora.Common,
  Sophora.Inference;

type

  { TsoEmbeddings }
  TsoEmbeddings = class(TsoBaseLLMModel)
  protected
    procedure Normalize(AInVectors, LOutVectors: PSingle; const ACount: Integer);
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function  LoadModel(const AMainGPU: Integer=-1; const AGPULayers: Integer=-1; const AFilename: string=CsoEmbeddingsLLMFilename): Boolean; override;
    function  Generate(const APrompt: string): TArray<Single>;
  end;

implementation

{ TsoEmbeddings }
procedure TsoEmbeddings.Normalize(AInVectors, LOutVectors: PSingle; const ACount: Integer);
var
  LNorm: Single;
  I: Integer;
begin
  LNorm := 0;

  // Compute the squared sum
  for I := 0 to ACount - 1 do
    //norm := norm + vec[i] * vec[i];
    LNorm := LNorm + TsoPointerArray1D<Single>.GetValue(AInVectors, I) * TsoPointerArray1D<Single>.GetValue(AInVectors, I);

  // Take the square root to get the norm
  LNorm := Sqrt(LNorm);

  // Normalize each element
  if LNorm <> 0 then
    for I := 0 to ACount - 1 do
      //outVec[i] := vec[i] / norm;
      TsoPointerArray1D<Single>.SetValue(LOutVectors, I, TsoPointerArray1D<Single>.GetValue(AInVectors, I) / LNorm);
end;

constructor TsoEmbeddings.Create();
begin
  inherited;
end;

destructor TsoEmbeddings.Destroy();
begin
  inherited;
end;

function  TsoEmbeddings.LoadModel(const AMainGPU: Integer; const AGPULayers: Integer; const AFilename: string): Boolean;
begin
  Result := inherited;
end;

function  TsoEmbeddings.Generate(const APrompt: string): TArray<Single>;
var
  LContextParams: llama_context_params;
  LContext: Pllama_context;
  LVocab: Pllama_vocab;
  LTokens: TArray<llama_token>;
  LTokenCount, LEmbeddingSize, I: Integer;
  LBatch: llama_batch;
  LSourceEmbeddings: TArray<Single>;
  LEmbeddingsP: PSingle;
  LInputText: UTF8String;
  LSeqId: Integer;
begin
  Result := nil;

  // check if model not loaded
  if not ModelLoaded() then
  begin
    SetError('[%s] Model not loaded', ['RunInference']);
    Exit;
  end;

  if APrompt.IsEmpty then
  begin
    SetError('Not messages was found', []);
    Exit;
  end;

  // Initialize context parameters
  LContextParams := llama_context_default_params();
  LContextParams.embeddings := True; // Enable embedding mode

  // Create a new context
  LContext := llama_new_context_with_model(FModel, LContextParams);
  if LContext = nil then
  begin
    SetError('Failed to create LLaMA context', []);
    Exit;
  end;

  // Get model vocab
  LVocab := llama_model_get_vocab(FModel);
  if LVocab = nil then
  begin
    SetError('Failed to get vocab', []);
    llama_free(LContext);
    Exit;
  end;

  // Tokenize input text
  LInputText := UTF8String(APrompt);
  LTokenCount := -llama_tokenize(LVocab, PUTF8Char(LInputText), Length(LInputText), nil, 0, true, true);
  SetLength(LTokens, LTokenCount);

  if llama_tokenize(LVocab, PUTF8Char(LInputText), Length(LInputText), @LTokens[0], Length(LTokens), True, True) < 0 then
  begin
    SetError('Tokenization failed!', []);
    llama_free(LContext);
    Exit;
  end;

  // Initialize batch
  LBatch := llama_batch_init(LTokenCount, 0, 1);

  LSeqId := 0;
  // llama_batch_add(batch, tokens, 0, )
  for I := 0 to LTokenCount - 1 do
  begin
    TsoPointerArray1D<llama_token>.SetValue(LBatch.token, LBatch.n_tokens, LTokens[I]);
    TsoPointerArray1D<llama_pos>.SetValue(LBatch.pos, LBatch.n_tokens, I);
    TsoPointerArray1D<Int32>.SetValue(LBatch.n_seq_id, LBatch.n_tokens, 1);
    TsoPointerArray2D<llama_seq_id>.SetValue(LBatch.seq_id, LBatch.n_tokens, 0, LSeqId);
    TsoPointerArray1D<Int8>.SetValue(LBatch.logits, LBatch.n_tokens, Ord(I = (LTokenCount - 1)));
    Inc(LBatch.n_tokens);
  end;

  // Allocate storage for embeddings
  LEmbeddingSize := llama_model_n_embd(FModel);
  SetLength(LSourceEmbeddings, LEmbeddingSize);
  SetLength(Result, LEmbeddingSize);

  // Process batch
  llama_kv_cache_clear(LContext);
  if llama_decode(LContext, LBatch) < 0 then
    begin
      SetError('LLaMA encoding failed!', []);
      llama_free(LContext);
      Exit;
    end;

  if llama_pooling_type_rtn(LContext) = LLAMA_POOLING_TYPE_NONE then
    LEmbeddingsP := PSingle(llama_get_embeddings(LContext))
  else
    LEmbeddingsP := PSingle(llama_get_embeddings_seq(LContext, TsoPointerArray2D<llama_seq_id>.GetValue(LBatch.seq_id, 0, 0)));

  for i := 0 to LEmbeddingSize-1 do
  begin
    LSourceEmbeddings[i] := TsoPointerArray1D<Single>.GetValue(LEmbeddingsP, i);
  end;

  // Normalizes an embedding vector to unit length
  Normalize(@LSourceEmbeddings[0], @Result[0], LEmbeddingSize);

  // Cleanup
  llama_batch_free(LBatch);
  llama_free(LContext);
end;

end.
