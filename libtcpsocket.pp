unit libtcpsocket;
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        baseunix, sockets,
        libcommon, libkvlist;
{----------------------------------------------------------------------------------------------------------------------}
type
        e_SO = (
            OPT_Linger,
            OPT_RecvBuf,
            OPT_SendBuf,
            OPT_NonBlock,
            OPT_RecvTimeout,
            OPT_SendTimeout,
            OPT_Reuse,
            OPT_KeepAlive
        );

        t_sock_opt = record
            option: e_SO;
            enable: bool;
            value: longint;
        end;

        t_tcp_socket = class(TObject)
        private
            fs,
            fe,
            ftlen,
            fclen: longint;

            FBUF,
            FMSG,
            FTERM: string;

            fHeader: bool;

            fhdl: ts_kvlist;

            fso: t_sock_opt;

            fl_addr,
            fr_addr: sockaddr;

            fFDSet: TFDSet;

            function get_EDESC: string;
            function get_sock_IP: string;
            function get_peer_IP: string;
            function get_sock_port: longint;
            function get_peer_port: longint;

            function buf_count: longint;
            function recv_packet(len: longint): string;

            procedure send_buffer(buf: pointer; len: longint);
            procedure get_addr;
            procedure set_socket(s: longint);
            procedure check_socket(s: longint);
            procedure set_addr(var addr: sockaddr; const IP, PORT: string);
            procedure set_term(const TRM: string);
            procedure set_option(const opt: t_sock_opt);

        public
            constructor Create();
            destructor  Destroy; override;

            function Accept: longint;
            function can_Read(timeout: longint): bool;
            function can_Write(timeout: longint): bool;

            function recv_SipMsg(timeout: longint): string;

            function recv_String(timeout: longint): string;
            function send_String(const STR: string; const TERM: string  = ''): bool;

            function recv_Buffer(timeout: longint): string;
            function recv_Byte(timeout: longint): byte;

            procedure Connect(const IP, PORT: string);
            procedure Bind(const IP, PORT: string);
            procedure Listen;

            procedure create_socket;
            procedure close_socket;

            procedure set_ReUse(enable: bool);
            procedure set_Linger(enable: bool; l: longint);
            procedure set_Keepalive(enable: bool);
            procedure set_SendTimeout(enable: bool; t: longint);
            procedure set_RecvTimeout(enable: bool; t: longint);
            procedure set_Timeout(enable: bool; t: longint);
            procedure set_NonBlock(enable: bool);

            property socket: longint read fs write set_socket;
            property bcount: longint read buf_count;
            property SOCK_IP: string read get_sock_IP;
            property PEER_IP: string read get_peer_IP;
            property sock_port: longint read get_sock_port;
            property peer_port: longint read get_peer_port;
            property error: longint read fe;
            property EDESC: string read get_EDESC;
            property TERM: string read FTERM write set_term;
        end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
implementation
uses
        sysutils, termio;
{----------------------------------------------------------------------------------------------------------------------}
const
        ANYHOST         = '0.0.0.0';
        ANYPORT         = '0';

        INVALID_SOCKET  = (-1);
        SOMAXCONN       = 1024;

        C_BLOCK_TIMEOUT = 15000;

        EsysEHOST_NOT_FOUND = 1;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
