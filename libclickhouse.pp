unit libclickhouse;
{-----------------------------------------------------------------------------------------------------------------------
    ClickHouse HTTP Client Library for Free Pascal (Lazarus, Delphi)
    Copyright (c) 2025 by Andrew Rachuk, <Interdnestrcom>

    Version 25.10.24

    Features:
       - Execution of SQL queries via ClickHouse HTTP API
       - Support for various data formats (JSON, JSONCompact, CSV, TSV + WithNames variants)
       - Connection and timeout management
       - Error handling

       - Batch data insertion - (in development)
       - Protection against SQL injections - (to be reviewed!)

   Requirements:
       - Synapse (httpsend, synautil)
       - ClickHouse server with an open HTTP port (default 8123)

   Note:
       - The library is not thread-safe!
         Use a separate instance of TClickHouseConnection for each thread or 
         synchronize access externally (for example, via mutexes).
-----------------------------------------------------------------------------------------------------------------------}
interface
{----------------------------------------------------------------------------------------------------------------------}
uses
        classes, sysutils, variants,
        httpsend, synautil,
        fpjson, jsonparser;
{----------------------------------------------------------------------------------------------------------------------}
const
        C_DEF_CLICKHOUSE_PORT   = 8123;

        C_DEFAULT_TIMEOUT       = 5000; { 5 секунд }
{----------------------------------------------------------------------------------------------------------------------}
type
        {---- ClickHouse data formats ----}
        TClickHouseFormat = (
            chfJSON,            { JSON формат }
            chfJSONCompact,     { Компактный JSON }
            chfCSV,             { CSV формат }
            chfTSV,             { Tab-separated values }
            chfTabSeparated,    { То же, что и TSV }
            chfValues,          { Для INSERT запросов }
            chfPretty,          { "Красивый" вывод таблицы }
            chfVertical,        { Вертикальный формат }
            chfNative,          { Нативный бинарный формат }
            chfScalar           { Одиночный результат - ответ }
        );

        {---- Request results ----}
        TClickHouseResult = class
        private
            FFormat: TClickHouseFormat;

            FColumns: TStringList;
            FRows: TList;

            frowCount: longint;

            FRawData,
            FError: string;

            fSuccess,
            fWithNames: boolean;

            procedure ParseJSON();
            procedure ParseCSV();
            procedure ParseTSV();
            procedure ParseScalar();

        public
            constructor Create(AFormat: TClickHouseFormat = chfTSV; aWithNames: boolean = true);
            destructor Destroy(); override;

            function GetValueByName(ARow: longint; const AColumnName: string): string;
            function GetValue(ARow, ACol: longint): string;

            function ToJSON(): TJSONObject;
            function ToStringList(): TStringList;

            procedure Clear;

            property RAWDATA: string read FRawData;
            property ERROR: string read FError;
            property Format: TClickHouseFormat read FFormat;
            property RowCount: longint read frowCount;
            property Columns: TStringList read FColumns;
            property Success: boolean read fSuccess;
            property WithNames: boolean read fWithNames;
        end;

        {---- Main ClickHouse class ----}
        TClickHouseConnection = class
        private
            FHost,
            FDatabase,
            FUsername,
            FPassword,
            FBaseURL,
            FLastError: string;

            fport,
            ftimeout,
            fresultCode: longint;

            FConnected: boolean;

            fhttp: THTTPSend;

            procedure set_fhost(const FH: string);
            procedure set_fport(fp: longint);

            function GetBaseURL(): string;

            function ExecuteHTTP(const AMethod, AURL, AData, SFormat: string): string;

            function FormatToString(AFormat: TClickHouseFormat): string;

            function EscapeString(const AStr: string): string;
            function EscapeIdentifier(const AStr: string): string;

        public
            constructor Create(const FH: string = 'localhost'; fp: longint = C_DEF_CLICKHOUSE_PORT);
            destructor  Destroy(); override;

            function  Connect(): boolean;
            procedure Disconnect();

            function Ping(): boolean;
            function QuoteString(const AStr: string): string;

            {---- ExecSql: Performs a query and stores result in VResult. NB! Caller must provide a valid VResult (not nil) ----}
            function ExecSql(const AQuery: string; var VResult: TClickHouseResult): boolean;

            function ExecScalar(const AQuery: string): string;
            function ExecNonQuery(const AQuery: string): boolean;

            function Insert(const ATable: string; const AValues: array of string): boolean;
            function InsertSafe(const ATable: string; const AColumns: array of string; const AValues: array of variant): boolean;

            function CreateTable(const ATable, AStructure, AEngine: string; AAutoPrimaryKey: boolean; const AIndexes: array of string): boolean;
            function DropTable(const ATable: string; AIfExists: boolean = true): boolean;
            function TableExists(const ATable: string): boolean;

            {---- GetTables: Stores table names in ATables. NB! Caller must provide a valid ATables (not nil) ----}
            function GetTables(var ATables: TStringList): boolean;

            {---- GetDatabases: Stores database names in ADBs. NB! Caller must provide a valid ADBs (not nil) ----}
            function GetDatabases(var VDBs: TStringList): boolean;

            {---- GetTableStructure: Stores table structure in AStructure. Caller must provide a valid AStructure (not nil) ----}
            function GetTableStructure(const ATable: string; var VStructure: TStringList): boolean;

            function GetServerVersion(): string;
            function GetCurrentDatabase(): string;

            property Host: string read FHost write set_fhost;
            property port: longint read fport write set_fport;

            property BaseURL: string read FBaseURL;

            property Database: string read FDatabase write FDatabase;
            property Username: string read FUsername write FUsername;
            property Password: string read FPassword write FPassword;

            property LastError: string read FLastError;
            property resultCode: longint read FResultCode;

            property timeout: longint read FTimeout write FTimeout;

            property Connected: boolean read FConnected;

        end;

        {---- Additional Class for building requests ----}
        TClickHouseQueryBuilder = class
        private
            FSelect,
            FWhere,
            FGroupBy,
            FOrderBy: TStringList;

            FFrom: string;

            FLimit,
            FOffset: longint;

        public
            constructor Create();
            destructor  Destroy(); override;

            function Select(const AColumns: array of string): TClickHouseQueryBuilder;
            function From(const ATable: string): TClickHouseQueryBuilder;
            function Where(const ACondition: string): TClickHouseQueryBuilder;
            function WhereAnd(const ACondition: string): TClickHouseQueryBuilder;
            function WhereOr(const ACondition: string): TClickHouseQueryBuilder;
            function GroupBy(const AColumns: array of string): TClickHouseQueryBuilder;
            function OrderBy(const AColumn: string; ADesc: boolean = false): TClickHouseQueryBuilder;
            function Limit(ALimit: longint): TClickHouseQueryBuilder;
            function Offset(AOffset: longint): TClickHouseQueryBuilder;
            function Build(): string;

            procedure Clear();
        end;
{----------------------------------------------------------------------------------------------------------------------}

