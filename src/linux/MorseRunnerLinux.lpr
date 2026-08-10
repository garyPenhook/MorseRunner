program MorseRunnerLinux;

{$mode delphi}{$H+}

uses
  Interfaces,
  Forms,
  LinuxMainForm;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