constructor t_tcp_socket.Create();
begin
        inherited Create();

        FBUF := '';
        FMSG := '';

        FTERM := CRLF;
        ftlen := 2;

        fhdl := ts_kvlist.Create();
        fhdl.Sorted := false;
        fhdl.upKeys := true;
        fhdl.Delimiter := CRLF;

        fclen := 0;
        fHeader := true;

        fs := INVALID_SOCKET;
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor t_tcp_socket.Destroy();
begin
        close_socket();

        fhdl.Free();

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.get_EDESC: string;
begin
        case (fe) of
            0:                   Result := '';
            EsysEINTR:           Result := 'Interrupted system call';
            EsysEBADF:           Result := 'Bad file number';
            EsysEACCES:          Result := 'Permission denied';
            EsysEFAULT:          Result := 'Bad address';
            EsysEINVAL:          Result := 'Invalid argument';
            EsysEMFILE:          Result := 'Too many open files';
            EsysEWOULDBLOCK:     Result := 'Operation would block';
            EsysEINPROGRESS:     Result := 'Operation now in progress';
            EsysEALREADY:        Result := 'Operation already in progress';
            EsysENOTSOCK:        Result := 'Socket operation on nonsocket';
            EsysEDESTADDRREQ:    Result := 'Destination address required';
            EsysEMSGSIZE:        Result := 'Message too long';
            EsysEPROTOTYPE:      Result := 'Protocol wrong type for Socket';
            EsysENOPROTOOPT:     Result := 'Protocol not available';
            EsysEPROTONOSUPPORT: Result := 'Protocol not supported';
            EsysESOCKTNOSUPPORT: Result := 'Socket not supported';
            EsysEPFNOSUPPORT:    Result := 'Protocol family not supported';
            EsysEAFNOSUPPORT:    Result := 'Address family not supported';
            EsysEADDRINUSE:      Result := 'Address already in use';
            EsysEADDRNOTAVAIL:   Result := 'Can''t assign requested address';
            EsysENETDOWN:        Result := 'Network is down';
            EsysENETUNREACH:     Result := 'Network is unreachable';
            EsysENETRESET:       Result := 'Network dropped connection on reset';
            EsysECONNABORTED:    Result := 'Software caused connection abort';
            EsysECONNRESET:      Result := 'Connection reset by peer';
            EsysENOBUFS:         Result := 'No buffer space available';
            EsysEISCONN:         Result := 'Socket is already connected';
            EsysENOTCONN:        Result := 'Socket is not connected';
            EsysESHUTDOWN:       Result := 'Can''t send after Socket shutdown';
            EsysETOOMANYREFS:    Result := 'Too many references:can''t splice';
            EsysETIMEDOUT:       Result := 'Connection timed out';
            EsysECONNREFUSED:    Result := 'Connection refused';
            EsysELOOP:           Result := 'Too many levels of symbolic links';
            EsysENAMETOOLONG:    Result := 'File name is too long';
            EsysEHOSTDOWN:       Result := 'Host is down';
            EsysEHOSTUNREACH:    Result := 'No route to host';
            EsysENOTEMPTY:       Result := 'Directory is not empty';
            EsysEUSERS:          Result := 'Too many users';
            EsysEDQUOT:          Result := 'Disk quota exceeded';
            EsysESTALE:          Result := 'Stale NFS file handle';
            EsysEREMOTE:         Result := 'Too many levels of remote in path';
            EsysEHOST_NOT_FOUND: Result := 'Host not found';
            ESysENOTRECOVERABLE: Result := 'Non recoverable error';
            ESysENODATA:         Result := 'No data available'
        else
            Result := format('Other socket error (%d)', [fe]);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.get_sock_IP: string;
begin
        Result := netaddrtostr(fl_addr.sin_addr);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.get_peer_IP: string;
begin
        Result := netaddrtostr(fr_addr.sin_addr);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.get_sock_port: longint;
begin
        result := ntohs(fl_addr.sin_port);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.get_peer_port: longint;
begin
        result := ntohs(fr_addr.sin_port);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.buf_count: longint;
var
        x: longint = 0;
begin
        result := 0;

        if (fpIoCtl(fs, FIONREAD, @x) = 0) then
            if (x <= C_64K) then
                result := x
            else
                result := C_64K;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.recv_packet(len: longint): string;
begin
        Result := '';
        SetLength(Result, len);

        len := fpRecv(fs, pointer(Result), len, MSG_NOSIGNAL);

        if (len >= 0) then
            SetLength(Result, len)
        else
        begin
            Result := '';
            fe := EsysECONNRESET;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.recv_Buffer(timeout: longint): string;
var
        len: longint;
begin
        Result := '';
        fe := 0;

        len := buf_count();
        if (len > 0) then
            Result := recv_packet(len)
        else
            if (can_Read(timeout)) then
            begin
                len := buf_count();
                if (len > 0) then
                    Result := recv_packet(len)
                else
                    fe := EsysECONNRESET;
            end
            else
                fe := EsysETIMEDOUT;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.recv_Byte(timeout: longint): byte;
begin
        result := 0;
        fe := 0;

        if (FBUF = '') then
            FBUF := recv_Buffer(timeout);

        if (fe = 0)and(FBUF <> '') then
        begin
            result := byte(FBUF[1]);
            system.Delete(FBUF, 1, 1);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.send_Buffer(buf: pointer; len: longint);
var
        pbuf: pointer;
        dc, dl, s: longint;