implementation
{----------------------------------------------------------------------------------------------------------------------}
constructor TClickHouseResult.Create(AFormat: TClickHouseFormat = chfTSV; aWithNames: boolean = true);
begin
        inherited Create();

        FRawData := '';
        FError := '';

        FFormat := AFormat;
        fWithNames := aWithNames;

        frowCount := 0;
    try
        FColumns := TStringList.Create();
        FRows := TList.Create();

        fSuccess := true;

    except
        on e: Exception do
        begin
            fSuccess := false;
            FError := e.Message;
        end;
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor TClickHouseResult.Destroy();
var
        Row: TStringList = nil;
        i: longint;
begin
        for i := 0 to (FRows.Count-1) do
        begin
            Row := TStringList(FRows[i]);
            FreeAndNil(Row);
        end;

        FreeAndNil(FRows);
        FreeAndNil(FColumns);

        FRawData := '';

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseResult.ParseJSON();
var
        JSONData: TJSONData = nil;
        JSONObj, MetaObj: TJSONObject;
        JSONArray, RowArray: TJSONArray;
        Row: TStringList;
        i, j: longint;
begin
        if (FRawData = '') then
        begin
            fSuccess := false;
            FError := 'Empty JSON data';
            exit();
        end;
    try
        JSONData := GetJSON(FRawData);

        if (JSONData = nil) then
        begin
            fSuccess := false;
            FError := 'Invalid JSON data: nil response from GetJSON';
            exit();
        end;

        if (JSONData is TJSONObject) then
        begin
            JSONObj := TJSONObject(JSONData);

            {---- Check for errors ----}
            if (JSONObj.IndexOfName('exception') >= 0) then
            begin
                fSuccess := false;
                FError := JSONObj.GetPath('exception').AsString;
                exit();
            end;

            {---- Get metadata (columns names) ----}
            if (JSONObj.IndexOfName('meta') >= 0) then
                if (JSONObj.GetPath('meta') is TJSONArray) then
                begin
                    JSONArray := TJSONArray(JSONObj.GetPath('meta'));

                    for i := 0 to (JSONArray.Count-1) do
                    begin
                        MetaObj := TJSONObject(JSONArray[i]);
                        FColumns.Add(MetaObj.GetPath('name').AsString);
                    end;
                end
                else
                begin
                    fSuccess := false;
                    FError := 'Invalid JSON: meta is not an array';
                    exit();
                end;

            {---- Get data ----}
            if (JSONObj.IndexOfName('data') >= 0) then
                if (JSONObj.GetPath('data') is TJSONArray) then
                begin
                    JSONArray := TJSONArray(JSONObj.GetPath('data'));
                    frowCount := JSONArray.Count;

                    for i := 0 to (JSONArray.Count-1) do
                    begin
                        Row := nil;

                        try
                            Row := TStringList.Create();

                            if (FFormat = chfJSON) then
                            begin
                                {---- Simple JSON - every row is an object ----}
                                JSONObj := TJSONObject(JSONArray[i]);

                                for j := 0 to (FColumns.Count-1) do
                                begin
                                    if (JSONObj.IndexOfName(FColumns[j]) >= 0) then
                                        Row.Add(JSONObj.GetPath(FColumns[j]).AsString)
                                    else
                                        Row.Add('');
                                end;
                            end
                            else
                            begin
                                {---- JSONCompact - every row is an array ----}
                                RowArray := TJSONArray(JSONArray[i]);

                                for j := 0 to (RowArray.Count-1) do
                                    Row.Add(RowArray[j].AsString);
                            end;

                            FRows.Add(Row);
                            Row := nil;

                        except
                            on e: Exception do
                            begin
                                if (Assigned(Row)) then
                                    FreeAndNil(Row);
                                raise;
                            end;
                        end;
                    end;
                end
                else
                begin
                    fSuccess := false;
                    FError := 'Invalid JSON: data is not an array';
                    exit();
                end;

            {---- Get rows count ----}
            if (JSONObj.IndexOfName('rows') >= 0) then
                frowCount := JSONObj.GetPath('rows').AsInteger;
        end
        else
        begin
            fSuccess := false;
            FError := 'Expected JSONObject, got ' + JSONData.ClassName;
        end;

    finally
        FreeAndNil(JSONData);
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseResult.ParseScalar();
var
        Row: TStringList = nil;
