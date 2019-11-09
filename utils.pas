unit utils;

{$mode objfpc}{$H+}

interface

uses
  Classes, sysutils, fpjson;

procedure dbExecIn(queryString: String);
function dbExecOut(queryString: String): TJSONArray;
function readfile(fnam: string): string;
function cuterandom(min,max: integer): Integer;
function mc_add(dict: TJSONObject;text: string): TJSONObject;
function mc_gen(dict: TJSONObject): string;
function iscommand(cmd,text: string): Boolean;


implementation
uses
  jsonparser, sqlite3conn, db, SQLdb, strutils;
var
  conn: TSQLite3Connection;
  trans: TSQLTransaction;
  query: TSQLQuery;

function readfile(fnam: string): string;
var
   F: TextFile;
   line: string;
begin
   AssignFile(F, fnam);
   Reset(F);
   while not Eof(F) do begin
     Readln(F, line);
     readfile += line;
   end;
   closeFile(F);
end;

function cuterandom(min,max: integer): Integer;
begin
  cuterandom := random(max-min+1)+min;
end;
function dbExecOut(queryString: String): TJSONArray;
var
  response: TJSONArray;
  responseRow: TJSONObject;
  i: Integer;
begin
  response := TJSONArray.create();
  query.SQL.text := queryString;
  query.open();
  while not query.eof do
  begin
    responseRow := TJSONObject.create();
    for i := 0 to query.fields.count-1 do
    begin
      case query.fields[i].dataType of
        TFieldType.ftInteger:
          responseRow.add(query.fields[i].fieldName, query.fields[i].asInteger);
        TFieldType.ftFloat:
          responseRow.add(query.fields[i].fieldName, query.fields[i].asFloat);
        TFieldType.ftMemo:
          responseRow.add(query.fields[i].fieldName, query.fields[i].asString);
        TFieldType.ftBlob:
          responseRow.add(query.fields[i].fieldName, query.fields[i].asInteger);
      end;
    end;
    response.add(responseRow);
    query.Next;
  end;
  query.close();
  trans.endTransaction();
  result := response;
end;

function veryBadToLower(str: String): String;
const
  convLowers: Array [0..87] of String = ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u',
      'v', 'w', 'x', 'y', 'z', 'à', 'á', 'â', 'ã', 'ä', 'å', 'æ', 'ç', 'è', 'é', 'ê', 'ë', 'ì', 'í', 'î', 'ï',
      'ð', 'ñ', 'ò', 'ó', 'ô', 'õ', 'ö', 'ø', 'ù', 'ú', 'û', 'ü', 'ý', 'а', 'б', 'в', 'г', 'д', 'е', 'ё', 'ж',
      'з', 'и', 'й', 'к', 'л', 'м', 'н', 'о', 'п', 'р', 'с', 'т', 'у', 'ф', 'х', 'ц', 'ч', 'ш', 'щ', 'ъ', 'ы',
      'ь', 'э', 'ю', 'я');
  convUppers: Array [0..87] of String = ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U',
      'V', 'W', 'X', 'Y', 'Z', 'À', 'Á', 'Â', 'Ã', 'Ä', 'Å', 'Æ', 'Ç', 'È', 'É', 'Ê', 'Ë', 'Ì', 'Í', 'Î', 'Ï',
      'Ð', 'Ñ', 'Ò', 'Ó', 'Ô', 'Õ', 'Ö', 'Ø', 'Ù', 'Ú', 'Û', 'Ü', 'Ý', 'А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ё', 'Ж',
      'З', 'И', 'Й', 'К', 'Л', 'М', 'Н', 'О', 'П', 'Р', 'С', 'Т', 'У', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Щ', 'Ъ', 'Ъ',
      'Ь', 'Э', 'Ю', 'Я');
var
  i: Integer;
begin
  result := str;
  for i := 0 to 87 do
    result := stringReplace(result, convUppers[i], convLowers[i], [rfReplaceAll]);
end;

procedure dbExecIn(queryString: String);
begin
  trans.startTransaction();
  conn.executeDirect(queryString);
  trans.commit();
  trans.endTransaction();
end;

function mc_add(dict: TJSONObject;text: string): TJSONObject;
var
  key: integer;
  text_split: TStringArray;
  jsonarr: TJSONArray;
begin
  text := 'START '+veryBadToLower(text)+' END';

  text := ReplaceStr(text,'.','');
  text := ReplaceStr(text,',','');

  text_split := text.split([' ']);
  for key:=0 to Length(text_split)-1 do
  begin
    if dict.IndexOfName(text_split[key]) = -1 then
    begin
      jsonarr := TJSONArray.Create;
      jsonarr.Add(text_split[key+1]);
      dict.Add(text_split[key],jsonarr);
    end
    else
    begin
      dict.Arrays[text_split[key]].Add(text_split[key+1]);
    end;
  end;
  mc_add := dict;
end;

function mc_gen(dict: TJSONObject): string;
var
  output, word: string;
begin
  word := dict.Arrays['START'].Strings[cuterandom(0,dict.Arrays['START'].Count-1)];
  output += word+' ';
  while true do
  begin
    word := dict.Arrays[word].Strings[cuterandom(0,dict.Arrays[word].Count-1)];
    if word = 'END' then break;
    output += word+' ';
  end;
  mc_gen := output;
end;

function iscommand(cmd,text: string): Boolean;
begin
  if (pos('/'+cmd,text) <> 0) or (pos('!'+cmd,text) <> 0) then
  begin
    iscommand := true;
    exit;
  end;
  iscommand := false;
end;

begin
  conn := TSQLite3Connection.create(nil);
  conn.databaseName := './db';
  trans := TSQLTransaction.create(nil);
  conn.transaction := trans;
  query := TSQLQuery.create(nil);
  query.database := conn;
end.

