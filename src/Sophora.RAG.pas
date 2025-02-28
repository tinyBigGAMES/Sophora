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
  System.Generics.Collections,
  System.Generics.Defaults,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.JSON,
  System.Math,
  System.NetEncoding,
  Sophora.CLibs,
  Sophora.Utils,
  Sophora.Common,
  Sophora.Inference,
  Sophora.Console;

type

  { TsoEmbeddings }
  TsoEmbeddings = class(TsoModel)
  protected
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function  LoadModel(const AMainGPU: Integer=0; const AGPULayers: Integer=0; const AFilename: string=csoDefaultEmbeddingsModelFilename): Boolean; override;
    function  Generate(const APrompt: string; const AMaxContext: Cardinal=CsoDefaultMaxContext; const AMaxThreads: Integer=CsoDefaultMaxThreads): TArray<Single>; virtual;
  end;

  { TsoDatabase }
  TsoDatabase = class(TsoBaseObject)
  protected
    FDatabase: string;
    FResponseText: string;
    FSQL: TStringList;
    FPrepairedSQL: string;
    FJSON: TJSONObject;
    FDataset: TJSONArray;
    FMacros: TDictionary<string, string>;
    FParams: TDictionary<string, string>;
    FHandle: PSQLite3;
    FStmt: Psqlite3_stmt;
    procedure SetMacroValue(const AName, AValue: string);
    procedure SetParamValue(const AName, AValue: string);
    procedure Prepair();
    function  ExecuteSQLInternal(const ASQL: string): Boolean;
  public
    property Handle: PSQLite3 read FHandle;
    constructor Create(); override;
    destructor Destroy(); override;
    function  IsOpen(): Boolean;
    function  Open(const AFilename: string): Boolean;
    procedure Close();
    procedure ClearSQLText();
    procedure AddSQLText(const AText: string);
    function  GetSQLText(): string;
    procedure SetSQLText(const AText: string);
    function  GetPrepairedSQL(): string;
    procedure ClearMacros();
    function  GetMacro(const AName: string): string;
    procedure SetMacro(const AName, AValue: string);
    procedure ClearParams();
    function  GetParam(const AName: string): string;
    procedure SetParam(const AName, AValue: string);
    function  RecordCount(): Integer;
    function  GetField(const AIndex: Cardinal; const AName: string): string;
    function  Execute(): Boolean;
    function  ExecuteSQL(const ASQL: string): Boolean;
    function  GetResponseText(): string;
  end;

  { TsoVectorDatabaseDocument }
  TsoVectorDatabaseDocument = record
    ID: string;
    Score: Single;
    Text: string;
  end;

  { TsoVectorDatabase }
  TsoVectorDatabase = class(TsoBaseObject)
  private
    FDatabase: TsoDatabase;
    FEmbeddings: TsoEmbeddings;
    procedure CreateTableIfNotExists();
    function CosineSimilarity(const AVec1, AVec2: TArray<Single>): Double;
  public
    constructor Create(); override;
    destructor Destroy; override;

    function Open(const AEmbeddings: TsoEmbeddings; const AFilename: string): Boolean;
    procedure Close();
    function AddDocument(const ADocID: string; const AText: string; const AMaxContext: Cardinal=1024*4; const AMaxThreads: Integer=-1): Boolean;
    function AddLargeDocument(const ADocID, ATitle, AText: string; const AChunkSize: Integer; const AMaxContext: Cardinal=1024*4; const AMaxThreads: Integer=-1): Boolean;
    function Search(const AQuery: string; const ATopK: Integer = 5; const AQueryLimit: Integer = 1000; const ASimilarityThreshold: Single=0.1; const AMaxContext: Cardinal=1024*4; const AMaxThreads: Integer=-1): TJSONArray;
    function Search2(const AQuery: string; const ATopK: Integer = 5; const AQueryLimit: Integer = 1000; const ASimilarityThreshold: Single=0.1; const AMaxContext: Cardinal=1024*4; const AMaxThreads: Integer=-1): TArray<TsoVectorDatabaseDocument>;
  end;

implementation

