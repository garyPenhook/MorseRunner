program QsoLogTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  QsoLog;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckEquals(const Expected, Actual: Integer;
  const MessageText: string); overload;
begin
  Check(Expected = Actual, Format('%s: expected %d, got %d',
    [MessageText, Expected, Actual]));
end;

procedure CheckEquals(const Expected, Actual: string;
  const MessageText: string); overload;
begin
  Check(Expected = Actual, Format('%s: expected "%s", got "%s"',
    [MessageText, Expected, Actual]));
end;

function ConfirmedQso(const Call, Prefix: string): TQso;
begin
  Result.Call := Call;
  Result.TrueCall := Call;
  Result.Rst := 599;
  Result.TrueRst := 599;
  Result.Nr := 1;
  Result.TrueNr := 1;
  Result.Pfx := Prefix;
  Result.Dupe := False;
  Result.Err := QsoErrorNone;
end;

procedure TestPrefixExtraction;
begin
  CheckEquals('VE3', ExtractPrefix('VE3NEA'),
    'standard prefix');
  CheckEquals('F0', ExtractPrefix('F/VE3NEA'),
    'shorter-side prefix rule');
  CheckEquals('VE4', ExtractPrefix('VE3NEA/4'),
    'numeric portable suffix replaces prefix digit');
  CheckEquals('VE3', ExtractPrefix('VE3NEA/P'),
    'portable modifier removed');
  CheckEquals('', ExtractPrefix('A'), 'too-short call has no prefix');
end;

procedure TestHstScoring;
begin
  CheckEquals(1, CallToHstScore('E'), 'single dit score');
  CheckEquals(13, CallToHstScore('A'), 'legacy AR-overwrite score');
  CheckEquals(5, CallToHstScore('EE'), 'inter-character gap score');
  CheckEquals(-1, CallToHstScore(''), 'empty callsign score');
end;

procedure TestErrorPriority;
var
  Qso: TQso;
begin
  Qso := ConfirmedQso('VE3NEA', 'VE3');
  CheckEquals(QsoErrorNone, DetermineQsoError(Qso), 'good QSO');

  Qso.TrueCall := '';
  Qso.Dupe := True;
  CheckEquals(QsoErrorNil, DetermineQsoError(Qso),
    'NIL error takes priority');
  Qso := ConfirmedQso('VE3NEA', 'VE3');
  Qso.Dupe := True;
  CheckEquals(QsoErrorDuplicate, DetermineQsoError(Qso),
    'duplicate error');
  Qso := ConfirmedQso('VE3NEA', 'VE3');
  Qso.TrueRst := 579;
  CheckEquals(QsoErrorRst, DetermineQsoError(Qso), 'RST error');
  Qso := ConfirmedQso('VE3NEA', 'VE3');
  Qso.TrueNr := 2;
  CheckEquals(QsoErrorSerial, DetermineQsoError(Qso), 'serial error');
end;

procedure TestContestScoring;
var
  Log: TQsoLog;
  Qso: TQso;
  Score: TContestScore;
begin
  Log := TQsoLog.Create;
  try
    Qso := ConfirmedQso('VE3NEA', 'VE3');
    Log.Add(Qso);
    Qso := ConfirmedQso('K1ABC', 'K1');
    Log.Add(Qso);
    Qso := ConfirmedQso('W1XYZ', 'K1');
    Qso.Err := QsoErrorRst;
    Log.Add(Qso);

    Score := ContestScore(Log);
    CheckEquals(3, Score.RawContacts, 'raw contacts');
    CheckEquals(2, Score.RawMultipliers, 'raw multipliers');
    CheckEquals(6, Score.RawScore, 'raw contest score');
    CheckEquals(2, Score.VerifiedContacts, 'verified contacts');
    CheckEquals(2, Score.VerifiedMultipliers, 'verified multipliers');
    CheckEquals(4, Score.VerifiedScore, 'verified contest score');
    Check(Log.IsDuplicateCall('VE3NEA'), 'confirmed duplicate found');
    Check(not Log.IsDuplicateCall('W1XYZ'),
      'incorrect QSO does not create duplicate');
  finally
    Log.Free;
  end;
end;

procedure TestHstLogScoring;
var
  Log: TQsoLog;
  Qso: TQso;
  Score: TContestScore;
begin
  Log := TQsoLog.Create;
  try
    Qso := ConfirmedQso('E', '');
    Log.Add(Qso);
    Qso := ConfirmedQso('A', '');
    Qso.Err := QsoErrorDuplicate;
    Log.Add(Qso);
    Score := HstScore(Log);
    CheckEquals(14, Score.RawScore, 'raw HST score');
    CheckEquals(1, Score.VerifiedScore, 'verified HST score');
  finally
    Log.Free;
  end;
end;

begin
  try
    TestPrefixExtraction;
    TestHstScoring;
    TestErrorPriority;
    TestContestScoring;
    TestHstLogScoring;
    WriteLn('QSO log tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'QSO log tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
