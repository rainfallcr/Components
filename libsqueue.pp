unit libsqueue;
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        cthreads, classes,
        libcommon;
{----------------------------------------------------------------------------------------------------------------------}
type
        p_strItems = ^t_strItems;
        t_strItems = array[0..MaxLongInt] of string;

        ts_sQueue = class
        private
            fmtx: t_mutex;

            fl: p_strItems;

            fh,
            fc,
            fs,
            fds,
            fMask: longint; {---- fMask = fs - 1 for fast bitwise AND instead of MOD ----}

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

{---- Helper to round up to the nearest power of 2 ----}
function NextPow2(v: longint): longint;
begin
        dec(v);
        v := v or (v shr 1);
        v := v or (v shr 2);
        v := v or (v shr 4);
        v := v or (v shr 8);
        v := v or (v shr 16);
        result := v + 1;
end;

{----------------------------------------------------------------------------------------------------------------------}
constructor ts_sQueue.Create(ds: longint = C_2K);
begin
        inherited Create();

        fmtx := t_mutex.Create();

        fh := 0;
        fc := 0;

        fds := NextPow2(ds); {---- Ensure size is power of 2 ----}
        fs  := fds;
        fMask := fs - 1;

        GetMem(fl, fs * sizeOf(string));
        FillChar(fl^, fs * sizeOf(string), 0); {---- Nil all string pointers ----}
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor ts_sQueue.Destroy();
begin
        Clear();

        fmtx.Lock();

        FreeMem(fl);

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
var
        old_fs, tail_len, i: longint;
begin
        ns := NextPow2(ns); {---- Ensure new size is power of 2 ----}

        if (ns = fs) then
            exit();

        old_fs := fs;

        ReAllocMem(fl, ns * sizeOf(string));

        for i := old_fs to (ns - 1) do
            pointer(fl^[i]) := nil;

        if (fc > 0) and ((fh + fc) > old_fs) then
        begin
            tail_len := (fh + fc) - old_fs;

            system.Move(fl^[0], fl^[old_fs], tail_len * sizeOf(string));

            for i := 0 to (tail_len - 1) do
                pointer(fl^[i]) := nil;
        end;

        fs := ns;
        fMask := fs - 1;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_sQueue.Clear();
var
        i: longint;
begin
        fmtx.Lock();

        for i := 0 to (fc - 1) do
            fl^[(fh + i) and fMask] := '';

        fh := 0;
        fc := 0;

        if (fs > fds) then
            set_size(fds);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_sQueue.enQueue(const STR: string): longint;
begin
        if (STR = '' ) then
            exit(-1);

        fmtx.Lock();

        if (fc = fs) then
            set_size(fs + fds);

        result := (fh + fc) and fMask; {---- FAST bitwise AND instead of MOD ----}
        fl^[result] := STR;

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
            Result := fl^[fh];
            fl^[fh] := '';

            fh := (fh + 1) and fMask;
            dec(fc);
        end;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_sQueue.Insert(const STR: string): longint;
begin
        if (STR = '') then
            exit(-1);

        fmtx.Lock();

        if (fc = fs) then
            set_size(fs + fds);

        fh := (fh - 1) and fMask;

        fl^[fh] := STR;

        inc(fc);

        result := 0;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
