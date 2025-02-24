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
  System.SysUtils,
  Sophora.Utils,
  Sophora.Common;

const
  { WebSearch API Key environment variable name }
  CsoWebSearchApiKeyEnvVar = 'TAVILY_API_KEY';

type

  { TsoWebSearch }
  TsoWebSearch = class(TsoBaseObject)
  var
    FResponse: string;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function Query(const AQuery: string): Boolean;
    function Response(): string;
  end;

implementation

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
