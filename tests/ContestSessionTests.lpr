program ContestSessionTests;

{$mode delphi}{$H+}

uses
  Math,
  SysUtils,
  ContestSettings,
  ContestSession,
  ContestTiming,
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

procedure CheckEquals(const Expected, Actual: TSessionState;
  const MessageText: string); overload;
begin
  Check(Expected = Actual, MessageText);
end;

procedure CheckEquals(const Expected, Actual: TSessionEndReason;
  const MessageText: string); overload;
begin
  Check(Expected = Actual, MessageText);
end;

procedure CheckClose(const Expected, Actual: Double; const MessageText: string);
begin
  Check(Abs(Expected - Actual) <= 1.0e-8,
    Format('%s: expected %.9f, got %.9f', [MessageText, Expected, Actual]));
end;

function ReceivedQso(const Call, TrueCall: string): TQso;
begin
  Result.Call := Call;
  Result.TrueCall := TrueCall;
  Result.Rst := 599;
  Result.TrueRst := 599;
  Result.Nr := 1;
  Result.TrueNr := 1;
end;

procedure TestStartAndTimedFinish;
var
  Settings: TContestSettings;
  Session: TContestSession;
begin
  Settings := DefaultContestSettings;
  Settings.DurationMinutes := 1;
  Settings.Audio.SampleRate := 8000;
  Session := TContestSession.Create(Settings);
  try
    CheckEquals(ssStopped, Session.State, 'initial state');
    Session.Start(rmPileup);
    CheckEquals(ssRunning, Session.State, 'started state');
    CheckEquals(0, Session.Log.Count, 'start clears log');
    Session.ConsumeFrames(8000 * 60 - 1);
    CheckEquals(ssRunning, Session.State, 'session remains active before end');
    Session.ConsumeFrames(1);
    CheckEquals(ssFinished, Session.State, 'session finishes at sample boundary');
    CheckEquals(serTimeElapsed, Session.EndReason, 'timed finish reason');
    CheckClose(60.0, Session.ElapsedSeconds, 'elapsed session time');
  finally
    Session.Free;
  end;
end;

procedure TestWpxUsesCompetitionDuration;
var
  Settings: TContestSettings;
  Session: TContestSession;
begin
  Settings := DefaultContestSettings;
  Settings.DurationMinutes := 1;
  Settings.CompetitionDurationMinutes := 2;
  Settings.Audio.SampleRate := 8000;
  Session := TContestSession.Create(Settings);
  try
    Session.Start(rmWpx);
    Session.ConsumeFrames(8000 * 60);
    CheckEquals(ssRunning, Session.State,
      'WPX ignores regular-duration limit');
    Session.ConsumeFrames(8000 * 60);
    CheckEquals(ssFinished, Session.State, 'WPX competition duration');
  finally
    Session.Free;
  end;
end;

procedure TestUserStop;
var
  Session: TContestSession;
begin
  Session := TContestSession.Create(DefaultContestSettings);
  try
    Session.Start(rmSingle);
    Session.ConsumeFrames(100);
    Session.RequestStop;
    CheckEquals(ssFinished, Session.State, 'user stop finishes session');
    CheckEquals(serStoppedByUser, Session.EndReason, 'user stop reason');
    Session.ConsumeFrames(100);
    CheckEquals(100, Session.ConsumedFrames,
      'finished session ignores later audio frames');
  finally
    Session.Free;
  end;
end;

procedure TestQsoSubmission;
var
  Session: TContestSession;
  Qso: TQso;
  Score: TContestScore;
begin
  Session := TContestSession.Create(DefaultContestSettings);
  try
    Check(not Session.SubmitQso(ReceivedQso('VE3NEA', 'VE3NEA')),
      'stopped session rejects QSO');
    Session.Start(rmPileup);
    Qso := ReceivedQso('ve3nea', 'VE3NEA');
    Check(Session.SubmitQso(Qso), 'running session accepts QSO');
    CheckEquals(1, Session.Log.Count, 'accepted QSO count');
    Check(Session.Log.Items[0].Call = 'VE3NEA', 'QSO call normalized');
    Check(Session.Log.Items[0].Err = QsoErrorNone, 'correct QSO accepted');

    Qso := ReceivedQso('VE3NEA', 'VE3NEA');
    Check(Session.SubmitQso(Qso), 'duplicate is retained for scoring');
    Check(Session.Log.Items[1].Err = QsoErrorDuplicate,
      'duplicate is marked after prior valid QSO');
    Score := Session.Score;
    CheckEquals(2, Score.RawContacts, 'raw session contacts');
    CheckEquals(1, Score.VerifiedContacts, 'verified session contacts');
  finally
    Session.Free;
  end;
end;

procedure TestHstSubmission;
var
  Session: TContestSession;
  Qso: TQso;
  Score: TContestScore;
begin
  Session := TContestSession.Create(DefaultContestSettings);
  try
    Session.Start(rmHst);
    Qso := ReceivedQso('E', 'E');
    Check(Session.SubmitQso(Qso), 'HST QSO accepted');
    Check(Session.Log.Items[0].Pfx = '1', 'HST display score stored');
    Score := Session.Score;
    CheckEquals(1, Score.RawScore, 'HST session score');
    CheckEquals(1, Score.VerifiedScore, 'verified HST session score');
  finally
    Session.Free;
  end;
end;

begin
  try
    TestStartAndTimedFinish;
    TestWpxUsesCompetitionDuration;
    TestUserStop;
    TestQsoSubmission;
    TestHstSubmission;
    WriteLn('Contest session tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Contest session tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