begin
        if (FRawData = '') then
        begin
            FSuccess := false;
            FError := 'Empty Scalar data';
            exit();
        end;

        Row := TStringList.Create();
        try
            Row.Add(Trim(FRawData));
            FRows.Add(Row);

            Row := nil; 

            FSuccess := true;
        finally
            FreeAndNil(Row); 
            FRowCount := FRows.count;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseResult.ParseCSV();
var
        Lines, Row: TStringList;
        i, s: longint;
begin
        if (FRawData = '') then
        begin
            FSuccess := false;
            FError := 'Empty CSV data';
            exit();
        end;

        Lines := TStringList.Create();
    try
        Lines.Text := FRawData;

        if (Lines.Count > 0) then
        begin
            {---- First row - headers (in ANY case!) ----}
            FColumns.CommaText := Lines[0];

            {---- Other rows - data ----}
            if (FWithNames) then
                s := 1
            else
            begin
                s := 0;

                for i := 0 to (FColumns.Count-1) do
                    FColumns[i] := 'Column' + intToStr(i);
            end;

            for i := s to (Lines.Count-1) do
                if (Trim(Lines[i]) <> '') then
                begin
                    Row := nil;
                    try
                        Row := TStringList.Create();

                        Row.CommaText := Lines[i];
                        FRows.Add(Row);

                    except
                        on e: Exception do
                        begin
                            if (Assigned(Row)) then
                                FreeAndNil(Row);
                            raise;
                        end;
                    end;
                end;
        end;

    finally
        FRowCount := FRows.count;

        FreeAndNil(Lines);
        Row := nil;
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseResult.ParseTSV();
var
        Lines, Row: TStringList;
        i, s: longint;
begin
        if (FRawData = '') then
        begin
            FSuccess := false;
            FError := 'Empty TSV data';
            exit();
        end;

        Lines := TStringList.Create();
    try
        Lines.Text := FRawData;

        if (Lines.Count > 0) then
        begin
            {---- First row - headers (in ANY case!) ----}
            FColumns.Delimiter := #9;
            FColumns.DelimitedText := Lines[0];

            {---- Other rows - data ----}
            if (FWithNames) then
                s := 1
            else
            begin
                s := 0;

                for i := 0 to (FColumns.Count-1) do
                    FColumns[i] := 'Column' + intToStr(i);
            end;

            for i := s to (Lines.Count-1) do
                if (Trim(Lines[i]) <> '') then
                begin
                    Row := nil;
                    try
                        Row := TStringList.Create();

                        Row.Delimiter := #9;
                        Row.DelimitedText := Lines[i];
                        FRows.Add(Row);

                    except
                        on e: Exception do
                        begin
                            if (Assigned(Row)) then
                                FreeAndNil(Row);
                            raise;
                        end;
                    end;
                end;
        end;

    finally
        FRowCount := FRows.count;

        FreeAndNil(Lines);
        Row := nil;
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseResult.GetValueByName(ARow: longint; const AColumnName: string): string;
var
        i: longint;
