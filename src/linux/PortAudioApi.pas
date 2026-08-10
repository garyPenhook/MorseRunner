unit PortAudioApi;

{$mode delphi}{$H+}

interface

uses
  ctypes;

const
  PortAudioLibrary = 'portaudio';
  paNoError = 0;
  paInt16 = $00000008;
  paContinue = 0;
  paAbort = 2;

type
  TPaError = cint;
  PPaStream = Pointer;
  TPaSampleFormat = culong;
  TPaStreamCallbackFlags = culong;
  PPaStreamCallbackTimeInfo = ^TPaStreamCallbackTimeInfo;
  TPaStreamCallbackTimeInfo = record
    InputBufferAdcTime: cdouble;
    CurrentTime: cdouble;
    OutputBufferDacTime: cdouble;
  end;
  TPaStreamCallback = function(Input, Output: Pointer; FrameCount: culong;
    TimeInfo: PPaStreamCallbackTimeInfo;
    StatusFlags: TPaStreamCallbackFlags; UserData: Pointer): cint; cdecl;

function Pa_GetVersion: cint; cdecl; external PortAudioLibrary;
function Pa_GetVersionText: PChar; cdecl; external PortAudioLibrary;
function Pa_GetErrorText(const ErrorCode: TPaError): PChar; cdecl;
  external PortAudioLibrary;
function Pa_Initialize: TPaError; cdecl; external PortAudioLibrary;
function Pa_Terminate: TPaError; cdecl; external PortAudioLibrary;
function Pa_OpenDefaultStream(var Stream: PPaStream; NumInputChannels,
  NumOutputChannels: cint; SampleFormat: TPaSampleFormat; SampleRate: cdouble;
  FramesPerBuffer: culong; StreamCallback: TPaStreamCallback;
  UserData: Pointer): TPaError; cdecl; external PortAudioLibrary;
function Pa_StartStream(Stream: PPaStream): TPaError; cdecl;
  external PortAudioLibrary;
function Pa_StopStream(Stream: PPaStream): TPaError; cdecl;
  external PortAudioLibrary;
function Pa_AbortStream(Stream: PPaStream): TPaError; cdecl;
  external PortAudioLibrary;
function Pa_CloseStream(Stream: PPaStream): TPaError; cdecl;
  external PortAudioLibrary;

function PortAudioErrorText(const ErrorCode: TPaError): string;

implementation

function PortAudioErrorText(const ErrorCode: TPaError): string;
var
  TextPointer: PChar;
begin
  TextPointer := Pa_GetErrorText(ErrorCode);
  if TextPointer = nil then
    Result := 'unknown PortAudio error'
  else
    Result := StrPas(TextPointer);
end;

end.
