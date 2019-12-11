unit TechniSatAPI;

{$mode objfpc}{$H+}
{$MACRO ON}

{____________________________________________________________
|  _______________________________________________________  |
| |                                                       | |
| |         Remote API for TechniSat based devices        | |
| | (c) 2019 Alexander Feuster (alexander.feuster@web.de) | |
| |             http://www.github.com/feuster             | |
| |_______________________________________________________| |
|___________________________________________________________}

//define API basics
{$DEFINE APIVERSION:='1.1'}
//{$DEFINE TSAPI_DEBUG}
{___________________________________________________________}

interface

uses
  Classes, SysUtils, IdUDPClient, IdStack, StrUtils, XMLRead, DOM
  {$IFDEF LCL}, Forms{$IFDEF TSAPI_DEBUG}, Dialogs{$ENDIF}{$ENDIF}
  ;

function tsapi_Info_DeviceList(TimeoutMS: Integer): TStringList;
function tsapi_Info_DeviceInformation(URL: String; TimeoutMS: Integer): TStringList;
function tsapi_Info_GetURLByDeviceList(SearchCriteria: String; TimeoutMS: Integer): String;
function tsapi_Info_Authentication(URL: String; PIN: String; TimeoutMS: Integer): Boolean;
function tsapi_Info_KeepAlive(URL: String; TimeoutMS: Integer): Boolean;
function tsapi_rcuButtonRequest(URL: String; PIN: String; ButtonCode: Byte; ButtonState: String; TimeoutMS: Integer): Boolean;
function tsapi_rcuButtonRequestByName(DeviceName: String; PIN: String; ButtonCode: Byte; ButtonState: String; TimeoutMS: Integer): Boolean;
function tsapi_rcuButtonRequestBySerial(Serial: String; PIN: String; ButtonCode: Byte; ButtonState: String; TimeoutMS: Integer): Boolean;
function tsapi_zoomRequest(URL: String; PIN: String; ZoomValue: Integer; TimeoutMS: Integer): Boolean;
function tsapi_BtnCodeByName(ButtonName: String): Byte;
function tsapi_BtnDescByName(ButtonName: String): String;
function tsapi_BtnNameByCode(ButtonCode: Byte): String;
function tsapi_BtnDescByCode(ButtonCode: Byte): String;

type
  TButton = record
    Code:         Byte;
    Name:         String;
    Description:  String;
  end;

{$IFDEF TSAPI_DEBUG}
var
  //storage variable for last debug message
  tsapi_Debug_NoShowMessage:  Boolean;
  tsapi_Debug_Message:        String;
{$ENDIF}


