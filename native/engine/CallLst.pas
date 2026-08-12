//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit CallLst;
{$ifdef FPC}{$MODE Delphi}{$endif}

interface

uses
  Classes{$ifdef FPC}, GetDataPath{$endif};

type
  // simple calllist. contains a TStringList of callsigns.
  TCallList = class
  protected
    Calls: TStringList;

  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadCallList;
    function IsEmpty : Boolean;
    procedure Clear();
    function PickCall : string;
  end;

// Validate and normalize a plain-text Super Check Partial list, then save it
// as the per-user override used by new practice sessions.
function ImportCallsignList(const SourceFileName: string; out CallCount: Integer;
  out ErrorMessage: string): Boolean;


implementation

uses
  SysUtils, Ini;

function CompareCalls(Item1, Item2: Pointer): Integer;
begin
  Result := StrComp(PChar(Item1), PChar(Item2));
end;

procedure LoadSuperCheckPartial(const FileName: string; const Calls: TStringList);
var
  Lines: TStringList;
  Index: Integer;
  CharacterIndex: Integer;
  Call: string;
  IsCall: Boolean;
begin
  Calls.Clear;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    for Index := 0 to Lines.Count - 1 do
    begin
      Call := UpperCase(Trim(Lines[Index]));
      if (Call = '') or (Call[1] in ['!', '#']) then
        Continue;
      IsCall := True;
      for CharacterIndex := 1 to Length(Call) do
        if not (Call[CharacterIndex] in ['A'..'Z', '0'..'9', '/']) then
        begin
          IsCall := False;
          Break;
        end;
      if IsCall then
        Calls.Add(Call);
    end;
  finally
    Lines.Free;
  end;
end;

function ImportCallsignList(const SourceFileName: string; out CallCount: Integer;
  out ErrorMessage: string): Boolean;
var
  ImportedCalls: TStringList;
  DestinationFileName: string;
  TemporaryFileName: string;
begin
  Result := False;
  CallCount := 0;
  ErrorMessage := '';
  ImportedCalls := TStringList.Create;
  try
    ImportedCalls.Sorted := True;
    ImportedCalls.Duplicates := dupIgnore;
    try
      LoadSuperCheckPartial(SourceFileName, ImportedCalls);
    except
      on E: Exception do
      begin
        ErrorMessage := E.Message;
        Exit;
      end;
    end;

    CallCount := ImportedCalls.Count;
    if CallCount = 0 then
    begin
      ErrorMessage := 'No valid callsigns were found. Use one callsign per line.';
      Exit;
    end;

    {$ifdef FPC}
    DestinationFileName := GetDataPath.GetUserPath + 'MASTER.SCP';
    {$else}
    DestinationFileName := ExtractFilePath(ParamStr(0)) + 'MASTER.SCP';
    {$endif}
    try
      // Publish the complete replacement atomically, preserving a usable
      // existing list if the import is interrupted or the disk fills up.
      TemporaryFileName := DestinationFileName + '.new';
      DeleteFile(TemporaryFileName);
      ImportedCalls.SaveToFile(TemporaryFileName);
      if not RenameFile(TemporaryFileName, DestinationFileName) then
      begin
        DeleteFile(TemporaryFileName);
        raise Exception.CreateFmt('Cannot replace "%s".', [DestinationFileName]);
      end;
    except
      on E: Exception do
      begin
        ErrorMessage := E.Message;
        Exit;
      end;
    end;
    Result := True;
  finally
    ImportedCalls.Free;
  end;
end;

// reads callsigns from Master.dta file
procedure TCallList.LoadCallList;
const
  Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/';
  CHRCOUNT = Length(Chars);
  INDEXSIZE = Sqr(CHRCOUNT) + 1;
  INDEXBYTES = INDEXSIZE * SizeOf(Integer);
var
  i: integer;
  P, Pe: PChar;
  L: TList;

  FileName: string;
  ScpFileName: string;
  FFileSize: integer;

  FIndex: array[0..INDEXSIZE-1] of integer;
  DataNew: AnsiString;
  Data: String;
begin
  Calls.Clear;

  // A list imported through the Linux UI is deliberately per-user so package
  // upgrades never overwrite it. It takes precedence over the bundled list.
  {$ifdef FPC}
  ScpFileName := GetDataPath.GetUserPath + 'MASTER.SCP';
  if FileExists(ScpFileName) then
  begin
    LoadSuperCheckPartial(ScpFileName, Calls);
    if Calls.Count > 0 then Exit;
  end;
  {$endif}

  ScpFileName := {$ifdef FPC}GetDataPath.GetDataPath{$else}ExtractFilePath(ParamStr(0)){$endif} + 'MASTER.SCP';
  if FileExists(ScpFileName) then
  begin
    LoadSuperCheckPartial(ScpFileName, Calls);
    if Calls.Count > 0 then Exit;
  end;

  FileName := {$ifdef FPC}GetDataPath.GetDataPath{$else}ExtractFilePath(ParamStr(0)){$endif} + 'MASTER.DTA';
  if not FileExists(FileName) then Exit;

  with TFileStream.Create(FileName, fmOpenRead) do
    try
      FFileSize := Size;
      if FFileSize < INDEXBYTES then Exit;
      ReadBuffer(FIndex, INDEXBYTES);

      if (FIndex[0] <> INDEXBYTES) or (FIndex[INDEXSIZE-1] <> FFileSize)
        then Exit;
      SetLength(DataNew, Size - Position);
      ReadBuffer(DataNew[1], Length(DataNew));
    finally
      Free;
    end;
    Data:= string(DataNew); //Modify By BG4FQD for unicode


  L := TList.Create;
  try
    //list pointers to calls
    L.Capacity := 20000;
      P := @Data[1];
    Pe := P + Length(Data);
    while P < Pe do
      begin
      L.Add(TObject(P));
      P := P + StrLen(P) + 1;
      end;
    //delete dupes
    L.Sort(CompareCalls);
    for i:=L.Count-1 downto 1 do
      if StrComp(PChar(L[i]), PChar(L[i-1])) = 0
        then L[i] := nil;
    //put calls to Lst
    Calls.Capacity := L.Count;
    for i:=0 to L.Count-1 do
      if L[i] <> nil then
        Calls.Add(PChar(L[i]));
  finally
    L.Free;
  end;
end;


function TCallList.IsEmpty : Boolean;
begin
  Result := Calls.Count = 0;
end;


procedure TCallList.Clear();
begin
  Calls.Clear;
end;


// returns a single callsign
function TCallList.PickCall : string;
var
  Idx: integer;
begin
  if Calls.Count = 0 then begin
    Result := 'P29SX';
    Exit;
  end;

  Idx := Random(Calls.Count);
  Result := Calls[Idx];

  if Ini.RunMode = rmHst then
    Calls.Delete(Idx);
end;


constructor TCallList.Create;
begin
  Calls := TStringList.Create;
end;

destructor TCallList.Destroy;
begin
  Calls.Clear;
  Calls.Free;
end;


end.
