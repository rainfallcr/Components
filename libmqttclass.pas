{
    MQTT Client Library for Free Pascal (Lazarus, Delphi)

    Copyright (c) 2018-2019 Karoly Balogh <charlie@amigaspirit.hu>
    Copyright (c) 2025 Andrew Rachuk <Interdnestrcom>

    Version 2.2

    Возможности:
        - Подключение к MQTT брокеру (TCP/SSL)
        - Публикация сообщений с QoS
        - Подписка/отписка от топиков
        - Обработка событий (сообщения, подключение, отключение)
        - Thread-safe колбэки
        - Поддержка Last Will
        - Поддержка MQTT 3.1, 3.1.1, 5.0
        - Полная поддержка TLS (client certificates)

    Требования:
        - Mosquitto library (libmosquitto.so/dll)
        - Free Pascal с модулями classes, ctypes, sysutils, syncobjs

    Примечание:
        Библиотека thread-safe (защищены мьютексом) для колбэков, методов Connect/Disconnect/Publish/Subscribe
        т.е. можно безопасно использовать один экземпляр из разных потоков!
}
{$MODE OBJFPC}
{$H+}
unit libmqttclass;
{---------------------------------------------------------------------------------------------------------------------}
interface
{---------------------------------------------------------------------------------------------------------------------}
uses
        Classes, Ctypes, sysUtils, syncobjs,
        libmosquitto;
{---------------------------------------------------------------------------------------------------------------------}
function mqtt_init(verbose: boolean = true): boolean;
function mqtt_loglevel_to_str(const loglevel: cint): string;
{---------------------------------------------------------------------------------------------------------------------}
type
        TMQTTOnConnectEvent     = procedure(const rc: cint) of object;
        TMQTTOnDisconnectEvent  = procedure(const rc: cint) of object;

        TMQTTOnMessageEvent     = procedure(const payload: Pmosquitto_message) of object;
        TMQTTOnPublishEvent     = procedure(const mid: cint) of object;

        TMQTTOnSubscribeEvent   = procedure(mid: cint; qos_count: cint; const granted_qos: pcint) of object;
        TMQTTOnUnsubscribeEvent = procedure(mid: cint) of object;

        TMQTTOnLogEvent         = procedure(const level: cint; const str: string) of object;

        TMQTTConnectionState = (
            st_None,
            st_Connecting,
            st_Connected,
            st_ReConnecting,
            st_Disconnected
        );

        TMQTTConfig = record
            Ssl_cacertfile,
            Ssl_capath,
            Ssl_certfile,
            Ssl_keyfile,
            Ssl_keyfile_pw,

            Username,
            Password,

            Client_id,
            Will_topic,
            Will_payload,

            Hostname: string;
            port: word;

            keepalives,
            reconnect_delay,
            reconnect_delay_max: longint;

            protocol_version,
            will_qos: cint;

            ssl,
            ssl_verify_peer,
            will_retain,
            reconnect_backoff: boolean;
        end;

        TMQTTConnection = class
        private
            FName,
            FLastError: string;

            FOnMessage: TMQTTOnMessageEvent;
            FOnPublish: TMQTTOnPublishEvent;
            FOnSubscribe: TMQTTOnSubscribeEvent;
            FOnUnsubscribe: TMQTTOnUnsubscribeEvent;
            FOnConnect: TMQTTOnConnectEvent;
            FOnDisconnect: TMQTTOnDisconnectEvent;
            FOnLog: TMQTTOnLogEvent;

            FConfig: TMQTTConfig;
            FState: TMQTTConnectionState;

            FMosq: Pmosquitto;

            FMutex: TCriticalSection;

            function  GetState: TMQTTConnectionState;
            procedure SetState(const state: TMQTTConnectionState);

        public
            constructor Create(const Name: string);
            destructor  Destroy; override;

            function Connect: boolean;
            function Disconnect: boolean;
            function ReConnect: boolean;

            function Publish(const Topic, Payload: string; qos: cint = 0; retain: cbool = false): cint;
            function Subscribe(const Topic: string; qos: cint = 0): cint;
            function Unsubscribe(const Topic: string): cint;

            property Name: string read FName;

            property state: TMQTTConnectionState read GetState;
            property config: TMQTTConfig read FConfig write FConfig;

            property Hostname: string read FConfig.Hostname write FConfig.Hostname;
            property port: word read FConfig.port write FConfig.port;
            property Username: string read FConfig.Username write FConfig.Username;
            property Password: string read FConfig.Password write FConfig.Password;

            property OnMessage: TMQTTOnMessageEvent read FOnMessage write FOnMessage;
            property OnPublish: TMQTTOnPublishEvent read FOnPublish write FOnPublish;
            property OnSubscribe: TMQTTOnSubscribeEvent read FOnSubscribe write FOnSubscribe;
            property OnUnsubscribe: TMQTTOnUnsubscribeEvent read FOnUnsubscribe write FOnUnsubscribe;
            property OnConnect: TMQTTOnConnectEvent read FOnConnect write FOnConnect;
            property OnDisconnect: TMQTTOnDisconnectEvent read FOnDisconnect write FOnDisconnect;
            property OnLog: TMQTTOnLogEvent read FOnLog write FOnLog;

            property LastError: string read FLastError;
        end;
{---------------------------------------------------------------------------------------------------------------------}
{---------------------------------------------------------------------------------------------------------------------}
implementation
{---------------------------------------------------------------------------------------------------------------------}
var
        libInited: boolean;
{---------------------------------------------------------------------------------------------------------------------}
procedure mqtt_on_message(mosq: Pmosquitto; obj: pointer; const message: Pmosquitto_message); cdecl;
var
        mqtt: TMQTTConnection;
