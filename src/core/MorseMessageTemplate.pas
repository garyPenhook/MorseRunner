//------------------------------------------------------------------------------
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Derived from the placeholder expansion in Station.TStation.SendText.
//------------------------------------------------------------------------------
unit MorseMessageTemplate;

{$mode delphi}{$H+}

interface

function ExpandMorseMessageTemplate(const TemplateText, MyCall, HisCall: string;
  const Rst, SerialNumber: Integer): string;

implementation

uses
  SysUtils;

function ExpandMorseMessageTemplate(const TemplateText, MyCall, HisCall: string;
  const Rst, SerialNumber: Integer): string;
var
  SerialText: string;
begin
  if (Rst < 0) or (SerialNumber < 0) then
    raise EArgumentOutOfRangeException.Create(
      'Morse message RST and serial number cannot be negative.');

  SerialText := Format('%d%.3d', [Rst, SerialNumber]);
  Result := StringReplace(TemplateText, '<#>', SerialText, [rfReplaceAll]);
  Result := StringReplace(Result, '<my>', MyCall, [rfReplaceAll]);
  Result := StringReplace(Result, '<his>', HisCall, [rfReplaceAll]);
end;

end.
