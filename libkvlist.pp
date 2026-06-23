unit libkvlist;
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        cthreads, classes,
        libcommon;
{----------------------------------------------------------------------------------------------------------------------}
type
        p_kvItem = ^r_kvItem;
        r_kvItem = record
            KEY,
            VAL: string;
        end;

        p_kvItems = ^t_kvItems;
        t_kvItems = array[0..MaxLongInt] of p_kvItem;

        ts_kvList = class
        private
            fl: p_kvItems;

            fc,
            fs, fds,
            fdlen,
            fslen: longint;

            fmtx: t_mutex;

            FDelimiter,
            FSeparator,
            FSpliter: string;

            fSorted,
            fUpKeys: bool;

            function get_key(i: longint): string;
            function get_val(i: longint): string;
            function get_line(i: longint): string;
            function get_kval(const SKEY: string): string;
            function get_text: string;
            function get_keys: string;

            procedure set_key(i: longint; const SKEY: string);
            procedure set_val(i: longint; const VAL: string);
            procedure set_kval(const SKEY, VAL: string);
            procedure set_text(const STR: string);
            procedure set_keys(const STR: string);

            procedure set_delimiter(const STR: string);
            procedure set_separator(const STR: string);
            procedure set_spliter(const STR: string);

            procedure set_size(ns: longint);
            procedure set_sorted(fA: bool);
            procedure set_upkeys(fA: bool);
            procedure insert(i: longint; const SKEY, VAL: string);

            function bFind(const SKEY: string; var i: longint): bool;
            function lFind(const SKEY: string; var i: longint): bool;

            procedure qsort(il, ir: longint);
            procedure exchange(index1, index2: longint);

        public
            constructor Create(ds: longint = C_2K);
            destructor  Destroy; override;

            function Add(const SKEY, VAL: string): longint;
            function Add(const STR: string): longint;
            function indexOf(const SKEY: string): longint;
            function Remove(const SKEY: string): bool;

            procedure Clear;
            procedure Delete(i: longint);

            property Delimiter: string read FDelimiter write set_delimiter;
            property Separator: string read FSeparator write set_separator;
            property Spliter: string read FSpliter write set_spliter;

            property count: longint read fc;

            property Sorted: bool read fSorted write set_sorted;
            property UpKeys: bool read fUpKeys write set_upkeys;

            property KEY[i: longint]: string read get_key write set_key; default;
            property VAL[i: longint]: string read get_val write set_val;
            property KVAL[K: string]: string read get_kval write set_kval;
            property LINE[i: longint]: string read get_line;
            property Keys: string read get_keys write set_keys;
            property Text: string read get_text write set_text;
        end;
{----------------------------------------------------------------------------------------------------------------------}
implementation
uses
        sysUtils;
{----------------------------------------------------------------------------------------------------------------------}
constructor ts_kvList.Create(ds: longint = C_2K);
begin
        inherited Create();

        fmtx := t_mutex.Create();

        fc := 0;

        fds := ds;
        set_size(fds);

        FDelimiter := ';';
        FSeparator := ':';
        FSpliter := ',';

        fdlen := 1;
        fslen := 1;

        fSorted := true;
        fUpKeys := false;
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor ts_kvList.Destroy();
begin
        Clear();

        fmtx.Free();

        FreeMem(fl);

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.get_key(i: longint): string;
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
            Result := fl^[i]^.KEY
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.get_val(i: longint): string;
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
            Result := fl^[i]^.VAL
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.get_line(i: longint): string;
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
            Result := format('%s%s%s', [fl^[i]^.KEY, FSeparator, fl^[i]^.VAL])
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.get_kval(const SKEY: string): string;
var
        LKEY: string = '';
        i: longint = 0;
        fRes: bool = false;
begin
        if (fUpKeys) then
            LKEY := upCase(SKEY)
        else
            LKEY := SKEY;

        fmtx.Lock();

        if (fSorted) then
            fRes := bFind(LKEY, i)
        else
            fRes := lFind(LKEY, i);

        if (fRes) then
            Result := fl^[i]^.VAL
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.get_text: string;
var
        i: longint = 0;
