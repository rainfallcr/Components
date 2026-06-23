unit libcommon;
{$MODESWITCH ADVANCEDRECORDS}
{$inline on}
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        classes, math;
{----------------------------------------------------------------------------------------------------------------------}
type
        t_string_array = array of string;
        t_crc_table = array[0..255] of word;

        bool = type boolean;
        {--------------------------------------------------------------------------------------------------------------}
        t_rbits = record
            bitBuf: array of byte;
            bCount: longint;
            offset: byte;

            function getByte: byte; inline;
            function getBits(len: byte): byte;

            procedure Init(len: longint);
            procedure Reset; inline;
            procedure setByte(value: byte); inline;
            procedure setBits(value, len: byte);
        end;
        {--------------------------------------------------------------------------------------------------------------}
        t_mutex = class
        private
            fcs: TRtlCriticalSection;
        public
            constructor Create();
            destructor  Destroy(); override;

            procedure Lock(); inline;
            procedure unLock(); inline;
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
                                  #$7F..#$FF, ';', '/', '?', ':', '@', '=', '&', '#', '+', ''''];

        {---- CRC Polynom for generated table ----}
        crc_polynom     = $8408;
{----------------------------------------------------------------------------------------------------------------------}
var
        d_start_time: tdatetime;
        worker_event: pointer; { pRTLEvent! }

        htob: array[0..255] of byte;

{---- t_rbits fuctional ----}
function  getbit(value, index: byte): bool;
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
function convert_TOD(tod: longint): string;

{---- String functions ----}
function nibbleSwap(const STR: string): string;
function addChars(const STR: string; ch: char; len: longint): string;
function addCharsr(const STR: string; ch: char; len: longint): string;
function addspaces(const STR: string; len: longint): string;
function delChars(const STR: string; ch: char): string;
function delSpaces(const STR: string): string;
function encodeURL(const STR: string): string;
function decodeURL(const STR: string): string;
function encodeByte(const STR: string): string;
function hextostring(const STR: string): string;
function stringToHex(const STR: string; fSP: bool = true): string;
function intToHex(value: longint; len: byte = 2): shortstring;
function clearDigits(const STR: string): string;
function escapeQuoters(const STR: string): string;
function upCase(const STR: string): string;
function lowerCase(const STR: string): string;
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
        sysUtils, unix;
{----------------------------------------------------------------------------------------------------------------------}
procedure createHtoBtable();
var
        i: byte;
begin
        FillChar(htob, 256, 0);

        for i := 0 to 9 do
            htob[Ord('0') + i] := i;

        for i := 0 to 5 do
        begin
            htob[Ord('A') + i] := 10 + i;
            htob[Ord('a') + i] := 10 + i;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
constructor t_mutex.Create();
begin
        inherited Create();

        initCriticalSection(fcs);
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor t_mutex.Destroy();
begin
        doneCriticalSection(fcs);

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_mutex.Lock(); inline;
begin
        EnterCriticalSection(fcs);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_mutex.unLock(); inline;
begin
        LeaveCriticalSection(fcs);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function t_rbits.getByte: byte; inline;
begin
        result := getBits(8);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_rbits.getBits(len: byte): byte;
var
        b: byte;
begin
        if (len = 0) then
            exit(0);

        if (bCount >= Length(bitBuf)) then
            raise Exception.Create('getBits(): size mismatch!');

        {---- Читаем байт и сдвигаем влево ----}
        b := bitBuf[bCount] shl offset;

        {---- Если биты пересекают границу байта, подтягиваем из следующего ----}
        if (offset + len > 8)and(bCount + 1 < Length(bitBuf)) then
            b := b or (bitBuf[bCount+1] shr (8 - offset));

        {---- Выравниваем вправо ----}
        result := b shr (8 - len);

        {---- Обновляем курсор ----}
        offset += len;

        if (offset >= 8) then
        begin
            inc(bCount);
            offset -= 8;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_rbits.Init(len: longint);
begin
        SetLength(bitBuf, (len div 8) + 1);
        FillChar(bitBuf[0], Length(bitBuf), 0);

        Reset();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_rbits.Reset; inline;
begin
        offset := 0;
        bCount := 0;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_rbits.setByte(value: byte); inline;
begin
        setBits(value, 8);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_rbits.setBits(value, len: byte);
var
        b: byte;
