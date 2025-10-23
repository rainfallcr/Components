unit libptrlists;
{$mode objfpc}
{$longstrings on}
{$inline on}
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        cmem, cthreads, classes,
        libcommon;
{----------------------------------------------------------------------------------------------------------------------}
type
        {---- PTR_ITEMS TYPES -----------------------------------------------------------------------------------------}
        r_ptr_item = record
            KEY: string;
            ptr: pointer;
        end;

        p_ptritems = ^t_ptritems;
        t_ptritems = array[0..MaxLongInt] of r_ptr_item;

        {---- t_ptrlist -----------------------------------------------------------------------------------------------}
        t_ptrlist = class
        private
            fl: p_ptritems;

            fc,
            fs,
            fds: longint;
            fSort: bool;

            function get_ptr(index: longint): pointer;
            function get_key(index: longint): string;

            function bfind(const KEY: string; var index: longint): bool;
            function lfind(const KEY: string; var index: longint): bool;

            procedure put_ptr(index: longint; item: pointer);
            procedure put_key(index: longint; KEY: string);
            procedure set_size(ns: longint);
            procedure set_sorted(fA: bool);
            procedure qsort(il, ir: longint);
            procedure exchange(index1, index2: longint);
            procedure insert(index: longint; const KEY: string; item: pointer);

        public
            constructor Create(ds: longint = C_4K);
            destructor  Destroy; override;

            function Add(const KEY: string; item: pointer): longint;
            function Find(const KEY: string; var item: pointer): bool;
            function indexOf(item: pointer): longint;
            function indexOf(const KEY: string): longint;
            function Remove(item: pointer): bool;
            function Remove(const KEY: string): bool;

            procedure Clear;
            procedure Delete(index: longint);

            property count: longint read fc;
            property Sorted: bool read fSort write set_sorted;
            property Items[index: longint]: pointer read get_ptr write put_ptr; default;
            property KEY[index: longint]: string read get_key write put_key;
        end;
        {--------------------------------------------------------------------------------------------------------------}

        {---- ts_ptrlist ----------------------------------------------------------------------------------------------}
        ts_ptrlist = class
        private
            fmtx: t_mutex;
            fl: t_ptrlist;

            function get_count: longint;
            function get_sorted: bool;

            procedure set_sorted(fA: bool);

        public
            constructor Create(ds: longint = C_4K);
            destructor  Destroy; override;

            function  Lock: t_ptrlist; inline;
            procedure unLock; inline;

            function Add(const KEY: string; item: pointer): longint;
            function Find(const KEY: string; var item: pointer): bool;
            function Remove(const KEY: string): bool;

            procedure Clear;
            procedure Delete(index: longint);

            property count: longint read get_count;
            property Sorted: bool read get_sorted write set_sorted;
        end;
{----------------------------------------------------------------------------------------------------------------------}
implementation
uses
        sysutils;
{----------------------------------------------------------------------------------------------------------------------}

{---- t_ptr_list ------------------------------------------------------------------------------------------------------}
constructor t_ptrlist.Create(ds: longint = C_4K);
begin
        inherited Create();

        fc := 0;

        fds := ds;
        set_size(fds);

        fSort := false;
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor t_ptrlist.Destroy();
begin
        Clear();

        freeMem(fl);

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.get_ptr(index: longint): pointer;
begin
        if (index >= 0)and(index < fc) then
            result := fl^[index].ptr
        else
            result := nil;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.get_key(index: longint): string;
begin
        if (index >= 0)and(index < fc) then
            result := fl^[index].KEY
        else
            result := '';
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.put_ptr(index: longint; item: pointer);
begin
        if (index >= 0)and(index < fc) then
            fl^[index].ptr := item;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.put_key(index: longint; KEY: string);
begin
        if (index >= 0)and(index < fc) then
            fl^[index].KEY := KEY;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.bfind(const KEY: string; var index: longint): bool;
var
        r, p: longint;
begin
        result := false;

        index := 0;
        r := (fc - 1);

        while (index <= r) do
        begin
            p := index + ((r - index) div 2);

            if (ansiCompareStr(KEY, fl^[p].KEY) > 0) then
                index := p + 1
            else
            begin
                r := p - 1;
                if (ansiCompareStr(KEY, fl^[p].KEY) = 0) then
                begin
                    index := p;
                    exit(true);
                end;
            end;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.lfind(const KEY: string; var index: longint): bool;
begin
        result := false;
        index := 0;

        while (index < fc)and(not result) do
            if (ansiCompareStr(fl^[index].KEY, KEY) <> 0) then
                inc(index)
            else
                result := true;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.set_size(ns: longint);
begin
        fs := ns;
        reAllocMem(fl, fs*sizeOf(r_ptr_item));
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.set_sorted(fA: bool);
begin
        if (fA)and(not fSort)and(fc > 0) then
        begin
            { duplicate_cleaning(); }
            qsort(0, fc-1);
        end;

        fSort := fA;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.qsort(il, ir: longint);