begin
        fe := 0;
        dc := 0;

        while (dc < len) do
        begin
            dl := (len - dc);
            if (dl > C_64K) then
                dl := C_64K;

            if (dl > 0) then
            begin
                pbuf := pointer(pAnsiChar(buf) + dc);

                s := fpSend(fs, pbuf, dl, MSG_NOSIGNAL);
                check_socket(s);

                if (fe = EsysEWOULDBLOCK) then
                begin
                    if (can_Write(C_BLOCK_TIMEOUT)) then
                    begin
                        s := fpSend(fs, pbuf, dl, MSG_NOSIGNAL);
                        check_socket(s);
                    end
                    else
                        fe := EsysETIMEDOUT;
                end;

                if (fe <> 0)or(s = INVALID_SOCKET) then
                    break;

                inc(dc, s);
            end
            else
                break;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.get_addr;
var
        x: longint;
begin
        x := sizeOf(sockAddr);
        fl_addr := default(sockAddr);
        fr_addr := default(sockAddr);

        fpGetSockName(fs, @fl_addr, @x);
        fpGetPeerName(fs, @fr_addr, @x);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_socket(s: longint);
begin
        fs := s;

        fpFD_ZERO(fFDSet);
        fpFD_SET(fs, fFDSet);

        get_addr();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.check_socket(s: longint);
begin
        if (s <> INVALID_SOCKET) then
            fe := 0
        else
            fe := fpGetErrNo();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_addr(var addr: sockAddr; const IP, PORT: string);
begin
        addr := default(sockAddr);

    with (addr) do
    begin
        sin_addr := strtonetaddr(IP);
        sin_port := htons(strToIntDef(PORT, 0));
        sin_family := AF_INET;
    end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_term(const TRM: string);
begin
        ftlen := length(TRM);
        FTERM := TRM;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_option(const opt: t_sock_opt);
var
        l: Linger;
        x: longint;
        pv: pointer;
        tv: TTimeVal;
begin
        if (fs = INVALID_SOCKET) then
            exit();

        case (opt.option) of
            OPT_Linger:
            begin
                l.l_onoff := byte(opt.enable);
                l.l_linger := (opt.value div 1000);
                fe := fpSetSockOpt(fs, SOL_SOCKET, SO_LINGER, @l, sizeOf(Linger));
            end;
            //----
            OPT_RecvBuf:
                fe := fpSetSockOpt(fs, SOL_SOCKET, SO_RCVBUF, @opt.value, sizeOf(opt.value));
            //----
            OPT_SendBuf:
                fe := fpSetSockOpt(fs, SOL_SOCKET, SO_SNDBUF, @opt.value, sizeOf(opt.value));
            //----
            OPT_NonBlock:
            begin
                x := byte(opt.enable);
                fpIoCtl(fs, FIONBIO, @x);
                fe := fpGetErrno();
            end;
            //----
            OPT_RecvTimeout:
            begin
                tv.tv_sec := (opt.value div 1000);
                tv.tv_usec := (opt.value mod 1000)*1000;
                fe := fpSetSockOpt(fs, SOL_SOCKET, SO_RCVTIMEO, @tv, sizeOf(tv));
            end;
            //----
            OPT_SendTimeout:
            begin
                tv.tv_sec := (opt.value div 1000);
                tv.tv_usec := (opt.value mod 1000)*1000;
                fe := fpSetSockOpt(fs, SOL_SOCKET, SO_SNDTIMEO, @tv, sizeOf(tv));
            end;
            //----
            OPT_Reuse:
            begin
                x := byte(opt.enable);
                pv := @x;
                fe := fpSetSockOpt(fs, SOL_SOCKET, SO_REUSEADDR, pv, sizeOf(x));
            end;
            //----
            OPT_KeepAlive:
            begin
                x := byte(opt.enable);
                pv := @x;
                fe := fpSetSockOpt(fs, SOL_SOCKET, SO_KEEPALIVE, pv, sizeOf(x));
            end;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.Accept: longint;
var
        x: longint;
begin
        x := sizeOf(sockaddr);
        result := fpAccept(fs, @fr_addr, @x);

        if (result < 0) then
            fe := fpGetErrNo()
        else
            fe := 0;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.can_Read(timeout: longint): bool;
var
        FDSet: TFDSet;
        s: longint = 0;
begin
        repeat
            FDSet := fFDSet;

            s := fpSelect(fs+1, @FDSet, nil, nil, timeout);

            if (s < 0) then
                fe := fpGetErrNo();
        until (s >= 0)or(fe <> EsysEINTR);

        result := (s > 0);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.can_Write(timeout: longint): bool;
var
        FDSet: TFDSet;
        s: longint = 0;
begin
        FDSet := fFDSet;

        repeat
            s := fpSelect(fs+1, nil, @FDSet, nil, timeout);

            if (s < 0) then
                fe := fpGetErrNo();

        until (s >= 0)or(fe <> EsysEINTR);

        result := (s > 0);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.recv_SipMsg(timeout: longint): string;
