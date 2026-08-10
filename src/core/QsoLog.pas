unit QsoLog;

{$mode delphi}{$H+}

interface

uses
  SysUtils;

const
  QsoErrorNone = '   ';
  QsoErrorNil = 'NIL';
  QsoErrorDuplicate = 'DUP';
  QsoErrorRst = 'RST';
  QsoErrorSerial = 'NR ';

type
  TQso = record
    T: TDateTime;
    Call: string;
    TrueCall: string;
    Rst: Integer;
    TrueRst: Integer;
    Nr: Integer;
    TrueNr: Integer;
    Pfx: string;
    Dupe: Boolean;
    Err: string;
  end;

  TContestScore = record
    RawContacts: Integer;
    RawMultipliers: Integer;
    RawScore: Integer;
    VerifiedContacts: Integer;
    VerifiedMultipliers: Integer;
    VerifiedScore: Integer;
  end;

  TQsoLog = class
  private
    FItems: array of TQso;
    function GetCount: Integer;
    function GetItem(Index: Integer): TQso;
  public
    procedure Clear;
    procedure Add(const Qso: TQso);
    function IsDuplicateCall(const Call: string): Boolean;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TQso read GetItem;
  end;

function ExtractPrefix(const Call: string): string;
function CallToHstScore(const Call: string): Integer;
function DetermineQsoError(const Qso: TQso): string;
function ContestScore(const Log: TQsoLog): TContestScore;
function HstScore(const Log: TQsoLog): TContestScore;

implementation

function ExtractPrefix(const Call: string): string;
const
  Digits = ['0'..'9'];
var
  Position: Integer;
  LeftPart: string;
  RightPart: string;
  SelectedDigit: string;
begin
  Result := Call + '|';
  Result := StringReplace(Result, '/QRP|', '', []);
  Result := StringReplace(Result, '/MM|', '', []);
  Result := StringReplace(Result, '/M|', '', []);
  Result := StringReplace(Result, '/P|', '', []);
  Result := StringReplace(Result, '|', '', []);
  Result := StringReplace(Result, '//', '/', [rfReplaceAll]);
  if Length(Result) < 2 then
  begin
    Result := '';
    Exit;
  end;

  SelectedDigit := '';
  Position := Pos('/', Result);
  if Position = 0 then
  begin
    { Keep the full callsign for the trailing-letter removal below. }
  end
  else if Position = 1 then
    Result := Copy(Result, 2, MaxInt)
  else if Position = Length(Result) then
    Result := Copy(Result, 1, Position - 1)
  else
  begin
    LeftPart := Copy(Result, 1, Position - 1);
    RightPart := Copy(Result, Position + 1, MaxInt);
    if (Length(LeftPart) = 1) and (LeftPart[1] in Digits) then
    begin
      SelectedDigit := LeftPart;
      Result := RightPart;
    end
    else if (Length(RightPart) = 1) and (RightPart[1] in Digits) then
    begin
      SelectedDigit := RightPart;
      Result := LeftPart;
    end
    else if Length(LeftPart) <= Length(RightPart) then
      Result := LeftPart
    else
      Result := RightPart;
  end;
  if Pos('/', Result) > 0 then
  begin
    Result := '';
    Exit;
  end;

  for Position := Length(Result) downto 3 do
    if Result[Position] in Digits then
      Break
    else
      Delete(Result, Position, 1);

  if not (Result[Length(Result)] in Digits) then
    Result := Result + '0';
  if SelectedDigit <> '' then
    Result[Length(Result)] := SelectedDigit[1];

  Result := Copy(Result, 1, 5);
end;

function MorseCode(const Character: Char): string;
begin
  case Character of
    { These six entries intentionally match the final overwrite performed by
      the legacy MorseTable loader for AR, BK, CQ, DX, KN, and SK. }
    'A': Result := '.-.-.';
    'B': Result := '-...-.-';
    'C': Result := '-.-.--.-';
    'D': Result := '-..-..-';
    'E': Result := '.';
    'F': Result := '..-.';
    'G': Result := '--.';
    'H': Result := '....';
    'I': Result := '..';
    'J': Result := '.---';
    'K': Result := '-.--.';
    'L': Result := '.-..';
    'M': Result := '--';
    'N': Result := '-.';
    'O': Result := '---';
    'P': Result := '.--.';
    'Q': Result := '--.-';
    'R': Result := '.-.';
    'S': Result := '...-.-';
    'T': Result := '-';
    'U': Result := '..-';
    'V': Result := '...-';
    'W': Result := '.--';
    'X': Result := '-..-';
    'Y': Result := '-.--';
    'Z': Result := '--..';
    '0': Result := '-----';
    '1': Result := '.----';
    '2': Result := '..---';
    '3': Result := '...--';
    '4': Result := '....-';
    '5': Result := '.....';
    '6': Result := '-....';
    '7': Result := '--...';
    '8': Result := '---..';
    '9': Result := '----.';
    '/': Result := '-..-.';
    '.': Result := '.-.-.-';
    ',': Result := '--..--';
    '?': Result := '..--..';
    '=': Result := '-...-';
    '\': Result := '...-.';
  else
    Result := '';
  end;
