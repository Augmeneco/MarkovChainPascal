program kbot;
uses strings, jsonparser, fpjson, Classes, sysutils, fphttpclient, process,
  RegExpr, utils;
type
  TConfig = record
  token: string;
  group_id: integer;
  end;
  TMsg = record
  text: string;
  toho: integer;
  text_split: TStringArray;
  userid: integer;
  end;

var
  i, k, count: integer;
  RegexObj: TRegExpr;
  requests: TFPHTTPClient;
  params, ts, output, stat: string;
  config: TConfig;
  jsonobj, lpb, updates: TJSONObject;
  jsonarr: TJSONArray;
  msg: TMsg;
  dict, counter: TJSONObject;

begin
  Randomize;
  writeln('Начинаю инициализацию бота');

  if not fileExists('./bot.cfg') then
  begin
    writeLn('ERROR: Config "bot.cfg" not exist!');
    halt(1);
  end;
  requests := TFPHTTPClient.Create(Nil);

  jsonobj := TJSONObject(GetJSON(readfile('bot.cfg')));
  config.token := jsonobj['group_token'].AsString;
  config.group_id := jsonobj['group_id'].AsInteger;

  params := 'access_token='+config.token+'&v=5.100&group_id='+inttostr(config.group_id);
  lpb := TJSONObject(GetJSON(requests.SimpleFormPost('https://api.vk.com/method/groups.getLongPollServer',params))).Objects['response'];
  ts := lpb['ts'].AsString;
  writeln('Получены данные лонгполла');
  counter := TJSONObject.Create;

  while(true) do
  begin
    try
    params := lpb['server'].AsString+'?act=a_check&key='+lpb['key'].AsString+'&ts='+ts+'&wait=20';
    jsonobj := TJSONObject(GetJSON(requests.SimpleGet(params)));

    try
      ts := jsonobj['ts'].AsString;
    except
      params := 'access_token='+config.token+'&v=5.100&group_id='+inttostr(config.group_id);
      lpb := TJSONObject(GetJSON(requests.SimpleFormPost('https://api.vk.com/method/groups.getLongPollServer',params))).Objects['response'];
      ts := lpb['ts'].AsString;
      writeln('Лонгполл обновлён');
      Continue;
    end;

    for i:=0 to jsonobj.Arrays['updates'].Count-1 do
    begin
      try
        updates := jsonobj.Arrays['updates'].Objects[i].Objects['object'];
        msg.text := updates['text'].AsString;
        msg.toho := updates['peer_id'].AsInteger;
        msg.userid := updates['from_id'].AsInteger;
        msg.text_split := msg.text.split([' ']);
        if Length(msg.text) = 0 then
           Continue;
        writeln('Получено сообщение: '+msg.text);

        if msg.toho < 2000000000 then
          continue;

        if msg.userid < 0 then
           continue;

        //if iscommand('стат,stat',msg.text) then
        //begin
        //  stat := readfile('/proc/self/status');
        //  RegexObj := TRegExpr.Create('VmRSS:\s+(\d+) kB');
        //  RegexObj.Exec(stat);
        //  apisay(format('Бот на цепях Маркова потребляет: %s кБ',[RegexObj.Match[1]]),msg.toho);
        //  RegexObj.Free;
        //end;

        if iscommand('начать,старт,start',msg.text) then
        begin
          count := dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Count;
          if count = 0 then
             dbExecIn(format('INSERT INTO main VALUES (%d,''%s'',''%s'')',[msg.toho,'{}','{"start":"true"}']))
          else
             dbExecIn(format('UPDATE main SET data = ''%s'' WHERE id = %d',['{"start":"true"}',msg.toho]));
          apisay('Генерация сообщений включена. Её всегда можно отключить командой /стоп. Не забудь дать боту доступ к сообщениям!',msg.toho);
        end;

        if iscommand('стоп,stop',msg.text) then
        begin
          count := dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Count;
          if count = 0 then
          begin
             apisay('Ну и зачем ты это высрал? Я эту беседу первый раз вижу.',msg.toho);
             exit;
          end
          else
             dbExecIn(format('UPDATE main SET data = ''%s'' WHERE id = %d',['{"start":"false"}',msg.toho]));
          apisay('Генерация сообщений отключена. Её всегда можно снова включить командой /старт.',msg.toho);
        end;

        if iscommand('инфо,info',msg.text) then
        begin
           output:='[ Статистика беседы ]'+#13#10+
        'До следующего моего сообщения: '+IntToStr(10-counter[IntToStr(msg.toho)].AsInteger);
           apisay(output,msg.toho);
        end;

        if iscommand('ген,g,gen,г',msg.text) then
        begin
           count := dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Count;
           if count > 0 then
           begin
              dict := TJSONObject(GetJSON(dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Objects[0]['json'].AsString));
              apisay(mc_gen(dict),msg.toho);
           end;
        end;
        if Pos('/',msg.text) = 0 then
        if Length(msg.text.split([' '])) >= 3 then
        begin
          count := dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Count;

          if count > 0 then
             dict := TJSONObject(GetJSON(dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Objects[0]['json'].AsString))
          else
             dict := TJSONObject.Create;

          dict := mc_add(dict,msg.text);
          if count = 0 then
             dbExecIn(format('INSERT INTO main VALUES (%d,''%s'',''%s'')',[msg.toho,dict.AsJSON,'{"start":"false"}']))
          else
             dbExecIn(format('UPDATE main SET json = ''%s'' WHERE id = %d',[dict.AsJSON,msg.toho]));
          FreeAndNil(dict);
        end;

        if dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Count = 0 then
           dbExecIn(format('INSERT INTO main VALUES (%d,''%s'',''%s'')',[msg.toho,'{}','{"start":"false"}']));

        if TJSONObject(GetJSON(dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Objects[0]['data'].AsString))['start'].AsString = 'true' then
        begin
          if counter.IndexOfName(IntToStr(msg.toho)) = -1 then
             counter.add(IntToStr(msg.toho),1);
          if counter[IntToStr(msg.toho)].AsInteger = 10 then
          begin
             dict := TJSONObject(GetJSON(dbExecOut(format('SELECT * FROM main WHERE id=%d',[msg.toho])).Objects[0]['json'].AsString));
             apisay(mc_gen(dict),msg.toho);
             counter[IntToStr(msg.toho)].AsInteger := 0;
          end;
          if counter[IntToStr(msg.toho)].AsInteger < 10 then
             counter[IntToStr(msg.toho)].AsInteger := counter[IntToStr(msg.toho)].AsInteger+1;
          writeln(counter[IntToStr(msg.toho)].AsInteger);

        end;


      except
        on E: Exception do
          writeln( 'LP Error: '+ E.ClassName + #13#10 + E.Message );
      end;
    end;
    except
      on E: Exception do
        writeln( 'Main Error: '+ E.ClassName + #13#10 + E.Message );
    end;
  end;
end.

