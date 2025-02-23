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

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Sophora in '..\..\src\Sophora.pas',
  Sophora.CLibs in '..\..\src\Sophora.CLibs.pas',
  Sophora.Utils in '..\..\src\Sophora.Utils.pas',
  Sophora.Console in '..\..\src\Sophora.Console.pas',
  Sophora.Common in '..\..\src\Sophora.Common.pas',
  Sophora.Inference in '..\..\src\Sophora.Inference.pas',
  Sophora.Messages in '..\..\src\Sophora.Messages.pas',
  UTestbed in 'UTestbed.pas',
  Sophora.RAG in '..\..\src\Sophora.RAG.pas';

begin
  try
    RunTests();
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