begin
        if (Assigned(mosq))and(mosquitto_userdata(mosq) = obj)and(Assigned(obj)) then
        begin
            mqtt := TMQTTConnection(obj);

            mqtt.FMutex.Enter();
            try
                if (Assigned(mqtt.FOnMessage))and(Assigned(message)) then
                    mqtt.FOnMessage(message);
            finally
                mqtt.FMutex.Leave();
            end;
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
procedure mqtt_on_publish(mosq: Pmosquitto; obj: pointer; mid: cint); cdecl;
var
        mqtt: TMQTTConnection;
begin
        if (Assigned(mosq))and(mosquitto_userdata(mosq) = obj)and(Assigned(obj)) then
        begin
            mqtt := TMQTTConnection(obj);

            mqtt.FMutex.Enter();
            try
                if (Assigned(mqtt.FOnPublish)) then
                    mqtt.FOnPublish(mid);
            finally
                mqtt.FMutex.Leave();
            end;
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
procedure mqtt_on_subscribe(mosq: Pmosquitto; obj: pointer; mid: cint; qos_count: cint; const granted_qos: pcint); cdecl;
var
        mqtt: TMQTTConnection;
begin
        if (Assigned(mosq))and(mosquitto_userdata(mosq) = obj)and(Assigned(obj)) then
        begin
            mqtt := TMQTTConnection(obj);

            mqtt.FMutex.Enter();
            try
                if (Assigned(mqtt.FOnSubscribe)) and (Assigned(granted_qos)) then
                    mqtt.FOnSubscribe(mid, qos_count, granted_qos);
            finally
                mqtt.FMutex.Leave();
            end;
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
procedure mqtt_on_unsubscribe(mosq: Pmosquitto; obj: pointer; mid: cint); cdecl;
var
        mqtt: TMQTTConnection;
begin
        if (Assigned(mosq))and(mosquitto_userdata(mosq) = obj)and(Assigned(obj)) then
        begin
            mqtt := TMQTTConnection(obj);

            mqtt.FMutex.Enter();
            try
                if (Assigned(mqtt.FOnUnsubscribe)) then
                    mqtt.FOnUnsubscribe(mid);
            finally
                mqtt.FMutex.Leave();
            end;
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
procedure mqtt_on_connect(mosq: Pmosquitto; obj: pointer; rc: cint); cdecl;
var
        mqtt: TMQTTConnection;