{ TsoEmbeddings }
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
  Result := inherited LoadModel(AMainGPU, AGPULayers, AFilename);
end;

function  TsoEmbeddings.Generate(const APrompt: string; const AMaxContext: Cardinal=1024*4; const AMaxThreads: Integer=-1): TArray<Single>;
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
  LNumPredict: Integer;
  LMaxContext: Cardinal;

  procedure Normalize(AInVectors, LOutVectors: PSingle; const ACount: Integer);
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

  if LMaxContext > 0 then
    LNumPredict := EnsureRange(AMaxContext, 512, LMaxContext)
  else
    LNumPredict := 512;


  // Get model vocab
  LVocab := llama_model_get_vocab(FModel);
  if LVocab = nil then
  begin
    SetError('Failed to get vocab', []);
    Exit;
  end;

  // Tokenize input text
  LInputText := UTF8String(APrompt);
  LTokenCount := -llama_tokenize(LVocab, PUTF8Char(LInputText), Length(LInputText), nil, 0, true, true);
  SetLength(LTokens, LTokenCount);

  // Initialize context parameters
  LContextParams := llama_context_default_params();
  LContextParams.embeddings := True; // Enable embedding mode
  LContextParams.n_ctx := LTokenCount + LNumPredict - 1;
  LContextParams.n_batch := LTokenCount;
  LContextParams.no_perf := false;
  if AMaxThreads = -1 then
    LContextParams.n_threads := soUtils.GetPhysicalProcessorCount()
  else
    LContextParams.n_threads := EnsureRange(AMaxThreads, 1, soUtils.GetPhysicalProcessorCount());
  LContextParams.n_threads_batch := LContextParams.n_threads;
  LContextParams.flash_attn := False;

  // Create a new context
  LContext := llama_new_context_with_model(FModel, LContextParams);
  if LContext = nil then
  begin
    SetError('Failed to create LLaMA context', []);
    Exit;
  end;

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
      llama_batch_free(LBatch);
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


{ TsoDatabase }
procedure TsoDatabase.SetMacroValue(const AName, AValue: string);
begin
  FPrepairedSQL := FPrepairedSQL.Replace('&'+AName, AValue);
end;

