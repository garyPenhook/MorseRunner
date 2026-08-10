//------------------------------------------------------------------------------
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit CallList;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils;

type
  ECallList = class(Exception);

  TCallList = class
  private
    FCalls: TStringList;
    function GetCount: Integer;
    function GetCall(const Index: Integer): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadMasterDta(const FileName: string);
    function Pick(const Index: Integer): string;

    property Count: Integer read GetCount;
    property Calls[const Index: Integer]: string read GetCall;
  end;

function FindMasterDta(const ExplicitFileName: string = ''): string;

implementation

const
  CALL_LIST_FILE_NAME = 'Master.dta';
  LEGACY_CALL_CHARS = ['A'..'Z', '0'..'9', '/'];
  LEGACY_INDEX_SIZE = 37 * 37 + 1;

function XdgDataHome: string;
begin
  Result := GetEnvironmentVariable('XDG_DATA_HOME');
  if Result = '' then
  begin
    Result := GetEnvironmentVariable('HOME');
    if Result = '' then
      Result := GetCurrentDir
    else
      Result := IncludeTrailingPathDelimiter(Result) + '.local' + PathDelim +
        'share';
  end;
end;

function ExistingFile(const FileName: string): string;
begin
  if (FileName <> '') and FileExists(FileName) then
    Result := FileName
  else
    Result := '';
end;

function FindMasterDta(const ExplicitFileName: string): string;
begin
  Result := ExistingFile(ExplicitFileName);
  if Result <> '' then
    Exit;
  Result := ExistingFile(IncludeTrailingPathDelimiter(XdgDataHome) +
    'morserunner' + PathDelim + CALL_LIST_FILE_NAME);
  if Result <> '' then
    Exit;
  Result := ExistingFile(IncludeTrailingPathDelimiter(GetCurrentDir) +
    CALL_LIST_FILE_NAME);
  if Result <> '' then
    Exit;
  Result := ExistingFile('/usr/share/morserunner/' + CALL_LIST_FILE_NAME);
end;

constructor TCallList.Create;
begin
  inherited Create;
  FCalls := TStringList.Create;
  FCalls.Sorted := True;
  FCalls.Duplicates := dupIgnore;
end;

destructor TCallList.Destroy;
begin
  FCalls.Free;
  inherited Destroy;
end;

procedure TCallList.Clear;
begin
  FCalls.Clear;
end;

function TCallList.GetCount: Integer;
begin
  Result := FCalls.Count;
end;

function TCallList.GetCall(const Index: Integer): string;
begin
  Result := FCalls[Index];
end;

function ReadNativeInteger(const Data: TBytes; const Offset: Integer): LongInt;
begin
  Result := 0;
  if (Offset < 0) or (Offset + SizeOf(Result) > Length(Data)) then
    raise ECallList.Create('Master.dta index is truncated.');
  Move(Data[Offset], Result, SizeOf(Result));
end;

procedure TCallList.LoadMasterDta(const FileName: string);
var
  Stream: TFileStream;
  Data: TBytes;
  HeaderBytes: Integer;
  FileSize: Integer;
  Position: Integer;
  Start: Integer;
  Character: Char;
  Entry: string;
begin
  Clear;
  Data := nil;
  Entry := '';
  if not FileExists(FileName) then
    raise ECallList.CreateFmt('Call list "%s" does not exist.', [FileName]);

  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size > MaxInt then
      raise ECallList.Create('Master.dta is too large.');
    FileSize := Stream.Size;
    SetLength(Data, FileSize);
    if FileSize > 0 then
      Stream.ReadBuffer(Data[0], FileSize);
  finally
    Stream.Free;
  end;

  HeaderBytes := LEGACY_INDEX_SIZE * SizeOf(LongInt);
  if FileSize < HeaderBytes then
    raise ECallList.Create('Master.dta is smaller than its legacy index.');
  if (ReadNativeInteger(Data, 0) <> HeaderBytes) or
    (ReadNativeInteger(Data, HeaderBytes - SizeOf(LongInt)) <> FileSize) then
    raise ECallList.Create('Master.dta has an invalid legacy index.');

  Position := HeaderBytes;
  while Position < FileSize do
  begin
    Start := Position;
    while (Position < FileSize) and (Data[Position] <> 0) do
    begin
      Character := Chr(Data[Position]);
      if not (Character in LEGACY_CALL_CHARS) then
        raise ECallList.Create('Master.dta contains an invalid callsign byte.');
      Inc(Position);
    end;
    if Position = FileSize then
      raise ECallList.Create('Master.dta ends inside a callsign.');
    if Position = Start then
      raise ECallList.Create('Master.dta contains an empty callsign.');

    SetLength(Entry, Position - Start);
    Move(Data[Start], Entry[1], Length(Entry));
    FCalls.Add(Entry);
    Inc(Position);
  end;

  if FCalls.Count = 0 then
    raise ECallList.Create('Master.dta contains no callsigns.');
end;

function TCallList.Pick(const Index: Integer): string;
begin
  if FCalls.Count = 0 then
    raise ECallList.Create('Cannot pick a callsign from an empty call list.');
  if Index < 0 then
    raise ECallList.Create('Call list selection index cannot be negative.');
  Result := FCalls[Index mod FCalls.Count];
end;

end.
