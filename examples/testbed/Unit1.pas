unit Unit1;

interface

implementation

uses
  System.SysUtils,
  Sophora.CLibs,
  Sophora.Utils;

procedure Test03();
const
  //MODEL_PATh = 'c:/llm/gguf/bge-m3-q8_0.gguf';
  MODEL_PATH = 'c:/llm/gguf/all-minilm-l6-v2-q8_0.gguf';
  //MODEL_PATH = 'c:/llm/gguf/DeepHermes-3-Llama-3-8B-q4.gguf';
var
  LModelParams: llama_model_params;
  LContextParams: llama_context_params;
  LModel: Pllama_model;
  LContext: Pllama_context;
  LVocab: Pllama_vocab;
  LTokens: array[0..511] of llama_token;
  LTokenCount, LEmbeddingSize, I: Integer;
  LBatch: llama_batch;
  LSourceEmbeddings: array of Single;
  LOutputEmbeddings: array of Single;
  LEmbeddingsP: PSingle;
  LInputText: UTF8String;
  LSeqId: Integer;

  procedure Normalize(AInVectors, LOutVectors: PSingle; n: Integer);
  var
    LNorm: Single;
    I: Integer;
  begin
    LNorm := 0;

    // Compute the squared sum
    for I := 0 to n - 1 do
      //norm := norm + vec[i] * vec[i];
      LNorm := LNorm + TPointerArray1D<Single>.GetValue(AInVectors, I) * TPointerArray1D<Single>.GetValue(AInVectors, I);

    // Take the square root to get the norm
    LNorm := Sqrt(LNorm);

    // Normalize each element
    if LNorm <> 0 then
      for I := 0 to n - 1 do
        //outVec[i] := vec[i] / norm;
        TPointerArray1D<Single>.SetValue(LOutVectors, I, TPointerArray1D<Single>.GetValue(AInVectors, I) / LNorm);
  end;

begin
  // Initialize backend
  llama_backend_init();

  llama_numa_init(GGML_NUMA_STRATEGY_DISTRIBUTE);

  // Initialize model parameters
  LModelParams := llama_model_default_params();
  LModelParams.n_gpu_layers := 99;

  // Load the model
  LModel := llama_load_model_from_file(PAnsiChar(MODEL_PATH), LModelParams);
  if LModel = nil then
  begin
    Writeln('Failed to load model: ', MODEL_PATH);
    llama_backend_free();
    Exit;
  end;

  // Initialize context parameters
  LContextParams := llama_context_default_params();
  LContextParams.embeddings := True; // Enable embedding mode
  //ContextParams.pooling_type := LLAMA_POOLING_TYPE_MEAN;
  //ContextParams.pooling_type := LLAMA_POOLING_TYPE_NONE;

  // Create a new context
  LContext := llama_new_context_with_model(LModel, LContextParams);
  if LContext = nil then
  begin
    Writeln('Failed to create LLaMA context');
    llama_free_model(LModel);
    llama_backend_free();
    Exit;
  end;

  writeln(llama_pooling_type_rtn(LContext));

  // Get model vocab
  LVocab := llama_model_get_vocab(LModel);
  if LVocab = nil then
  begin
    Writeln('Failed to get vocab');
    llama_free(LContext);
    llama_free_model(LModel);
    llama_backend_free();
    Exit;
  end;

  // Tokenize input text
  LInputText := UTF8String('one');
  LTokenCount := llama_tokenize(LVocab, PUTF8Char(LInputText), Length(LInputText), @LTokens[0], Length(LTokens), True, True);
  if LTokenCount < 0 then
  begin
    Writeln('Tokenization failed!');
    llama_free(LContext);
    llama_free_model(LModel);
    llama_backend_free();
    Exit;
  end;

  // Initialize batch
  LBatch := llama_batch_init(512, 0, 1);

  LSeqId := 0;
  // llama_batch_add(batch, tokens, 0, )
  for I := 0 to LTokenCount - 1 do
  begin
    TPointerArray1D<llama_token>.SetValue(LBatch.token, LBatch.n_tokens, LTokens[I]);
    TPointerArray1D<llama_pos>.SetValue(LBatch.pos, LBatch.n_tokens, I);
    TPointerArray1D<Int32>.SetValue(LBatch.n_seq_id, LBatch.n_tokens, 1);
    TPointerArray2D<llama_seq_id>.SetValue(LBatch.seq_id, LBatch.n_tokens, 0, LSeqId);
    TPointerArray1D<Int8>.SetValue(LBatch.logits, LBatch.n_tokens, Ord(I = (LTokenCount - 1)));
    Inc(LBatch.n_tokens);
  end;

  // Allocate storage for embeddings
  LEmbeddingSize := llama_model_n_embd(LModel);
  SetLength(LSourceEmbeddings, LEmbeddingSize);
  SetLength(LOutputEmbeddings, LEmbeddingSize);

  // Process batch
  llama_kv_cache_clear(LContext);
  if llama_decode(LContext, LBatch) < 0 then
    begin
      Writeln('LLaMA encoding failed!');
      llama_free(LContext);
      llama_free_model(LModel);
      llama_backend_free();
      Exit;
    end;

  //Move(PSingle(llama_get_embeddings(Context))^, Embeddings[0], sizeof(single)*EmbeddingSize);

  //ep := PSingle(llama_get_embeddings(Context));
  //embd = llama_get_embeddings_seq(ctx, batch.seq_id[i][0]);
  LEmbeddingsP := PSingle(llama_get_embeddings_seq(LContext, TPointerArray2D<llama_seq_id>.GetValue(LBatch.seq_id, 0, 0)));

  for i := 0 to LEmbeddingSize-1 do
  begin
    LSourceEmbeddings[i] := TPointerArray1D<Single>.GetValue(LEmbeddingsP, i);
  end;

  Normalize(@LSourceEmbeddings[0], @LOutputEmbeddings[0], LEmbeddingSize);

  // Print embeddings
  for I := 0 to High(LOutputEmbeddings) do
    Write(Format('%0.6f ', [LOutputEmbeddings[I]]));

  Writeln;

  // Cleanup
  llama_batch_free(LBatch);
  llama_free(LContext);
  llama_free_model(LModel);
end;

end.
