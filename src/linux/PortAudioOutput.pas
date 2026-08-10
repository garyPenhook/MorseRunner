unit PortAudioOutput;

{$mode delphi}{$H+}

interface

uses
  ctypes,
  SysUtils,
  PcmRing,
  PortAudioApi;

type
  EPortAudioOutput = class(Exception);
  TPortAudioOutputState = (paosClosed, paosOpened, paosStarted);

  TPortAudioOutput = class
  private
    FRing: TPcmSpscRing;
    FStream: PPaStream;
    FState: TPortAudioOutputState;
    FInitialized: Boolean;
    FSampleRate: Integer;
    FCallbackFormatErrors: LongInt;
    FPlayedBlockCount: LongInt;
    FUnreportedPlayedBlocks: LongInt;
    procedure CheckPortAudio(const ErrorCode: TPaError; const Operation: string);
    function GetCallbackFormatErrors: LongInt;
    function GetPlayedFrames: Int64;
    procedure ResetPlaybackStatistics;
  public
    constructor Create(const Ring: TPcmSpscRing);
    destructor Destroy; override;
    procedure Open(const SampleRate: Integer);
    procedure Start;
    procedure Stop;
    procedure Abort;
    procedure Close;
    procedure FillCallbackBuffer(const Output: Pointer;
      const FrameCount: culong);
    function TakePlayedFrames: Int64;

    property State: TPortAudioOutputState read FState;
    property SampleRate: Integer read FSampleRate;
    property CallbackFormatErrors: LongInt read GetCallbackFormatErrors;
    property PlayedFrames: Int64 read GetPlayedFrames;
  end;

function PortAudioOutputCallback(Input, Output: Pointer; FrameCount: culong;
  TimeInfo: PPaStreamCallbackTimeInfo; StatusFlags: TPaStreamCallbackFlags;
  UserData: Pointer): cint; cdecl;

implementation

constructor TPortAudioOutput.Create(const Ring: TPcmSpscRing);
begin
  inherited Create;
  if Ring = nil then
    raise EArgumentNilException.Create('PortAudio output requires a PCM ring.');
  FRing := Ring;
  FState := paosClosed;
  ResetPlaybackStatistics;
end;

destructor TPortAudioOutput.Destroy;
begin
  try
    Close;
  except
    { Destructors must not propagate a native cleanup failure. }
  end;
  inherited Destroy;
end;

procedure TPortAudioOutput.CheckPortAudio(const ErrorCode: TPaError;
  const Operation: string);
begin
  if ErrorCode <> paNoError then
    raise EPortAudioOutput.Create(Format('%s failed: %s (%d)',
      [Operation, PortAudioErrorText(ErrorCode), ErrorCode]));
end;

procedure TPortAudioOutput.Open(const SampleRate: Integer);
var
  ErrorCode: TPaError;
begin
  if FState <> paosClosed then
    raise EPortAudioOutput.Create('PortAudio stream is already open.');
  if SampleRate <= 0 then
    raise EArgumentOutOfRangeException.Create('Sample rate must be positive.');

  ErrorCode := Pa_Initialize;
  CheckPortAudio(ErrorCode, 'Pa_Initialize');
  FInitialized := True;
  try
    ErrorCode := Pa_OpenDefaultStream(FStream, 0, 1, paInt16, SampleRate,
      FRing.BlockFrames, @PortAudioOutputCallback, Self);
    CheckPortAudio(ErrorCode, 'Pa_OpenDefaultStream');
  except
    Pa_Terminate;
    FInitialized := False;
    FStream := nil;
    raise;
  end;

  FSampleRate := SampleRate;
  ResetPlaybackStatistics;
  FState := paosOpened;
end;

procedure TPortAudioOutput.Start;
begin
  if FState <> paosOpened then
    raise EPortAudioOutput.Create('PortAudio stream is not ready to start.');
  CheckPortAudio(Pa_StartStream(FStream), 'Pa_StartStream');
  FState := paosStarted;
end;

