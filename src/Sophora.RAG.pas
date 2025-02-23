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
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.JSON,
  Sophora.CLibs,
  Sophora.Utils,
  Sophora.Common,
  Sophora.Inference;

type

  { TsoEmbeddings }
  TsoEmbeddings = class(TsoModel)
  protected
    procedure Normalize(AInVectors, LOutVectors: PSingle; const ACount: Integer);
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function  LoadModel(const AMainGPU: Integer=-1; const AGPULayers: Integer=-1; const AFilename: string=CsoEmbeddingsLLMFilename): Boolean; override;
    function  Generate(const APrompt: string): TArray<Single>;
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

  function GetTypeAsString(AStmt: Psqlite3_stmt; AColumn: Integer): string;
  begin
    case sqlite3_column_type(AStmt, AColumn) of
      SQLITE_INTEGER: Result := IntToStr(sqlite3_column_int(AStmt, AColumn));
      SQLITE_FLOAT: Result := FloatToStr(sqlite3_column_double(AStmt, AColumn));
      SQLITE_TEXT: Result := string(PWideChar(sqlite3_column_text16(AStmt, i)));
      SQLITE_BLOB: Result := '[Blob Data]';  // BLOB data typically needs special handling
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

  if ASQL.StartsWith('with') then
  begin
    writeln('got here');
    writeln(sqlite3_bind_text16(FStmt, 1,PChar('firearm courtroom'), -1, sqlite3_destructor_type(0)));
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
    FDataset := TJSONArray.Create;
    while LRes = SQLITE_ROW do
    begin
      var Row := TJSONObject.Create;
      for i := 0 to sqlite3_column_count(FStmt) - 1 do
      begin
        LName := string(PWideChar(sqlite3_column_name16(FStmt, i)));
        LValue := GetTypeAsString(FStmt, i);

        Row.AddPair(LName, LValue);
      end;
      FDataset.AddElement(Row);
      LRes := sqlite3_step(FStmt);
    end;
    FJSON := TJSONObject.Create;
    FJSON.AddPair('response', FDataset);
    FResponseText := FJson.Format();
  end;

  FError := '';
  Result := True;
  sqlite3_finalize(FStmt);
  FStmt := nil;
end;

function TsoDatabase.GetResponseText(): string;
begin
  Result := FResponseText;
end;

end.