var
        i, j, p: longint;
begin
        if ((ir - il) <= 1) then
        begin
            if (il < ir) then
                if (ansiCompareStr(fl^[il].KEY, fl^[ir].KEY)  > 0) then
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

            while (j > p)and(ansiCompareStr(fl^[j].KEY, fl^[p].KEY)  > 0) do
                dec(j);

            exchange(i, j);

            if (p = i) then
                p := j
            else
                if (p = j) then
                    p := i;

            if ((p - 1) >= il) then
                qsort(il, p-1);

            if ((p + 1) <= ir) then
                qsort(p+1, ir);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.exchange(index1, index2: longint);
var
        p1, p2: pointer;
begin
        p1 := pointer(fl^[index1].KEY);
        p2 := pointer(fl^[index1].ptr);

        pointer(fl^[index1].KEY) := pointer(fl^[index2].KEY);
        pointer(fl^[index1].ptr) := pointer(fl^[index2].ptr);

        pointer(fl^[index2].KEY) := p1;
        pointer(fl^[index2].ptr) := p2;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.insert(index: longint; const KEY: string; item: pointer);
begin
        if (index < fc) then
            system.Move(fl^[index], fl^[index+1], (fc-index)*sizeOf(r_ptr_item));

        pointer(fl^[index].KEY) := nil;
        pointer(fl^[index].ptr) := nil;

        fl^[index].KEY := KEY;
        fl^[index].ptr := item;

        inc(fc);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.Add(const KEY: string; item: pointer): longint;
begin
        if (fc = fs) then
            set_size(fs + fds);

        if (not fSort) then
            result := fc
        else
            if (bfind(KEY, result)) then
                result := (-1);

        if (result >= 0) then
            insert(result, KEY, item);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.Find(const KEY: string; var item: pointer): bool;
var
        i: longint = 0;
begin
        item := nil;

        if (fSort) then
            result := bfind(KEY, i)
        else
            result := lfind(KEY, i);

        if (result) then
            item := fl^[i].ptr;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.indexOf(item: pointer): longint;
begin
        result := 0;

        while (result < fc)and(fl^[result].ptr <> item) do
            inc(result);

        if (result = fc) then
            result := (-1);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.indexOf(const KEY: string): longint;
var
        fR: bool;
begin
        result := (-1);

        if (fSort) then
            fR := bfind(KEY, result)
        else
            fR := lfind(KEY, result);

        if (not fR) then
            result := (-1);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.Remove(item: pointer): bool;
var
        i: longint = 0;
begin
        i := indexOf(item);
        result := (i >= 0);

        if (result) then
            Delete(i);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrlist.Remove(const KEY: string): bool;
var
        i: longint = 0;
begin
        if (fSort) then
            result := bfind(KEY, i)
        else
            result := lfind(KEY, i);

        if (result) then
            Delete(i);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.Clear();
begin
        while (fc > 0) do
            Delete(fc-1);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrlist.Delete(index: longint);
begin
        if (index >= 0)and(index < fc) then
        begin
            fl^[index].KEY := '';
            dec(fc);

            if (index < fc) then
                system.Move(fl^[index+1], fl^[index], (fc-index)*sizeOf(r_ptr_item));

            if (fs > fds)and(fc < fds) then
                set_size(fds);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}


{---- ts_ptrlist ------------------------------------------------------------------------------------------------------}
constructor ts_ptrlist.Create(ds: longint = C_4K);
begin
        inherited Create();

        fmtx := t_mutex.Create();

        fl := t_ptrlist.Create(ds);
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor ts_ptrlist.Destroy();
begin
        fmtx.Lock();
        fl.Free();
        fmtx.unLock();

        fmtx.Free();

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrlist.get_count(): longint;
begin
        fmtx.Lock();
        result := fl.count;
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrlist.get_sorted(): bool;
begin
        fmtx.Lock();
        result := fl.Sorted;
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_ptrlist.set_sorted(fA: bool);
begin
        fmtx.Lock();
        fl.Sorted := fA;
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrlist.Lock(): t_ptrlist;
begin
        fmtx.Lock();
        result := fl;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_ptrlist.unLock();
begin
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrlist.Add(const KEY: string; item: pointer): longint;
begin
        fmtx.Lock();
        result := fl.Add(KEY, item);
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrlist.Find(const KEY: string; var item: pointer): bool;
begin
        fmtx.Lock();
        result := fl.Find(KEY, item);
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrlist.Remove(const KEY: string): bool;
begin
        fmtx.Lock();
        result := fl.Remove(KEY);
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_ptrlist.Clear();
begin
        fmtx.Lock();
        fl.Clear();
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_ptrlist.Delete(index: longint);
begin
        fmtx.Lock();
        fl.Delete(index);
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