begin
        if (len = 0) then
            exit();

        if (bCount >= Length(bitBuf)) then
            raise Exception.Create('setBits(): size mismatch!');

        {---- Выравниваем значение влево ----}
        b := value shl (8 - len);

        {---- Записываем в текущий байт ----}
        bitBuf[bCount] := bitBuf[bCount] or (b shr offset);

        {---- Если пересекли границу, пишем остаток в следующий байт ----}
        if (offset + len > 8)and(bCount + 1 < Length(bitBuf)) then
            bitBuf[bCount+1] := bitBuf[bCount+1] or (b shl (8-offset));

        {---- Обновляем курсор ----}
        offset += len;

        if (offset >= 8) then
        begin
            inc(bCount);
            offset -= 8;
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
        value := (value and (($01 << index) xor $FF))or(byte(fstate) << index);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure putbitword(var value: word; index: byte; fstate: bool);
begin
        value := (value and (($01 << index) xor $FFFF))or(word(fstate) << index);
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

        Result := format('%s:%s:%s.%s', [SH, SM, SS, DS]);
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
        Result := '';

        for i := 1 to Length(DT) do
            if (DT[i] in ['0'..'9']) then
                Result += DT[i];
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
function nibbleSwap(const STR: string): string;
var
        i: longint;
begin
        Result := '';

        for i := 1 to (length(STR) div 2) do
            Result += STR[2*i] + STR[2*i-1];
end;
{----------------------------------------------------------------------------------------------------------------------}
function addChars(const STR: string; ch: char; len: longint): string;
var
        l: longint;
begin
        Result := STR;
        l := Length(Result);

        if (l < len) then
            Result := stringOfChar(ch, len-l) + Result;
end;
{----------------------------------------------------------------------------------------------------------------------}
function addCharsR(const STR: string; ch: char; len: longint): string;
var
        l: longint;
begin
        Result := STR;
        l := Length(Result);

        if (l >= len) then
            result := copy(STR, 1, len)
        else
            result := STR + stringOfChar(ch, len - l);
end;
{----------------------------------------------------------------------------------------------------------------------}
function addSpaces(const STR: string; len: longint): string;
begin
        Result := addCharsR(STR, SPACE, len);
end;
{----------------------------------------------------------------------------------------------------------------------}
function delChars(const STR: string; ch: char): string;
var
        i, j: longint;
begin
        Result := STR;
        i := Length(Result);

        while (i > 0) do
        begin
            if (ch = Result[i]) then
            begin
                j := (i - 1);

                while (j > 0)and(ch = Result[j]) do
                    dec(j);

                delete(Result, j+1, i-j);

                i := (j + 1);
            end;

            dec(i);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function delSpaces(const STR: string): string;
begin
        Result := delChars(STR, SPACE);
        Result := delChars(Result, TAB);
end;
{----------------------------------------------------------------------------------------------------------------------}
function encodeURL(const STR: string): string;
var
        i, len, resLen: longint;
        ch: char;
        P: pchar;
