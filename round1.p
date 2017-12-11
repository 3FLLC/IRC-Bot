Program IRCBot.v1171209;

Uses
   DateTime, // FORMATTIMESTAMP
   Strings,  // FETCH
   Display,  // KEYBOARD
   Sockets;  // DXSOCK

Const
   IRCServer='Chicago.IL.US.Undernet.Org';
   IRCPort=7000;
   __USER="USER Whiteboy 2 * :I am written using ModernPascal";
   __NICK="Guerdo";
   __CHANNEL="#ModernPascal";
   ApprovedBosses=[':SqZ!~ozznixon@c-73-147-125-238.hsd1.va.comcast.net'];

type
   LineRec = Packed Record
      OpCode:Word;
      Server:String;
      Nick:String;
      Email:String;
      Command:String;
      Channel:String;
      Users:String;
      Message:String;
   End;

Var
   Client:TDXSock;
   Ws,Ts,Ss:String;
   SsLen:Longint;
   JoinNick:String;
   PingElapse:TTimestamp;
   BotEmailAddress:String;
   IsJoined:Boolean;
   TriedToJoin:Boolean;
   LineResponse:LineRec;

function ParseMessage(S:String):LineRec;
var
   TmpStr:String;

Begin
   If Copy(S,1,1)=':' then begin    // Either P2P or S2P message
      If Pos(#33,S)>0 then begin    // P2P
         Delete(S,1,1);
         Result.Nick:=Fetch(S,#33); // everything left of !
         Result.Email:=Fetch(S);    // everything after ! to SPACE
         Result.Command:=Fetch(S);  // MODE,KICK
         If Result.Command='JOIN' then begin
            Result.OpCode:=321;     // RFC2812 3.2.1 JOIN Command
            Result.Channel:=Fetch(S);
            Result.Message:=S;
            IsJoined:=True;
         End
         else If Result.Command='KICK' then begin
            Result.OpCode:=328;     // RFC2812 3.2.8 KICK Command
            Result.Channel:=Fetch(S);
            Result.Users:=Fetch(S);
            Result.Message:=S;
         End
         else If Result.Command='MODE' then begin
// Nick vs Channel?
         End
         else If Result.Command='PRIVMSG' then begin
            // :SqZ!~ozznixon@c-73-147-125-238.hsd1.va.comcast.net PRIVMSG #ModernPascal :Wassup Ganni?
            Result.OpCode:=331;
            TmpStr:=Fetch(S);
            If (Copy(TmpStr,1,1)='#') or
               (Copy(TmpStr,1,1)='&') then Result.Channel:=TmpStr;
            Result.Message:=S;
         End;
      end
      else begin                    // S2P
         Result.Server:=Fetch(S);
         TmpStr:=Fetch(S);
         If IsNumericString(TmpStr) then begin
            Result.OpCode:=StrToIntDef(TmpStr,0);
            If Result.OpCode=451 then begin
               Result.Nick:=Fetch(S);
               Fetch(S); // extra nick skip
               Result.Message:=S;
            end
            else If Copy(S,1,Length(__NICK))=__NICK then begin
               Result.Nick:=Fetch(S);
               Result.Message:=S;
            End
         End;
      End;
   End
   Else Begin // NOTICE, PING, PONG
      TmpStr:=Fetch(S);
      If TmpStr='NOTICE' then begin
         Result.OpCode:=332;
         Result.Message:=S;
      end
      else if TmpStr='PING' then begin
         Result.OpCode:=372;
         Result.Message:=Fetch(S);
         Result.Server:=S;
      end
      else if TmpStr='PONG' then begin
         Result.OpCode:=373;
         Result.Message:=Fetch(S);
         Result.Server;
      End;
   End;
End;

Begin
   Client.Init;
   Write(' √ connecting to IRC server ');
   If Client.ConnectTo(IRCServer, IRCPort) then begin
      Writeln('Connected @ ',Timestamp);
      Client.Writeln('CAP LS'); // ask server for compabilities
      While Client.CountWaiting=0 do Yield(1);
      Client.Writeln(__USER);
      Client.Writeln('NICK '+__NICK);
      Client.Writeln('WHOIS '+__NICK);
      Ss:='JOIN :'+__CHANNEL;
      SsLen:=Length(Ss);
      PingElapse:=Timestamp+15; // wait 15 seconds first time through //
      IsJoined:=False;
      TriedToJoin:=False;
      While Client.Connected do begin
         If Client.Readable then begin
            If Client.CountWaiting=0 then Begin
               Writeln('TCP SYN Disconnect Received.');
               Break; //Recieved SYN_ Disconnect
            End;
            Ws:=Client.Readln(500);
            LineResponse:=ParseMessage(Ws);
            Case LineResponse.OpCode of
               1:Begin
                  TextColor(Yellow);
                  Writeln(LineResponse.Message);
               End;
               2..4:Begin
                  TextColor(7);
                  Writeln(LineResponse.Message);
               End;
               5:Begin
                  TextColor(4);
                  Writeln(LineResponse.Message);
               End;
               251..255:Begin
                  TextColor(3);
                  Writeln(LineResponse.Message);
               End;
               321:Begin
                  TextColor(15);
                  TextBackground(1);
                  Writeln(LineResponse.Channel);
                  TextColor(14);
                  TextBackground(0);
                  Writeln(LineResponse.Message);
               End;
               331:Begin
                  TextColor(11);
                  Writeln(LineResponse.Message);
                  If lowercase(LineResponse.Message)=':.time' then begin
                     Writeln('PRIVMSG '+LineResponse.Channel+' :'+FormatTimestamp('ddd, mmm dd yyyy hh:nn:ss',Timestamp));
                     Client.Writeln('PRIVMSG '+LineResponse.Channel+' :'+FormatTimestamp('ddd, mmm dd yyyy hh:nn:ss',Timestamp));
                  End;
               End;
               332:Begin
                  TextColor(5);
                  Writeln(LineResponse.Message);
               End;
               353,366:Begin
                  TextColor(2);
                  Writeln(LineResponse.Message);
               End;
               372,373:Begin
                  TextColor(13);
                  Writeln(LineResponse.Message);
                  If LineResponse.OpCode=372 then begin
                     Client.Writeln('PONG '+Copy(LineResponse.Message,2,255));
                  End;
               End;
               375,376:Begin
                  TextColor(10);
                  Writeln(LineResponse.Message);
               End;
               451:Begin
                  TextColor(12);
                  Writeln(LineResponse.Message);
               End;
               Else Begin
                  TextColor(8);
                  If Copy(Ws,1,length(IRCServer)+2)=':'+IRCServer+#32 then Delete(Ws,1,length(IRCServer)+2);
                  Writeln('R>'+Ws);
                  If Copy(Ws,Succ(Length(Ws)-SsLen),SsLen)=Ss then begin
                     JoinNick:=Copy(Ws,1,Pos('!',Ws)-1);
                     Client.Writeln('NOTICE '+JoinNick+' :Hi '+JoinNick+
                        ', welcome to '+__CHANNEL+' channel.');
                  End
                  else If Copy(Ws,1,5)='PING ' then begin
                     Writeln('S>PONG '+Copy(Ws,6,Length(Ws)));
                     Client.Writeln('PONG '+Copy(Ws,6,Length(Ws)));
                  End
                  else If (Copy(Ws,1,Length(__NICK)+2)=':'+__NICK+'!') then begin
                     // :MPBot!~ModernPas@ip-50-63-13-245.ip.secureserver.net MODE MPBot :+iw
                     // :MPBot!~ModernPas@ip-50-63-13-245.ip.secureserver.net JOIN #my_channel
                     If Pos(' JOIN ',Ws)=0 then begin
                        Client.Writeln('JOIN '+__CHANNEL);
                        If not IsJoined then TriedToJoin:=True;
                        Fetch(Ws,'!'+#126);
                        If not IsJoined then BotEmailAddress:=Fetch(Ws)
                        else Fetch(Ws);
                        If copy(Ws,1,5)='MODE ' then begin
                           Fetch(Ws,':');
                           // parse attribute +iw for example
                           // +invisible
                           // +wallops
                        End;
                     End
                     Else begin
                        Fetch(Ws,' JOIN ');
                        IsJoined:=True;
                        TriedToJoin:=False;
                        Client.Writeln('PRIVMSG '+Ws+' :I am back, with all the jack!');
                        Client.Writeln('PRIVMSG '+Ws+' :PM me to get all the goods.');
                        Writeln('S:Introduction Posted.');
                     end;
                  End
                  else If Pos(' PRIVMSG '+__NICK,Ws)>0 then begin
                     // INNER OPS: :SqZ!~ozznixon@c-73-147-125-238.hsd1.va.comcast.net PRIVMSG MPBot :join #my_channel
                     Ts:=Fetch(Ws,' PRIVMSG '+__NICK+' :');
                     If ArrayIndexOf(Ts,ApprovedBosses)>-1 then begin
                        Client.Writeln(Ws);
                        Writeln('E:'+Ws+' on behalf of '+Ts);
                     End;
                  End
                  else begin
                     // :SqZ!~ozznixon@c-73-147-125-238.hsd1.va.comcast.net JOIN #my_channel
                     Ts:=Fetch(Ws);
                     If ArrayIndexOf(Ts,ApprovedBosses)>-1 then begin // what did he do?
                        If Copy(Ws,1,5)='JOIN ' then begin // if I have ops give him ops!
                           Fetch(Ws);
                           Client.Writeln('MODE '+Ws+' +o '+Copy(Ts,2,Pos('!',Ts)-2));
                           Writeln('S>MODE '+Ws+' +o '+Copy(Ts,2,Pos('!',Ts)-2));
                        End;
                     End;
                  End;
               End; {case else}
            End; {case}
         End
         Else Begin
            Yield(1); // CPU friendly on Windows //
            If PingElapse<Timestamp then Begin // every 120 seconds //
               TextColor(9);
               Writeln('S>PING '+IntToStr(Timestamp)+" :"+IRCServer);
               Client.Writeln('PING '+IntToStr(Timestamp)+" :"+IRCServer);
               PingElapse:=Timestamp+120;
               If not IsJoined then begin
                  TextColor(15);
                  Client.Writeln('JOIN '+__CHANNEL);
                  Writeln('S:JOIN '+__CHANNEL);
                  TriedToJoin:=True;
               End;
            End;
            If Keypressed then if ReadKey=#27 then break; // cancel @ console [ESC]
         End;
      End;
   End
   Else Writeln('timeout to '+IRCServer+':'+IntToStr(IRCPort));
   Client.Free;
End.