procedure TPortAudioOutput.Stop;
begin
  if FState <> paosStarted then
    Exit;
  CheckPortAudio(Pa_StopStream(FStream), 'Pa_StopStream');
  FState := paosOpened;
end;

procedure TPortAudioOutput.Abort;
begin
  if FState <> paosStarted then
    Exit;
  CheckPortAudio(Pa_AbortStream(FStream), 'Pa_AbortStream');
  FState := paosOpened;
end;

procedure TPortAudioOutput.Close;
var
  FirstError: TPaError;
  ErrorCode: TPaError;
begin
  FirstError := paNoError;
  if FState = paosStarted then
  begin
    ErrorCode := Pa_AbortStream(FStream);
    if ErrorCode <> paNoError then
      FirstError := ErrorCode;
    FState := paosOpened;
  end;

  if FStream <> nil then
  begin
    ErrorCode := Pa_CloseStream(FStream);
    if (FirstError = paNoError) and (ErrorCode <> paNoError) then
      FirstError := ErrorCode;
    FStream := nil;
    FState := paosClosed;
  end;

  if FInitialized then
  begin
    FInitialized := False;
    ErrorCode := Pa_Terminate;
    if (FirstError = paNoError) and (ErrorCode <> paNoError) then
      FirstError := ErrorCode;
  end;
  FSampleRate := 0;

  if FirstError <> paNoError then
    raise EPortAudioOutput.Create(Format('PortAudio close failed: %s (%d)',
      [PortAudioErrorText(FirstError), FirstError]));
end;

procedure TPortAudioOutput.FillCallbackBuffer(const Output: Pointer;
  const FrameCount: culong);
begin
  if (Output = nil) or (FrameCount <> culong(FRing.BlockFrames)) then
  begin
    if Output <> nil then
      FillChar(Output^, NativeUInt(FrameCount) * SizeOf(SmallInt), 0);
    InterlockedIncrement(FCallbackFormatErrors);
    Exit;
  end;

  FRing.ReadOrSilenceToBuffer(PSmallInt(Output), FrameCount);
  InterlockedIncrement(FPlayedBlockCount);
  InterlockedIncrement(FUnreportedPlayedBlocks);
end;

function TPortAudioOutput.GetCallbackFormatErrors: LongInt;
begin
  Result := InterlockedCompareExchange(FCallbackFormatErrors, 0, 0);
end;

procedure TPortAudioOutput.ResetPlaybackStatistics;
begin
  { Lifecycle operation: call only while no callback is active. }
  InterlockedExchange(FPlayedBlockCount, 0);
  InterlockedExchange(FUnreportedPlayedBlocks, 0);
  InterlockedExchange(FCallbackFormatErrors, 0);
end;

function TPortAudioOutput.GetPlayedFrames: Int64;
begin
  Result := Int64(InterlockedCompareExchange(FPlayedBlockCount, 0, 0)) *
    FRing.BlockFrames;
end;

function TPortAudioOutput.TakePlayedFrames: Int64;
begin
  { The controller drains this counter outside the callback, then applies the
    result to TContestSession. This keeps contest state off the audio thread. }
  Result := Int64(InterlockedExchange(FUnreportedPlayedBlocks, 0)) *
    FRing.BlockFrames;
end;

function PortAudioOutputCallback(Input, Output: Pointer; FrameCount: culong;
  TimeInfo: PPaStreamCallbackTimeInfo; StatusFlags: TPaStreamCallbackFlags;
  UserData: Pointer): cint; cdecl;
var
  OutputOwner: TPortAudioOutput;
begin
  if UserData = nil then
  begin
    if Output <> nil then
      FillChar(Output^, NativeUInt(FrameCount) * SizeOf(SmallInt), 0);
    Result := paAbort;
    Exit;
  end;

  OutputOwner := TPortAudioOutput(UserData);
  OutputOwner.FillCallbackBuffer(Output, FrameCount);
  if FrameCount <> culong(OutputOwner.FRing.BlockFrames) then
    Result := paAbort
  else
    Result := paContinue;
end;

end.