var
        i: longint;
begin
        Result := '';

        if (FBUF <> '') then
        begin
            if (fHEADER) then
            begin
                i := pos(CRLF2, FBUF);

                if (i > 0) then
                begin
                    FMSG := copy(FBUF, 1, i+3);
                    system.Delete(FBUF, 1, i+3);

                    fhdl.Text := FMSG;
                    fclen := strToIntDef(fhdl.KVAL['CONTENT-LENGTH'], 0);

                    if (fclen > 0) then
                        fHeader := false
                    else
                        result := FMSG;
                end;
            end;

            if (not fHeader)and(length(FBUF) >= fclen) then
            begin
                FMSG += copy(FBUF, 1, fclen);
                system.Delete(FBUF, 1, fclen);

                fHeader := true;
                result := FMSG;
            end;
        end;

        if (result = '') then
            FBUF += recv_Buffer(timeout);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.recv_String(timeout: longint): string;
var
        i: longint = 0;
begin
        Result := '';

        if (pos(FTERM, FBUF) = 0) then
            FBUF += recv_Buffer(timeout);

        if (fe = 0) then
        begin
            i := pos(FTERM, FBUF);

            if (i > 0) then
            begin
                dec(i);

                Result := copy(FBUF, 1, i);

                system.delete(FBUF, 1, i+ftlen);
            end;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_tcp_socket.send_String(const STR: string; const TERM: string = ''): bool;
var
        MSG: string = '';
        buf: pointer = nil;
begin
        MSG := STR + TERM;
        buf := pointer(MSG);

        send_buffer(buf, length(MSG));
        result := (fe = 0);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.Connect(const IP, PORT: string);
begin
        fe := 0;
        set_addr(fr_addr, IP, PORT);

        if (fs = INVALID_SOCKET) then
            create_socket();

        if (fe = 0) then
            if (fpConnect(fs, @fr_addr, sizeOf(sockAddr)) < 0) then
                fe := fpGetErrNo()
            else
                get_addr();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.Bind(const IP, PORT: string);
begin
        if (IP = ANYHOST)and(PORT = ANYPORT) then
            fe := EsysEHOST_NOT_FOUND
        else
        begin
            fe := 0;
            set_addr(fl_addr, IP, PORT);

            if (fs = INVALID_SOCKET) then
                create_socket();

            if (fe = 0) then
                if (fpBind(fs, @fl_addr, sizeOf(sockAddr)) < 0) then
                    fe := fpGetErrNo();
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.Listen();
begin
        if (fpListen(fs, SOMAXCONN) = 0) then
            get_addr()
        else
            fe := fpGetErrNo();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.create_socket();
begin
        fe := 0;

        FBUF := '';
        FMSG := '';

        fclen := 0;
        fHEADER := true;

        if (fs = INVALID_SOCKET) then
        begin
            fs := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

            if (fs <> INVALID_SOCKET) then
            begin
                fpFD_ZERO(fFDSet);
                fpFD_SET(fs, fFDSet);
            end
            else
                fe := fpGetErrNo();
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.close_socket();
begin
        fe := 0;
        while (fe = 0)and(buf_count() > 0) do
            recv_Buffer(0);

        if (fs <> INVALID_SOCKET) then
        begin
            fpShutdown(fs, SHUT_RDWR);
            closeSocket(fs);
            fs := INVALID_SOCKET;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_ReUse(enable: bool);
begin
        fso.option := OPT_Reuse;
        fso.enable := enable;
        set_option(fso);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_Linger(enable: bool; l: longint);
begin
        fso.option := OPT_Linger;
        fso.enable := enable;
        fso.value := l;
        set_option(fso);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_Keepalive(enable: bool);
begin
        fso.option := OPT_KeepAlive;
        fso.enable := enable;
        set_option(fso);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_SendTimeout(enable: bool; t: longint);
begin
        fso.option := OPT_SendTimeout;
        fso.enable := enable;
        fso.value := t;
        set_option(fso);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_RecvTimeout(enable: bool; t: longint);
begin
        fso.option := OPT_RecvTimeout;
        fso.enable := enable;
        fso.value := t;
        set_option(fso);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_NonBlock(enable: bool);
begin
        fso.option := OPT_NonBlock;
        fso.enable := enable;
        set_option(fso);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_tcp_socket.set_Timeout(enable: bool; t: longint);
begin
        set_SendTimeout(enable, t);
        set_RecvTimeout(enable, t);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