begin
        if (Assigned(mosq))and(mosquitto_userdata(mosq) = obj)and(Assigned(obj)) then
        begin
            mqtt := TMQTTConnection(obj);

            mqtt.FMutex.Enter();
            try
                if (rc = 0) then
                    mqtt.SetState(st_Connected)
                else
                    mqtt.SetState(st_Disconnected);

                if (Assigned(mqtt.FOnConnect)) then
                    mqtt.FOnConnect(rc);
            finally
                mqtt.FMutex.Leave();
            end;
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
procedure mqtt_on_disconnect(mosq: Pmosquitto; obj: pointer; rc: cint); cdecl;
var
        mqtt: TMQTTConnection;
begin
        if (Assigned(mosq))and(mosquitto_userdata(mosq) = obj)and(Assigned(obj)) then
        begin
            mqtt := TMQTTConnection(obj);

            mqtt.FMutex.Enter();
            try
                mqtt.SetState(st_Disconnected);

                if (Assigned(mqtt.FOnDisconnect)) then
                    mqtt.FOnDisconnect(rc);
            finally
                mqtt.FMutex.Leave();
            end;
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
procedure mqtt_on_log(mosq: Pmosquitto; obj: pointer; level: cint; const str: pchar); cdecl;
var
        mqtt: TMQTTConnection;
begin
        if (Assigned(mosq))and(mosquitto_userdata(mosq) = obj)and(Assigned(obj)) then
        begin
            mqtt := TMQTTConnection(obj);

            mqtt.FMutex.Enter();
            try
                if (Assigned(mqtt.FOnLog)) then
                    mqtt.FOnLog(level, str);
            finally
                mqtt.FMutex.Leave();
            end;
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
{---- TMQTTConnection class ----}
{---------------------------------------------------------------------------------------------------------------------}
constructor TMQTTConnection.Create(const Name: string);
begin
        inherited Create();

        FMutex := TCriticalSection.Create();

        FName := Name;
        FState := st_None;
        FLastError := '';

        FMosq := nil;

        FConfig := default(TMQTTConfig);

        FConfig.Hostname := 'localhost';
        FConfig.port := 1883;
        FConfig.keepalives := 60;
        FConfig.reconnect_delay := 2;
        //FConfig.reconnect_delay_max := 0; { 0 = auto (delay * 30) }
        FConfig.reconnect_backoff := true;
        FConfig.ssl_verify_peer := true;
        FConfig.protocol_version := MOSQ_PROTOCOL_V31;

        if (not libInited) then
            mqtt_init(false);
end;
{---------------------------------------------------------------------------------------------------------------------}
destructor TMQTTConnection.Destroy();
begin
        FMutex.Enter();
    try
        Disconnect();

        if (Assigned(FMosq)) then
        begin
            mosquitto_destroy(FMosq);
            FMosq := nil;
        end;

    finally
        FMutex.Leave();
    end;
        FreeAndNil(FMutex);

        inherited Destroy();
end;
{---------------------------------------------------------------------------------------------------------------------}
procedure TMQTTConnection.SetState(const state: TMQTTConnectionState);
begin
        FMutex.Enter();
        FState := state;
        FMutex.Leave();
end;
{---------------------------------------------------------------------------------------------------------------------}
function TMQTTConnection.GetState(): TMQTTConnectionState;
begin
        FMutex.Enter();
        result := FState;
        FMutex.Leave();
end;
{---------------------------------------------------------------------------------------------------------------------}
function TMQTTConnection.Connect(): boolean;
var
        res: cint;
        CLIENT_ID: pchar;
