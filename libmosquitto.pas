{
    Mosquitto Library Binding for Free Pascal/Delphi

    Copyright (c) 2010-2019 Roger Light <roger@atchoo.org>
    Copyright (c) 2018-2019 Karoly Balogh <charlie@amigaspirit.hu>
    Copyright (c) 2025 Andrew Rachuk <Interdnestrcom>

    Version 2.0.1

    Возможности:
        - Низкоуровневый интерфейс к libmosquitto (MQTT клиент)
        - Поддержка MQTT 3.1, 3.1.1 (planned for 5.0)
        - Подключение, публикация, подписка, TLS
        - Обработка ошибок и логов
        - Совместимость с Linux, macOS, Windows
        - Полный набор error codes и QoS levels

    Требования:
        - libmosquitto.so (Linux), libmosquitto.dynlib (macOS), mosquitto.dll (Windows)
        - Free Pascal с модулем ctypes

    Примечание:
        - Используйте cbool вместо boolean для C API.
        - Проверяйте версию через mosquitto_lib_version.
}
{$MODE OBJFPC}
{$PACKRECORDS C}
unit libmosquitto;
{---------------------------------------------------------------------------------------------------------------------}
interface
{---------------------------------------------------------------------------------------------------------------------}
uses
        ctypes;
{---------------------------------------------------------------------------------------------------------------------}
type
        {---- Workaround for GCC boolean optimization issue ----}
        cbool = boolean;
        pcbool = ^cbool;
{----------------------------------------------------------------------------------------------------------------------}
const
{$IFDEF UNIX}
    {$IFDEF DARWIN}
        {$LINKLIB mosquitto}
        LIBMOSQ_NAME = 'libmosquitto.dynlib';
    {$ELSE}
        LIBMOSQ_NAME = 'libmosquitto.so';
    {$ENDIF}
{$ELSE}
    {$IFDEF MSWINDOWS}
        LIBMOSQ_NAME = 'mosquitto.dll';
    {$ELSE}
        LIBMOSQ_NAME = '';
        {$WARNING Unsupported platform, libmosquitto not linked!}
    {$ENDIF}
{$ENDIF}
{----------------------------------------------------------------------------------------------------------------------}
const
        {---- Library version ----}
        LIBMOSQUITTO_MAJOR      = 2;
        LIBMOSQUITTO_MINOR      = 0;
        LIBMOSQUITTO_REVISION   = 18;

        LIBMOSQUITTO_VERSION_NUMBER = (LIBMOSQUITTO_MAJOR*1000000 + LIBMOSQUITTO_MINOR*1000 + LIBMOSQUITTO_REVISION);

        {---- Protocol versions ----}
        MOSQ_PROTOCOL_V31       = 3;
        MOSQ_PROTOCOL_V311      = 4;
        MOSQ_PROTOCOL_V5        = 5;

        {---- QoS levels ----}
        MOSQ_QOS_AT_MOST_ONCE   = 0; { Fire and forget }
        MOSQ_QOS_AT_LEAST_ONCE  = 1; { Acknowledged delivery }
        MOSQ_QOS_EXACTLY_ONCE   = 2; { Assured delivery }

        {---- Log types ----}
        MOSQ_LOG_NONE           = $00;
        MOSQ_LOG_INFO           = $01;
        MOSQ_LOG_NOTICE         = $02;
        MOSQ_LOG_WARNING        = $04;
        MOSQ_LOG_ERR            = $08;
        MOSQ_LOG_DEBUG          = $10;
        MOSQ_LOG_SUBSCRIBE      = $20;
        MOSQ_LOG_UNSUBSCRIBE    = $40;
        MOSQ_LOG_WEBSOCKETS     = $80;
        MOSQ_LOG_ALL            = $FFFF;
        MOSQ_LOG_NODEBUG        = MOSQ_LOG_ALL and (not MOSQ_LOG_DEBUG);

        {---- Error codes ----}
        MOSQ_ERR_CONN_PENDING   = -1;
        MOSQ_ERR_SUCCESS        = 0;
        MOSQ_ERR_NOMEM          = 1;
        MOSQ_ERR_PROTOCOL       = 2;
        MOSQ_ERR_INVAL          = 3;
        MOSQ_ERR_NO_CONN        = 4;
        MOSQ_ERR_CONN_REFUSED   = 5;
        MOSQ_ERR_NOT_FOUND      = 6;
        MOSQ_ERR_CONN_LOST      = 7;
        MOSQ_ERR_TLS            = 8;
        MOSQ_ERR_PAYLOAD_SIZE   = 9;
        MOSQ_ERR_NOT_SUPPORTED  = 10;
        MOSQ_ERR_AUTH           = 11;
        MOSQ_ERR_ACL_DENIED     = 12;
        MOSQ_ERR_UNKNOWN        = 13;
        MOSQ_ERR_ERRNO          = 14;
        MOSQ_ERR_EAI            = 15;
        MOSQ_ERR_PROXY          = 16;
        MOSQ_ERR_PLUGIN_DEFER   = 17;
        MOSQ_ERR_MALFORMED_UTF8 = 18;
        MOSQ_ERR_KEEPALIVE      = 19;
        MOSQ_ERR_LOOKUP         = 20;
{----------------------------------------------------------------------------------------------------------------------}
type
        Pmosquitto = pointer;
        Pmosquitto_property = pointer;

        Pmosquitto_message = ^mosquitto_message;
        mosquitto_message = record
            mid: cint;
            topic: pchar;
            payload: pointer;
            payloadlen: cint;
            qos: cint;
            retain: cbool;
        end;

        {---- Callbacks ----}
        Ton_message_callback     = procedure(mosq: Pmosquitto; userdata: pointer; const message: Pmosquitto_message); cdecl;
        Ton_publish_callback     = procedure(mosq: Pmosquitto; userdata: pointer; mid: cint); cdecl;
        Ton_subscribe_callback   = procedure(mosq: Pmosquitto; userdata: pointer; mid: cint; qos_count: cint; const granted_qos: pcint); cdecl;
        Ton_unsubscribe_callback = procedure(mosq: Pmosquitto; userdata: pointer; mid: cint); cdecl;
        Ton_connect_callback     = procedure(mosq: Pmosquitto; userdata: pointer; rc: cint); cdecl;
        Ton_disconnect_callback  = procedure(mosq: Pmosquitto; userdata: pointer; rc: cint); cdecl;
        Ton_log_callback         = procedure(mosq: Pmosquitto; userdata: pointer; level: cint; const str: pchar); cdecl;

        Ton_tls_pw_callback      = function(buf: pchar; size: cint; rwflag: cint; userdata: pointer): cint; cdecl;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}

