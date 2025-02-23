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

unit Sophora.Console;

{$I Sophora.Defines.inc}

interface

uses
  WinApi.Windows,
  WinApi.Messages,
  System.SysUtils,
  Sophora.Utils;

const
  soLF   = AnsiChar(#10);
  soCR   = AnsiChar(#13);
  soCRLF = soLF+soCR;
  soESC  = AnsiChar(#27);

  soVK_ESC = 27;

  // Cursor Movement
  soCSICursorPos = soESC + '[%d;%dH';         // Set cursor position
  soCSICursorUp = soESC + '[%dA';             // Move cursor up
  soCSICursorDown = soESC + '[%dB';           // Move cursor down
  soCSICursorForward = soESC + '[%dC';        // Move cursor forward
  soCSICursorBack = soESC + '[%dD';           // Move cursor backward
  soCSISaveCursorPos = soESC + '[s';          // Save cursor position
  soCSIRestoreCursorPos = soESC + '[u';       // Restore cursor position

  // Cursor Visibility
  soCSIShowCursor = soESC + '[?25h';          // Show cursor
  soCSIHideCursor = soESC + '[?25l';          // Hide cursor
  soCSIBlinkCursor = soESC + '[?12h';         // Enable cursor blinking
  soCSISteadyCursor = soESC + '[?12l';        // Disable cursor blinking

  // Screen Manipulation
  soCSIClearScreen = soESC + '[2J';           // Clear screen
  soCSIClearLine = soESC + '[2K';             // Clear line
  soCSIScrollUp = soESC + '[%dS';             // Scroll up by n lines
  soCSIScrollDown = soESC + '[%dT';           // Scroll down by n lines

  // Text Formatting
  soCSIBold = soESC + '[1m';                  // Bold text
  soCSIUnderline = soESC + '[4m';             // Underline text
  soCSIResetFormat = soESC + '[0m';           // Reset text formatting
  soCSIResetBackground = #27'[49m';         // Reset background text formatting
  soCSIResetForeground = #27'[39m';         // Reset forground text formatting
  soCSIInvertColors = soESC + '[7m';          // Invert foreground/background
  soCSINormalColors = soESC + '[27m';         // Normal colors

  soCSIDim = soESC + '[2m';
  soCSIItalic = soESC + '[3m';
  soCSIBlink = soESC + '[5m';
  soCSIFramed = soESC + '[51m';
  soCSIEncircled = soESC + '[52m';

  // Text Modification
  soCSIInsertChar = soESC + '[%d@';           // Insert n spaces at cursor position
  soCSIDeleteChar = soESC + '[%dP';           // Delete n characters at cursor position
  soCSIEraseChar = soESC + '[%dX';            // Erase n characters at cursor position

  // Colors (Foreground and Background)
  soCSIFGBlack = soESC + '[30m';
  soCSIFGRed = soESC + '[31m';
  soCSIFGGreen = soESC + '[32m';
  soCSIFGYellow = soESC + '[33m';
  soCSIFGBlue = soESC + '[34m';
  soCSIFGMagenta = soESC + '[35m';
  soCSIFGCyan = soESC + '[36m';
  soCSIFGWhite = soESC + '[37m';

  soCSIBGBlack = soESC + '[40m';
  soCSIBGRed = soESC + '[41m';
  soCSIBGGreen = soESC + '[42m';
  soCSIBGYellow = soESC + '[43m';
  soCSIBGBlue = soESC + '[44m';
  soCSIBGMagenta = soESC + '[45m';
  soCSIBGCyan = soESC + '[46m';
  soCSIBGWhite = soESC + '[47m';

  soCSIFGBrightBlack = soESC + '[90m';
  soCSIFGBrightRed = soESC + '[91m';
  soCSIFGBrightGreen = soESC + '[92m';
  soCSIFGBrightYellow = soESC + '[93m';
  soCSIFGBrightBlue = soESC + '[94m';
  soCSIFGBrightMagenta = soESC + '[95m';
  soCSIFGBrightCyan = soESC + '[96m';
  soCSIFGBrightWhite = soESC + '[97m';

  soCSIBGBrightBlack = soESC + '[100m';
  soCSIBGBrightRed = soESC + '[101m';
  soCSIBGBrightGreen = soESC + '[102m';
  soCSIBGBrightYellow = soESC + '[103m';
  soCSIBGBrightBlue = soESC + '[104m';
  soCSIBGBrightMagenta = soESC + '[105m';
  soCSIBGBrightCyan = soESC + '[106m';
  soCSIBGBrightWhite = soESC + '[107m';

  soCSIFGRGB = soESC + '[38;2;%d;%d;%dm';        // Foreground RGB
  soCSIBGRGB = soESC + '[48;2;%d;%d;%dm';        // Backg

type
  { soCharSet }
  soCharSet = set of AnsiChar;

  { soConsole }
  soConsole = class
  private class var
    FInputCodePage: Cardinal;
    FOutputCodePage: Cardinal;
    FTeletypeDelay: Integer;
    FKeyState: array [0..1, 0..255] of Boolean;
  private
    class constructor Create();
    class destructor Destroy();
  public
    class procedure UnitInit();
    class procedure Print(const AMsg: string); overload; static;
    class procedure PrintLn(const AMsg: string); overload; static;

    class procedure Print(const AMsg: string; const AArgs: array of const); overload; static;
    class procedure PrintLn(const AMsg: string; const AArgs: array of const); overload; static;

    class procedure Print(); overload; static;
    class procedure PrintLn(); overload; static;

    class procedure GetCursorPos(X, Y: PInteger); static;
    class procedure SetCursorPos(const X, Y: Integer); static;
    class procedure SetCursorVisible(const AVisible: Boolean); static;
    class procedure HideCursor(); static;
    class procedure ShowCursor(); static;
    class procedure SaveCursorPos(); static;
    class procedure RestoreCursorPos(); static;
    class procedure MoveCursorUp(const ALines: Integer); static;
    class procedure MoveCursorDown(const ALines: Integer); static;
    class procedure MoveCursorForward(const ACols: Integer); static;
    class procedure MoveCursorBack(const ACols: Integer); static;

    class procedure ClearScreen(); static;
    class procedure ClearLine(); static;
    class procedure ClearLineFromCursor(const AColor: string); static;

    class procedure SetBoldText(); static;
    class procedure ResetTextFormat(); static;
    class procedure SetForegroundColor(const AColor: string); static;
    class procedure SetBackgroundColor(const AColor: string); static;
    class procedure SetForegroundRGB(const ARed, AGreen, ABlue: Byte); static;
    class procedure SetBackgroundRGB(const ARed, AGreen, ABlue: Byte); static;

    class procedure GetSize(AWidth: PInteger; AHeight: PInteger); static;

    class procedure SetTitle(const ATitle: string); static;
    class function  GetTitle(): string; static;

    class function  HasOutput(): Boolean; static;
    class function  WasRunFrom(): Boolean; static;
    class procedure WaitForAnyKey(); static;
    class function  AnyKeyPressed(): Boolean; static;

    class procedure ClearKeyStates(); static;
    class procedure ClearKeyboardBuffer(); static;

    class function  IsKeyPressed(AKey: Byte): Boolean; static;
    class function  WasKeyReleased(AKey: Byte): Boolean; static;
    class function  WasKeyPressed(AKey: Byte): Boolean; static;

    class function  ReadKey(): WideChar; static;
    class function  ReadLnX(const AAllowedChars: soCharSet; AMaxLength: Integer; const AColor: string=soCSIFGWhite): string; static;

    class procedure Pause(const AForcePause: Boolean=False; AColor: string=soCSIFGWhite; const AMsg: string=''); static;

    class function  WrapTextEx(const ALine: string; AMaxCol: Integer; const ABreakChars: soCharSet=[' ', '-', ',', ':', #9]): string; static;
    class procedure Teletype(const AText: string; const AColor: string=soCSIFGWhite; const AMargin: Integer=10; const AMinDelay: Integer=0; const AMaxDelay: Integer=3; const ABreakKey: Byte=VK_ESCAPE); static;
  end;

implementation

{ soConsole }
class constructor soConsole.Create();
begin
  FTeletypeDelay := 0;

  // save current console codepage
  FInputCodePage := GetConsoleCP();
  FOutputCodePage := GetConsoleOutputCP();

  // set code page to UTF8
  SetConsoleCP(CP_UTF8);
  SetConsoleOutputCP(CP_UTF8);

  soUtils.EnableVirtualTerminalProcessing();
end;

class destructor soConsole.Destroy();
begin
  // restore code page
  SetConsoleCP(FInputCodePage);
  SetConsoleOutputCP(FOutputCodePage);
end;

class procedure soConsole.UnitInit();
begin
end;

class procedure soConsole.Print(const AMsg: string);
begin
  if not HasOutput() then Exit;
  Write(AMsg+soCSIResetFormat);
end;

class procedure soConsole.PrintLn(const AMsg: string);
begin
  if not HasOutput() then Exit;
  WriteLn(AMsg+soCSIResetFormat);
end;

class procedure soConsole.Print(const AMsg: string; const AArgs: array of const);
begin
  if not HasOutput() then Exit;
  Write(Format(AMsg, AArgs)+soCSIResetFormat);
end;

class procedure soConsole.PrintLn(const AMsg: string; const AArgs: array of const);
begin
  if not HasOutput() then Exit;
  WriteLn(Format(AMsg, AArgs)+soCSIResetFormat);
end;

class procedure soConsole.Print();
begin
  if not HasOutput() then Exit;
  Write(soCSIResetFormat);
end;

class procedure soConsole.PrintLn();
begin
  if not HasOutput() then Exit;
  WriteLn(soCSIResetFormat);
end;

class procedure soConsole.GetCursorPos(X, Y: PInteger);
var
  hConsole: THandle;
  BufferInfo: TConsoleScreenBufferInfo;
begin
  hConsole := GetStdHandle(STD_OUTPUT_HANDLE);
  if hConsole = INVALID_HANDLE_VALUE then
    Exit;

  if not GetConsoleScreenBufferInfo(hConsole, BufferInfo) then
    Exit;

  if Assigned(X) then
    X^ := BufferInfo.dwCursorPosition.X;
  if Assigned(Y) then
    Y^ := BufferInfo.dwCursorPosition.Y;
end;

class procedure soConsole.SetCursorPos(const X, Y: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(soCSICursorPos, [X, Y]));
end;

class procedure soConsole.SetCursorVisible(const AVisible: Boolean);
var
  ConsoleInfo: TConsoleCursorInfo;
  ConsoleHandle: THandle;
begin
  ConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  ConsoleInfo.dwSize := 25; // You can adjust cursor size if needed
  ConsoleInfo.bVisible := AVisible;
  SetConsoleCursorInfo(ConsoleHandle, ConsoleInfo);
end;

class procedure soConsole.HideCursor();
begin
  if not HasOutput() then Exit;
  Write(soCSIHideCursor);
end;

class procedure soConsole.ShowCursor();
begin
  if not HasOutput() then Exit;
  Write(soCSIShowCursor);
end;

class procedure soConsole.SaveCursorPos();
begin
  if not HasOutput() then Exit;
  Write(soCSISaveCursorPos);
end;

class procedure soConsole.RestoreCursorPos();
begin
  if not HasOutput() then Exit;
  Write(soCSIRestoreCursorPos);
end;

class procedure soConsole.MoveCursorUp(const ALines: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(soCSICursorUp, [ALines]));
end;

class procedure soConsole.MoveCursorDown(const ALines: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(soCSICursorDown, [ALines]));
end;

class procedure soConsole.MoveCursorForward(const ACols: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(soCSICursorForward, [ACols]));
end;

class procedure soConsole.MoveCursorBack(const ACols: Integer);
begin
  if not HasOutput() then Exit;
  Write(Format(soCSICursorBack, [ACols]));
end;

class procedure soConsole.ClearScreen();
begin
  if not HasOutput() then Exit;
  Write(soCSIClearScreen);
  SetCursorPos(0, 0);
end;

class procedure soConsole.ClearLine();
begin
  if not HasOutput() then Exit;
  Write(soCR);
  Write(soCSIClearLine);
end;

class procedure soConsole.ClearLineFromCursor(const AColor: string);
var
  LConsoleOutput: THandle;
  LConsoleInfo: TConsoleScreenBufferInfo;
  LNumCharsWritten: DWORD;
  LCoord: TCoord;
begin
  LConsoleOutput := GetStdHandle(STD_OUTPUT_HANDLE);

  if GetConsoleScreenBufferInfo(LConsoleOutput, LConsoleInfo) then
  begin
    LCoord.X := 0;
    LCoord.Y := LConsoleInfo.dwCursorPosition.Y;

    Print(AColor, []);
    FillConsoleOutputCharacter(LConsoleOutput, ' ', LConsoleInfo.dwSize.X
      - LConsoleInfo.dwCursorPosition.X, LCoord, LNumCharsWritten);
    SetConsoleCursorPosition(LConsoleOutput, LCoord);
  end;
end;

class procedure soConsole.SetBoldText();
begin
  if not HasOutput() then Exit;
  Write(soCSIBold);
end;

class procedure soConsole.ResetTextFormat();
begin
  if not HasOutput() then Exit;
  Write(soCSIResetFormat);
end;

class procedure soConsole.SetForegroundColor(const AColor: string);
begin
  if not HasOutput() then Exit;
  Write(AColor);
end;

class procedure soConsole.SetBackgroundColor(const AColor: string);
begin
  if not HasOutput() then Exit;
  Write(AColor);
end;

class procedure soConsole.SetForegroundRGB(const ARed, AGreen, ABlue: Byte);
begin
  if not HasOutput() then Exit;
  Write(Format(soCSIFGRGB, [ARed, AGreen, ABlue]));
end;

class procedure soConsole.SetBackgroundRGB(const ARed, AGreen, ABlue: Byte);
begin
  if not HasOutput() then Exit;
  Write(Format(soCSIBGRGB, [ARed, AGreen, ABlue]));
end;

class procedure soConsole.GetSize(AWidth: PInteger; AHeight: PInteger);
var
  LConsoleInfo: TConsoleScreenBufferInfo;
begin
  if not HasOutput() then Exit;

  GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), LConsoleInfo);
  if Assigned(AWidth) then
    AWidth^ := LConsoleInfo.dwSize.X;

  if Assigned(AHeight) then
  AHeight^ := LConsoleInfo.dwSize.Y;
end;

class procedure soConsole.SetTitle(const ATitle: string);
begin
  WinApi.Windows.SetConsoleTitle(PChar(ATitle));
end;

class function  soConsole.GetTitle(): string;
const
  MAX_TITLE_LENGTH = 1024;
var
  LTitle: array[0..MAX_TITLE_LENGTH] of WideChar;
  LTitleLength: DWORD;
begin
  // Get the console title and store it in LTitle
  LTitleLength := GetConsoleTitleW(LTitle, MAX_TITLE_LENGTH);

  // If the title is retrieved, assign it to the result
  if LTitleLength > 0 then
    Result := string(LTitle)
  else
    Result := '';
end;

class function  soConsole.HasOutput(): Boolean;
var
  LStdHandle: THandle;
begin
  LStdHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  Result := (LStdHandle <> INVALID_HANDLE_VALUE) and
            (GetFileType(LStdHandle) = FILE_TYPE_CHAR);
end;

class function  soConsole.WasRunFrom(): Boolean;
var
  LStartupInfo: TStartupInfo;
begin
  LStartupInfo.cb := SizeOf(TStartupInfo);
  GetStartupInfo(LStartupInfo);
  Result := ((LStartupInfo.dwFlags and STARTF_USESHOWWINDOW) = 0);
end;

class procedure soConsole.WaitForAnyKey();
var
  LInputRec: TInputRecord;
  LNumRead: Cardinal;
  LOldMode: DWORD;
  LStdIn: THandle;
begin
  LStdIn := GetStdHandle(STD_INPUT_HANDLE);
  GetConsoleMode(LStdIn, LOldMode);
  SetConsoleMode(LStdIn, 0);
  repeat
    ReadConsoleInput(LStdIn, LInputRec, 1, LNumRead);
  until (LInputRec.EventType and KEY_EVENT <> 0) and
    LInputRec.Event.KeyEvent.bKeyDown;
  SetConsoleMode(LStdIn, LOldMode);
end;

class function  soConsole.AnyKeyPressed(): Boolean;
var
  LNumberOfEvents     : DWORD;
  LBuffer             : TInputRecord;
  LNumberOfEventsRead : DWORD;
  LStdHandle           : THandle;
begin
  Result:=false;
  //get the console handle
  LStdHandle := GetStdHandle(STD_INPUT_HANDLE);
  LNumberOfEvents:=0;
  //get the number of events
  GetNumberOfConsoleInputEvents(LStdHandle,LNumberOfEvents);
  if LNumberOfEvents<> 0 then
  begin
    //retrieve the event
    PeekConsoleInput(LStdHandle,LBuffer,1,LNumberOfEventsRead);
    if LNumberOfEventsRead <> 0 then
    begin
      if LBuffer.EventType = KEY_EVENT then //is a Keyboard event?
      begin
        if LBuffer.Event.KeyEvent.bKeyDown then //the key was pressed?
          Result:=true
        else
          FlushConsoleInputBuffer(LStdHandle); //flush the buffer
      end
      else
      FlushConsoleInputBuffer(LStdHandle);//flush the buffer
    end;
  end;
end;

class procedure soConsole.ClearKeyStates();
begin
  FillChar(FKeyState, SizeOf(FKeyState), 0);
  ClearKeyboardBuffer();
end;

class procedure soConsole.ClearKeyboardBuffer();
var
  LInputRecord: TInputRecord;
  LEventsRead: DWORD;
  LMsg: TMsg;
begin
  while PeekConsoleInput(GetStdHandle(STD_INPUT_HANDLE), LInputRecord, 1, LEventsRead) and (LEventsRead > 0) do
  begin
    ReadConsoleInput(GetStdHandle(STD_INPUT_HANDLE), LInputRecord, 1, LEventsRead);
  end;

  while PeekMessage(LMsg, 0, WM_KEYFIRST, WM_KEYLAST, PM_REMOVE) do
  begin
    // No operation; just removing messages from the queue
  end;
end;

class function  soConsole.IsKeyPressed(AKey: Byte): Boolean;
begin
  Result := (GetAsyncKeyState(AKey) and $8000) <> 0;
end;

class function  soConsole.WasKeyReleased(AKey: Byte): Boolean;
begin
  Result := False;
  if IsKeyPressed(AKey) and (not FKeyState[1, AKey]) then
  begin
    FKeyState[1, AKey] := True;
    Result := True;
  end
  else if (not IsKeyPressed(AKey)) and (FKeyState[1, AKey]) then
  begin
    FKeyState[1, AKey] := False;
    Result := False;
  end;
end;

class function  soConsole.WasKeyPressed(AKey: Byte): Boolean;
begin
  Result := False;
  if IsKeyPressed(AKey) and (not FKeyState[1, AKey]) then
  begin
    FKeyState[1, AKey] := True;
    Result := False;
  end
  else if (not IsKeyPressed(AKey)) and (FKeyState[1, AKey]) then
  begin
    FKeyState[1, AKey] := False;
    Result := True;
  end;
end;

class function  soConsole.ReadKey(): WideChar;
var
  LInputRecord: TInputRecord;
  LEventsRead: DWORD;
begin
  repeat
    ReadConsoleInput(GetStdHandle(STD_INPUT_HANDLE), LInputRecord, 1, LEventsRead);
  until (LInputRecord.EventType = KEY_EVENT) and LInputRecord.Event.KeyEvent.bKeyDown;
  Result := LInputRecord.Event.KeyEvent.UnicodeChar;
end;

class function  soConsole.ReadLnX(const AAllowedChars: soCharSet; AMaxLength: Integer; const AColor: string): string;
var
  LInputChar: Char;
begin
  Result := '';

  repeat
    LInputChar := ReadKey;

    if CharInSet(LInputChar, AAllowedChars) then
    begin
      if Length(Result) < AMaxLength then
      begin
        if not CharInSet(LInputChar, [#10, #0, #13, #8])  then
        begin
          //Print(LInputChar, AColor);
          Print('%s%s', [AColor, LInputChar]);
          Result := Result + LInputChar;
        end;
      end;
    end;
    if LInputChar = #8 then
    begin
      if Length(Result) > 0 then
      begin
        //Print(#8 + ' ' + #8);
        Print(#8 + ' ' + #8, []);
        Delete(Result, Length(Result), 1);
      end;
    end;
  until (LInputChar = #13);

  PrintLn();
end;

class procedure soConsole.Pause(const AForcePause: Boolean; AColor: string; const AMsg: string);
var
  LDoPause: Boolean;
begin
  if not HasOutput then Exit;

  ClearKeyboardBuffer();

  if not AForcePause then
  begin
    LDoPause := True;
    if WasRunFrom() then LDoPause := False;
    if soUtils.IsStartedFromDelphiIDE() then LDoPause := True;
    if not LDoPause then Exit;
  end;

  WriteLn;
  if AMsg = '' then
    Print('%sPress any key to continue... ', [aColor])
  else
    Print('%s%s', [aColor, AMsg]);

  WaitForAnyKey();
  WriteLn;
end;

class function  soConsole.WrapTextEx(const ALine: string; AMaxCol: Integer; const ABreakChars: soCharSet): string;
var
  LText: string;
  LPos: integer;
  LChar: Char;
  LLen: Integer;
  I: Integer;
begin
  LText := ALine.Trim;

  LPos := 0;
  LLen := 0;

  while LPos < LText.Length do
  begin
    Inc(LPos);

    LChar := LText[LPos];

    if LChar = #10 then
    begin
      LLen := 0;
      continue;
    end;

    Inc(LLen);

    if LLen >= AMaxCol then
    begin
      for I := LPos downto 1 do
      begin
        LChar := LText[I];

        if CharInSet(LChar, ABreakChars) then
        begin
          LText.Insert(I, #10);
          Break;
        end;
      end;

      LLen := 0;
    end;
  end;

  Result := LText;
end;

class procedure soConsole.Teletype(const AText: string; const AColor: string; const AMargin: Integer; const AMinDelay: Integer; const AMaxDelay: Integer; const ABreakKey: Byte);
var
  LText: string;
  LMaxCol: Integer;
  LChar: Char;
  LWidth: Integer;
begin
  GetSize(@LWidth, nil);
  LMaxCol := LWidth - AMargin;

  LText := WrapTextEx(AText, LMaxCol);

  for LChar in LText do
  begin
    soUtils.ProcessMessages();
    Print('%s%s', [AColor, LChar]);
    if not soUtils.RandomBool() then
      FTeletypeDelay := soUtils.RandomRange(AMinDelay, AMaxDelay);
    soUtils.Wait(FTeletypeDelay);
    if IsKeyPressed(ABreakKey) then
    begin
      ClearKeyboardBuffer;
      Break;
    end;
  end;
end;

end.