begin
        result := false;
        FLastError := '';

        FMutex.Enter();
    try
        if (FState in [st_Connecting, st_Connected]) then
        begin
            FLastError := 'Already connected or connecting';
            exit();
        end;

        if (not libInited) then
        begin
            FLastError := 'Mosquitto library not initialized';
            exit();
        end;

        if (FConfig.Hostname = '') then
        begin
            FLastError := 'Hostname is empty';
            exit();
        end;

        if (FConfig.port = 0) then
        begin
            FLastError := 'Port is zero';
            exit();
        end;

        if (FConfig.keepalives <= 0) then
        begin
            FLastError := 'Keepalives must be > 0';
            exit();
        end;

        if (Assigned(FMosq)) then
        begin
            mosquitto_loop_stop(FMosq, true);

            mosquitto_destroy(FMosq);
            FMosq := nil;
        end;

        CLIENT_ID := nil;
        if (FConfig.Client_id <> '') then
            CLIENT_ID := pchar(FConfig.Client_id);

        FMosq := mosquitto_new(CLIENT_ID, true, self);
        if (not Assigned(FMosq)) then
        begin
            FLastError := 'Failed to create mosquitto instance';
            exit();
        end;

        mosquitto_message_callback_set(FMosq, @mqtt_on_message);
        mosquitto_publish_callback_set(FMosq, @mqtt_on_publish);
        mosquitto_subscribe_callback_set(FMosq, @mqtt_on_subscribe);
        mosquitto_unsubscribe_callback_set(FMosq, @mqtt_on_unsubscribe);
        mosquitto_connect_callback_set(FMosq, @mqtt_on_connect);
        mosquitto_disconnect_callback_set(FMosq, @mqtt_on_disconnect);
        mosquitto_log_callback_set(FMosq, @mqtt_on_log);

        {---- Setup will topic configuration ----}
        if (FConfig.Will_topic <> '') then
        begin
            res := mosquitto_will_set(FMosq, pchar(FConfig.Will_topic), Length(FConfig.Will_payload), pchar(FConfig.Will_payload), FConfig.will_qos, FConfig.will_retain);
            if (res <> MOSQ_ERR_SUCCESS) then
            begin
                mosquitto_destroy(FMosq);
                FMosq := nil;

                FLastError := format('Will setup failed: %s', [mosquitto_strerror(res)]);
                exit();
            end;
        end;

        {---- Configuring SSL support ----}
        if (FConfig.ssl) then
        begin
            res := mosquitto_tls_set(FMosq, pchar(FConfig.Ssl_cacertfile), pchar(FConfig.Ssl_capath), pchar(FConfig.Ssl_certfile), pchar(FConfig.Ssl_keyfile), nil);
            if (res <> MOSQ_ERR_SUCCESS) then
            begin
                mosquitto_destroy(FMosq);
                FMosq := nil;

                FLastError := format('TLS setup failed: %s', [mosquitto_strerror(res)]);
                exit();
            end;

            if (not FConfig.ssl_verify_peer) then
            begin
                res := mosquitto_tls_insecure_set(FMosq, true);
                if (res <> MOSQ_ERR_SUCCESS) then
                begin
                    mosquitto_destroy(FMosq);
                    FMosq := nil;

                    FLastError := format('TLS insecure set failed: %s', [mosquitto_strerror(res)]);
                    exit();
                end;
            end;
        end;

        {---- Setup username and password ----}
        if (FConfig.Username <> '') then
        begin
            res := mosquitto_username_pw_set(FMosq, pchar(FConfig.Username), pchar(FConfig.Password));
            if (res <> MOSQ_ERR_SUCCESS) then
            begin
                mosquitto_destroy(FMosq);
                FMosq := nil;

                FLastError := format('Username/password setup failed: %s', [mosquitto_strerror(res)]);
                exit();
            end;
        end;

        {---- Setup reconnect and delay ----}
        if (FConfig.reconnect_delay_max = 0) then
            FConfig.reconnect_delay_max := (FConfig.reconnect_delay * 30);

        res := mosquitto_reconnect_delay_set(FMosq, FConfig.reconnect_delay, FConfig.reconnect_delay_max, FConfig.reconnect_backoff);
        if (res <> MOSQ_ERR_SUCCESS) then
        begin
            mosquitto_destroy(FMosq);
            FMosq := nil;

            FLastError := format('Reconnect setup failed: %s', [mosquitto_strerror(res)]);
            exit();
        end;

        {---- Try to setup connection ----}
        SetState(st_Connecting);

        res := mosquitto_connect(FMosq, pchar(FConfig.Hostname), FConfig.port, FConfig.keepalives);
        if (res <> MOSQ_ERR_SUCCESS) then
        begin
            SetState(st_Disconnected);

            mosquitto_destroy(FMosq);
            FMosq := nil;

            FLastError := format('Connect failed: %s', [mosquitto_strerror(res)]);
            exit();
        end;

        {---- Starup main loop cycle ----}
        res := mosquitto_loop_start(FMosq);
        if (res <> MOSQ_ERR_SUCCESS) then
        begin
            SetState(st_Disconnected);

            mosquitto_destroy(FMosq);
            FMosq := nil;

            FLastError := format('Loop start failed: %s', [mosquitto_strerror(res)]);
            exit();
        end;

        result := true;

    finally
        FMutex.Leave();
    end;
