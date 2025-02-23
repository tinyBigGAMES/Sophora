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

unit Sophora.Common;

{$I Sophora.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.IOUtils,
  Sophora.CLibs,
  Sophora.Utils,
  Sophora.Console;

const
  CsoSophoraVersion  = '0.1.0';

  CsoTavilyApiKeyEnvVar = 'TAVILY_API_KEY';

  CsoDefaultModelPath  = 'C:/LLM/GGUF';

  CsoGeneralLLMFilename = 'deephermes-3-llama-3-8b-preview-q4_k_m.gguf';
  //CsoEmbeddingsLLMFilename = 'bge-m3-q8_0.gguf';
  //CsoEmbeddingsLLMFilename = 'all-minilm-l6-v2-q8_0.gguf';
  //CsoEmbeddingsLLMFilename = 'bge-m3-F16.gguf';
  CsoEmbeddingsLLMFilename = 'deephermes-3-llama-3-8b-preview-q4_k_m.gguf';

type

  { TsoBaseObject }
  TsoBaseObject = class
  protected
    FError: string;
  public
    constructor Create(); virtual;
    destructor Destroy(); override;
    procedure SetError(const AText: string; const AArgs: array of const); virtual;
    function  GetError(): string; virtual;
  end;

implementation

{ TsoBaseObject }
constructor TsoBaseObject.Create();
begin
  inherited;
end;

destructor TsoBaseObject.Destroy();
begin
  inherited;
end;

procedure TsoBaseObject.SetError(const AText: string; const AArgs: array of const);
begin
  FError := Format(AText, AArgs);
end;

function  TsoBaseObject.GetError(): string;
begin
  Result := FError;
end;

initialization
begin
  ReportMemoryLeaksOnShutdown := True;

  soUtils.UnitInit();
  soConsole.UnitInit();
end;

finalization
begin
end;

end.