begin
        result := '';

        i := FColumns.IndexOf(AColumnName);

        if (i >= 0)and(ARow >= 0)and(ARow < FRows.Count) then
            result := GetValue(ARow, i);
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseResult.GetValue(ARow, ACol: longint): string;
begin
        result := '';

        if (ARow >= 0)and(ARow < FRows.Count)and(ACol >= 0) then
        try
            if (ACol < TStringList(FRows[ARow]).Count) then
                result := TStringList(FRows[ARow])[ACol];
        except
            result := '';
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseResult.ToJSON(): TJSONObject;
var
        JSONArray: TJSONArray;
        JSONRow: TJSONObject;
        Row: TStringList = nil;
        i, j: longint;
begin
    try
        result := TJSONObject.Create();

        try
            JSONArray := TJSONArray.Create();

            for i := 0 to (FRows.Count-1) do
            begin
                Row := TStringList(FRows[i]);
                JSONRow := TJSONObject.Create();

                try
                    for j := 0 to (FColumns.Count-1) do
                        if (j < Row.Count) then
                            JSONRow.Add(FColumns[j], Row[j])
                        else
                            JSONRow.Add(FColumns[j], '');

                    JSONArray.Add(JSONRow);

                except
                    FreeAndNil(JSONRow);
                    raise;
                end;
            end;

            result.Add('data', JSONArray);
            result.Add('rows', FRowCount);

        except
            FreeAndNil(JSONArray);
            raise;
        end;

    except
        FreeAndNil(result);
        raise;
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseResult.ToStringList(): TStringList;
var
        Row: TStringList = nil;
        LINE: string;
        i, j: longint;
begin
        result := TStringList.Create();
    try
        {---- Add headers ----}
        result.Add(FColumns.CommaText);

        {---- Add data ----}
        for i := 0 to (FRows.Count-1) do
        begin
            Row := TStringList(FRows[i]);
            LINE := '';

            for j := 0 to (Row.Count-1) do
            begin
                if (j > 0) then
                    LINE += ',';

                LINE += '"' + StringReplace(Row[j], '"', '""', [rfReplaceAll]) + '"';
            end;

            result.Add(LINE);
        end;

    except
        FreeAndNil(result);
        raise;
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseResult.Clear;
var
        Row: TStringList = nil;
        i: longint;
begin
        for i := 0 to (FRows.Count-1) do
        begin
            Row := TStringList(FRows[i]);
            FreeAndNil(Row);
        end;

        FRows.Clear();
        FColumns.Clear();

        FRawData := '';
        FError := '';

        FRowCount := 0;
        FSuccess := true;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
constructor TClickHouseConnection.Create(const FH: string = 'localhost'; fp: longint = C_DEF_CLICKHOUSE_PORT);
begin
        inherited Create();

        FHost := FH;
        FPort := fp;

        FBaseURL := GetBaseUrl();

        FDatabase := 'default';
        FUsername := 'default';
        FPassword := '';

        FLastError := '';

        FTimeout := C_DEFAULT_TIMEOUT;

        FConnected := false;

        fhttp := THTTPSend.Create();
        fhttp.Timeout := FTimeout;
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor TClickHouseConnection.Destroy();
begin
        Disconnect();

        FreeAndNil(fhttp);

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseConnection.set_fhost(const FH: string);
begin
        FHost := FH;
        FBaseURL := GetBaseUrl();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseConnection.set_fport(fp: longint);
begin
        FPort := fp;
        FBaseURL := GetBaseUrl();
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.GetBaseURL(): string;
begin
        Result := format('http://%s:%d/', [FHOST, FPort]);
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.FormatToString(AFormat: TClickHouseFormat): string;
begin
        case (AFormat) of
            chfJSON:
                Result := 'JSON';
            //----
            chfJSONCompact:
                Result := 'JSONCompact';
            //----
            chfCSV:
                Result := 'CSV';
            //----
            chfTSV:
                Result := 'TSV';
            //----
            chfTabSeparated:
                Result := 'TabSeparated';
            //----
            chfValues:
                Result := 'Values';
            //----
            chfPretty:
                Result := 'Pretty';
            //----
            chfVertical:
                Result := 'Vertical';
            //----
            chfNative:
                Result := 'Native';
            //----
            chfScalar:
                Result := 'Scalar';
            else
                Result := 'JSON';
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.EscapeString(const AStr: string): string;
var
        P: PChar;
        i: longint;