end;
{---------------------------------------------------------------------------------------------------------------------}
function TMQTTConnection.Disconnect(): boolean;
var
        res: cint;
begin
        result := false;
        FLastError := '';

        FMutex.Enter();
    try
        if (not Assigned(FMosq)) then
        begin
            SetState(st_None);
            FLastError := 'Not connected';

            exit(true);
        end;

        res := mosquitto_disconnect(FMosq);
        if (res <> MOSQ_ERR_SUCCESS) then
            FLastError := format('Disconnect failed: %s', [mosquitto_strerror(res)]);

        res := mosquitto_loop_stop(FMosq, true);
        if (res <> MOSQ_ERR_SUCCESS) then
        begin
            if (FLastError <> '') then
                FLastError += ' / ';

            FLastError += format('Loop stop failed: %s', [mosquitto_strerror(res)]);
        end;

        mosquitto_destroy(FMosq);
        FMosq := nil;

        SetState(st_Disconnected);
        result := true;

    finally
        FMutex.Leave();
    end;
end;
{---------------------------------------------------------------------------------------------------------------------}
function TMQTTConnection.ReConnect(): boolean;
var
        res: cint;
begin
        result := false;
        FLastError := '';

        FMutex.Enter();
    try
        if (not Assigned(FMosq)) then
        begin
            FLastError := 'Not connected';
            exit();
        end;

        SetState(st_ReConnecting);

        res := mosquitto_reconnect(FMosq);
        if (res = MOSQ_ERR_SUCCESS) then
            exit(true)
        else
        begin
            SetState(st_Disconnected);
            FLastError := format('Reconnect failed: %s', [mosquitto_strerror(res)]);
        end;

    finally
        FMutex.Leave();
    end;
end;
{---------------------------------------------------------------------------------------------------------------------}
function TMQTTConnection.Publish(const Topic, Payload: string; qos: cint = 0; retain: cbool = false): cint;
var
        res, mid: cint;
begin
        result := MOSQ_ERR_NO_CONN;
        FLastError := '';

        FMutex.Enter();
    try
        if (FState <> st_Connected) then
        begin
            FLastError := 'Not in connected state';
            exit();
        end;

        if (not Assigned(FMosq)) then
        begin
            FLastError := 'Mosquitto instance is nil';
            exit();
        end;

        if (Topic = '') then
        begin
            FLastError := 'Empty topic';
            exit();
        end;

        if (qos < 0)or(qos > 2) then
        begin
            FLastError := 'Invalid QoS (must be 0, 1, or 2)';
            exit();
        end;

        res := mosquitto_publish(FMosq, @mid, pchar(Topic), Length(Payload), pchar(Payload), qos, retain);
        if (res <> MOSQ_ERR_SUCCESS) then
        begin
            FLastError := format('Publish failed: %s', [mosquitto_strerror(res)]);
            exit();
        end;

        result := mid;

    finally
        FMutex.Leave();
    end;
end;
{---------------------------------------------------------------------------------------------------------------------}
function TMQTTConnection.Subscribe(const Topic: string; qos: cint = 0): cint;
var
        res, mid: cint;
