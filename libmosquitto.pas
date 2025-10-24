{
    Mosquitto Library Binding for Free Pascal (Lazarus, Delphi)

    Copyright (c) 2010-2019 Roger Light <roger@atchoo.org>
    Copyright (c) 2018-2019 Karoly Balogh <charlie@amigaspirit.hu>
    Copyright (c) 2025 Andrew Rachuk <Interdnestrcom>

    Version 25.10.24

    Features:
       - Low-level interface to libmosquitto (MQTT client)
       - Support for MQTT 3.1, 3.1.1 (planned for 5.0)
       - Connection, publishing, subscribing, TLS
       - Error and log handling
       - Compatibility with Linux, macOS, Windows
       - Full set of error codes and QoS levels

   Requirements:
       - libmosquitto.so (Linux), libmosquitto.dynlib (macOS), mosquitto.dll (Windows)
       - Free Pascal with ctypes module

   Note:
       - Use cbool instead of boolean for C API.
       - Check the version via mosquitto_lib_version.
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
        LIBNAME = 'libmosquitto.dynlib';
    {$ELSE}
        LIBNAME = 'libmosquitto.so';
    {$ENDIF}
{$ELSE}
    {$IFDEF MSWINDOWS}
        LIBNAME = 'mosquitto.dll';
    {$ELSE}
        LIBNAME = '';
        {$WARNING Unsupported platform, libmosquitto not linked!}
    {$ENDIF}
{$ENDIF}
{----------------------------------------------------------------------------------------------------------------------}
const
        {---- Library version ----}
        libMosquitto_Major      = 2;
        libMosquitto_Minor      = 0;
        libMosquitto_Revision   = 18;

        libMosquitto_Version_Number = (libMosquitto_Major*1000000 + libMosquitto_Minor*1000 + libMosquitto_Revision);

        {---- Protocol versions ----}
        C_PROTOCOL_V31       = 3;
        C_PROTOCOL_V311      = 4;
        C_PROTOCOL_V5        = 5;

        {---- QoS levels ----}
        C_QOS_AT_MOST_ONCE   = 0; { Fire and forget }
        C_QOS_AT_LEAST_ONCE  = 1; { Acknowledged delivery }
        C_QOS_EXACTLY_ONCE   = 2; { Assured delivery }

        {---- Log types ----}
        C_LOG_NONE           = $00;
        C_LOG_INFO           = $01;
        C_LOG_NOTICE         = $02;
        C_LOG_WARNING        = $04;
        C_LOG_ERR            = $08;
        C_LOG_DEBUG          = $10;
        C_LOG_SUBSCRIBE      = $20;
        C_LOG_UNSUBSCRIBE    = $40;
        C_LOG_WEBSOCKETS     = $80;
        C_LOG_ALL            = $FFFF;
        C_LOG_NODEBUG        = (C_LOG_ALL) and (not C_LOG_DEBUG);

        {---- Error codes ----}
        C_ERR_CONN_PENDING   = -1;
        C_ERR_SUCCESS        = 0;
        C_ERR_NOMEM          = 1;
        C_ERR_PROTOCOL       = 2;
        C_ERR_INVAL          = 3;
        C_ERR_NO_CONN        = 4;
        C_ERR_CONN_REFUSED   = 5;
        C_ERR_NOT_FOUND      = 6;
        C_ERR_CONN_LOST      = 7;
        C_ERR_TLS            = 8;
        C_ERR_PAYLOAD_SIZE   = 9;
        C_ERR_NOT_SUPPORTED  = 10;
        C_ERR_AUTH           = 11;
        C_ERR_ACL_DENIED     = 12;
        C_ERR_UNKNOWN        = 13;
        C_ERR_ERRNO          = 14;
        C_ERR_EAI            = 15;
        C_ERR_PROXY          = 16;
        C_ERR_PLUGIN_DEFER   = 17;
        C_ERR_MALFORMED_UTF8 = 18;
        C_ERR_KEEPALIVE      = 19;
        C_ERR_LOOKUP         = 20;
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
function mosquitto_lib_init: cint; cdecl; external LIBNAME;
function mosquitto_lib_cleanup: cint; cdecl; external LIBNAME;

procedure mosquitto_lib_version(major, minor, revision: pcint); cdecl; external LIBNAME;

{---- Client creation and destruction ----}
function mosquitto_new(const id: pchar; clean_session: cbool; obj: pointer): Pmosquitto; cdecl; external LIBNAME;
function mosquitto_destroy(mosq: Pmosquitto): cint; cdecl; external LIBNAME;
function mosquitto_reinitialise(mosq: Pmosquitto; const id: pchar; clean_session: cbool; obj: pointer): cint; cdecl; external LIBNAME;

{---- Callback setters ----}
function mosquitto_message_callback_set(mosq: Pmosquitto; callback: Ton_message_callback): cint; cdecl; external LIBNAME;
function mosquitto_publish_callback_set(mosq: Pmosquitto; callback: Ton_publish_callback): cint; cdecl; external LIBNAME;
function mosquitto_subscribe_callback_set(mosq: Pmosquitto; callback: Ton_subscribe_callback): cint; cdecl; external LIBNAME;
function mosquitto_unsubscribe_callback_set(mosq: Pmosquitto; callback: Ton_unsubscribe_callback): cint; cdecl; external LIBNAME;
function mosquitto_connect_callback_set(mosq: Pmosquitto; callback: Ton_connect_callback): cint; cdecl; external LIBNAME;
function mosquitto_disconnect_callback_set(mosq: Pmosquitto; callback: Ton_disconnect_callback): cint; cdecl; external LIBNAME;
function mosquitto_log_callback_set(mosq: Pmosquitto; callback: Ton_log_callback): cint; cdecl; external LIBNAME;

{---- Connection ----}
function mosquitto_connect(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl; external LIBNAME;
function mosquitto_connect_bind(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; const bind_address: pchar): cint; cdecl; external LIBNAME;
function mosquitto_connect_async(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint): cint; cdecl; external LIBNAME;
function mosquitto_connect_bind_async(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; const bind_address: pchar): cint; cdecl; external LIBNAME;
//function mosquitto_connect_v5(mosq: Pmosquitto; const host: pchar; port: cint; keepalive: cint; properties: Pmosquitto_property): cint; cdecl; external LIBNAME;

function mosquitto_reconnect(mosq: Pmosquitto): cint; cdecl; external LIBNAME;
function mosquitto_reconnect_async(mosq: Pmosquitto): cint; cdecl; external LIBNAME;

function mosquitto_disconnect(mosq: Pmosquitto): cint; cdecl; external LIBNAME;

{---- Publishing ----}
function mosquitto_publish(mosq: Pmosquitto; mid: pcint; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool): cint; cdecl; external LIBNAME;
//function mosquitto_publish_v5(mosq: Pmosquitto; mid: pcint; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool; properties: Pmosquitto_property): cint; cdecl; external LIBNAME;

{---- Subscribing ----}
function mosquitto_subscribe(mosq: Pmosquitto; mid: pcint; const sub: pchar; qos: cint): cint; cdecl; external LIBNAME;
//function mosquitto_subscribe_v5(mosq: Pmosquitto; mid: pcint; const sub: pchar; qos: cint; options: cint; properties: Pmosquitto_property): cint; cdecl; external LIBNAME;

function mosquitto_unsubscribe(mosq: Pmosquitto; mid: pcint; const sub: pchar): cint; cdecl; external LIBNAME;
//function mosquitto_unsubscribe_v5(mosq: Pmosquitto; mid: pcint; const sub: pchar; properties: Pmosquitto_property): cint; cdecl; external LIBNAME;

{---- Event loop ----}
function mosquitto_loop(mosq: Pmosquitto; timeout: cint; max_packets: cint): cint; cdecl; external LIBNAME;
function mosquitto_loop_forever(mosq: Pmosquitto; timeout: cint; max_packets: cint): cint; cdecl; external LIBNAME;
function mosquitto_loop_start(mosq: Pmosquitto): cint; cdecl; external LIBNAME;
function mosquitto_loop_stop(mosq: Pmosquitto; force: cbool): cint; cdecl; external LIBNAME;

{---- Network loop (for non-threaded operation) ----}
function mosquitto_loop_read(mosq: Pmosquitto; max_packets: cint): cint; cdecl; external LIBNAME;
function mosquitto_loop_write(mosq: Pmosquitto; max_packets: cint): cint; cdecl; external LIBNAME;
function mosquitto_loop_misc(mosq: Pmosquitto): cint; cdecl; external LIBNAME;

{---- Will ----}
function mosquitto_will_set(mosq: Pmosquitto; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool): cint; cdecl; external LIBNAME;
//function mosquitto_will_set_v5(mosq: Pmosquitto; const topic: pchar; payloadlen: cint; const payload: pointer; qos: cint; retain: cbool; properties: Pmosquitto_property): cint; cdecl; external LIBNAME;

function mosquitto_will_clear(mosq: Pmosquitto): cint; cdecl; external LIBNAME;

{---- Authentication ----}
function mosquitto_username_pw_set(mosq: Pmosquitto; const username, password: pchar): cint; cdecl; external LIBNAME;

{---- TLS ----}
function mosquitto_tls_set(mosq: Pmosquitto; const cafile, capath, certfile, keyfile: pchar; pw_callback: Ton_tls_pw_callback): cint; cdecl; external LIBNAME;
function mosquitto_tls_insecure_set(mosq: Pmosquitto; value: cbool): cint; cdecl; external LIBNAME;
function mosquitto_tls_opts_set(mosq: Pmosquitto; cert_reqs: cint; const tls_version, ciphers: pchar): cint; cdecl; external LIBNAME;
function mosquitto_tls_psk_set(mosq: Pmosquitto; const psk, identity, ciphers: pchar): cint; cdecl; external LIBNAME;

{---- Options ----}
function mosquitto_opts_set(mosq: Pmosquitto; option: cint; value: pointer): cint; cdecl; external LIBNAME;
function mosquitto_reconnect_delay_set(mosq: Pmosquitto; reconnect_delay, reconnect_delay_max: cuint; reconnect_exponential_backoff: cbool): cint; cdecl; external LIBNAME;
function mosquitto_max_inflight_messages_set(mosq: Pmosquitto; max_inflight_messages: cuint): cint; cdecl; external LIBNAME;
function mosquitto_message_retry_set(mosq: Pmosquitto; message_retry: cuint): cint; cdecl; external LIBNAME;

{---- Utilities ----}
function mosquitto_userdata(mosq: Pmosquitto): pointer; cdecl; external LIBNAME;
function mosquitto_strerror(mosq_errno: cint): pchar; cdecl; external LIBNAME;
function mosquitto_connack_string(connack_code: cint): pchar; cdecl; external LIBNAME;
function mosquitto_sub_topic_tokenise(const subtopic: pchar; var topics: ppchar; var count: cint): cint; cdecl; external LIBNAME;
function mosquitto_sub_topic_tokens_free(var topics: ppchar; count: cint): cint; cdecl; external LIBNAME;
function mosquitto_topic_matches_sub(const sub, topic: pchar; var result: cbool): cint; cdecl; external LIBNAME;
function mosquitto_validate_utf8(const str: pchar; len: cint): cint; cdecl; external LIBNAME;

{---- MQTT 5.0 properties ----}
function mosquitto_property_add_byte(var props: Pmosquitto_property; identifier: cint; value: cuint8): cint; cdecl; external LIBNAME;
function mosquitto_property_add_int16(var props: Pmosquitto_property; identifier: cint; value: cuint16): cint; cdecl; external LIBNAME;
function mosquitto_property_add_int32(var props: Pmosquitto_property; identifier: cint; value: cuint32): cint; cdecl; external LIBNAME;
function mosquitto_property_add_varint(var props: Pmosquitto_property; identifier: cint; value: cuint32): cint; cdecl; external LIBNAME;
function mosquitto_property_add_binary(var props: Pmosquitto_property; identifier: cint; const value: pointer; len: cuint16): cint; cdecl; external LIBNAME;
function mosquitto_property_add_string(var props: Pmosquitto_property; identifier: cint; const value: pchar): cint; cdecl; external LIBNAME;
function mosquitto_property_add_string_pair(var props: Pmosquitto_property; identifier: cint; const name, value: pchar): cint; cdecl; external LIBNAME;
function mosquitto_property_free_all(var props: Pmosquitto_property): cint; cdecl; external LIBNAME;
function mosquitto_property_copy_all(var dest: Pmosquitto_property; const src: Pmosquitto_property): cint; cdecl; external LIBNAME;
function mosquitto_property_check_all(command: cint; properties: Pmosquitto_property): cint; cdecl; external LIBNAME;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
implementation
{----------------------------------------------------------------------------------------------------------------------}
end.