end;

function CallToHstScore(const Call: string): Integer;
var
  Index: Integer;
  SymbolIndex: Integer;
  Code: string;
  EncodedAnyCharacter: Boolean;
begin
  Result := -1;
  EncodedAnyCharacter := False;
  for Index := 1 to Length(Call) do
  begin
    if Call[Index] in [' ', '_'] then
    begin
      Inc(Result, 2);
      EncodedAnyCharacter := True;
      Continue;
    end;

    Code := MorseCode(Call[Index]);
    if Code = '' then
      Continue;
    EncodedAnyCharacter := True;
    for SymbolIndex := 1 to Length(Code) do
      case Code[SymbolIndex] of
        '.': Inc(Result, 2);
        '-': Inc(Result, 4);
      end;
    Inc(Result, 2);
  end;

  if EncodedAnyCharacter then
    Dec(Result, 2)
  else
    Result := -1;
end;

function DetermineQsoError(const Qso: TQso): string;
begin
  if Qso.TrueCall = '' then
    Result := QsoErrorNil
  else if Qso.Dupe then
    Result := QsoErrorDuplicate
  else if Qso.TrueRst <> Qso.Rst then
    Result := QsoErrorRst
  else if Qso.TrueNr <> Qso.Nr then
    Result := QsoErrorSerial
  else
    Result := QsoErrorNone;
end;

function UniquePrefixCount(const Log: TQsoLog; const VerifiedOnly: Boolean): Integer;
var
  Index: Integer;
  PreviousIndex: Integer;
  AlreadyPresent: Boolean;
begin
  Result := 0;
  for Index := 0 to Log.Count - 1 do
  begin
    if VerifiedOnly and (Log.Items[Index].Err <> QsoErrorNone) then
      Continue;
    AlreadyPresent := False;
    for PreviousIndex := 0 to Index - 1 do
      if (not VerifiedOnly or
          (Log.Items[PreviousIndex].Err = QsoErrorNone)) and
         (Log.Items[PreviousIndex].Pfx = Log.Items[Index].Pfx) then
      begin
        AlreadyPresent := True;
        Break;
      end;
    if not AlreadyPresent then
      Inc(Result);
  end;
end;

function ContestScore(const Log: TQsoLog): TContestScore;
var
  Index: Integer;
begin
  Result.RawContacts := Log.Count;
  Result.RawMultipliers := UniquePrefixCount(Log, False);
  Result.RawScore := Result.RawContacts * Result.RawMultipliers;

  Result.VerifiedContacts := 0;
  for Index := 0 to Log.Count - 1 do
    if Log.Items[Index].Err = QsoErrorNone then
      Inc(Result.VerifiedContacts);
  Result.VerifiedMultipliers := UniquePrefixCount(Log, True);
  Result.VerifiedScore :=
    Result.VerifiedContacts * Result.VerifiedMultipliers;
end;

function HstScore(const Log: TQsoLog): TContestScore;
var
  Index: Integer;
  Points: Integer;
begin
  Result.RawContacts := Log.Count;
  Result.RawMultipliers := 0;
  Result.RawScore := 0;
  Result.VerifiedContacts := 0;
  Result.VerifiedMultipliers := 0;
  Result.VerifiedScore := 0;

  for Index := 0 to Log.Count - 1 do
  begin
    Points := CallToHstScore(Log.Items[Index].Call);
    Inc(Result.RawScore, Points);
    if Log.Items[Index].Err = QsoErrorNone then
    begin
      Inc(Result.VerifiedContacts);
      Inc(Result.VerifiedScore, Points);
    end;
  end;
end;

procedure TQsoLog.Clear;
begin
  SetLength(FItems, 0);
end;

procedure TQsoLog.Add(const Qso: TQso);
var
  NewIndex: Integer;
begin
  NewIndex := Length(FItems);
  SetLength(FItems, NewIndex + 1);
  FItems[NewIndex] := Qso;
end;

function TQsoLog.GetCount: Integer;
begin
  Result := Length(FItems);
end;

function TQsoLog.GetItem(Index: Integer): TQso;
begin
  Result := FItems[Index];
end;

function TQsoLog.IsDuplicateCall(const Call: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 0 to High(FItems) do
    if (FItems[Index].Call = Call) and
       (FItems[Index].Err = QsoErrorNone) then
    begin
      Result := True;
      Exit;
    end;
end;

end.