begin
        result := MOSQ_ERR_NO_CONN;
        FLastError := '';

        FMutex.Enter();
    try
        if (FState <> st_Connected) then
        begin
            FLastError := 'Not in connected state';
            exit();
        end;

        if (not Assigned(FMosq)) then
        begin
            FLastError := 'Mosquitto instance is nil';
            exit();
        end;

        if (Topic = '') then
        begin
            FLastError := 'Empty topic';
            exit();
        end;

        if (qos < 0)or(qos > 2) then
        begin
            FLastError := 'Invalid QoS (must be 0, 1, or 2)';
            exit();
        end;

        res := mosquitto_subscribe(FMosq, @mid, pchar(Topic), qos);
        if (res <> MOSQ_ERR_SUCCESS) then
        begin
            FLastError := format('Subscribe failed: %s', [mosquitto_strerror(res)]);
            exit();
        end;

        result := mid;

    finally
        FMutex.Leave();
    end;
end;
{---------------------------------------------------------------------------------------------------------------------}
function TMQTTConnection.Unsubscribe(const Topic: string): cint;
var
        res, mid: cint;
begin
        result := MOSQ_ERR_NO_CONN;
        FLastError := '';

        FMutex.Enter();
    try
        if (FState <> st_Connected) then
        begin
            FLastError := 'Not in connected state';
            exit();
        end;

        if (not Assigned(FMosq)) then
        begin
            FLastError := 'Mosquitto instance is nil';
            exit();
        end;

        if (Topic = '') then
        begin
            FLastError := 'Empty topic';
            exit();
        end;

        res := mosquitto_unsubscribe(FMosq, @mid, pchar(Topic));
        if (res <> MOSQ_ERR_SUCCESS) then
        begin
            FLastError := format('Unsubscribe failed: %s', [mosquitto_strerror(res)]);
            exit();
        end;

        result := mid;

    finally
        FMutex.Leave();
    end;
end;
{---------------------------------------------------------------------------------------------------------------------}
{---------------------------------------------------------------------------------------------------------------------}
function mqtt_init(verbose: boolean = true): boolean;
var
        major, minor, revision: cint;
begin
        result := libInited;
        if (libInited) then
            exit();

        libInited := (mosquitto_lib_init() = MOSQ_ERR_SUCCESS);
        if (not libInited) then
        begin
            if (verbose) then
                writeln('[MQTT] Failed to initialize mosquitto library!');

            exit();
        end;

        if (verbose) then
        begin
            mosquitto_lib_version(@major, @minor, @revision);

            writeln(format('[MQTT] Compiled against mosquitto header version %d.%d.%d',
                            [LIBMOSQUITTO_MAJOR, LIBMOSQUITTO_MINOR, LIBMOSQUITTO_REVISION]));

            writeln(format('[MQTT] Running against libmosquitto version %d.%d.%d',
                            [major, minor, revision]));
        end;

        result := true;
end;
{---------------------------------------------------------------------------------------------------------------------}
function mqtt_loglevel_to_str(const loglevel: cint): string;
begin
        case (loglevel) of
            MOSQ_LOG_INFO:
                Result := 'INFO';
            //----
            MOSQ_LOG_NOTICE:
                Result := 'NOTICE';
            //----
            MOSQ_LOG_WARNING:
                Result := 'WARNING';
            //----
            MOSQ_LOG_ERR:
                Result := 'ERROR';
            //----
            MOSQ_LOG_DEBUG:
                Result := 'DEBUG';
            //----
            MOSQ_LOG_SUBSCRIBE:
                Result := 'SUBSCRIBE';
            //----
            MOSQ_LOG_UNSUBSCRIBE:
                Result := 'UNSUBSCRIBE';
            //----
            MOSQ_LOG_WEBSOCKETS:
                Result := 'WEBSOCKETS';
            //----
            else
                Result := 'UNKNOWN';
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
{---------------------------------------------------------------------------------------------------------------------}
initialization
        libInited := false;
{---------------------------------------------------------------------------------------------------------------------}
finalization
        if (libInited) then
            mosquitto_lib_cleanup();
{---------------------------------------------------------------------------------------------------------------------}
{---------------------------------------------------------------------------------------------------------------------}
end.