begin
        len := Length(STR);
        SetLength(Result, len * 3);
        P := pchar(Result);
        resLen := 0;

        for i := 1 to len do
        begin
            ch := STR[i];

            if (ch in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~']) then
            begin
                P^ := ch; 
                Inc(P);
                Inc(resLen);
            end
            else
            begin
                P^ := '%';
                Inc(P);

                P^ := HEX_DIGITS[byte(ch) shr 4];
                Inc(P);

                P^ := HEX_DIGITS[byte(ch) and $0F];
                Inc(P);

                Inc(resLen, 3);
            end;
        end;

        SetLength(Result, resLen);
end;
{----------------------------------------------------------------------------------------------------------------------}
function decodeURL(const STR: string): string;
var
        i, j, len: longint;
        P: pchar;
begin
        len := Length(STR);
        SetLength(Result, len);
        P := pchar(Result);

        j := 0;
        i := 1;

        while (i <= len) do
        begin
            if (STR[i] = '%') then
            begin
                if (i+2 <= len)and(STR[i+1] in ['0'..'9', 'A'..'F', 'a'..'f'])and(STR[i+2] in ['0'..'9', 'A'..'F', 'a'..'f']) then
                begin
                    P^ := char((htob[Ord(STR[i+1])] shl 4) or htob[Ord(STR[i+2])]);
                    inc(P);
                    inc(j);
                    inc(i, 3);
                end
                else { something wrong! }
                begin
                    P^ := STR[i];
                    inc(P);
                    inc(j);
                    inc(i);
                end;
            end
            else
            begin
                if (STR[i] = '+') then
                    P^ := ' '
                else
                    P^ := STR[i];

                inc(P);
                inc(j);
                inc(i);
            end
        end;

        SetLength(Result, j);
end;
{----------------------------------------------------------------------------------------------------------------------}
function encodeByte(const STR: string): string;
var
        i, len: longint;
begin
        Result := '';

        len := (length(STR) div 2) - 1;
        for i := 0 to len do
            Result += '%' + copy(STR, 2*i+1, 2);
end;
{----------------------------------------------------------------------------------------------------------------------}
function hextobin(hval, bval: pchar; len: longint): longint;
var
        i: longint;
begin
        result := 0;

        for i := 1 to len do
        begin
            if not (hval^ in ['0'..'9', 'a'..'f', 'A'..'F']) or
               not ((hval+1)^ in ['0'..'9', 'a'..'f', 'A'..'F']) then
               break;

            bval^ := char((htob[byte(hval^)] shl 4) or htob[byte((hval+1)^)]);
            inc(hval, 2);
            inc(bval);

            inc(result);
        end;
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
            hval[0] := HEX_DIGITS[(byte(bval^) shr $04)];
            hval[1] := HEX_DIGITS[(byte(bval^) and $0F)];

            inc(hval, c);
            inc(bval);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function hextostring(const STR: string): string;
var
        len: longint;
begin
        Result := '';

        len := (length(STR) div 2);
        SetLength(Result, len);

        if (hextobin(pchar(STR), pchar(Result), len) <> len) then
            Result := '';
end;
{----------------------------------------------------------------------------------------------------------------------}
function stringtohex(const STR: string; fSP: bool = true): string;
var
        len: longint;
begin
        len := Length(STR);

        if (fSP) then
            Result := StringOfChar(#32, 3*len - 1)
        else
            Result := StringOfChar(#0, 2*len);

        bintohex(pchar(STR), pchar(Result), len, fSP);
end;
{----------------------------------------------------------------------------------------------------------------------}
function inttohex(value: longint; len: byte = 2): shortstring;
var
        i: longint;
begin
        Result[0] := char(len);

        for i := len downto 1 do
        begin
            Result[i] := HEX_DIGITS[value and $0f];
            value := (value >> 4);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function leftStr(const STR: string; len: longint): string;
begin
        Result := copy(STR, 1, len);
end;
{----------------------------------------------------------------------------------------------------------------------}
function rightStr(const STR: string; len: longint): string;
var
        l: longint;
begin
        l := Length(STR);

        if (len > l) then
            len := l;

        Result := copy(STR, l - len + 1, len);
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

        while (result)and(i <= Length(STR)) do
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
        Result := '';

        for i := 1 to Length(STR) do
            if (STR[i] in ['0'..'9']) then
                Result += STR[i];
end;
{----------------------------------------------------------------------------------------------------------------------}
function escapeQuoters(const STR: string): string;
var
        i: longint;
begin
        Result := '';

        for i := 1 to Length(STR) do
        begin
            if (STR[i] = '"') then
                Result += '\';

            Result += STR[i];
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function upCase(const STR: string): string;
var
        i: longint;
begin
        Result := STR;

        for i := 1 to Length(Result) do
            if (Result[i] in ['a'..'z']) then
                Result[i] := char(byte(Result[i]) xor $20);
end;
{----------------------------------------------------------------------------------------------------------------------}
function lowerCase(const STR: string): string;
var
        i: longint;
begin
        Result := STR;

        for i := 1 to Length(Result) do
            if (Result[i] in ['A'..'Z']) then
                Result[i] := char(byte(Result[i]) xor $20);
end;
{----------------------------------------------------------------------------------------------------------------------}
function get_param(const SPLIT: string; var VSTR: string): string;
var
        x, l: longint;
begin
        x := pos(SPLIT, VSTR);
        if (x > 0) then
        begin
            Result := copy(VSTR, 1, x-1);

            l := Length(SPLIT);
            VSTR := copy(VSTR, x + l, Length(VSTR) - x - l + 1);
        end
        else
        begin
            Result := VSTR;
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
        VCMD := lowerCase(copy(VSTR, 1, 4));
        case (VCMD) of
            'quit',
            'exit':
                exit(true);
        end;

        {---- Check for HTTP request ----}
        if (copy(VSTR, 1, 5) = 'GET /')and(pos('HTTP', VSTR) <> 0) then
        begin
            case (lowerCase(copy(VSTR, 1, 13))) of
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

        LSTR := lowerCase(copy(VSTR, 1, i-1));
        delete(VSTR, 1, i);

        i := pos(':', LSTR);
        if (i = 0) then
            exit(false);

        VCMD := copy(LSTR, 1, i-1);
        VVAL := copy(LSTR, i+1, Length(LSTR)-i);

        result := true;
end;
{---------------------------------------------------------------------------------------------------------------------}
function split_params(const STR: string; var params: TStringList): bool;
var
        len: longint;
begin
        len := Length(STR);

        if (len = 0) then
            exit(false);

        params.Clear();

        if (STR[len] = params.Delimiter) then
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

        for i := 1 to (Length(DATA)) do
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
initialization
        createHtoBtable();
end.