begin
        fmtx.Lock();

        Result := '';

        for i := 0 to (fc-1) do
            Result += format('%s%s%s%s', [fl^[i]^.KEY, FSeparator, fl^[i]^.VAL, FDelimiter]);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.get_keys: string;
var
        i: longint = 0;
begin
        fmtx.Lock();

        if (fc > 0) then
        begin
            Result := fl^[0]^.KEY;

            for i := 1 to (fc - 1) do
                Result += FSpliter + fl^[i]^.KEY;
        end
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_key(i: longint; const SKEY: string);
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
        begin
            if (fUpKeys) then
                fl^[i]^.KEY := upCase(SKEY)
            else
                fl^[i]^.KEY := SKEY;

            if (fSorted) then
                qSort(0, fc-1);
        end;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_val(i: longint; const VAL: string);
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
            fl^[i]^.VAL := VAL;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_kval(const SKEY, VAL: string);
var
        LKEY: string = '';
        i: longint = (-1);
        fR: bool = false;
begin
        if (fUpKeys) then
            LKEY := upCase(SKEY)
        else
            LKEY := SKEY;

        fmtx.Lock();

        if (fSorted) then
            fR := bFind(LKEY, i)
        else
            fR := lFind(LKEY, i);

        if (fR) then
            fl^[i]^.VAL := VAL
        else
            Insert(i, LKEY, VAL);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_text(const STR: string);
var
        LSTR: string = '';
        i: longint = 0;
begin
        if (STR = '') then
            exit();

        Clear();

        LSTR := STR;
        if (RightStr(STR, fdlen) <> FDelimiter) then
            LSTR += FDelimiter;

        repeat
            i := (pos(FDelimiter, LSTR) - 1);

            case (i) of
                -1:
                    LSTR := '';
                //----
                0:
                    while (pos(FDelimiter, LSTR) = 1) do
                        system.Delete(LSTR, 1, fdlen);
                //----
                else
                begin
                    self.Add(copy(LSTR, 1, i));
                    system.Delete(LSTR, 1, i+fdlen);
                end;
            end;
        until (LSTR = '');
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_keys(const STR: string);
var
        LSTR: string = '';
        i: longint = 0;
begin
        Clear();

        LSTR := STR;

        if (rightStr(STR, fslen) <> FSpliter) then
            LSTR += FSpliter;

        repeat
            i := (pos(FSpliter, LSTR) - 1);
            case (i) of
                -1:
                    LSTR := '';
                //----
                0:
                    while (pos(FSpliter, LSTR) = 1) do
                        system.Delete(LSTR, 1, fslen);
                //----
                else
                begin
                    self.Add(copy(LSTR, 1, i));
                    system.Delete(LSTR, 1, i+fslen);
                end;
            end;
        until (LSTR = '');
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_delimiter(const STR: string);
begin
        fmtx.Lock();

        FDelimiter := STR;
        fdlen := length(FDelimiter);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_separator(const STR: string);
begin
        fmtx.Lock();

        FSeparator := STR;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_spliter(const STR: string);
begin
        fmtx.Lock();

        FSpliter := STR;
        fslen := length(FSpliter);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.bFind(const SKEY: string; var i: longint): bool;
var
        l, r, p, cmp: longint;
begin
        result := false;

        i := (-1);

        l := 0;
        r := (fc - 1);

        while (l <= r) do
        begin
            p := l + ((r - l) shr 1);
            cmp := AnsiCompareStr(SKEY, fl^[p]^.KEY);

            if (cmp > 0) then
                l := p + 1
            else
                if (cmp < 0) then
                    r := p - 1
                else
                begin
                    i := p;
                    exit(true);
                end;
        end;

        i := l;
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.lFind(const SKEY: string; var i: longint): bool;
begin
        result := false;

        i := 0;

        while (i < fc)and(not result) do
            if (AnsiCompareStr(SKEY, fl^[i]^.KEY) <> 0) then
                inc(i)
            else
                result := true;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_size(ns: longint);
begin
        fmtx.Lock();

        fs := ns;

        ReAllocMem(fl, fs*sizeOf(p_kvitem));

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_sorted(fA: bool);
begin
        fmtx.Lock();

        if (fA)and(not fSorted)and(fc > 0) then
            qSort(0, fc-1);

        fSorted := fA;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.set_upkeys(fA: bool);