{---- Library initialization ----}
function mosquitto_lib_init: cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_lib_cleanup: cint; cdecl; external LIBMOSQ_NAME;

procedure mosquitto_lib_version(major, minor, revision: pcint); cdecl; external LIBMOSQ_NAME;

{---- Client creation and destruction ----}
function mosquitto_new(const id: pchar; clean_session: cbool; obj: pointer): Pmosquitto; cdecl; external LIBMOSQ_NAME;
function mosquitto_destroy(mosq: Pmosquitto): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_reinitialise(mosq: Pmosquitto; const id: pchar; clean_session: cbool; obj: pointer): cint; cdecl; external LIBMOSQ_NAME;

{---- Callback setters ----}
function mosquitto_message_callback_set(mosq: Pmosquitto; callback: Ton_message_callback): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_publish_callback_set(mosq: Pmosquitto; callback: Ton_publish_callback): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_subscribe_callback_set(mosq: Pmosquitto; callback: Ton_subscribe_callback): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_unsubscribe_callback_set(mosq: Pmosquitto; callback: Ton_unsubscribe_callback): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_connect_callback_set(mosq: Pmosquitto; callback: Ton_connect_callback): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_disconnect_callback_set(mosq: Pmosquitto; callback: Ton_disconnect_callback): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_log_callback_set(mosq: Pmosquitto; callback: Ton_log_callback): cint; cdecl; external LIBMOSQ_NAME;

