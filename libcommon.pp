unit libcommon;
{$MODESWITCH ADVANCEDRECORDS}
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        classes, math;
{----------------------------------------------------------------------------------------------------------------------}
type
        t_string_array = array of string;
        t_crc_table = array[0..255] of word;

        bool = type boolean;
        //--------
        t_rbits = record
            bitBuf: array of bool;
            bCount: longint;
            offset: byte;

            function getByte: byte;
            function getbits(len: byte): byte;

            procedure init(len: longint);
            procedure reset;
            procedure setByte(value: byte);
            procedure setbits(value, len: byte);
        end;
        {--------------------------------------------------------------------------------------------------------------}
        t_mutex = class
        private
            fcs: TRtlCriticalSection;
        public
            constructor Create;
            destructor  Destroy; override;

            procedure lock; inline;
            procedure unlock; inline;
        end;
{----------------------------------------------------------------------------------------------------------------------}
const
        {---- Timeouts ----}
        C_SYS_TIMEOUT   = 250; { milliseconds }
        C_NET_TIMEOUT   = 200;

        C_2K            = 2048;
        C_4K            = 4096;
        C_8K            = 8192;

        C_16K           = 1024 * 16;
        C_32K           = 1024 * 32;
        C_64K           = 1024 * 64;
        C_128K          = 1024 * 128;
        C_256K          = 1024 * 256;
        C_512K          = 1024 * 512;

        {---- Service Indicator types ----}
        SI_OTASP        = '01';
        SI_OTAPA        = '03';

        {---- Link type codes ----}
        C_LT_LSL        = 0;
        C_LT_HSL        = 1;

        {---- Task Queue length ----}
        C_QUEUE_LEN_MIN         = 20;
        C_QUEUE_MAX_LSL         = 50;
        C_QUEUE_MAX_HSL         = 3000;

        {---- Exit Codes ----}
        C_ECODE_NO_SMSC                 = $ff;
        C_ECODE_SUCCESS                 = $00;
        C_ECODE_TERM_OFFLINE            = $01;
        C_ECODE_SENDSMS_FAIL            = $02;
        C_ECODE_START_OTAPA_FAIL        = $03;
        C_ECODE_STOP_OTAPA_FAIL         = $04;
        C_ECODE_AUTH_SIGN_FAIL          = $05;
        C_ECODE_CHECK_SPASM_FAIL        = $06;
        C_ECODE_CHECK_SPC_FAIL          = $07;
        C_ECODE_ATTACH_MSC_FAIL         = $08;
        C_ECODE_RELEASE_TRN_FAIL        = $09;
        C_ECODE_COMMIT_FAIL             = $0A;
        C_ECODE_REC_NEWMSID_FAIL        = $0B;
        C_ECODE_CHANGE_SPC_FAIL         = $0C;

        C_ECODE_CHECK_TIMEOUT           = $0D;

        C_ECODE_SLEEP_TASK              = $10;
        C_ECODE_SAME_TASK_FAIL          = $11;
        C_ECODE_MS_INACTIVE             = $20;

        C_ECODE_NO_SUBSCRIBER           = $30;
        C_ECODE_SENDOTA_FAIL            = $40;

        C_ECODE_ISYSPOS_FAIL            = $50;

        C_ECODE_CONN_ERROR              = $60;
        C_ECODE_NETIO_ERROR             = $61;
        C_ECODE_NO_INIT                 = $62;
        C_ECODE_NO_DATA                 = $63;
        C_ECODE_PROC_EXCEPTION          = $64;
        C_ECODE_PROC_TIMEOUT            = $65;

        C_ECODE_DB_ERROR                = $70;

        C_ECODE_SSPR_DLOAD_FAIL         = $100;
        C_ECODE_SSPR_EXTDIM_FAIL        = $101;
        C_ECODE_SSPR_DIM_FAIL           = $102;
        C_ECODE_SSPR_PRL_FAIL           = $104;

        C_ECODE_GETCONF_FAIL            = $200;
        C_ECODE_DECODE_ANAM_FAIL        = $201;
        C_ECODE_DECODE_MDN_FAIL         = $202;
        C_ECODE_DECODE_CNAM_FAIL        = $204;
        C_ECODE_DECODE_IMSI_FAIL        = $208;

        C_ECODE_GETPCAP_FAIL            = $300;

        C_ECODE_SETCONF_FAIL            = $400;
        C_ECODE_CONF_ANAM_FAIL          = $401;
        C_ECODE_CONF_MDN_FAIL           = $402;
        C_ECODE_CONF_CNAM_FAIL          = $404;
        C_ECODE_CONF_IMSI_FAIL          = $408;

        C_ECODE_GEN_PUB_ENC_FAIL        = $501;
        C_ECODE_MS_KEY_FAIL             = $502;
        C_ECODE_KEY_GEN_FAIL            = $503;
        C_ECODE_GEN_AKEY_FAIL           = $504;
        C_ECODE_SSD_UPDATE_FAIL         = $505;
        C_ECODE_COMMIT_AKEY_FAIL        = $506;

        C_ECODE_USER_NOT_REGISTERED     = 480;

        {---- DateTime constants ----}
        MSecsPerSec     = 1000;
        SecsPerMin      = 60;
        MinsPerHour     = 60;
        SecsPerHour     = 3600;
        HoursPerDay     = 24;
        MinsPerDay      = HoursPerDay * MinsPerHour;
        SecsPerDay      = MinsPerDay * SecsPerMin;
        MSecsPerDay     = SecsPerDay * MSecsPerSec;

        OneMillisecond  = 1 / MSecsPerDay;
        OneSecond       = 1 / SecsPerDay;
        OneMinute       = 1 / MinsPerDay;
        OneHour         = 1 / HoursPerDay;
        OneDay          = 1;

        julianEpoch     = tdatetime(-2415018.5);
        unixEpoch       = julianEpoch + tdatetime(2440587.5);

        {---- Chars constants ----}
        LF              = #10;
        CR              = #13;
        TAB             = #9;
        ESC             = #27;
        SPACE           = #32;
        CRLF            = CR + LF;
        CRLF2           = CRLF + CRLF;
        ESC_CODES       = [#91, #92, #93, #94, #123, #124, #125, #126, #164];

        HEX_DIGITS: array[0..15] of char = '0123456789abcdef';

        {---- MSC & CSYS type string ----}
        S_MTYPE: array[bool] of string = ('SECOND','MASTER');
        S_LTYPE: array[bool] of string = ('FAILED','ACTIVE');

        URL_Chars: set of char = [#$00..#$20, '_', '<', '>', '"', '%', '{', '}', '|', '\', '^', '~', '[', ']', '`',
                                  #$7f..#$ff, ';', '/', '?', ':', '@', '=', '&', '#', '+', ''''];

        {---- CRC Polynom for generated table ----}
        crc_polynom     = $8408;
{----------------------------------------------------------------------------------------------------------------------}
var
        d_start_time: tdatetime;
        worker_event: pointer; { pRTLEvent! }

{---- t_rbits fuctional ----}
function getbit(value, index: byte): bool;
procedure putbit(var value: byte; index: byte; fstate: bool);
procedure putbitword(var value: word; index: byte; fstate: bool);

{---- DateTime functions ----}
function utime_to_datetime(utime: int64): tdatetime;
function get_local_tz: shortint;
function get_datetime(tz: shortint = 0): tdatetime;
function get_sdatetime(tz: shortint = 0): tdatetime;
function get_utime(tz: shortint = 0): int64;
function compare_datetime(A, B: tdatetime): TValueRelationship;
function datetime_trim(const DT: string): string;
function datetime_to_sstr(const dt: tdatetime): string;
function datetime_to_str(const dt: tdatetime): string;
function datetime_to_otap(const dt: tdatetime): string;
function time_to_str(const dt: tdatetime): string;
//function utime_to_string(utime: int64): string;
function convert_TOD(tod: longint): string;

{---- String functions ----}
function decodeLongInt(const VALUE: string; index: longint): longint;
function codeLongInt(value: longint): string;
function nibbleswap(const STR: string): string;
function swapBytes(value: longint): longint;
function xorString(const STR1: string; var STR2: string): string;
function addchars(const STR: string; ch: char; len: longint): string;
function addcharsr(const STR: string; ch: char; len: longint): string;
function addspaces(const STR: string; len: longint): string;
function delchars(const STR: string; ch: char): string;
function delspaces(const STR: string): string;
function encodeURL(const STR: string): string;
function decodeURL(const STR: string): string;
function URLDecode(const STR: string): string;
function encodeByte(const STR: string): string;
function hextostring(const STR: string): string;
function stringtohex(const STR: string; fSP: bool = true): string;
function inttohex(value: longint; len: byte = 2): shortstring;
function clearDigits(const STR: string): string;
function escapeQuoters(const STR: string): string;
function upcase(const STR: string): string;
function lowercase(const STR: string): string;
function isDigitsOnly(const STR: string): bool;

{---- Split command & key values functions ----}
function get_param(const SPLIT: string; var VSTR: string): string;
function split_command(var VSTR, VCMD, VVAL: string): bool;
function split_params(const STR: string; var params: TStringList): bool;

{---- CRC table functions ----}
function generate_crc_table: t_crc_table;
function calculate_crc(DATA: string; table: t_crc_table; init_fcs: word = $FFFF; xor_out: word = $FFFF): word;

{---- String output of error ----}
function OTAF_ERR(code: longint): string;
function DESC_ERR(code: longint): string;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
implementation
uses
        sysutils, unix;
{----------------------------------------------------------------------------------------------------------------------}
constructor t_mutex.create;
begin
        inherited create();
        initCriticalSection(fcs);
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor t_mutex.destroy;
begin
        doneCriticalSection(fcs);
        inherited destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_mutex.lock;
begin
        enterCriticalSection(fcs);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_mutex.unlock;
begin
        leaveCriticalSection(fcs);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function t_rbits.getByte: byte;
begin
        result := getbits(8);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_rbits.getbits(len: byte): byte;
var
        i: byte;
begin
        result := 0;

        if (offset = 0) then
        begin
            if (length(bitbuf) < (bcount*8 - 8) + len) then
                raise exception.create('getbits(): size mismatch!');

            for i := 0 to (len - 1) do
                putbit(result, i, bitbuf[8*bcount+i+(8-len)]);

            offset := (8 - len);
            if (offset = 0) then
                inc(bcount);

            exit();
        end;

        if (length(bitbuf) < (bcount*8 - offset) + len) then
            raise exception.create('getbits(): size mismatch!');

        if (len < offset) then
        begin
            for i := 0 to (len - 1) do
                putbit(result, i, bitbuf[8*bcount+i+(offset-len)]);

            offset := (offset - len);
            if (offset = 0) then
                inc(bcount);

            exit();
        end;

        if (len > offset) then
        begin
            for i := (len - offset) to (len - 1) do
                putbit(result, i, bitbuf[8*bcount+i-(len-offset)]);

            inc(bcount);
            for i := 0 to (len - offset - 1) do
                putbit(result, i, bitbuf[8*bcount+i+(8-len+offset)]);

            offset := (8 - len + offset);
            if (offset = 0) then
                inc(bcount);

            exit();
        end;

        if (len = offset) then
        begin
            for i := 0 to (len - 1) do
                putbit(result, i, bitbuf[8*bcount+i]);

            inc(bcount);
            offset := 0;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_rbits.init(len: longint);
var
        i: longint;
begin
        setlength(bitbuf, len);

        for i := 0 to (len-1) do
            bitbuf[i] := false;

        reset();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_rbits.reset;
begin
        offset := 0;
        bcount := 0;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_rbits.setByte(value: byte);
begin
        setbits(value, 8);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_rbits.setbits(value, len: byte);
var
        i: byte = 0;
begin
        if (length(bitbuf) < bcount*8 + len) then
            raise exception.create('setbits(): size mismatch!');

        if (offset = 0) then
        begin
            for i := 0 to (len - 1) do
                bitbuf[8*bcount+i+(8-len)] := getbit(value, i);

            {---- set how many bit are free! ----}
            offset := (8 - len);
            if (offset = 0) then
                inc(bcount);
            exit();
        end;

        if (len < offset) then
        begin
            for i := 0 to (len - 1) do
                bitbuf[8*bcount+i+(offset-len)] := getbit(value, i);

            offset -= len;
            if (offset = 0) then
                inc(bcount);
            exit();
        end;

        if (len > offset) then
        begin
            for i := (len - offset) to (len - 1) do
                bitbuf[8*bcount+i-(len-offset)] := getbit(value, i);

            inc(bcount);
            for i := 0 to (len - offset - 1) do
                bitbuf[8*bcount+i+(8-len+offset)] := getbit(value, i);

            offset := (8 - len + offset);
            if (offset = 0) then
                inc(bcount);
            exit();
        end;

        if (len = offset) then
        begin
            for i := 0 to (len - 1) do
                bitbuf[8*bcount+i] := getbit(value, i);
            inc(bcount);
            offset := 0;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function getbit(value, index: byte): bool;
begin
        result := (((value >> index) and $01) = $01);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure putbit(var value: byte; index: byte; fstate: bool);
begin
        value := (value and (($01 << index) xor $ff))or(byte(fstate) << index);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure putbitword(var value: word; index: byte; fstate: bool);
begin
        value := (value and (($01 << index) xor $ffff))or(word(fstate) << index);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function convert_TOD(tod: longint): string;
var
        SH, SM, SS, DS: string;
        t: longint;
        h, m, s: byte;
begin
        DS := inttostr(tod mod 10);
        t := (tod div 10);

        h := (t div 3600);
        SH := inttostr(h);
        if (h < 10) then
            SH := '0' + SH;

        t := (t - h*3600);
        m := (t div 60);
        SM := inttostr(m);
        if (m < 10) then
            SM := '0' + SM;

        s := (t - m*60);
        SS := inttostr(s);
        if (s < 10) then
            SS := '0' + SS;

        result :=  format('%s:%s:%s.%s', [SH,SM,SS,DS]);
end;
{----------------------------------------------------------------------------------------------------------------------}
function utime_to_datetime(utime: int64): tdatetime;
begin
        result := unixEpoch + (utime / SecsPerDay);
end;
{----------------------------------------------------------------------------------------------------------------------}
function get_local_tz: shortint;
begin
        ReReadLocalTime();
        result := (-1 * (GetLocalTimeOffset() div 60));
end;
{----------------------------------------------------------------------------------------------------------------------}
function get_datetime(tz: shortint = 0): tdatetime;
var
        tv: ttimeval;
begin
        fpgettimeofday(@tv, nil);
        result := utime_to_datetime(tv.tv_sec + tz*SecsPerHour) + ((tv.tv_usec div 1000) / MSecsPerDay);
end;
{----------------------------------------------------------------------------------------------------------------------}
function get_sdatetime(tz: shortint = 0): tdatetime;
var
        tv: ttimeval;
begin
        fpgettimeofday(@tv, nil);
        result := utime_to_datetime(tv.tv_sec + tz*SecsPerHour);
end;
{----------------------------------------------------------------------------------------------------------------------}
function get_utime(tz: shortint = 0): int64;
var
        tv: ttimeval;
begin
        fpgettimeofday(@tv, nil);
        result := (tv.tv_sec + tz*SecsPerHour);
end;
{----------------------------------------------------------------------------------------------------------------------}
function compare_datetime(a, b: tdatetime): TValueRelationship;
begin
        result := compareValue(a, b, OneMillisecond); {from "math": compareValue(double, double): TValueRelationship}
end;
{----------------------------------------------------------------------------------------------------------------------}
function datetime_trim(const DT: string): string;
var
        i: longint;
begin
        result := '';

        for i := 1 to length(DT) do
            if (DT[i] in ['0'..'9']) then
                result += DT[i];
end;
{----------------------------------------------------------------------------------------------------------------------}
function datetime_to_str(const dt: tdatetime): string;
begin
        result := formatdatetime('yyyy-mm-dd hh:nn:ss.zzz', dt);
end;
{----------------------------------------------------------------------------------------------------------------------}
function datetime_to_sstr(const dt: tdatetime): string;
begin
        result := formatdatetime('yyyy-mm-dd hh:nn:ss', dt);
end;
{----------------------------------------------------------------------------------------------------------------------}
function datetime_to_otap(const dt: tdatetime): string;
begin
        result := formatdatetime('yyyy"/"mm"/"dd"T"hh:nn:ss"UTC"', dt);
end;
{----------------------------------------------------------------------------------------------------------------------}
function time_to_str(const dt: tdatetime): string;
begin
        result := formatdatetime('hh:nn:ss.zzz', dt);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function decodeLongInt(const VALUE: string; index: longint): longint;
var
        len: longint;
        x, y, xl, yl: byte;
begin
        len := length(VALUE);

        if (len > index) then
            x := byte(VALUE[index])
        else
            x := 0;

        if (len >= (index+1)) then
            y := byte(VALUE[index+1])
        else
            y := 0;

        if (len >= (index+2)) then
            xl := byte(VALUE[index+2])
        else
            xl := 0;

        if (len >= (index+3)) then
            yl := byte(VALUE[index+3])
        else
            yl := 0;

        result := ((x*256 + y)*65536) + (xl*256 + yl);
end;
{----------------------------------------------------------------------------------------------------------------------}
function codeLongInt(value: longint): string;
var
        x, y: word;
begin
        // this is fix for negative numbers on systems where longint = integer
        x := (value shr 16) and integer($ffff);
        y := value and integer($ffff);

        setlength(result, 4);

        result[1] := char(x div 256);
        result[2] := char(x mod 256);
        result[3] := char(y div 256);
        result[4] := char(y mod 256);
end;
{----------------------------------------------------------------------------------------------------------------------}
function nibbleswap(const STR: string): string;
var
        i: longint;
begin
        result := '';

        for i := 1 to (length(STR) div 2) do
            result += STR[2*i] + STR[2*i-1];
end;
{----------------------------------------------------------------------------------------------------------------------}
function swapBytes(value: longint): longint;
var
        S: string;
        x, y, xl, yl: byte;
begin
        S := codeLongInt(value);
        x := byte(s[4]);
        y := byte(s[3]);
        xl := byte(s[2]);
        yl := byte(s[1]);

        result := ((x*256 + y)*65536) + (xl*256 + yl);
end;
{----------------------------------------------------------------------------------------------------------------------}
function xorString(const STR1: string; var STR2: string): string;
var
        i: integer;
begin
        result := '';
        STR2 := addcharsr(STR2, #0, length(STR1));

        for i := 1 to length(STR1) do
            result += char(byte(STR1[i])xor(byte(STR2[i])));
end;
{----------------------------------------------------------------------------------------------------------------------}
function addchars(const STR: string; ch: char; len: longint): string;
var
        i: longint;
begin
        result := STR;
        i := length(result);

        if (i < len) then
            result := stringOfChar(ch, len-i) + result;
end;
{----------------------------------------------------------------------------------------------------------------------}
function addcharsr(const STR: string; ch: char; len: longint): string;
begin
        result := STR;
        if (length(STR) >= len) then
            result := copy(STR, 1, len)
        else
            result := STR + stringOfChar(ch, len-length(STR));
end;
{----------------------------------------------------------------------------------------------------------------------}
function addspaces(const STR: string; len: longint): string;
begin
        result := addcharsr(STR, SPACE, len);
end;
{----------------------------------------------------------------------------------------------------------------------}
function delchars(const STR: string; ch: char): string;
var
        i, j: longint;
begin
        result := STR;
        i := length(result);

        while (i > 0) do
        begin
            if (ch = result[i]) then
            begin
                j := (i - 1);
                while (j > 0)and(ch = result[j]) do
                    dec(j);

                delete(result, j+1, i-j);
                i := (j + 1);
            end;

            dec(i);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function delspaces(const STR: string): string;
begin
        result := delchars(STR, SPACE);
        result := delchars(result, TAB);
end;
{----------------------------------------------------------------------------------------------------------------------}
function encodeURL(const STR: string): string;
var
    i: longint;
    ch: byte;
begin
    result := '';
    for i := 1 to length(STR) do
        if STR[i] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~'] then
            result += STR[i]
        else
        begin
            // UTF-8 символ может занимать несколько байт
            for ch in TEncoding.UTF8.GetBytes(STR[i]) do
                result += '%' + IntToHex(ch, 2);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function URLDecode(const STR: string): string;
var
    i, j, len, hex, resLen: integer;
    buf: array of char;
begin
    len := length(STR);
    resLen := len;  // Максимальная длина результирующей строки не будет больше исходной
    SetLength(buf, resLen);

    j := 0;
    I := 1;

    while (i <= len) do
    begin
        if (STR[I] = '%') then
        begin
            if (i+2 <= Len)and(STR[i+1] in ['0'..'9', 'A'..'F', 'a'..'f'])and(STR[i+2] in ['0'..'9', 'A'..'F', 'a'..'f']) then
            begin
                // Преобразуем HEX в символ
                Hex := StrToInt('$' + STR[i+1] + STR[i+2]);
                buf[j] := chr(hex);
                inc(j);
                inc(I, 3);
                continue;
            end;
        end
        else
            if (STR[i] = '+') then
                buf[j] := ' '
            else
                buf[j] := STR[i];

        inc(j);
        inc(i);
    end;

    SetString(result, pchar(@buf[0]), j);
end;
{----------------------------------------------------------------------------------------------------------------------}
function decodeURL(const STR: string): string;
var
        i, len: longint;
begin
        result := '';
        i := 0;
        len := length(STR);

        while (i < len) do
        begin
            inc(i);

            if (STR[i] < SPACE)and((STR[i] <> LF)or(STR[i] <> CR)) then
                continue;

            if (STR[i] = '+') then
            begin
                result += SPACE;
                continue;
            end;

            if (STR[i] = '%') then
            begin
                result += hextostring(copy(STR, i+1, 2));
                inc(i, 2);
                continue;
            end;

            result += STR[i];
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function encodeByte(const STR: string): string;
var
        i, len: longint;
begin
        result := '';

        len := (length(STR) div 2) - 1;
        for i := 0 to len do
            result += '%' + copy(STR, 2*i+1, 2);
end;
{----------------------------------------------------------------------------------------------------------------------}
function hextobin(hval, bval: pchar; len: longint): longint;
var
        i, j, h, l: longint;
begin
        i := len;
        while (i > 0) do
        begin
            if (hval^ in ['a'..'f','A'..'F']) then
                h := ((byte(hval^)+9) and $0f)
            else
                if (hval^ in ['0'..'9']) then
                    h := (byte(hval^) and $0f)
                else
                    break;

            inc(hval);
            if (hval^ in ['a'..'f','A'..'F']) then
                l := ((byte(hval^)+9) and $0f)
            else
                if (hval^ in ['0'..'9']) then
                    l := (byte(hval^) and $0f)
                else
                    break;

            j := l + (h << 4);
            bval^ := char(j);

            inc(hval);
            inc(bval);

            dec(i);
        end;

        result := (len - i);
end;
{----------------------------------------------------------------------------------------------------------------------}
function bintohex(bval, hval: pchar; len: longint; fSP: bool): longint;
var
        c: byte = 2;
begin
        if (fSP) then
            c := 3;

        for result := 1 to len do
        begin
            hval[0] := HEX_DIGITS[(byte(bval^) shr 4)];
            hval[1] := HEX_DIGITS[(byte(bval^) and 15)];

            inc(hval, c);
            inc(bval);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function hextostring(const STR: string): string;
var
        len: longint;
begin
        result := '';

        len := (length(STR) div 2);
        setlength(result, len);

        if (hextobin(pchar(STR), pchar(result), len) <> len) then
            result := '';
end;
{----------------------------------------------------------------------------------------------------------------------}
function stringtohex(const STR: string; fSP: bool = true): string;
var
        len: longint;
begin
        len := length(STR);

        if (fSP) then
            result := stringOfChar(#32, 3*len - 1)
        else
            result := stringOfChar(#0, 2*len);

        bintohex(pchar(STR), pchar(result), len, fSP);
end;
{----------------------------------------------------------------------------------------------------------------------}
function inttohex(value: longint; len: byte = 2): shortstring;
var
        i: longint;
begin
        result[0] := char(len);

        for i := len downto 1 do
        begin
            result[i] := HEX_DIGITS[value and $0f];
            value := (value >> 4);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function leftstr(const STR: string; len: longint): string;
begin
        result := copy(STR, 1, len);
end;
{----------------------------------------------------------------------------------------------------------------------}
function rightstr(const STR: string; len: longint): string;
var
        l: longint;
begin
        l := length(STR);

        if (len > l) then
            len := l;

        result := copy(STR, l - len + 1, len);
end;
{----------------------------------------------------------------------------------------------------------------------}
function isDigitsOnly(const STR: string): bool;
var
        i: longint;
begin
        if (STR = '') then
            exit(false);

        i := 1;
        result := true;

        while (result)and(i <= length(STR)) do
        begin
            result := (STR[i] in ['0'..'9']);
            inc(i);
        end;
end;

{----------------------------------------------------------------------------------------------------------------------}
function clearDigits(const STR: string): string;
var
        i: longint;
begin
        result := '';

        for i := 1 to length(STR) do
            if (STR[i] in ['0'..'9']) then
                result += STR[i];
end;
{----------------------------------------------------------------------------------------------------------------------}
function escapeQuoters(const STR: string): string;
var
        i: longint;
begin
        result := '';
        for i := 1 to length(STR) do
        begin
            if (STR[i] = '"') then
                result += '\';
            result += STR[i];
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function upcase(const STR: string): string;
var
        i, len: longint;
begin
        len := length(STR);
        result := STR;

        for i := 1 to len do
            if (STR[i] in ['a'..'z']) then
                result[i] := char(byte(STR[i]) xor $20)
            else
                result[i] := STR[i];
end;
{----------------------------------------------------------------------------------------------------------------------}
function lowercase(const STR: string): string;
var
        i, len: longint;
begin
        len := length(STR);
        result := STR;

        for i := 1 to len do
            if (STR[i] in ['A'..'Z']) then
                result[i] := char(byte(STR[i]) xor $20)
            else
                result[i] := STR[i];
end;
{----------------------------------------------------------------------------------------------------------------------}
function get_param(const SPLIT: string; var VSTR: string): string;
var
        x: longint;
begin
        x := pos(SPLIT, VSTR);
        if (x > 0) then
        begin
            result := copy(VSTR, 1, x-1);
            VSTR := copy(VSTR, x+1, length(VSTR)-x);
        end
        else
        begin
            result := VSTR;
            VSTR := '';
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function split_command(var VSTR, VCMD, VVAL: string): bool;
var
        LSTR: string = '';
           i: longint;
begin
        {---- Check for exit or quit command ----}
        VCMD := lowercase(copy(VSTR, 1, 4));
        case (VCMD) of
            'quit',
            'exit':
                exit(true);
        end;

        {---- Check for HTTP request ----}
        if (copy(VSTR, 1, 5) = 'GET /')and(pos('HTTP', VSTR) <> 0) then
        begin
            case (lowercase(copy(VSTR, 1, 13))) of
                'get /showstat':
                    VCMD := 'httpstat';
                //----
                'get /showqueu':
                    VCMD := 'httpqueue';
                //----
                'get /show_sou':
                    VCMD := 'httpsou';
            else
                VCMD := 'httpfail';
            end;

            exit(true);
        end;

        {---- Start parsing ----}
        i := pos(';', VSTR);
        if (i = 0) then
            exit(false);

        LSTR := lowercase(copy(VSTR, 1, i-1));
        delete(VSTR, 1, i);

        i := pos(':', LSTR);
        if (i = 0) then
            exit(false);

        VCMD := copy(LSTR, 1, i-1);
        VVAL := copy(LSTR, i+1, length(LSTR)-i);

        result := true;
end;
{---------------------------------------------------------------------------------------------------------------------}
function split_params(const STR: string; var params: TStringList): bool;
var
        len: longint;
begin
        params.clear;
        len := length(STR);
        if (STR[len] = params.delimiter) then
            dec(len);

        params.delimitedText := copy(STR, 1, len);

        result := (params.count > 0);
end;
{---------------------------------------------------------------------------------------------------------------------}
{---------------------------------------------------------------------------------------------------------------------}
function generate_crc_table: t_crc_table;
var
        i, j: byte;
        crc: word;
begin
        for i := 0 to 255 do
        begin
            crc := i;

            for j := 0 to 7 do
                if ((crc and 1) = 1) then
                    crc := ((crc shr 1) xor crc_polynom)
                else
                    crc := (crc shr 1);

            result[i] := crc;
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
function calculate_crc(DATA: string; table: t_crc_table; init_fcs: word = $FFFF; xor_out: word = $FFFF): word;
var
        i: longint;
begin
        result := init_fcs;

        for i := 1 to (length(DATA)) do
            result := (result shr 8) xor table[(result xor byte(DATA[i])) and $FF];

        result := (result xor xor_out);
end;
{---------------------------------------------------------------------------------------------------------------------}
{---------------------------------------------------------------------------------------------------------------------}
function OTAF_ERR(code: longint): string;
begin
        case (code) of
            C_ECODE_SUCCESS:          result := 'SUCCESS';
            C_ECODE_TERM_OFFLINE:     result := 'TERMINAL IS OFFLINE';
            C_ECODE_SENDSMS_FAIL:     result := 'SMS NOT SEND';
            C_ECODE_START_OTAPA_FAIL: result := 'START OTAPA SESSION FAILED';
            C_ECODE_STOP_OTAPA_FAIL:  result := 'STOP OTAPA SESSION FAILED';
            C_ECODE_AUTH_SIGN_FAIL:   result := 'OTASP: GENERATE AUTH SIGNATURE FAILED';
            C_ECODE_CHECK_SPASM_FAIL: result := 'VALIDATE REQUEST (SPASM) FAILED';
            C_ECODE_CHECK_SPC_FAIL:   result := 'VALIDATE REQUEST (SPC) FAILED';
            C_ECODE_ATTACH_MSC_FAIL:  result := 'ATTACH MSC TO OTAF FAILED';
            C_ECODE_RELEASE_TRN_FAIL: result := 'RELEASE TRN FAILED';
            C_ECODE_COMMIT_FAIL:      result := 'COMMIT REQUEST FAILED';
            C_ECODE_REC_NEWMSID_FAIL: result := 'RECORD NEW MSID FAILED';
            C_ECODE_CHANGE_SPC_FAIL:  result := 'CHANGE SPC FAILED';
            C_ECODE_SLEEP_TASK:       result := 'SLEEP TASK';
            C_ECODE_SAME_TASK_FAIL:   result := 'REMOVE SAME FAILED TASK';
            C_ECODE_MS_INACTIVE:      result := 'ANOTHER NETWORK';
            C_ECODE_NO_SUBSCRIBER:    result := 'UNKNOWN SUBSCRIBER';
            C_ECODE_SENDOTA_FAIL:     result := 'SEND OTA MESSAGE FAIL';
            C_ECODE_ISYSPOS_FAIL:     result := 'IPOS REQUEST FAILED';
            C_ECODE_SSPR_DLOAD_FAIL:  result := 'SSPR DOWNLOAD REQUEST FAILED';
            C_ECODE_SSPR_EXTDIM_FAIL: result := 'EXTENDED PRL DIMENTIONS REQUEST ERROR';
            C_ECODE_SSPR_DIM_FAIL:    result := 'PRL DIMENTIONS REQUEST ERROR';
            C_ECODE_SSPR_PRL_FAIL:    result := 'PRL REQUEST ERROR';
            C_ECODE_GETCONF_FAIL:     result := 'CONFIGURATION REQUEST FAILED';
            C_ECODE_DECODE_ANAM_FAIL: result := 'ANALOG/CDMA NAM DECODING ERROR';
            C_ECODE_DECODE_MDN_FAIL:  result := 'MDN DECODING ERROR';
            C_ECODE_DECODE_CNAM_FAIL: result := 'CDMA NAM DECODING ERROR';
            C_ECODE_DECODE_IMSI_FAIL: result := 'IMSI DECODING ERROR';
            C_ECODE_GETPCAP_FAIL:     result := 'PROTOCOL CAPABILITY REQUEST FAILED';
            C_ECODE_SETCONF_FAIL:     result := 'DOWNLOAD CONFIG REQUEST FAILED';
            C_ECODE_CONF_ANAM_FAIL:   result := 'WRITE ANALOG/CDMA NAM ERROR';
            C_ECODE_CONF_MDN_FAIL:    result := 'WRITE MDN ERROR';
            C_ECODE_CONF_CNAM_FAIL:   result := 'WRITE CDMA NAM ERROR';
            C_ECODE_CONF_IMSI_FAIL:   result := 'WRITE IMSI ERROR';
            C_ECODE_GEN_PUB_ENC_FAIL: result := 'GENERATE PUBLIC ENCRYPTION VALUES FAILED';
            C_ECODE_MS_KEY_FAIL:      result := 'MS KEY REQUEST FAILED';
            C_ECODE_KEY_GEN_FAIL:     result := 'KEY GENERATION REQUEST FAILED';
            C_ECODE_GEN_AKEY_FAIL:    result := 'GENERATE A-KEY FAILED';
            C_ECODE_SSD_UPDATE_FAIL:  result := 'SSD UPDATE REQUEST FAILED';
            C_ECODE_COMMIT_AKEY_FAIL: result := 'COMMIT A-KEY FAILED';

            C_ECODE_USER_NOT_REGISTERED: result := 'OFFLINE';
            //----
            else
                result := 'UNKNOWN';
        end;
end;
{---------------------------------------------------------------------------------------------------------------------}
function DESC_ERR(code: longint): string;
begin
        case (code) of
            C_ECODE_CONN_ERROR:       result := 'SOCKET CONNECTION ERROR';
            C_ECODE_NETIO_ERROR:      result := 'SOCKET IO ERROR';
            C_ECODE_NO_INIT:          result := 'NO INIT RESPONSE';
            C_ECODE_NO_DATA:          result := 'NO VALID DATA';
            C_ECODE_PROC_EXCEPTION:   result := 'PROCESSING EXCEPTION';
            C_ECODE_PROC_TIMEOUT:     result := 'PROCESSING TIMEOUT';

            C_ECODE_DB_ERROR:         result := 'DATABASE ERROR';
            //----
            else
                result := 'UNKNOWN';
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