var
        i: longint;
begin
        fmtx.Lock();

        if (fA)and(not fUpKeys)and(fc > 0) then
            for i := 0 to (fc-1) do
                fl^[i]^.KEY := upCase(fl^[i]^.KEY);

        fUpKeys := fA;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.qsort(il, ir: longint);
var
        i, j: longint;
        pivot: p_kvItem;
begin
        if (il >= ir) then
            exit();

        i := il;
        j := ir;

        pivot := fl^[(il + ir) shr 1];

        while (i <= j) do
        begin
            while (ansiCompareStr(fl^[i]^.KEY, pivot^.KEY) < 0) do
                inc(i);

            while (ansiCompareStr(fl^[j]^.KEY, pivot^.KEY) > 0) do
                dec(j);

            if (i <= j) then
            begin
                exchange(i, j);

                inc(i);
                dec(j);
            end;
        end;

        if (il < j) then
            qsort(il, j);

        if (i < ir) then
            qsort(i, ir);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.exchange(index1, index2: longint);
var
        p: p_kvItem;
begin
        p := fl^[index1];
        fl^[index1] := fl^[index2];
        fl^[index2] := p;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.insert(i: longint; const SKEY, VAL: string);
var
        newItem: p_kvItem;
begin
        if (i < fc) then
            system.Move(fl^[i], fl^[i+1], (fc-i)*sizeOf(p_kvItem));

        New(newItem);
        newItem^.KEY := SKEY;
        newItem^.VAL := VAL;

        fl^[i] := newItem;
        inc(fc);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.Add(const SKEY, VAL: string): longint;
var
        nsize: longword = 0;
        LKEY: string ='';
        fRes: bool = false;
begin
        result := (-1);

        if (fUpKeys) then
            LKEY := UpCase(SKEY)
        else
            LKEY := SKEY;

        fmtx.Lock();

        if (fc = fs) then
        begin
            nsize := fs + fds;
            if (nsize > MaxLongInt) then
                nsize := MaxLongInt;

            set_size(nsize);
        end;

        if (fSorted) then
            fRes := bFind(LKEY, result)
        else
            result := fc;

        if (not fRes) then
            insert(result, LKEY, VAL);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.Add(const STR: string): longint;
var
        i: longint;
begin
        i := pos(FSeparator, STR);

        if (i > 0) then
            result := self.Add(copy(STR, 1, i-1), copy(STR, i+1, length(STR)))
        else
            result := self.Add(STR, '');
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.indexOf(const SKEY: string): longint;
var
        LKEY: string = '';
        fRes: bool;
begin
        result := (-1);

        if (fUpKeys) then
            LKEY := UpCase(SKEY)
        else
            LKEY := SKEY;

        fmtx.Lock();

        if (fSorted) then
            fRes := bFind(LKEY, result)
        else
            fRes := lFind(LKEY, result);

        fmtx.unLock();

        if (not fRes) then
            result := (-1);
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvList.Remove(const SKEY: string): bool;
var
        LKEY: string = '';
        i: longint = 0;
begin
        if (fUpKeys) then
            LKEY := UpCase(SKEY)
        else
            LKEY := SKEY;

        fmtx.Lock();

        if (fSorted) then
            result := bFind(LKEY, i)
        else
            result := lFind(LKEY, i);

        if (result) then
            self.Delete(i);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.Clear();
var
        i: longint;
begin
        fmtx.Lock();

        for i := 0 to (fc - 1) do
        begin
            Dispose(fl^[i]);
            fl^[i] := nil;
        end;

        fc := 0;

        if (fs > fds) then
            set_size(fds);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvList.Delete(i: longint);
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
        begin
            Dispose(fl^[i]);
            fl^[i] := nil;

            dec(fc);

            if (i < fc) then
                system.Move(fl^[i+1], fl^[i], (fc-i)*sizeOf(p_kvItem));

            fl^[fc] := nil;

            if (fs > fds)and(fc < fds) then
                set_size(fds);
        end;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