{---- Connection ----}
function mosquitto_connect(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_connect_bind(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; const bind_address: pchar): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_connect_async(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_connect_bind_async(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; const bind_address: pchar): cint; cdecl; external LIBMOSQ_NAME;
//function mosquitto_connect_v5(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; properties: Pmosquitto_property): cint; cdecl; external LIBMOSQ_NAME;

function mosquitto_reconnect(mosq: Pmosquitto): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_reconnect_async(mosq: Pmosquitto): cint; cdecl; external LIBMOSQ_NAME;

function mosquitto_disconnect(mosq: Pmosquitto): cint; cdecl; external LIBMOSQ_NAME;

{---- Publishing ----}
function mosquitto_publish(mosq: Pmosquitto; mid: pcint; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool): cint; cdecl; external LIBMOSQ_NAME;
//function mosquitto_publish_v5(mosq: Pmosquitto; mid: pcint; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool; properties: Pmosquitto_property): cint; cdecl; external LIBMOSQ_NAME;

{---- Subscribing ----}
function mosquitto_subscribe(mosq: Pmosquitto; mid: pcint; const sub: pchar; qos: cint): cint; cdecl; external LIBMOSQ_NAME;
//function mosquitto_subscribe_v5(mosq: Pmosquitto; mid: pcint; const sub: pchar; qos: cint; options: cint; properties: Pmosquitto_property): cint; cdecl; external LIBMOSQ_NAME;

function mosquitto_unsubscribe(mosq: Pmosquitto; mid: pcint; const sub: pchar): cint; cdecl; external LIBMOSQ_NAME;
//function mosquitto_unsubscribe_v5(mosq: Pmosquitto; mid: pcint; const sub: pchar; properties: Pmosquitto_property): cint; cdecl; external LIBMOSQ_NAME;

{---- Event loop ----}
function mosquitto_loop(mosq: Pmosquitto; timeout: cint; max_packets: cint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_loop_forever(mosq: Pmosquitto; timeout: cint; max_packets: cint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_loop_start(mosq: Pmosquitto): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_loop_stop(mosq: Pmosquitto; force: cbool): cint; cdecl; external LIBMOSQ_NAME;

{---- Network loop (for non-threaded operation) ----}
function mosquitto_loop_read(mosq: Pmosquitto; max_packets: cint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_loop_write(mosq: Pmosquitto; max_packets: cint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_loop_misc(mosq: Pmosquitto): cint; cdecl; external LIBMOSQ_NAME;

{---- Will ----}
function mosquitto_will_set(mosq: Pmosquitto; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool): cint; cdecl; external LIBMOSQ_NAME;
//function mosquitto_will_set_v5(mosq: Pmosquitto; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool; properties: Pmosquitto_property): cint; cdecl; external LIBMOSQ_NAME;

function mosquitto_will_clear(mosq: Pmosquitto): cint; cdecl; external LIBMOSQ_NAME;

{---- Authentication ----}
function mosquitto_username_pw_set(mosq: Pmosquitto; const username, password: pchar): cint; cdecl; external LIBMOSQ_NAME;

{---- TLS ----}
function mosquitto_tls_set(mosq: Pmosquitto; const cafile, capath, certfile, keyfile: pchar; pw_callback: Ton_tls_pw_callback): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_tls_insecure_set(mosq: Pmosquitto; value: cbool): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_tls_opts_set(mosq: Pmosquitto; cert_reqs: cint; const tls_version, ciphers: pchar): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_tls_psk_set(mosq: Pmosquitto; const psk, identity, ciphers: pchar): cint; cdecl; external LIBMOSQ_NAME;

{---- Options ----}
function mosquitto_opts_set(mosq: Pmosquitto; option: cint; value: pointer): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_reconnect_delay_set(mosq: Pmosquitto; reconnect_delay, reconnect_delay_max: cuint; reconnect_exponential_backoff: cbool): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_max_inflight_messages_set(mosq: Pmosquitto; max_inflight_messages: cuint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_message_retry_set(mosq: Pmosquitto; message_retry: cuint): cint; cdecl; external LIBMOSQ_NAME;

{---- Utilities ----}
function mosquitto_userdata(mosq: Pmosquitto): pointer; cdecl; external LIBMOSQ_NAME;
function mosquitto_strerror(mosq_errno: cint): pchar; cdecl; external LIBMOSQ_NAME;
function mosquitto_connack_string(connack_code: cint): pchar; cdecl; external LIBMOSQ_NAME;
function mosquitto_sub_topic_tokenise(const subtopic: pchar; var topics: ppchar; var count: cint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_sub_topic_tokens_free(var topics: ppchar; count: cint): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_topic_matches_sub(const sub, topic: pchar; var result: cbool): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_validate_utf8(const str: pchar; len: cint): cint; cdecl; external LIBMOSQ_NAME;

{---- MQTT 5.0 properties ----}
function mosquitto_property_add_byte(var props: Pmosquitto_property; identifier: cint; value: cuint8): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_add_int16(var props: Pmosquitto_property; identifier: cint; value: cuint16): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_add_int32(var props: Pmosquitto_property; identifier: cint; value: cuint32): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_add_varint(var props: Pmosquitto_property; identifier: cint; value: cuint32): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_add_binary(var props: Pmosquitto_property; identifier: cint; const value: pointer; len: cuint16): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_add_string(var props: Pmosquitto_property; identifier: cint; const value: pchar): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_add_string_pair(var props: Pmosquitto_property; identifier: cint; const name, value: pchar): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_free_all(var props: Pmosquitto_property): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_copy_all(var dest: Pmosquitto_property; const src: Pmosquitto_property): cint; cdecl; external LIBMOSQ_NAME;
function mosquitto_property_check_all(command: cint; properties: Pmosquitto_property): cint; cdecl; external LIBMOSQ_NAME;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
implementation
{----------------------------------------------------------------------------------------------------------------------}
end.