begin
        Result := '';

        SetLength(Result, (length(AStr) * 2)); { Максимум удвоение длины - пока так }
        P := PChar(Result);

        for i := 1 to length(AStr) do
        begin
            case (AStr[i]) of
                '\':
                begin
                    P^ := '\'; Inc(P);
                    P^ := '\'; Inc(P);
                end;
                //----
                '''':
                begin
                    P^ := ''''; Inc(P);
                    P^ := ''''; Inc(P);
                end;
                //----
                #0:
                begin
                    P^ := '\'; Inc(P);
                    P^ := '0'; Inc(P);
                end;
                //----
                #8:
                begin
                    P^ := '\'; Inc(P);
                    P^ := 'b'; Inc(P);
                end;
                //----
                #9:
                begin
                    P^ := '\'; Inc(P);
                    P^ := 't'; Inc(P);
                end;
                //----
                #10:
                begin
                    P^ := '\'; Inc(P);
                    P^ := 'n'; Inc(P);
                end;
                //----
                #13:
                begin
                    P^ := '\'; Inc(P);
                    P^ := 'r'; Inc(P);
                end;
                //----
                else
                    P^ := AStr[i]; Inc(P);
            end;
        end;

        SetLength(Result, (P - PChar(Result)));
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.QuoteString(const AStr: string): string;
begin
        Result := '''' + EscapeString(AStr) + '''';
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.EscapeIdentifier(const AStr: string): string;
var
        P: PChar;
        i: longint;
        NeedsQuoting: boolean;
begin
        if (length(AStr) = 0) then
        begin
            Result := '``';
            exit();
        end;

        NeedsQuoting := (not (AStr[1] in ['a'..'z', 'A'..'Z', '_']));

        if (not NeedsQuoting) then
            for i := 2 to Length(AStr) do
                if (not (AStr[i] in ['a'..'z', 'A'..'Z', '0'..'9', '_'])) then
                begin
                    NeedsQuoting := true;
                    break;
                end;

        if (NeedsQuoting) then
        begin
            SetLength(Result, Length(AStr) * 2 + 2);

            P := PChar(Result);
            P^ := '`'; Inc(P);

            for i := 1 to Length(AStr) do
                if (AStr[i] = '`') then
                begin
                    P^ := '`'; Inc(P);
                    P^ := '`'; Inc(P);
                end
                else
                begin
                    P^ := AStr[i]; Inc(P);
                end;

            P^ := '`'; Inc(P);

            SetLength(Result, P - PChar(Result));
        end
        else
            Result := AStr;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.ExecuteHTTP(const AMethod, AURL, AData, SFormat: string): string;
var
        buf: array of byte = ();
        i: longint = 0;
        fRes: boolean;
begin
        result := '';
        FLastError := '';

        fhttp.Clear();
        fhttp.Headers.Clear();
        fhttp.Timeout := FTimeout;

        fhttp.MimeType := 'text/plain; charset=UTF-8';

        if (FUsername <> '') then
            fhttp.Headers.Add('X-ClickHouse-User: ' + FUsername);

        if (FPassword <> '') then
            fhttp.Headers.Add('X-ClickHouse-Key: ' + FPassword);

        if (AData <> '') then
        begin
            fhttp.Document.Clear();
            fhttp.Document.Write(pAnsiChar(AData)^, length(AData));
        end;

        fhttp.Headers.Add('X-ClickHouse-Format: ' + SFormat);

{$IFDEF DEBUG}
        writeln('.executeHTTP(send): BODY: ', AData);
{$ENDIF}

    try
        if (AMethod = 'POST') then
            fRes := fhttp.HTTPMethod('POST', AURL)
        else
            fRes := fhttp.HTTPMethod('GET', AURL);

        FResultCode := fhttp.resultCode;

{$IFDEF DEBUG}
        writeln('.ExecuteHTTP(recv): Headers:');
        for i := 0 to (fhttp.Headers.Count-1) do
            writeln(fhttp.Headers[i]);

        writeln();
        writeln('.executeHTTP(recv): resultCode: ', FResultCode);
{$ENDIF}

    except
        on e: exception do
        begin
            fRes := false;
            FLastError := format('HTTP Request failed: %s', [e.Message]);
        end;
    end;

        if (fRes) then
        begin
            if (fhttp.Document.Size > 0) then
                begin
                    SetLength(Result, fhttp.Document.Size);
                    fhttp.Document.Read(Result[1], Length(Result));
                end;

            FLastError := format('HTTP %d BODY: %s', [fhttp.resultCode, Result]);
        end
        else
        begin
            if (fhttp.Document.Size > 0) then
            begin
                SetLength(buf, fhttp.Document.Size);
                fhttp.Document.Read(buf[0], fhttp.Document.Size);

                result := TEncoding.UTF8.GetString(buf);

                FLastError := format('HTTP Error %d: %s', [fhttp.resultCode, result]);
            end
            else
                FLastError := format('HTTP Error %d: No response', [fhttp.resultCode]);

            Result := '';
        end;
{$IFDEF DEBUG}
        writeln('.executeHTTP: Result: ', Result);
{$ENDIF}
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.Connect(): boolean;
begin
        FConnected := Ping();

        result := FConnected;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseConnection.Disconnect();
begin
        FConnected := false;

        if (Assigned(fhttp)) then
            fhttp.Document.Clear();
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.Ping(): boolean;
var
        RESPONSE: string;
begin
        RESPONSE := ExecuteHTTP('GET', FBaseURL + 'ping', '', 'TabSeparated');

        result := (Pos('Ok', RESPONSE) > 0);

        if (not result) then
            FLastError := 'Cannot connect to ClickHouse server!';
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.ExecSql(const AQuery: string; var VResult: TClickHouseResult): boolean;
var
        RESPONSE, SFORMAT: string;
begin
        result := false;

        if (Trim(AQuery) = '') then
        begin
            FLastError := 'ExecSql: Empty query';
            exit();
        end;

        if (VResult = nil) then
        begin
            FLastError := 'ExecSql: VResult is nil';
            exit();
        end;

        if not (VResult.Format in [chfJSON, chfJSONCompact, chfCSV]) then
            SFORMAT := FormatToString(chfTabSeparated)
        else
            SFORMAT := FormatToString(VResult.Format);

        if (VResult.FWithNames) then
            SFORMAT += 'WithNames';

        RESPONSE := ExecuteHTTP('POST', FBaseURL, AQuery, SFORMAT);
    try
        VResult.Clear();

        VResult.FRawData := RESPONSE;

        case (VResult.Format) of
            chfJSON,
            chfJSONCompact:
                VResult.ParseJSON();
            //----
            chfCSV:
                VResult.ParseCSV();
            //----
            chfTSV,
            chfTabSeparated:
                VResult.ParseTSV();
            //----
            chfScalar:
                VResult.ParseScalar();
        end;

        result := (VResult.Success);

        if (not result) then
            FLastError := VResult.ERROR;

    except
        on e: Exception do
        begin
            result := false;
            FLastError := 'ExecSql: Failed to process result: ' + e.message;
        end;
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.ExecScalar(const AQuery: string): string;
var
        Res: TClickHouseResult = nil;
begin
        result := '';

        if (AQuery = '') then
        begin
            FLastError := 'ExecScalar: Empty query';
            exit();
        end;

        Res := TClickHouseResult.Create(chfScalar, false);
    try
        if (ExecSql(AQuery, Res))and(Res.RowCount > 0) then
            result := Res.GetValue(0, 0);
    finally
        FreeAndNil(Res);
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.ExecNonQuery(const AQuery: string): boolean;
var
        RESPONSE: string;
begin
        result := false;

        if (AQuery = '') then
        begin
            FLastError := 'ExecNonQuery: Empty query';
            exit();
        end;

        RESPONSE := ExecuteHTTP('POST', FBaseURL, AQuery, 'TabSeparated');

        result := (fhttp.resultCode = 200);

        if (not result) then
            FLastError := RESPONSE;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.Insert(const ATable: string; const AValues: array of string): boolean;
var
        VALUES: string;
        i: longint;
begin
        result := false;

        if (ATable = '') then
        begin
            FLastError := 'Insert: Empty table name';
            exit();
        end;

        VALUES := '';

        for i := Low(AValues) to High(AValues) do
        begin
            if (i > Low(AValues)) then
                VALUES += ', ';

            VALUES += AValues[i];
        end;

        result := ExecNonQuery(format('INSERT INTO %s VALUES (%s)', [ATable, VALUES]));
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.InsertSafe(const ATable: string; const AColumns: array of string; const AValues: array of variant): boolean;
var
        COLUMNS, VALUES: string;
        SB: TStringBuilder;
        i: longint;
begin
        result := false;

        if (ATable = '') then
        begin
            FLastError := 'InsertSafe: Empty table name';
            exit();
        end;

        if (High(AColumns) <> High(AValues)) then
        begin
            FLastError := 'InsertSafe: Columns and values count mismatch';
            exit();
        end;

        SB := TStringBuilder.Create();
    try
        for i := Low(AColumns) to High(AColumns) do
        begin
            if (i > Low(AColumns)) then
                SB.Append(', ');

            SB.Append(EscapeIdentifier(AColumns[i]));
        end;
        COLUMNS := SB.ToString();

        SB.Clear();
        for i := Low(AValues) to High(AValues) do
        begin
            if (i > Low(AValues)) then
                SB.Append(', ');

            case (VarType(AValues[i])) of
                varString,
                varUString,
                varOleStr:
                    SB.Append(QuoteString(VarToStr(AValues[i])));
                //----
                varNull:
                    SB.Append('NULL');
                //----
                varBoolean:
                    if (AValues[i]) then
                        SB.Append('1')
                    else
                        SB.Append('0');
                //----
                varDouble,
                varCurrency:
                    SB.Append(StringReplace(FloatToStr(AValues[i]), ',', '.', [rfReplaceAll]));
                //----
                varDate:
                    SB.Append(QuoteString(FormatDateTime('yyyy-mm-dd hh:nn:ss', AValues[i])));
                //----
                else
                    SB.Append(VarToStr(AValues[i]));
            end;
        end;
        VALUES := SB.ToString();

        result := ExecNonQuery(format('INSERT INTO %s (%s) VALUES (%s)', [ATable, COLUMNS, VALUES]));

    finally
        FreeAndNil(SB);
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.CreateTable(const ATable, AStructure, AEngine: string; AAutoPrimaryKey: boolean; const AIndexes: array of string): boolean;
var
        QUERY, INDEX_CLAUSE,
        PRIMARY_KEY_CLAUSE, FIRST_COLUMN: string;
        I: longint;
begin
        result := false;

        if (ATable = '') then
        begin
            FLastError := 'CreateTable: Empty table name';
            exit();
        end;

        if (AStructure = '') then
        begin
            FLastError := 'CreateTable: Empty structure';
            exit();
        end;

        if (AEngine = '') then
        begin
            FLastError := 'CreateTable: Empty engine';
            exit();
        end;

        INDEX_CLAUSE := '';
        if (Length(AIndexes) > 0) then
            for I := 0 to (Length(AIndexes)-1) do
                if (AIndexes[I] <> '') then
                begin
                    if (INDEX_CLAUSE <> '') then
                        INDEX_CLAUSE += ', ';
                    INDEX_CLAUSE += AIndexes[I];
                end;

        PRIMARY_KEY_CLAUSE := '';
        if (AAutoPrimaryKey) then
        begin
            if (Pos(',', AStructure) > 0) then
                FIRST_COLUMN := Copy(AStructure, 1, Pos(',', AStructure) - 1)
            else
                FIRST_COLUMN := AStructure; { Только одна колонка }

            FIRST_COLUMN := Trim(FIRST_COLUMN);

            if (Pos(' ', FIRST_COLUMN) > 0) then
                FIRST_COLUMN := Copy(FIRST_COLUMN, 1, Pos(' ', FIRST_COLUMN) - 1)
            else
                FIRST_COLUMN := ''; { Нет пробела = некорректная структура }

            if (FIRST_COLUMN <> '') then
            begin
                if (INDEX_CLAUSE <> '') then
                    INDEX_CLAUSE += ', ';

                PRIMARY_KEY_CLAUSE := format('PRIMARY KEY (%s)', [FIRST_COLUMN]);
            end;
        end;

        if (INDEX_CLAUSE <> '')or(PRIMARY_KEY_CLAUSE <> '') then
            QUERY := format('CREATE TABLE %s (%s, %s%s) ENGINE = %s;', [ATable, AStructure, INDEX_CLAUSE, PRIMARY_KEY_CLAUSE, AEngine])
        else
            QUERY := format('CREATE TABLE %s (%s) ENGINE = %s;', [ATable, AStructure, AEngine]);

        result := ExecNonQuery(QUERY);
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.DropTable(const ATable: string; AIfExists: boolean = true): boolean;
begin
        result := false;

        if (ATable = '') then
        begin
            FLastError := 'DropTable: Empty table name';
            exit();
        end;

        if (AIfExists) then
            result := ExecNonQuery(format('DROP TABLE IF EXISTS %s', [ATable]))
        else
            result := ExecNonQuery(format('DROP TABLE %s', [ATable]));
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.TableExists(const ATable: string): boolean;
begin
        result := false;

        if (ATable = '') then
        begin
            FLastError := 'TableExists: Empty table name';
            exit();
        end;

        result := (ExecScalar(format('EXISTS TABLE %s', [ATable])) = '1');
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.GetTables(var ATables: TStringList): boolean;
var
        Res: TClickHouseResult;
        i: longint;
begin
        result := false;

        if (ATables = nil) then
        begin
            FLastError := 'GetTables: ATables is nil';
            exit();
        end;

        ATables.Clear();

        Res := TClickHouseResult.Create();
    try
        if (ExecSql('SHOW TABLES', Res)) then
        begin
            for i := 0 to (Res.RowCount-1) do
                ATables.Add(Res.GetValue(i, 0));

            result := Res.Success;
        end
        else
            FLastError := Res.ERROR;
    finally
        FreeAndNil(Res);
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.GetDatabases(var VDBs: TStringList): boolean;
var
        Res: TClickHouseResult;
        i: longint;
begin
        result := false;

        if (VDBs = nil) then
        begin
            FLastError := 'GetDatabases: ADBs is nil';
            exit();
        end;

        VDBs.Clear();
        Res := TClickHouseResult.Create();
    try
        if (ExecSql('SHOW DATABASES', Res)) then
        begin
            for i := 0 to (Res.RowCount-1) do
                VDBs.Add(Res.GetValue(i, 0));

            result := Res.Success;
        end
        else
            FLastError := Res.ERROR;
    finally
        FreeAndNil(Res);
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.GetTableStructure(const ATable: string; var VStructure: TStringList): boolean;
var
        Res: TClickHouseResult;
        i: longint;
begin
        result := false;

        if (ATable = '') then
        begin
            FLastError := 'GetTableStructure: Empty table name';
            exit();
        end;

        if (VStructure = nil) then
        begin
            FLastError := 'GetTableStructure: AStructure is nil';
            exit();
        end;
        VStructure.Clear();

        Res := TClickHouseResult.Create();
    try
        if (ExecSql(format('DESCRIBE TABLE %s', [ATable]), Res)) then
        begin
            if (Res.Columns.Count >= 2) then
            begin
                for i := 0 to (Res.RowCount-1) do
                    VStructure.Add(format('%s %s', [Res.GetValue(i, 0), Res.GetValue(i, 1)]));

                result := Res.Success;
            end
            else
                FLastError := 'GetTableStructure: Unexpected table format';
        end
        else
            FLastError := Res.ERROR;
    finally
        FreeAndNil(Res);
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.GetServerVersion(): string;
begin
        result := ExecScalar('SELECT version()');
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseConnection.GetCurrentDatabase(): string;
begin
        result := ExecScalar('SELECT currentDatabase()');
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
constructor TClickHouseQueryBuilder.Create();
begin
        inherited Create();

        FSelect := TStringList.Create();
        FWhere := TStringList.Create();
        FGroupBy := TStringList.Create();
        FOrderBy := TStringList.Create();

        FLimit := 0;
        FOffset := 0;
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor TClickHouseQueryBuilder.Destroy();
begin
        FreeAndNil(FSelect);
        FreeAndNil(FWhere);
        FreeAndNil(FGroupBy);
        FreeAndNil(FOrderBy);

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.Select(const AColumns: array of string): TClickHouseQueryBuilder;
var
        i: longint;
begin
        for i := Low(AColumns) to High(AColumns) do
            FSelect.Add(AColumns[i]);

        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.From(const ATable: string): TClickHouseQueryBuilder;
begin
        FFrom := ATable;
        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.Where(const ACondition: string): TClickHouseQueryBuilder;
begin
        FWhere.Clear();
        FWhere.Add(ACondition);

        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.WhereAnd(const ACondition: string): TClickHouseQueryBuilder;
begin
        if (FWhere.Count > 0) then
            FWhere.Add('AND ' + ACondition)
        else
            FWhere.Add(ACondition);

        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.WhereOr(const ACondition: string): TClickHouseQueryBuilder;
begin
        if (FWhere.Count > 0) then
            FWhere.Add('OR ' + ACondition)
        else
            FWhere.Add(ACondition);

        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.GroupBy(const AColumns: array of string): TClickHouseQueryBuilder;
var
        i: longint;
begin
        for i := Low(AColumns) to High(AColumns) do
            FGroupBy.Add(AColumns[i]);

        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.OrderBy(const AColumn: string; ADesc: boolean): TClickHouseQueryBuilder;
begin
        if (ADesc) then
            FOrderBy.Add(AColumn + ' DESC')
        else
            FOrderBy.Add(AColumn + ' ASC');

        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.Limit(ALimit: longint): TClickHouseQueryBuilder;
begin
        FLimit := ALimit;
        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.Offset(AOffset: longint): TClickHouseQueryBuilder;
begin
        FOffset := AOffset;
        result := self;
end;
{----------------------------------------------------------------------------------------------------------------------}
function TClickHouseQueryBuilder.Build(): string;
var
        i: longint;
begin
        result := '';

        {---- SELECT ----}
        if (FSelect.Count > 0) then
        begin
            result := 'SELECT ';

            for i := 0 to (FSelect.Count-1) do
            begin
                if (i > 0) then
                    result += ', ';

                result += FSelect[i];
            end;
        end
        else
            result := 'SELECT *';

        {---- FROM ----}
        if (FFrom <> '') then
            result += ' FROM ' + FFrom;

        {---- WHERE ----}
        if (FWhere.Count > 0) then
        begin
            result += ' WHERE ';

            for i := 0 to (FWhere.Count-1) do
            begin
                if (i > 0) then
                    result += ' ';

                result += FWhere[i];
            end;
        end;

        {---- GROUP BY ----}
        if (FGroupBy.Count > 0) then
        begin
            result += ' GROUP BY ';

            for i := 0 to (FGroupBy.Count-1) do
            begin
                if (i > 0) then
                    result += ', ';

                result += FGroupBy[i];
            end;
        end;

        {---- ORDER BY ----}
        if (FOrderBy.Count > 0) then
        begin
            result += ' ORDER BY ';

            for i := 0 to (FOrderBy.Count-1) do
            begin
                if (i > 0) then
                    result += ', ';

                result += FOrderBy[i];
            end;
        end;

        {---- LIMIT ----}
        if (FLimit > 0) then
        begin
            result += ' LIMIT ' + IntToStr(FLimit);

            if (FOffset > 0) then
                result += ' OFFSET ' + IntToStr(FOffset);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure TClickHouseQueryBuilder.Clear();
begin
        FFrom := '';

        FSelect.Clear();
        FWhere.Clear();
        FGroupBy.Clear();
        FOrderBy.Clear();

        FLimit := 0;
        FOffset := 0;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