procedure TsoDatabase.SetParamValue(const AName, AValue: string);
begin
  FPrepairedSQL := FPrepairedSQL.Replace(':'+AName, ''''+AValue+'''');
end;

procedure TsoDatabase.Prepair();
var
  LKey: string;
begin
  FPrepairedSQL := FSQL.Text;

  // Substitute macros
  for LKey in FMacros.Keys do
  begin
    SetMacroValue(LKey, FMacros.Items[LKey]);
  end;

  // Substitute field params
  for LKey in FParams.Keys do
  begin
    SetParamValue(LKey, FParams.Items[LKey]);
  end;
end;

constructor TsoDatabase.Create();
begin
  inherited;

  FSQL := TStringList.Create;
  FMacros := TDictionary<string, string>.Create;
  FParams := TDictionary<string, string>.Create;
end;

destructor TsoDatabase.Destroy();
begin
  Close();
  FParams.Free();
  FMacros.Free();
  FSQL.Free();

  inherited;
end;

function TsoDatabase.IsOpen(): Boolean;
begin
  Result := Assigned(FHandle);
end;

function TsoDatabase.Open(const AFilename: string): Boolean;
begin
  Result := False;

  if IsOpen() then
  begin
    SetError('Database already open', []);
    Exit;
  end;

  FDatabase := TPath.ChangeExtension(AFilename, 'db');
  if sqlite3_open(PAnsiChar(AnsiString(FDatabase)), @FHandle) <> SQLITE_OK then
  begin
    SetError(string(sqlite3_errmsg(FHandle)), []);
    sqlite3_close(FHandle);
    FHandle := nil;
  end;

  Result := IsOpen();
end;

procedure TsoDatabase.Close();
begin
  if not IsOpen() then
  begin
    SetError('Database was not open', []);
    Exit;
  end;

  if Assigned(FJSON) then
  begin
    FJSON.Free();
    FJSON := nil;
  end;

  if Assigned(FStmt) then
  begin
    sqlite3_finalize(FStmt);
    FStmt := nil;
  end;

  if Assigned(FHandle) then
  begin
    sqlite3_close(FHandle);
    FHandle := nil;
  end;

  ClearMacros();
  ClearParams();
  ClearSQLText();

  FDatabase := '';
  FResponseText := '';
  FError := '';
  FPrepairedSQL := '';
end;

procedure TsoDatabase.ClearSQLText();
begin
  FSQL.Clear;
end;

procedure TsoDatabase.AddSQLText(const AText: string);
begin
  FSQL.Add(AText);
end;

function TsoDatabase.GetSQLText(): string;
begin
  Result := FSQL.Text;
end;

procedure TsoDatabase.SetSQLText(const AText: string);
begin
  FSQL.Text := AText;
end;

function  TsoDatabase.GetPrepairedSQL(): string;
begin
  Result := FPrepairedSQL;
end;

procedure TsoDatabase.ClearMacros();
begin
  FMacros.Clear();
end;

function TsoDatabase.GetMacro(const AName: string): string;
begin
  FMacros.TryGetValue(AName, Result);
end;

procedure TsoDatabase.SetMacro(const AName, AValue: string);
begin
  FMacros.AddOrSetValue(AName, AValue);
end;

procedure TsoDatabase.ClearParams();
begin
  FParams.Clear();
end;

function TsoDatabase.GetParam(const AName: string): string;
begin
  FParams.TryGetValue(AName, Result);
end;

procedure TsoDatabase.SetParam(const AName, AValue: string);
begin
  FParams.AddOrSetValue(AName, AValue);
end;

function TsoDatabase.RecordCount(): Integer;
begin
  Result := 0;
  if not Assigned(FDataset) then Exit;
  Result := FDataset.Count;
end;

function TsoDatabase.GetField(const AIndex: Cardinal; const AName: string): string;
begin
  Result := '';
  if not Assigned(FDataset) then Exit;
  if AIndex > Cardinal(FDataset.Count-1) then Exit;
  Result := FDataset.Items[AIndex].GetValue<string>(AName);
end;

function TsoDatabase.Execute(): Boolean;
begin
  Prepair;
  Result := ExecuteSQL(FPrepairedSQL);
end;

function TsoDatabase.ExecuteSQL(const ASQL: string): Boolean;
begin
  Result := ExecuteSQLInternal(ASQL);
end;

function TsoDatabase.ExecuteSQLInternal(const ASQL: string): Boolean;
var
  LRes: Integer;
  I: Integer;
  LName: string;
  LValue: string;
  LRow: TJSONObject;

  function GetTypeAsString(AStmt: Psqlite3_stmt; AColumn: Integer): string;
  begin
    case sqlite3_column_type(AStmt, AColumn) of
      SQLITE_INTEGER: Result := IntToStr(sqlite3_column_int(AStmt, AColumn));
      SQLITE_FLOAT: Result := FloatToStr(sqlite3_column_double(AStmt, AColumn));
      SQLITE_TEXT: Result := string(PWideChar(sqlite3_column_text16(AStmt, AColumn))); // Fixed AColumn usage
      SQLITE_BLOB: Result := '[Blob Data]';
      SQLITE_NULL: Result := 'NULL';
    else
      Result := 'Unknown';
    end;
  end;

begin
  Result := False;
  if not Assigned(FHandle) then Exit;

  LRes := sqlite3_prepare16_v2(FHandle, PChar(ASQL), -1, @FStmt, nil);
  if LRes <> SQLITE_OK then
  begin
    SetError(string(PWideChar(sqlite3_errmsg16(FHandle))), []);
    Exit;
  end;

  LRes := sqlite3_step(FStmt);
  if (LRes <> SQLITE_DONE) and (LRes <> SQLITE_ROW) then
  begin
    SetError(string(PWideChar(sqlite3_errmsg16(FHandle))), []);
    sqlite3_finalize(FStmt);
    FStmt := nil;
    Exit;
  end;

  FResponseText := '';
  if LRes = SQLITE_ROW then
  begin
    try
      // Free the current Dataset
      if Assigned(FJSON) then
      begin
        FJSON.Free();
        FJSON := nil;
      end;

      FDataset := TJSONArray.Create;
      while LRes = SQLITE_ROW do
      begin
        LRow := TJSONObject.Create;
        for I := 0 to sqlite3_column_count(FStmt) - 1 do
        begin
          LName := string(PWideChar(sqlite3_column_name16(FStmt, I)));
          LValue := GetTypeAsString(FStmt, I);
          LRow.AddPair(LName, LValue);
        end;
        FDataset.AddElement(LRow);
        LRes := sqlite3_step(FStmt);
      end;
      FJSON := TJSONObject.Create;
      FJSON.AddPair('response', FDataset);
      FResponseText := FJSON.Format();
    except
      on E: Exception do
      begin
        FreeAndNil(FDataset);
        FreeAndNil(FJSON);
        raise; // Re-raise to ensure the caller handles it
      end;
    end;
  end;

  FError := '';
  Result := True;
  sqlite3_reset(FStmt);  // Reset instead of immediate finalize
  sqlite3_finalize(FStmt);
  FStmt := nil;
end;

function TsoDatabase.GetResponseText(): string;
begin
  Result := FResponseText;
end;


{ TsoVectorDatabase }
constructor TsoVectorDatabase.Create();
begin
  inherited;
  FDatabase := TsoDatabase.Create;
end;

destructor TsoVectorDatabase.Destroy();
begin
  Close();

  FDatabase.Free();

  inherited;
end;

function TsoVectorDatabase.Open(const AEmbeddings: TsoEmbeddings; const AFilename: string): Boolean;
begin
  Result := False;
  if not Assigned(AEmbeddings) then Exit;
  FEmbeddings := AEmbeddings;

  if not FDatabase.Open(AFilename) then Exit;

  CreateTableIfNotExists();

  Result := True;
end;

procedure TsoVectorDatabase.Close();
begin
  FDatabase.Close();
end;

procedure TsoVectorDatabase.CreateTableIfNotExists();
begin
  FDatabase.ClearSQLText();
  FDatabase.SetMacro('table', 'vectors');
  FDatabase.AddSQLText('CREATE TABLE IF NOT EXISTS &table (' +
                       'id TEXT PRIMARY KEY, ' +
                       'text TEXT, ' +
                       'embedding BLOB)');
  FDatabase.Execute();
end;

function TsoVectorDatabase.CosineSimilarity(const AVec1, AVec2: TArray<Single>): Double;
var
  LDotProduct, LNorm1, LNorm2: Double;
  I: Integer;
begin
  LDotProduct := 0;
  LNorm1 := 0;
  LNorm2 := 0;

  for I := Low(AVec1) to High(AVec1) do
  begin
    LDotProduct := LDotProduct + (AVec1[I] * AVec2[I]);
    LNorm1 := LNorm1 + (AVec1[I] * AVec1[I]);
    LNorm2 := LNorm2 + (AVec2[I] * AVec2[I]);
  end;

  LNorm1 := Sqrt(LNorm1);
  LNorm2 := Sqrt(LNorm2);

  // ✅ Prevent divide by zero
  if (LNorm1 < 1e-6) or (LNorm2 < 1e-6) then
    Exit(0.0);

  Result := LDotProduct / (LNorm1 * LNorm2);

  // ✅ Ensure result stays between -1 and 1
  if Result > 1 then Result := 1;
  if Result < -1 then Result := -1;
end;

function TsoVectorDatabase.AddDocument(const ADocID: string; const AText: string; const AMaxContext: Cardinal; const AMaxThreads: Integer): Boolean;
var
  LEmbedding: TArray<Single>;
  LEmbeddingBlob: TBytes;
  LEncodedEmbedding: string;
  LSize: Integer;
begin
  Result := False;
  if ADocID.IsEmpty then Exit;
  if AText.IsEmpty then Exit;

  LEmbedding := FEmbeddings.Generate(AText, AMaxContext, AMaxThreads);
  LSize := Length(LEmbedding) * SizeOf(Single);
  SetLength(LEmbeddingBlob, LSize);

  // Optimized memory move
  Move(LEmbedding[0], LEmbeddingBlob[0], LSize);

  // Encode BLOB as Base64 string
  LEncodedEmbedding := TNetEncoding.Base64.EncodeBytesToString(LEmbeddingBlob);

  FDatabase.ClearSQLText;
  FDatabase.SetMacro('table', 'vectors');
  FDatabase.AddSQLText('INSERT OR REPLACE INTO &table (id, text, embedding) VALUES (:id, :text, :embedding)');
  FDatabase.SetParam('id', ADocID);
  FDatabase.SetParam('text', AText);
  FDatabase.SetParam('embedding', LEncodedEmbedding);  // Base64-encoded BLOB

  Result := FDatabase.Execute;
end;

function TsoVectorDatabase.AddLargeDocument(const ADocID, ATitle, AText: string; const AChunkSize: Integer; const AMaxContext: Cardinal; const AMaxThreads: Integer): Boolean;
var
  LWords, LParagraphs: TArray<string>;
  LChunkText, LCurrentChunk: string;
  LStartIdx, LChunkCounter, LWordCount, I: Integer;
begin
  Result := False;

  // Validate input
  if AText.Trim.IsEmpty then
  begin
    SetError('Cannot add an empty document', []);
    Exit;
  end;

  if AChunkSize <= 0 then
  begin
    SetError('Chunk size must be greater than zero', []);
    Exit;
  end;

  // Try to split by paragraphs first to maintain context
  LParagraphs := AText.Split([#13#10+#13#10, #10+#10], TStringSplitOptions.None);

  // If we have multiple paragraphs, process paragraph by paragraph
  if Length(LParagraphs) > 1 then
  begin
    LChunkCounter := 1;
    LCurrentChunk := '';
    LWordCount := 0;

    for I := 0 to High(LParagraphs) do
    begin
      if LParagraphs[I].Trim = '' then Continue; // Skip empty paragraphs

      // Count words in current paragraph
      LWords := LParagraphs[I].Split([' ']);

      // If adding this paragraph would exceed chunk size, store current chunk
      if (LWordCount > 0) and (LWordCount + Length(LWords) > AChunkSize) then
      begin
        // Add chunk with context from title
        LChunkText := Format('[%s - Part %d] %s', [ATitle, LChunkCounter, LCurrentChunk.Trim]);

        // Store chunk
        if not AddDocument(Format('%s_chunk%d', [ADocID, LChunkCounter]),
                          LChunkText, AMaxContext, AMaxThreads) then
        begin
          SetError('Failed to add chunk %d', [LChunkCounter]);
          Exit;
        end;

        // Reset for next chunk
        Inc(LChunkCounter);
        LCurrentChunk := '';
        LWordCount := 0;
      end;

      // Add paragraph to current chunk
      if LCurrentChunk <> '' then
        LCurrentChunk := LCurrentChunk + #13#10#13#10;
      LCurrentChunk := LCurrentChunk + LParagraphs[I];
      Inc(LWordCount, Length(LWords));
    end;

    // Add final chunk if not empty
    if LCurrentChunk <> '' then
    begin
      LChunkText := Format('[%s - Part %d] %s', [ATitle, LChunkCounter, LCurrentChunk.Trim]);
      if not AddDocument(Format('%s_chunk%d', [ADocID, LChunkCounter]),
                        LChunkText, AMaxContext, AMaxThreads) then
      begin
        SetError('Failed to add final chunk', []);
        Exit;
      end;
    end;
  end
  else
  begin
    // Fall back to original word-based chunking for single paragraphs
    LWords := AText.Split([' ']);
    LChunkCounter := 1;
    LCurrentChunk := '';
    LWordCount := 0;

    for LStartIdx := 0 to High(LWords) do
    begin
      // Add next word to chunk
      if LCurrentChunk <> '' then
        LCurrentChunk := LCurrentChunk + ' ';

      LCurrentChunk := LCurrentChunk + LWords[LStartIdx];
      Inc(LWordCount);

      // If chunk size is reached or end of document, store chunk
      if (LWordCount >= AChunkSize) or (LStartIdx = High(LWords)) then
      begin
        // Add title to each chunk for better context
        LChunkText := Format('[%s - Part %d] %s', [ATitle, LChunkCounter, LCurrentChunk]);

        // Store chunk separately
        if not AddDocument(Format('%s_chunk%d', [ADocID, LChunkCounter]),
                          LChunkText, AMaxContext, AMaxThreads) then
        begin
          SetError('Failed to add chunk: %s', [LChunkText]);
          Exit;
        end;

        // Reset for next chunk
        Inc(LChunkCounter);
        LCurrentChunk := '';
        LWordCount := 0;
      end;
    end;
  end;

  Result := True;
end;

function TsoVectorDatabase.Search(const AQuery: string; const ATopK: Integer; const AQueryLimit: Integer; const ASimilarityThreshold: Single; const AMaxContext: Cardinal; const AMaxThreads: Integer): TJSONArray;
var
  LQueryEmbedding: TArray<Single>;
  LDocID, LTextData, LEncodedEmbedding: string;
  LDBEmbedding: TArray<Single>;
  LEmbeddingBlob: TBytes;
  LSimilarityScores: TDictionary<string, Single>;
  LScore, LExistingScore: Single;
  I, LVectorSize: Integer;
  LJSONObject: TJSONObject;
  LSortedScores: TList<TPair<string, Single>>;
  LPair: TPair<string, Single>;
  LTextMap: TDictionary<string, string>;
  LStartTime: TDateTime;
begin
  LStartTime := Now;
  Result := TJSONArray.Create;  // Always return an empty array if no results

  // Exit if model is not loaded or empty query
  if (not FEmbeddings.ModelLoaded()) then
  begin
    SetError('Model not loaded for search', []);
    Exit;
  end;

  if (Trim(AQuery) = '') then
  begin
    SetError('Empty search query', []);
    Exit;
  end;

  // Generate embedding for query
  LQueryEmbedding := FEmbeddings.Generate(AQuery, AMaxContext, AMaxThreads);
  if Length(LQueryEmbedding) = 0 then
  begin
    SetError('Failed to generate embedding for query', []);
    Exit;
  end;

  LSimilarityScores := TDictionary<string, Single>.Create;
  LTextMap := TDictionary<string, string>.Create;
  try
    LSortedScores := TList<TPair<string, Single>>.Create;
    try
      FDatabase.ClearSQLText;
      FDatabase.SetMacro('table', 'vectors');

      // Improved SQL - add ORDER BY id for consistent results
      FDatabase.AddSQLText('SELECT id, text, embedding FROM &table ORDER BY id ASC LIMIT :limit');
      FDatabase.SetParam('limit', AQueryLimit.ToString);

      if not FDatabase.Execute then
      begin
        SetError('Database query failed', []);
        Exit;
      end;

      // Preallocate for better performance if RecordCount is large
      if FDatabase.RecordCount > 100 then
      begin
        LSimilarityScores.Capacity := FDatabase.RecordCount;
        LTextMap.Capacity := FDatabase.RecordCount;
      end;

      for I := 0 to FDatabase.RecordCount - 1 do
      begin
        LDocID := FDatabase.GetField(I, 'id');
        if LDocID = '' then Continue;  // Skip records with empty IDs

        LTextData := FDatabase.GetField(I, 'text');

        // Retrieve and decode Base64-encoded embedding
        LEncodedEmbedding := FDatabase.GetField(I, 'embedding');
        if LEncodedEmbedding = '' then Continue;  // Skip records with empty embeddings

        try
          LEmbeddingBlob := TNetEncoding.Base64.DecodeStringToBytes(LEncodedEmbedding);

          // Convert byte array back to float array
          LVectorSize := Length(LEmbeddingBlob) div SizeOf(Single);
          if LVectorSize = 0 then Continue;  // Skip invalid embeddings

          SetLength(LDBEmbedding, LVectorSize);
          Move(LEmbeddingBlob[0], LDBEmbedding[0], Length(LEmbeddingBlob));

          // Compute similarity only if vectors have same dimensions
          if Length(LDBEmbedding) = Length(LQueryEmbedding) then
          begin
            LScore := CosineSimilarity(LQueryEmbedding, LDBEmbedding);

            // Only process scores above threshold
            if LScore > ASimilarityThreshold then
            begin
              // Store highest score per chunk
              if LSimilarityScores.TryGetValue(LDocID, LExistingScore) then
                LSimilarityScores[LDocID] := Max(LExistingScore, LScore)
              else
                LSimilarityScores.Add(LDocID, LScore);

              // Store text for retrieval
              LTextMap.AddOrSetValue(LDocID, LTextData);
            end;
          end;
        except
          on E: Exception do
          begin
            // Log error but continue to next record
            // soConsole.PrintLn('Error processing embedding for %s: %s', [LDocID, E.Message]);
            Continue;
          end;
        end;
      end;

      // Early exit if no results
      if LSimilarityScores.Count = 0 then Exit;

      // Optimization: Only sort as many items as needed
      LSortedScores.Capacity := LSimilarityScores.Count;
      for LPair in LSimilarityScores do
        LSortedScores.Add(LPair);

      LSortedScores.Sort(
        TComparer<TPair<string, Single>>.Construct(
          function(const Left, Right: TPair<string, Single>): Integer
          begin
            Result := CompareValue(Right.Value, Left.Value);  // Higher scores first
          end
        )
      );

      // Return top chunks separately (not merged)
      for I := 0 to Min(ATopK - 1, LSortedScores.Count - 1) do
      begin
        LJSONObject := TJSONObject.Create;
        try
          LJSONObject.AddPair('id', LSortedScores[I].Key);
          LJSONObject.AddPair('score', TJSONNumber.Create(LSortedScores[I].Value));
          if LTextMap.ContainsKey(LSortedScores[I].Key) then
            LJSONObject.AddPair('text', LTextMap[LSortedScores[I].Key]);
          Result.AddElement(LJSONObject);
        except
          LJSONObject.Free;
          Continue;  // Continue to next result on error
        end;
      end;

      // soConsole.PrintLn('Search completed in %d ms with %d results', [MilliSecondsBetween(Now, LStartTime), Result.Count]);
    finally
      LSortedScores.Free;
    end;
  finally
    LSimilarityScores.Free;
    LTextMap.Free;
  end;
end;

function TsoVectorDatabase.Search2(const AQuery: string; const ATopK: Integer; const AQueryLimit: Integer; const ASimilarityThreshold: Single; const AMaxContext: Cardinal; const AMaxThreads: Integer): TArray<TsoVectorDatabaseDocument>;

var
  LJson: TJSONArray;

  function ParseJSONToDocuments(const JSONArray: TJSONArray): TArray<TsoVectorDatabaseDocument>;
  var
    DocumentList: TList<TsoVectorDatabaseDocument>;
    JSONObject: TJSONObject;
    Doc: TsoVectorDatabaseDocument;
    i: Integer;
  begin
    Result := nil;
    if not Assigned(JSONArray) then
      Exit;

    DocumentList := TList<TsoVectorDatabaseDocument>.Create;
    try
      for i := 0 to JSONArray.Count - 1 do
      begin
        JSONObject := JSONArray.Items[i] as TJSONObject;
        if Assigned(JSONObject) then
        begin
          Doc.ID := JSONObject.GetValue<string>('id');
          Doc.Score := JSONObject.GetValue<Double>('score');  // JSON numbers are treated as Double
          Doc.Text := JSONObject.GetValue<string>('text');
          DocumentList.Add(Doc);
        end;
      end;
      Result := DocumentList.ToArray;
    finally
      DocumentList.Free;
    end;
  end;

begin
  Result := nil;

  LJson := Search(AQuery, ATopK, AQueryLimit, ASimilarityThreshold, AMaxContext, AMaxThreads);
  try
    if not Assigned(LJson) then Exit;

    Result := ParseJSONToDocuments(LJson);
  finally
    LJson.Free();
  end;


end;

end.
