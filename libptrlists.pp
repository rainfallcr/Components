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
        p_ptrItem = ^r_ptrItem;
        r_ptrItem = record
            KEY: string;
            ptr: pointer;
        end;

        p_ptrItems = ^t_ptrItems;
        t_ptrItems = array[0..MaxLongInt] of p_ptrItem;

        {---- t_ptrList -----------------------------------------------------------------------------------------------}
        t_ptrList = class
        private
            fl: p_ptrItems;

            fc,
            fs,
            fds: longint;
            fSort: bool;

            function get_ptr(index: longint): pointer;
            function get_key(index: longint): string;

            function bFind(const KEY: string; var index: longint): bool;
            function lFind(const KEY: string; var index: longint): bool;

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

        {---- ts_ptrList ----------------------------------------------------------------------------------------------}
        ts_ptrList = class
        private
            fmtx: t_mutex;
            fl: t_ptrList;

            function get_count: longint;
            function get_sorted: bool;

            procedure set_sorted(fA: bool);

        public
            constructor Create(ds: longint = C_4K);
            destructor  Destroy; override;

            function  Lock: t_ptrList; inline;
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
        sysUtils;
{----------------------------------------------------------------------------------------------------------------------}

{---- t_ptr_list ------------------------------------------------------------------------------------------------------}
constructor t_ptrList.Create(ds: longint = C_4K);
begin
        inherited Create();

        fc := 0;

        fds := ds;
        set_size(fds);

        fSort := false;
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor t_ptrList.Destroy();
begin
        Clear();

        FreeMem(fl);

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.get_ptr(index: longint): pointer;
begin
        if (index >= 0)and(index < fc) then
            result := fl^[index]^.ptr
        else
            result := nil;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.get_key(index: longint): string;
begin
        if (index >= 0)and(index < fc) then
            result := fl^[index]^.KEY
        else
            result := '';
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrList.put_ptr(index: longint; item: pointer);
begin
        if (index >= 0)and(index < fc) then
            fl^[index]^.ptr := item;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrList.put_key(index: longint; KEY: string);
begin
        if (index >= 0)and(index < fc) then
            fl^[index]^.KEY := KEY;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.bfind(const KEY: string; var index: longint): bool;
var
        r, p: longint;
begin
        result := false;

        index := 0;
        r := (fc - 1);

        while (index <= r) do
        begin
            p := index + ((r - index) div 2);

            if (ansiCompareStr(KEY, fl^[p]^.KEY) > 0) then
                index := p + 1
            else
            begin
                r := p - 1;
                if (ansiCompareStr(KEY, fl^[p]^.KEY) = 0) then
                begin
                    index := p;
                    exit(true);
                end;
            end;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.lfind(const KEY: string; var index: longint): bool;
begin
        result := false;
        index := 0;

        while (index < fc)and(not result) do
            if (ansiCompareStr(fl^[index]^.KEY, KEY) <> 0) then
                inc(index)
            else
                result := true;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrList.set_size(ns: longint);
begin
        fs := ns;

        ReAllocMem(fl, fs*sizeOf(p_ptrItem));
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrList.set_sorted(fA: bool);
begin
        if (fA)and(not fSort)and(fc > 0) then
        begin
            { duplicate_cleaning(); }
            qsort(0, fc-1);
        end;

        fSort := fA;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrList.qsort(il, ir: longint);
var
        i, j: longint;
        pivot: p_ptrItem;
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
procedure t_ptrList.exchange(index1, index2: longint);
var
        p: p_ptrItem;
begin
        p := fl^[index1];
        fl^[index1] := fl^[index2];
        fl^[index2] := p;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrList.insert(index: longint; const KEY: string; item: pointer);
var
        newItem: p_ptrItem;
begin
        if (index < fc) then
            system.Move(fl^[index], fl^[index+1], (fc-index)*sizeOf(p_ptrItem));

        New(newItem);

        newItem^.KEY := KEY;
        newItem^.ptr := item;

        fl^[index] := newItem;

        inc(fc);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.Add(const KEY: string; item: pointer): longint;
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
function t_ptrList.Find(const KEY: string; var item: pointer): bool;
var
        i: longint = 0;
begin
        item := nil;

        if (KEY = '') then
            exit(false);

        if (fSort) then
            result := bfind(KEY, i)
        else
            result := lfind(KEY, i);

        if (result) then
            item := fl^[i]^.ptr;
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.indexOf(item: pointer): longint;
begin
        result := 0;

        while (result < fc)and(fl^[result]^.ptr <> item) do
            inc(result);

        if (result = fc) then
            result := (-1);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.indexOf(const KEY: string): longint;
var
        fR: bool;
begin
        result := (-1);

        if (fSort) then
            fR := bFind(KEY, result)
        else
            fR := lFind(KEY, result);

        if (not fR) then
            result := (-1);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.Remove(item: pointer): bool;
var
        i: longint = 0;
begin
        i := indexOf(item);
        result := (i >= 0);

        if (result) then
            Delete(i);
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_ptrList.Remove(const KEY: string): bool;
var
        i: longint = 0;
begin
        if (fSort) then
            result := bFind(KEY, i)
        else
            result := lFind(KEY, i);

        if (result) then
            Delete(i);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrList.Clear();
var
        i: longint;
begin
        for i := 0 to (fc - 1) do
        begin
            Dispose(fl^[i]);
            fl^[i] := nil;
        end;

        fc := 0;

        if (fs > fds) then
            set_size(fds);
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_ptrList.Delete(index: longint);
begin
        if (index >= 0)and(index < fc) then
        begin
            Dispose(fl^[index]);
            fl^[index] := nil;

            dec(fc);

            if (index < fc) then
                system.Move(fl^[index+1], fl^[index], (fc-index)*sizeOf(p_ptrItem));

            fl^[fc] := nil;

            if (fs > fds)and(fc < fds) then
                set_size(fds);
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}


{---- ts_ptrList ------------------------------------------------------------------------------------------------------}
constructor ts_ptrList.Create(ds: longint = C_4K);
begin
        inherited Create();

        fmtx := t_mutex.Create();

        fl := t_ptrList.Create(ds);
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor ts_ptrList.Destroy();
begin
        fmtx.Lock();

        fl.Free();

        fmtx.unLock();

        fmtx.Free();

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrList.get_count(): longint;
begin
        fmtx.Lock();

        result := fl.count;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrList.get_sorted(): bool;
begin
        fmtx.Lock();

        result := fl.Sorted;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_ptrList.set_sorted(fA: bool);
begin
        fmtx.Lock();

        fl.Sorted := fA;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrList.Lock(): t_ptrList;
begin
        fmtx.Lock();
        result := fl;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_ptrList.unLock();
begin
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrList.Add(const KEY: string; item: pointer): longint;
begin
        fmtx.Lock();

        result := fl.Add(KEY, item);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrList.Find(const KEY: string; var item: pointer): bool;
begin
        fmtx.Lock();

        result := fl.Find(KEY, item);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function ts_ptrList.Remove(const KEY: string): bool;
begin
        fmtx.Lock();

        result := fl.Remove(KEY);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_ptrList.Clear();
begin
        fmtx.Lock();

        fl.Clear();

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure ts_ptrList.Delete(index: longint);
begin
        fmtx.Lock();

        fl.Delete(index);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
