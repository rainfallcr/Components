unit libsqueue;
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        cthreads, classes,
        libcommon;
{----------------------------------------------------------------------------------------------------------------------}
type
        ts_sQueue = class
        private
            fmtx: t_mutex;

            fl: array of string;

            fh,
            fc,
            fs,
            fds: longint;

            function get_count: longint;

            procedure set_size(ns: longint);

        public
            constructor Create(ds: longint = C_2K);
            destructor  Destroy; override;

            function enQueue(const STR: string): longint;
            function deQueue: string;
            function Insert(const STR: string): longint;

            procedure Clear;

            property count: longint read get_count;
        end;
{----------------------------------------------------------------------------------------------------------------------}
implementation
uses
        sysutils;
{----------------------------------------------------------------------------------------------------------------------}
constructor ts_sQueue.Create(ds: longint = C_2K);
begin
        inherited Create();

        fmtx := t_mutex.Create();

        fh := 0;
        fc := 0;

        if (ds < C_2K) then
            ds := C_2K;

        fds := ds;
        fs := ds;

        SetLength(fl, fs);
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor ts_sQueue.Destroy();
begin
        fmtx.Lock();

        fh := 0;
        fc := 0;
        SetLength(fl, 0);

        fmtx.unLock();

        fmtx.Free();

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_sQueue.get_count: longint;
begin
        fmtx.Lock();
        result := fc;
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_sQueue.set_size(ns: longint);
begin
        SetLength(fl, ns);
        fs := ns;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_sQueue.Clear();
var
        i: longint;
begin
        fmtx.Lock();

        for i := 0 to (fc - 1) do
            fl[(fh + i) mod fs] := '';

        fh := 0;
        fc := 0;

        set_size(fds);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_sQueue.enQueue(const STR: string): longint;
begin
        if (STR = '') then
            exit(-1);

        fmtx.Lock();

        if (fc = fs) then
            set_size(fs + fds);

        result := (fh + fc) mod fs;
        fl[result] := STR;

        inc(fc);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_sQueue.deQueue: string;
begin
        Result := '';

        fmtx.Lock();

        if (fc > 0) then
        begin
            Result := fl[fh];
            fl[fh] := '';

            fh := (fh + 1) mod fs;
            dec(fc);
        end;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_sQueue.insert(const STR: string): longint;
begin
        if (STR = '') then
            exit(-1);

        fmtx.Lock();

        if (fc = fs) then
            set_size(fs + fds);

        if (fh > 0) then
            dec(fh)
        else
            fh := fs - 1;

        fl[fh] := STR;

        inc(fc);

        result := 0;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
