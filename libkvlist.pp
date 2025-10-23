unit libkvlist;
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        cthreads, classes,
        libcommon;
{----------------------------------------------------------------------------------------------------------------------}
type
        r_kvitem = record
            KEY,
            VAL: string;
        end;

        p_kvitems = ^t_kvitems;
        t_kvitems = array[0..MaxLongInt] of r_kvitem;

        ts_kvlist = class
        private
            fl: p_kvitems;

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

            function bfind(const SKEY: string; var i: longint): bool;
            function lfind(const SKEY: string; var i: longint): bool;

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
constructor ts_kvlist.Create(ds: longint = C_2K);
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
destructor ts_kvlist.Destroy();
begin
        Clear();

        fmtx.Free();

        freeMem(fl); // set_size(0);

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.get_key(i: longint): string;
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
            Result := fl^[i].KEY
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.get_val(i: longint): string;
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
            Result := fl^[i].VAL
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.get_line(i: longint): string;
begin
        fmtx.Lock();

        if (i >= 0)and(i < fc) then
            Result := format('%s%sd%s', [fl^[i].KEY, FSeparator, fl^[i].VAL])
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.get_kval(const SKEY: string): string;
var
        i: longint = 0;
        fR: bool = false;
begin
        fmtx.Lock();

        if (fSorted) then
            fR := bfind(SKEY, i)
        else
            fR := lfind(SKEY, i);

        if (fR) then
            Result := fl^[i].VAL
        else
            Result := '';

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.get_text: string;
var
        i: longint = 0;
begin
        fmtx.Lock();

        Result := '';

        for i := 0 to (fc-1) do
            Result += format('%s%s%s%s', [fl^[i].KEY, FSeparator, fl^[i].VAL, FDelimiter]);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.get_keys: string;
var
        i: longint = 0;
begin
        if (fc > 0) then
        begin
            fmtx.Lock();

            Result := fl^[0].KEY;

            for i := 1 to (fc-1) do
                Result += FSpliter + fl^[i].KEY;

            fmtx.unLock();
        end
        else
            Result := '';
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_key(i: longint; const SKEY: string);
begin
        if (i >= 0)and(i < fc) then
        begin
            fmtx.Lock();

            if (fUpKeys) then
                fl^[i].KEY := upCase(SKEY)
            else
                fl^[i].KEY := SKEY;

            if (fSorted) then
                qSort(0, fc-1);

            fmtx.unLock();
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_val(i: longint; const VAL: string);
begin
        if (i >= 0)and(i < fc) then
        begin
            fmtx.Lock();

            fl^[i].VAL := VAL;

            fmtx.unLock();
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_kval(const SKEY, VAL: string);
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
            fR := bfind(LKEY, i)
        else
            fR := lfind(LKEY, i);

        if (fR) then
            fl^[i].VAL := VAL
        else
            Insert(i, LKEY, VAL);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_text(const STR: string);
var
        LSTR: string = '';
        i: longint = 0;
begin
        if (STR = '') then
            exit();

        Clear();

        LSTR := STR;
        if (rightStr(STR, fdlen) <> FDelimiter) then
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
procedure ts_kvlist.set_keys(const STR: string);
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
procedure ts_kvlist.set_delimiter(const STR: string);
begin
        fmtx.Lock();

        FDelimiter := STR;
        fdlen := length(FDelimiter);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_separator(const STR: string);
begin
        fmtx.Lock();
        FSeparator := STR;
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_spliter(const STR: string);
begin
        fmtx.Lock();
        FSpliter := STR;
        fslen := length(FSpliter);
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.bfind(const SKEY: string; var i: longint): bool;
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
            cmp := ansiCompareStr(SKEY, fl^[p].KEY);

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
{
function ts_kvlist.bfind(const SKEY: string; var i: longint): bool;
var
        l, r, p: longint;
begin
        result := false;
        i := (-1);

        l := 0;
        r := (fc - 1);

        while (l <= r) do
        begin
            p := l + ((r - l) div 2);
            if (ansiCompareStr(SKEY, fl^[p].KEY) > 0) then
                l := p + 1
            else
            begin
                r := p - 1;
                if (ansiCompareStr(SKEY, fl^[p].KEY) = 0) then
                begin
                    result := true;
                    l := p; // quit from while loop
                end;
            end;
        end;
        i := l;
end;
}
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.lfind(const SKEY: string; var i: longint): bool;
begin
        result := false;

        i := 0;

        while (i < fc)and(not result) do
            if (ansiCompareStr(SKEY, fl^[i].KEY) <> 0) then
                inc(i)
            else
                result := true;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_size(ns: longint);