const
  API_Version:  String = APIVERSION;
  {$IFDEF TSAPI_DEBUG}
  //Debug message strings
  STR_Error:      String = 'Debug:   Error: ';
  STR_Info:       String = 'Debug:   Info: ';
  STR_Space:      String = '         ';
  //Define DEBUG constant
  TSAPI_DEBUG:    Boolean = true;
  {$ELSE}
  TSAPI_DEBUG:    Boolean = false;
  {$ENDIF}

  API_License:  String = '--------------------------------------------------------------------------------'+#13#10#13#10+
                           'TechniSat API V'+APIVERSION+' (c) 2019 Alexander Feuster (alexander.feuster@web.de)'+#13#10+
                           'http://www.github.com/feuster'+#13#10+
                           'This API is provided "as-is" without any warranties for any data loss,'+#13#10+
                           'device defects etc. Use at own risk!'+#13#10+
                           'Free for personal use. Commercial use is prohibited without permission.'+#13#10#13#10+
                           '--------------------------------------------------------------------------------'+#13#10#13#10+
                           'Indy BSD License'+#13#10+
                           #13#10+
                           'Copyright'+#13#10+
                           #13#10+
                           'Portions of this software are Copyright (c) 1993 - 2003, Chad Z. Hower (Kudzu)'+#13#10+
                           'and the Indy Pit Crew - http://www.IndyProject.org/'+#13#10+
                           #13#10+
                           'License'+#13#10+
                           #13#10+
                           'Redistribution and use in source and binary forms, with or without modification,'+#13#10+
                           'are permitted provided that the following conditions are met: Redistributions'+#13#10+
                           'of source code must retain the above copyright notice, this list of conditions'+#13#10+
                           'and the following disclaimer.'+#13#10+
                           #13#10+
                           'Redistributions in binary form must reproduce the above copyright notice, this'+#13#10+
                           'list of conditions and the following disclaimer in the documentation, about box'+#13#10+
                           'and/or other materials provided with the distribution.'+#13#10+
                           #13#10+
                           'No personal names or organizations names associated with the Indy project may'+#13#10+
                           'be used to endorse or promote products derived from this software without'+#13#10+
                           'specific prior written permission of the specific individual or organization.'+#13#10+
                           #13#10+
                           'THIS SOFTWARE IS PROVIDED BY Chad Z. Hower (Kudzu) and the Indy Pit Crew "AS'+#13#10+
                           'IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE'+#13#10+
                           'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE'+#13#10+
                           'DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY'+#13#10+
                           'DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES'+#13#10+
                           '(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;'+#13#10+
                           'LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON'+#13#10+
                           'ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT'+#13#10+
                           '(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS'+#13#10+
                           'SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.'+#13#10#13#10+
                           '-------------------------[scroll up for full License]--------------------------'+#13#10#13#10;

  tsapi_deviceDiscoveryRequest:   String  = '<deviceDiscoveryRequest/>';
  tsapi_deviceInformationRequest: String  = '<deviceInformationRequest/>';
  tsapi_keepAliveRequest:         String  = '<keepAliveRequest/>';
  tsapi_keepAliveResponse:        String  = '<keepAliveResponse/>';
  tsapi_ListenerPort:             Integer = 8090;
  tsapi_ButtonState_pressed:      String  = 'pressed';
  tsapi_ButtonState_released:     String  = 'released';
  tsapi_ButtonState_hold:         String  = 'hold';
  tsapi_ButtonStates:             array[0..2] of String = ('pressed', 'released', 'hold');
  tsapi_TimeoutMS_Max:            Integer = 1000;

  tsapi_Buttons: array[0..128] of TButton =
    (
      (Code:    0; Name: 'BTN_0';          Description: '0'),
      (Code:    1; Name: 'BTN_1';          Description: '1'),
      (Code:    2; Name: 'BTN_2';          Description: '2'),
      (Code:    3; Name: 'BTN_3';          Description: '3'),
      (Code:    4; Name: 'BTN_4';          Description: '4'),
      (Code:    5; Name: 'BTN_5';          Description: '5'),
      (Code:    6; Name: 'BTN_6';          Description: '6'),
      (Code:    7; Name: 'BTN_7';          Description: '7'),
      (Code:    8; Name: 'BTN_8';          Description: '8'),
      (Code:    9; Name: 'BTN_9';          Description: '9'),
      (Code:   10; Name: 'BTN_SWITCHDEC';  Description: 'SWITCH DEC'),
      (Code:   11; Name: 'BTN_STANDBY';    Description: 'STANDBY'),
      (Code:   12; Name: 'BTN_MUTE';       Description: 'MUTE'),
      (Code:   13; Name: 'BTN_NOTUSED13';  Description: 'BUTTON 13 NOT USED'),
      (Code:   14; Name: 'BTN_LIST';       Description: 'LIST'),
      (Code:   15; Name: 'BTN_VOL_UP';     Description: 'VOLUME UP'),
      (Code:   16; Name: 'BTN_VOL_DOWN';   Description: 'VOLUME DOWN'),
      (Code:   17; Name: 'BTN_HELP';       Description: 'HELP'),
      (Code:   18; Name: 'BTN_PROG_UP';    Description: 'PROGRAM UP'),
      (Code:   19; Name: 'BTN_PROG_DOWN';  Description: 'PROGRAM DOWN'),
      (Code:   20; Name: 'BTN_BACK';       Description: 'BACK'),
      (Code:   21; Name: 'BTN_AUDIO';      Description: 'AUDIO'),
      (Code:   22; Name: 'BTN_STILL';      Description: 'STILL'),
      (Code:   23; Name: 'BTN_EPG';        Description: 'SFI/EPG'),
      (Code:   24; Name: 'BTN_EXT';        Description: 'EXT'),
      (Code:   25; Name: 'BTN_TXT';        Description: 'TELETEXT'),
      (Code:   26; Name: 'BTN_OFF';        Description: 'OFF'),
      (Code:   27; Name: 'BTN_TOGGLEIRC';  Description: 'TOGGLE IRC'),
      (Code:   28; Name: 'BTN_TVSAT';      Description: 'TV/SAT'),
      (Code:   29; Name: 'BTN_INFO';       Description: 'INFO'),
      (Code:   30; Name: 'BTN_UP';         Description: 'UP'),
      (Code:   31; Name: 'BTN_DOWN';       Description: 'DOWN'),
      (Code:   32; Name: 'BTN_MENU';       Description: 'MENU'),
      (Code:   33; Name: 'BTN_TVRADIO';    Description: 'TV/RADIO'),
      (Code:   34; Name: 'BTN_LEFT';       Description: 'LEFT'),
      (Code:   35; Name: 'BTN_RIGHT';      Description: 'RIGHT'),
      (Code:   36; Name: 'BTN_OK';         Description: 'OK'),
      (Code:   37; Name: 'BTN_RED';        Description: 'RED'),
      (Code:   38; Name: 'BTN_GREEN';      Description: 'GREEN'),
      (Code:   39; Name: 'BTN_YELLOW';     Description: 'YELLOW'),
      (Code:   40; Name: 'BTN_BLUE';       Description: 'BLUE'),
      (Code:   41; Name: 'BTN_OPTION';     Description: 'OPTION'),
      (Code:   42; Name: 'BTN_SLEEP';      Description: 'SLEEP'),
      (Code:   43; Name: 'BTN_REC';        Description: 'RECORD'),
      (Code:   44; Name: 'BTN_PIP';        Description: 'PIP/PAP'),
      (Code:   45; Name: 'BTN_ZOOM';       Description: 'ZOOM'),
      (Code:   46; Name: 'BTN_GENRE';      Description: 'GENRE'),
      (Code:   47; Name: 'BTN_HDMI';       Description: 'HDMI'),
      (Code:   48; Name: 'BTN_MORE';       Description: 'MORE'),
      (Code:   49; Name: 'BTN_REWIND';     Description: 'REWIND'),
      (Code:   50; Name: 'BTN_STOP';       Description: 'STOP'),
      (Code:   51; Name: 'BTN_PLAYPAUSE';  Description: 'PLAY/PAUSE'),
      (Code:   52; Name: 'BTN_WIND';       Description: 'FORWARD WIND'),
      (Code:   53; Name: 'BTN_CODESAT1';   Description: 'CODE SAT1'),
      (Code:   54; Name: 'BTN_CODESAT2';   Description: 'CODE SAT2'),
      (Code:   55; Name: 'BTN_CODETV1';    Description: 'CODE TV1'),
      (Code:   56; Name: 'BTN_CODETV2';    Description: 'CODE TV2'),
      (Code:   57; Name: 'BTN_CODEVCR1';   Description: 'CODE VCR1'),
      (Code:   58; Name: 'BTN_CODEVCR2';   Description: 'CODE VCR2'),
      (Code:   59; Name: 'BTN_FREESATBACK';Description: 'FREESAT BACK'),
      (Code:   60; Name: 'BTN_AD';         Description: 'AD'),
      (Code:   61; Name: 'BTN_SUBTITLE';   Description: 'SUBTITLE'),
      (Code:   62; Name: 'BTN_NAV';        Description: 'NAVIGATION'),
      (Code:   63; Name: 'BTN_PAGEUP';     Description: 'PAGE UP'),
      (Code:   64; Name: 'BTN_PAGEDOWN';   Description: 'PAGE DOWN'),
      (Code:   65; Name: 'BTN_PVR';        Description: 'PVR'),
      (Code:   66; Name: 'BTN_WWW';        Description: 'WWW'),
      (Code:   67; Name: 'BTN_TIMER';      Description: 'TIMER'),
      (Code:   68; Name: 'BTN_NOTUSED68';  Description: 'BUTTON 68 NOT USED'),
      (Code:   69; Name: 'BTN_NOTUSED69';  Description: 'BUTTON 69 NOT USED'),
      (Code:   70; Name: 'BTN_NOTUSED70';  Description: 'BUTTON 70 NOT USED'),
      (Code:   71; Name: 'BTN_NOTUSED71';  Description: 'BUTTON 71 NOT USED'),
      (Code:   72; Name: 'BTN_NOTUSED72';  Description: 'BUTTON 72 NOT USED'),
      (Code:   73; Name: 'BTN_NOTUSED73';  Description: 'BUTTON 73 NOT USED'),
      (Code:   74; Name: 'BTN_NOTUSED74';  Description: 'BUTTON 74 NOT USED'),
      (Code:   75; Name: 'BTN_NOTUSED75';  Description: 'BUTTON 75 NOT USED'),
      (Code:   76; Name: 'BTN_NOTUSED76';  Description: 'BUTTON 76 NOT USED'),
      (Code:   77; Name: 'BTN_NOTUSED77';  Description: 'BUTTON 77 NOT USED'),
      (Code:   78; Name: 'BTN_NOTUSED78';  Description: 'BUTTON 78 NOT USED'),
      (Code:   79; Name: 'BTN_NOTUSED79';  Description: 'BUTTON 79 NOT USED'),
      (Code:   80; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 80 NOT USED'),
      (Code:   81; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 81 NOT USED'),
      (Code:   82; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 82 NOT USED'),
      (Code:   83; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 83 NOT USED'),
      (Code:   84; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 84 NOT USED'),
      (Code:   85; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 85 NOT USED'),
      (Code:   86; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 86 NOT USED'),
      (Code:   87; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 87 NOT USED'),
      (Code:   88; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 88 NOT USED'),
      (Code:   89; Name: 'BTN_NOTUSED80';  Description: 'BUTTON 89 NOT USED'),
      (Code:   90; Name: 'BTN_NOTUSED90';  Description: 'BUTTON 90 NOT USED'),
      (Code:   91; Name: 'BTN_NOTUSED91';  Description: 'BUTTON 91 NOT USED'),
      (Code:   92; Name: 'BTN_NOTUSED92';  Description: 'BUTTON 92 NOT USED'),
      (Code:   93; Name: 'BTN_NOTUSED93';  Description: 'BUTTON 93 NOT USED'),
      (Code:   94; Name: 'BTN_NOTUSED94';  Description: 'BUTTON 94 NOT USED'),
      (Code:   95; Name: 'BTN_NOTUSED95';  Description: 'BUTTON 95 NOT USED'),
      (Code:   96; Name: 'BTN_NOTUSED96';  Description: 'BUTTON 96 NOT USED'),
      (Code:   97; Name: 'BTN_NOTUSED97';  Description: 'BUTTON 97 NOT USED'),
      (Code:   98; Name: 'BTN_NOTUSED98';  Description: 'BUTTON 98 NOT USED'),
      (Code:   99; Name: 'BTN_NOTUSED99';  Description: 'BUTTON 99 NOT USED'),
      (Code:  100; Name: 'BTN_NOTUSED100';  Description: 'BUTTON 100 NOT USED'),
      (Code:  101; Name: 'BTN_NOTUSED101';  Description: 'BUTTON 101 NOT USED'),
      (Code:  102; Name: 'BTN_NOTUSED102';  Description: 'BUTTON 102 NOT USED'),
      (Code:  103; Name: 'BTN_NOTUSED103';  Description: 'BUTTON 103 NOT USED'),
      (Code:  104; Name: 'BTN_NOTUSED104';  Description: 'BUTTON 104 NOT USED'),
      (Code:  105; Name: 'BTN_NOTUSED105';  Description: 'BUTTON 105 NOT USED'),
      (Code:  106; Name: 'BTN_KBDF1';       Description: 'KEYBOARD F1'),
      (Code:  107; Name: 'BTN_KBDF2';       Description: 'KEYBOARD F2'),
      (Code:  108; Name: 'BTN_KBDF3';       Description: 'KEYBOARD F3'),
      (Code:  109; Name: 'BTN_KBDF4';       Description: 'KEYBOARD F4'),
      (Code:  110; Name: 'BTN_KBDF5';       Description: 'KEYBOARD F5'),
      (Code:  111; Name: 'BTN_KBDF6';       Description: 'KEYBOARD F6'),
      (Code:  112; Name: 'BTN_KBDF7';       Description: 'KEYBOARD F7'),
      (Code:  113; Name: 'BTN_KBDF8';       Description: 'KEYBOARD F8'),
      (Code:  114; Name: 'BTN_KBDF9';       Description: 'KEYBOARD F9'),
      (Code:  115; Name: 'BTN_KBDF10';      Description: 'KEYBOARD F10'),
      (Code:  116; Name: 'BTN_KBDF11';      Description: 'KEYBOARD F11'),
      (Code:  117; Name: 'BTN_KBDF12';      Description: 'KEYBOARD F12'),
      (Code:  118; Name: 'BTN_SOFTKEY1';    Description: 'SOFTKEY 1'),
      (Code:  119; Name: 'BTN_SOFTKEY2';    Description: 'SOFTKEY 2'),
      (Code:  120; Name: 'BTN_SOFTKEY3';    Description: 'SOFTKEY 3'),
      (Code:  121; Name: 'BTN_SOFTKEY4';    Description: 'SOFTKEY 4'),
      (Code:  122; Name: 'BTN_KBDINFO';     Description: 'KEYBOARD INFO'),
      (Code:  123; Name: 'BTN_KBDDOWN';     Description: 'KEYBOARD DOWN'),
      (Code:  124; Name: 'BTN_KBDUP';       Description: 'KEYBOARD UP'),
      (Code:  125; Name: 'BTN_KBDMODE';     Description: 'KEYBOARD MODE'),
      (Code:  126; Name: 'BTN_DOFLASH';     Description: 'DO FLASH RESET'),
      (Code:  127; Name: 'BTN_NOTDEFINED';  Description: 'BUTTON NOT DEFINED'),
      (Code:  128; Name: 'BTN_INVALID';     Description: 'BUTTON INVALID')
    );

implementation

{$IFDEF TSAPI_DEBUG}
procedure DebugPrint(DebugText: String);
//generate debug messages for Console or GUI application
begin
  tsapi_Debug_Message:=tsapi_Debug_Message+#13#10+DebugText;
  {$IFNDEF LCL}
  WriteLn(tsapi_Debug_Message);
  {$ELSE}
  if fsapi_Debug_NoShowMessage=false then
    ShowMessage(tsapi_Debug_Message);
  {$ENDIF}
end;
{$ENDIF}

//------------------------------------------------------------------------------
// Helper functions
//------------------------------------------------------------------------------

function tsapi_BtnCodeByName(ButtonName: String): Byte;
//read button code from given button name
var
  Counter: Byte;

begin
  //set default result to invalid button
  Result:=128;

  //Check if string is not empty and starts with BTN_
  if (ButtonName<>'') and (LeftStr(UpperCase(ButtonName),4)<>'BTN_') then
    exit;

  //Read code from array
  for Counter:=0 to Length(tsapi_Buttons) do
    begin
      if tsapi_Buttons[Counter].Name=UpperCase(ButtonName) then
        begin
          Result:=tsapi_Buttons[Counter].Code;
          exit;
        end;
    end;
end;

function tsapi_BtnDescByName(ButtonName: String): String;
//read button description from given button name
begin
  //set default result to invalid button
  Result:=tsapi_BtnDescByCode(tsapi_BtnCodeByName(ButtonName));
end;

function tsapi_BtnNameByCode(ButtonCode: Byte): String;
//read button name from given button code
begin
  //set default result to invalid button
  Result:=tsapi_Buttons[128].Name;

  //Check if button code is valid
  if ButtonCode>128 then
    exit;

  //Read name from array
  Result:=tsapi_Buttons[ButtonCode].Name;
end;

function tsapi_BtnDescByCode(ButtonCode: Byte): String;
//read button description from given button code
begin
  //set default result to invalid button
  Result:=tsapi_Buttons[128].Description;

  //Check if button code is valid
  if ButtonCode>128 then
    exit;

  //Read name from array
  Result:=tsapi_Buttons[ButtonCode].Description;
end;

//------------------------------------------------------------------------------
// Info
//------------------------------------------------------------------------------
function tsapi_Info_DeviceList(TimeoutMS: Integer): TStringList;
//List available devices from network
var
  Buffer:         String;
  DeviceList:     TStringList;
  UDPClient:      TIdUDPClient;
  UDPPeerPort:    Word;
  UDPPeerIP:      String;
  Response:       String;
  XMLBuffer:      TStringStream;
  XML:            TXMLDocument;
  Node:           TDOMNode;

begin
  try
  UDPClient:=TIdUDPClient.Create(nil);
  DeviceList:=TStringList.Create;
  DeviceList.TextLineBreakStyle:=tlbsCRLF;
  DeviceList.Duplicates:=dupIgnore;
  DeviceList.SortStyle:=sslAuto;

  try
    //send discovery request broadcast
    UDPClient.BoundIP:=GStack.LocalAddress;
    UDPClient.BoundPort:=tsapi_ListenerPort;
    UDPClient.Port:=tsapi_ListenerPort;
    UDPClient.BroadcastEnabled:=true;
    UDPClient.Send('255.255.255.255', tsapi_ListenerPort, tsapi_deviceDiscoveryRequest);
    UDPClient.Send('255.255.255.255', tsapi_ListenerPort, tsapi_deviceDiscoveryRequest);
    UDPClient.Send('255.255.255.255', tsapi_ListenerPort, tsapi_deviceDiscoveryRequest);

    //check for discovery request answers
    if TimeoutMS>0 then
      UDPClient.ReceiveTimeout:=TimeoutMS
    else
      UDPClient.ReceiveTimeout:=tsapi_TimeoutMS_Max;
    repeat
      {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
      Response:=UDPClient.ReceiveString(UDPPeerIP, UDPPeerPort);
      //discovery request response received
      if (UDPPeerPort<>0) and (GStack.LocalAddress<>UDPPeerIP) then
        begin
          {$IFDEF TSAPI_DEBUG}{$IFNDEF LCL}
          WriteLn(STR_Info,'Response from ',Format('%s:%d', [UDPPeerIP, UDPPeerPort]));
          writeln(STR_Info,'tsapi_Info_DeviceList -> RESPONSE BEGIN');
          writeln('--------------------------------------------------------------------------------');
          Writeln(Response);
          writeln('--------------------------------------------------------------------------------');
          writeln(STR_Info,'tsapi_Info_DeviceList -> RESPONSE END'+#13#10+#13#10);
          {$ENDIF}{$ENDIF}

          //extract device infos from response
          if AnsiPos('deviceDiscoveryResponse', Response)>0 then
            begin
              Buffer:=UDPPeerIP+'|';
              XMLBuffer:=TStringStream.Create(Trim(Response));
              ReadXMLFile(XML, XMLBuffer);
              Node:=XML.DocumentElement.ParentNode.FirstChild;
              if Node<>NIL then
                begin
                  Buffer:=Buffer+(String(Node.Attributes.GetNamedItem('name').NodeValue))+'|';
                  Buffer:=Buffer+(String(Node.Attributes.GetNamedItem('type').NodeValue))+'|';
                  Buffer:=Buffer+(String(Node.Attributes.GetNamedItem('serial').NodeValue))+'|';
                  Buffer:=Buffer+(String(Node.Attributes.GetNamedItem('version').NodeValue));
                end;
              if Node<>NIL then Node.Free;
              if XML<>NIL then XML.Free;
              if XMLBuffer<>NIL then XMLBuffer.Free;
              DeviceList.Add(Buffer);
            end;
        end;
    until UDPPeerPort=0;

    //sort list
    DeviceList.Sort;
  finally
    UDPClient.Free;
  end;
  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=DeviceList;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_Info_DeviceList -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:=DeviceList;
    end;
  end;
end;

function tsapi_Info_DeviceInformation(URL: String; TimeoutMS: Integer): TStringList;
//List device information
var
  DeviceInfo:     TStringList;
  UDPClient:      TIdUDPClient;
  UDPPeerPort:    Word;
  UDPPeerIP:      String;
  Response:       String;
  XMLBuffer:      TStringStream;
  XML:            TXMLDocument;
  Node:           TDOMNode;
  Node2:          TDOMNode;
  Node3:          TDOMNode;
  Counter:        LongWord;
  Counter2:       LongWord;
  Buffer:         String;

begin
  try
  UDPClient:=TIdUDPClient.Create(nil);
  DeviceInfo:=TStringList.Create;
  DeviceInfo.TextLineBreakStyle:=tlbsCRLF;
  DeviceInfo.Duplicates:=dupIgnore;
  DeviceInfo.SortStyle:=sslAuto;

  //check if URL is available
  if URL='' then
    begin
      Result:=DeviceInfo;
      exit;
    end;

  try
    //send device information
    UDPClient.BoundIP:=GStack.LocalAddress;
    UDPClient.BoundPort:=tsapi_ListenerPort;
    UDPClient.Port:=tsapi_ListenerPort;
    UDPClient.BroadcastEnabled:=true;
    UDPClient.Send(URL, tsapi_ListenerPort, tsapi_deviceInformationRequest);

    //check for device information request answers
    if TimeoutMS>0 then
      UDPClient.ReceiveTimeout:=TimeoutMS
    else
      UDPClient.ReceiveTimeout:=tsapi_TimeoutMS_Max;
    repeat
      {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
      Response:=UDPClient.ReceiveString(UDPPeerIP, UDPPeerPort);
      //discovery request response received
      if (UDPPeerPort<>0) and (GStack.LocalAddress<>UDPPeerIP) then
        begin
          {$IFDEF TSAPI_DEBUG}{$IFNDEF LCL}
          WriteLn(STR_Info,'Response from ',Format('%s:%d', [UDPPeerIP, UDPPeerPort]));
          writeln(STR_Info,'tsapi_Info_DeviceInformation -> RESPONSE BEGIN');
          writeln('--------------------------------------------------------------------------------');
          Writeln(Response);
          writeln('--------------------------------------------------------------------------------');
          writeln(STR_Info,'tsapi_Info_DeviceInformation -> RESPONSE END'+#13#10+#13#10);
          {$ENDIF}{$ENDIF}

          //extract device infos from response
          if AnsiPos('deviceInformationResponse', Response)>0 then
            begin
              XMLBuffer:=TStringStream.Create(Trim(Response));
              ReadXMLFile(XML, XMLBuffer);
              Node:=XML.DocumentElement.ParentNode.FirstChild;
              if Node<>NIL then
                begin
                  for Counter:=0 to Node.Attributes.Length-1 do
                    begin
                      if String(Node.Attributes.Item[Counter].NodeValue)<>'' then
                        begin
                          Buffer:=String(Node.Attributes.Item[Counter].NodeName+'='+Node.Attributes.Item[Counter].NodeValue);
                          DeviceInfo.Add(Trim(Buffer));
                        end;
                    end;
                  //extract additional information like capabilities
                  for Counter:=0 to Node.GetChildNodes.Count-1 do
                    begin
                      Node2:=Node.GetChildNodes.Item[Counter];
                      if String(Node2.NodeName)<>'' then
                        begin
                          for Counter2:=0 to Node2.GetChildNodes.Count-1 do
                            begin
                              Buffer:=String(Node2.NodeName+':'+Node2.GetChildNodes.Item[Counter2].NodeName+Node2.GetChildNodes.Item[Counter2].NodeValue);
                              Node3:=Node2.GetChildNodes.Item[Counter2].FirstChild;
                              if Node3<>NIL then
                                begin
                                  if String(Node3.NodeValue)<>'' then
                                    Buffer:=Buffer+'='+String(Node3.NodeValue);
                                end;
                              DeviceInfo.Add(Trim(Buffer));
                            end;
                        end;
                    end;
                end;
              //clean up variables
              if Node<>NIL then Node.Free;
              if Node2<>NIL then Node2.Free;
              if Node3<>NIL then Node3.Free;
              if XML<>NIL then XML.Free;
              if XMLBuffer<>NIL then XMLBuffer.Free;
            end;
        end;
    until UDPPeerPort=0;
    //sort list
    DeviceInfo.Sort;
  finally
    UDPClient.Free;
  end;
  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=DeviceInfo;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_Info_DeviceInformation -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:=DeviceInfo;
    end;
  end;
end;

function tsapi_Info_Authentication(URL: String; PIN: String; TimeoutMS: Integer): Boolean;
//Device authentication with PIN
var
  Authentication: Boolean;
  UDPClient:      TIdUDPClient;
  UDPPeerPort:    Word;
  UDPPeerIP:      String;
  Response:       String;
  XMLBuffer:      TStringStream;
  XML:            TXMLDocument;
  Node:           TDOMNode;

begin
  try
  UDPClient:=TIdUDPClient.Create(nil);
  Authentication:=false;

  //check if URL is available
  if URL='' then
    begin
      Result:=Authentication;
      exit;
    end;

  //check if PIN is available, if not try fallback to default value
  if PIN='' then PIN:='0000';

  try
    //send authentication request
    UDPClient.BoundIP:=GStack.LocalAddress;
    UDPClient.BoundPort:=tsapi_ListenerPort;
    UDPClient.Port:=tsapi_ListenerPort;
    UDPClient.BroadcastEnabled:=true;
    UDPClient.Send(URL, tsapi_ListenerPort, '<authenticationRequest pin="'+PIN+'"/>');

    //check authentication request answer
    if TimeoutMS>0 then
      UDPClient.ReceiveTimeout:=TimeoutMS
    else
      UDPClient.ReceiveTimeout:=tsapi_TimeoutMS_Max;
    repeat
      {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
      Response:=UDPClient.ReceiveString(UDPPeerIP, UDPPeerPort);
      //discovery request response received
      if (UDPPeerPort<>0) and (GStack.LocalAddress<>UDPPeerIP) then
        begin
          {$IFDEF TSAPI_DEBUG}{$IFNDEF LCL}
          WriteLn(STR_Info,'Response from ',Format('%s:%d', [UDPPeerIP, UDPPeerPort]));
          writeln(STR_Info,'tsapi_Info_Authentication -> RESPONSE BEGIN');
          writeln('--------------------------------------------------------------------------------');
          Writeln(Response);
          writeln('--------------------------------------------------------------------------------');
          writeln(STR_Info,'tsapi_Info_Authentication -> RESPONSE END'+#13#10+#13#10);
          {$ENDIF}{$ENDIF}

          //check authentication response
          if AnsiPos('authenticationResponse', Response)>0 then
            begin
              XMLBuffer:=TStringStream.Create(Trim(Response));
              ReadXMLFile(XML, XMLBuffer);
              Node:=XML.DocumentElement.ParentNode.FirstChild;
              if Node<>NIL then
                begin
                  if UpperCase((String(Node.Attributes.GetNamedItem('result').NodeValue)))='SUCCESS' then
                    Authentication:=true
                  else
                    Authentication:=false;
                end;
              if Node<>NIL then Node.Free;
              if XML<>NIL then XML.Free;
              if XMLBuffer<>NIL then XMLBuffer.Free;
            end;
        end;
    until UDPPeerPort=0;
  finally
    UDPClient.Free;
  end;

  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=Authentication;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_Info_Authentication -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:=false;
    end;
  end;
end;

function tsapi_Info_KeepAlive(URL: String; TimeoutMS: Integer): Boolean;
//Device keep alive check
var
  KeepAlive:      Boolean;
  UDPClient:      TIdUDPClient;
  UDPPeerPort:    Word;
  UDPPeerIP:      String;
  Response:       String;

begin
  try
  UDPClient:=TIdUDPClient.Create(nil);
  KeepAlive:=false;

  //check if URL is available
  if URL='' then
    begin
      Result:=KeepAlive;
      exit;
    end;

  try
    //send keep alive request
    UDPClient.BoundIP:=GStack.LocalAddress;
    UDPClient.BoundPort:=tsapi_ListenerPort;
    UDPClient.Port:=tsapi_ListenerPort;
    UDPClient.BroadcastEnabled:=true;
    UDPClient.Send(URL, tsapi_ListenerPort, tsapi_keepAliveRequest);

    //check keep alive request answer
    if TimeoutMS>0 then
      UDPClient.ReceiveTimeout:=TimeoutMS
    else
      UDPClient.ReceiveTimeout:=tsapi_TimeoutMS_Max;
    repeat
      {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
      Response:=UDPClient.ReceiveString(UDPPeerIP, UDPPeerPort);
      //keep alive request response received
      if (UDPPeerPort<>0) and (GStack.LocalAddress<>UDPPeerIP) then
        begin
          {$IFDEF TSAPI_DEBUG}{$IFNDEF LCL}
          WriteLn(STR_Info,'Response from ',Format('%s:%d', [UDPPeerIP, UDPPeerPort]));
          writeln(STR_Info,'tsapi_Info_KeepAlive -> RESPONSE BEGIN');
          writeln('--------------------------------------------------------------------------------');
          Writeln(Response);
          writeln('--------------------------------------------------------------------------------');
          writeln(STR_Info,'tsapi_Info_KeepAlive -> RESPONSE END'+#13#10+#13#10);
          {$ENDIF}{$ENDIF}

          //check keep alive response
          if AnsiPos(tsapi_keepAliveResponse, Response)>0 then
            KeepAlive:=true
          else
            KeepAlive:=false;
        end;
    until UDPPeerPort=0;
  finally
    UDPClient.Free;
  end;

  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=KeepAlive;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_Info_KeepAlive -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:=false;
    end;
  end;
end;

//------------------------------------------------------------------------------
// Button Request
//------------------------------------------------------------------------------
function tsapi_rcuButtonRequest(URL: String; PIN: String; ButtonCode: Byte; ButtonState: String; TimeoutMS: Integer): Boolean;
//Device button request
var
  rcuBtnRequest:  Boolean;
  UDPClient:      TIdUDPClient;
  UDPPeerPort:    Word;
  UDPPeerIP:      String;
  Response:       String;

begin
  try
  UDPClient:=TIdUDPClient.Create(nil);
  rcuBtnRequest:=false;

  //check if URL and button code is available and not invalid
  if (URL='') or (ButtonCode>Length(tsapi_Buttons)-1) then
    begin
      Result:=rcuBtnRequest;
      exit;
    end;

  //check if ButtonState is correct
  if AnsiIndexText(ButtonState, tsapi_ButtonStates)<0 then
    ButtonState:=tsapi_ButtonStates[0];

  try
    //check if device reacts on keep alive request
    if tsapi_Info_KeepAlive(URL, TimeoutMS)=false then
      begin
        //keep alive failed so try to authenticate
        if tsapi_Info_Authentication(URL, PIN, TimeoutMS)=false then
          begin
            //Authentication failed also therefore button request can not be send
            Result:=rcuBtnRequest;
            exit;
          end;
      end;

    //send rcu button request
    UDPClient.BoundIP:=GStack.LocalAddress;
    UDPClient.BoundPort:=tsapi_ListenerPort;
    UDPClient.Port:=tsapi_ListenerPort;
    UDPClient.BroadcastEnabled:=true;
    UDPClient.Send(URL, tsapi_ListenerPort, '<rcuButtonRequest code="'+IntToStr(ButtonCode)+'" state="'+ButtonState+'"/>');

    //check keep alive request answer
    if TimeoutMS>0 then
      UDPClient.ReceiveTimeout:=TimeoutMS
    else
      UDPClient.ReceiveTimeout:=tsapi_TimeoutMS_Max;
    repeat
      {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
      Response:=UDPClient.ReceiveString(UDPPeerIP, UDPPeerPort);
      //keep rcu button request response received
      if (UDPPeerPort<>0) and (GStack.LocalAddress<>UDPPeerIP) then
        begin
          {$IFDEF TSAPI_DEBUG}{$IFNDEF LCL}
          WriteLn(STR_Info,'Response from ',Format('%s:%d', [UDPPeerIP, UDPPeerPort]));
          writeln(STR_Info,'tsapi_rcuButtonRequest -> RESPONSE BEGIN');
          writeln('--------------------------------------------------------------------------------');
          Writeln(Response);
          writeln('--------------------------------------------------------------------------------');
          writeln(STR_Info,'tsapi_rcuButtonRequest -> RESPONSE END'+#13#10+#13#10);
          {$ENDIF}{$ENDIF}

          //check button request response if available
          if Response<>'' then
            begin
              if AnsiPos('rcuButtonRequest', Response)>0 then
                rcuBtnRequest:=true
              else
                rcuBtnRequest:=false;
            end
          else
            rcuBtnRequest:=true;
        end
      else
        rcuBtnRequest:=true;
    until UDPPeerPort=0;
  finally
    UDPClient.Free;
  end;

  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=rcuBtnRequest;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_rcuButtonRequest -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:=false;
    end;
  end;
end;

function tsapi_Info_GetURLByDeviceList(SearchCriteria: String; TimeoutMS: Integer): String;
//retrieve URL from device list by a given search criteria
var
  DeviceList:     TStringList;
  Counter:        Integer;
  Buffer:         String;

begin
  try
  Buffer:='';

  //check if search criteria is not empty
  if SearchCriteria='' then
    begin
      Result:=Buffer;
      exit;
    end;

  //read device list
  DeviceList:=TStringList.Create;
  DeviceList.TextLineBreakStyle:=tlbsCRLF;
  DeviceList.Duplicates:=dupIgnore;
  DeviceList.SortStyle:=sslAuto;
  DeviceList:=tsapi_Info_DeviceList(TimeoutMS);
  if DeviceList.Count=0 then
    begin
      if DeviceList<>NIL then DeviceList.Free;
      exit;
    end;

  //search device URL
  for Counter:=0 to DeviceList.Count-1 do
    begin
      if (UpperCase(SearchCriteria)=Uppercase(DeviceList.Strings[Counter].Split('|')[1])) or (UpperCase(SearchCriteria)=Uppercase(DeviceList.Strings[Counter].Split('|')[2])) or (UpperCase(SearchCriteria)=Uppercase(DeviceList.Strings[Counter].Split('|')[3])) then
        begin
          Buffer:=DeviceList.Strings[Counter].Split('|')[0];
        end;
    end;

  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=Buffer;
  if DeviceList<>NIL then DeviceList.Free;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_Info_GetURLByDeviceList -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:='';
    end;
  end;
end;

function tsapi_rcuButtonRequestByName(DeviceName: String; PIN: String; ButtonCode: Byte; ButtonState: String; TimeoutMS: Integer): Boolean;
//Device button request with device name
var
  rcuBtnRequest:  Boolean;
  URL:            String;

begin
  try
  rcuBtnRequest:=false;

  //check if device name is not empty
  if DeviceName='' then
    begin
      Result:=rcuBtnRequest;
      exit;
    end;

  //retrieve device URL by name
  URL:=tsapi_Info_GetURLByDeviceList(DeviceName,TimeoutMS);

  //start now button request with found URL
  if URL<>'' then
    begin
      writeln(URL);
      rcuBtnRequest:=tsapi_rcuButtonRequest(URL, PIN, ButtonCode, ButtonState, TimeoutMS);
    end;

  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=rcuBtnRequest;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_rcuButtonRequestByName -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:=false;
    end;
  end;
end;

function tsapi_rcuButtonRequestBySerial(Serial: String; PIN: String; ButtonCode: Byte; ButtonState: String; TimeoutMS: Integer): Boolean;
//Device button request with serial
var
  rcuBtnRequest:  Boolean;
  URL:            String;

begin
  try
  rcuBtnRequest:=false;

  //check if serial is not empty
  if Serial='' then
    begin
      Result:=rcuBtnRequest;
      exit;
    end;

  //retrieve device URL by serial
  URL:=tsapi_Info_GetURLByDeviceList(Serial,TimeoutMS);

  //start now button request with found URL
  if URL<>'' then
    begin
      writeln(URL);
      rcuBtnRequest:=tsapi_rcuButtonRequest(URL, PIN, ButtonCode, ButtonState, TimeoutMS);
    end;

  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=rcuBtnRequest;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_rcuButtonRequestBySerial -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:=false;
    end;
  end;
end;

//------------------------------------------------------------------------------
// Zoom Request
//------------------------------------------------------------------------------
function tsapi_zoomRequest(URL: String; PIN: String; ZoomValue: Integer; TimeoutMS: Integer): Boolean;
//Device zoom request
var
  ZoomRequest:    Boolean;
  UDPClient:      TIdUDPClient;

begin
  try
  UDPClient:=TIdUDPClient.Create(nil);
  ZoomRequest:=false;

  //check if URL and zoom value is available and not invalid
  if (URL='') or (ZoomValue=0) then
    begin
      Result:=ZoomRequest;
      exit;
    end;

  try
    //check if device reacts on keep alive request
    if tsapi_Info_KeepAlive(URL, TimeoutMS)=false then
      begin
        //keep alive failed so try to authenticate
        if tsapi_Info_Authentication(URL, PIN, TimeoutMS)=false then
          begin
            //Authentication failed also therefore button request can not be send
            Result:=ZoomRequest;
            exit;
          end;
      end;

    //send zoom request (there will be no response from the device)
    UDPClient.BoundIP:=GStack.LocalAddress;
    UDPClient.BoundPort:=tsapi_ListenerPort;
    UDPClient.Port:=tsapi_ListenerPort;
    UDPClient.BroadcastEnabled:=true;
    UDPClient.Send(URL, tsapi_ListenerPort, '<zoomRequest zoom="'+IntToStr(ZoomValue)+'"/>');
    ZoomRequest:=true;
  finally
    UDPClient.Free;
  end;

  {$IFDEF LCL}Application.ProcessMessages;{$ENDIF}
  Result:=ZoomRequest;
  except
  on E:Exception do
    begin
      {$IFDEF FSAPI_DEBUG}E.Message:=STR_Error+'tsapi_zoomRequest -> '+E.Message; DebugPrint(E.Message);{$ENDIF}
      Result:=false;
    end;
  end;
end;

end.

