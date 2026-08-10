program CallListTests;

{$mode delphi}{$H+}

uses
  Classes,
  SysUtils,
  CallList;

const
  IndexSize = 37 * 37 + 1;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure WriteInteger(Stream: TStream; const Value: LongInt);
begin
  Stream.WriteBuffer(Value, SizeOf(Value));
end;

procedure WriteFixture(const FileName: string; const Entries: array of string);
var
  Stream: TFileStream;
  HeaderBytes: LongInt;
  FileSize: LongInt;
  Index: Integer;
  Entry: string;
  Zero: Byte;
begin
  HeaderBytes := IndexSize * SizeOf(LongInt);
  FileSize := HeaderBytes;
  for Index := Low(Entries) to High(Entries) do
    Inc(FileSize, Length(Entries[Index]) + 1);

  Stream := TFileStream.Create(FileName, fmCreate);
  try
    WriteInteger(Stream, HeaderBytes);
    for Index := 1 to IndexSize - 2 do
      WriteInteger(Stream, 0);
    WriteInteger(Stream, FileSize);
    Zero := 0;
    for Index := Low(Entries) to High(Entries) do
    begin
      Entry := Entries[Index];
      Stream.WriteBuffer(Entry[1], Length(Entry));
      Stream.WriteBuffer(Zero, SizeOf(Zero));
    end;
  finally
    Stream.Free;
  end;
end;

function TestFileName(const Suffix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'morserunner-call-list-' + IntToStr(GetTickCount64) + '-' + Suffix;
end;

procedure TestLoadAndPick;
var
  FileName: string;
  List: TCallList;
  Failed: Boolean;
begin
  FileName := TestFileName('valid.dta');
  WriteFixture(FileName, ['P29SX', 'VE3NEA', 'P29SX', 'F/VE3NEA']);
  List := TCallList.Create;
  try
    List.LoadMasterDta(FileName);
    Check(List.Count = 3, 'duplicates are removed');
    Check(List.Calls[0] = 'F/VE3NEA', 'calls are sorted');
    Check(List.Pick(4) = 'P29SX', 'selection wraps safely');
    Failed := False;
    try
      List.Pick(-1);
    except
      on ECallList do Failed := True;
    end;
    Check(Failed, 'negative selection is rejected');
  finally
    List.Free;
    DeleteFile(FileName);
  end;
end;

procedure TestRejectsBadData;
var
  FileName: string;
  Stream: TFileStream;
  List: TCallList;
  Failed: Boolean;
begin
  FileName := TestFileName('invalid.dta');
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer('bad', 3);
  finally
    Stream.Free;
  end;
  List := TCallList.Create;
  try
    Failed := False;
    try
      List.LoadMasterDta(FileName);
    except
      on ECallList do Failed := True;
    end;
    Check(Failed, 'truncated legacy index is rejected');
  finally
    List.Free;
    DeleteFile(FileName);
  end;
end;

procedure TestSuperCheckPartial;
var
  FileName: string;
  Lines: TStringList;
  List: TCallList;
begin
  FileName := TestFileName('master.scp');
  Lines := TStringList.Create;
  try
    Lines.Add('!!Order,1,1');
    Lines.Add('# Super Check Partial fixture');
    Lines.Add('ve3nea');
    Lines.Add('P29SX');
    Lines.Add('VE3NEA');
    Lines.SaveToFile(FileName);
  finally
    Lines.Free;
  end;

  List := TCallList.Create;
  try
    List.Load(FileName);
    Check(List.Count = 2, 'SCP duplicate calls are removed');
    Check(List.Calls[1] = 'VE3NEA', 'SCP calls are normalized');
  finally
    List.Free;
    DeleteFile(FileName);
  end;
end;

begin
  try
    TestLoadAndPick;
    TestRejectsBadData;
    TestSuperCheckPartial;
    WriteLn('Call list tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Call list tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