begin
        fmtx.Lock();

        fs := ns;

        reAllocMem(fl, fs*sizeOf(r_kvitem));

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_sorted(fA: bool);
begin
        fmtx.Lock();

        if (fA)and(not fSorted)and(fc > 0) then
            qSort(0, fc-1);

        fSorted := fA;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.set_upkeys(fA: bool);
var
        i: longint;
begin
        fmtx.Lock();

        if (fA)and(not fUpKeys)and(fc > 0) then
            for i := 0 to (fc-1) do
                fl^[i].KEY := upCase(fl^[i].KEY);

        fUpKeys := fA;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.qsort(il, ir: longint);
var
        i, j, p: longint;
begin
        if ((ir - il) <= 1) then
        begin
            if (il < ir) then
                if (ansiCompareStr(fl^[il].KEY, fl^[ir].KEY) > 0) then
                    exchange(il, ir);
            exit();
        end;

        i := il;
        j := ir;
        p := (il + Random(ir - il));

        while (i < j) do
        begin
            while (i < p)and(ansiCompareStr(fl^[i].KEY, fl^[p].KEY) <= 0) do
                inc(i);

            while (j > p)and(ansiCompareStr(fl^[j].KEY, fl^[p].KEY) > 0) do
                dec(j);

            exchange(i, j);

            if (p = i) then
                p := j
            else
                if (p = j) then
                    p := i;

            if ((p - 1) >= il) then
                qSort(il, p-1);

            if ((p + 1) <= ir) then
                qSort(p+1, ir);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.exchange(index1, index2: longint);
var
        p1, p2: pointer;
begin
        p1 := pointer(fl^[index1].KEY);
        p2 := pointer(fl^[index1].VAL);

        pointer(fl^[index1].KEY) := pointer(fl^[index2].KEY);
        pointer(fl^[index1].VAL) := pointer(fl^[index2].VAL);

        pointer(fl^[index2].KEY) := p1;
        pointer(fl^[index2].VAL) := p2;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.insert(i: longint; const SKEY, VAL: string);
begin
        if (i < fc) then
            system.Move(fl^[i], fl^[i+1], (fc-i)*sizeOf(r_kvitem));

        {---- strange, but it's work ----}
        pointer(fl^[i].KEY) := nil;
        pointer(fl^[i].VAL) := nil;

        fl^[i].KEY := SKEY;
        fl^[i].VAL := VAL;

        inc(fc);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.Add(const SKEY, VAL: string): longint;
var
        nsize: longword = 0;
        LKEY: string ='';
        fRes: bool = false;
begin
        result := (-1);

        if (fUpKeys) then
            LKEY := upCase(SKEY)
        else
            LKEY := SKEY;

        if (fc = fs) then
        begin
            nsize := fs + fds;
            if (nsize > MaxLongInt) then
                nsize := MaxLongInt;

            set_size(nsize);
        end;

        fmtx.Lock();

        if (fSorted) then
            fRes := bfind(LKEY, result)
        else
            result := fc;

        if (not fRes) then
            Insert(result, LKEY, VAL);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.Add(const STR: string): longint;
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
function ts_kvlist.indexOf(const SKEY: string): longint;
var
        fRes: bool;
begin
        result := (-1);

        fmtx.Lock();

        if (fSorted) then
            fRes := bfind(SKEY, result)
        else
            fRes := lfind(SKEY, result);

        fmtx.unLock();

        if (not fRes) then
            result := (-1);
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_kvlist.Remove(const SKEY: string): bool;
var
        i: longint = 0;
begin
        fmtx.Lock();

        if (fSorted) then
            result := bfind(SKEY, i)
        else
            result := lfind(SKEY, i);

        fmtx.unLock();

        if (result) then
            self.Delete(i);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.Clear();
begin
        while (fc > 0) do
            self.Delete(fc-1);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_kvlist.Delete(i: longint);
begin
        if (i >= 0)and(i < fc) then
        begin
            fmtx.Lock();

            fl^[i].KEY := '';
            fl^[i].VAL := '';

            dec(fc);

            if (i < fc) then
                system.Move(fl^[i+1], fl^[i], (fc-i)*sizeOf(r_kvitem));

            fmtx.unLock();

            if (fs > fds)and(fc < fds) then
                set_size(fds);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
