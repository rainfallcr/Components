unit liblogfile;
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        cmem,
        libcommon;
{----------------------------------------------------------------------------------------------------------------------}
type
        {---- t_log_file ----------------------------------------------------------------------------------------------}
        t_log_file = class
        private
            fmtx: t_mutex;
            ffile,
            dfile: TextFile;
            flevel: byte;

        public
            constructor Create(ltz: word = 0);
            destructor  Destroy; override;

            function open(const FName: string; level: byte): bool;
            function close(const Str: string): bool;

            procedure set_level(level: byte);
            procedure write(level: byte; const Str: string);
            procedure dump(const Str: string);

        public
            tz: byte;
        end;
{----------------------------------------------------------------------------------------------------------------------}
const
        LOG_SYS      = 0;
        LOG_ERR      = 1;
        LOG_WARN     = 2;
        LOG_INFO     = 3;
        LOG_DEBUG    = 4;
        LOG_TRACE    = 5;

        MAX_LOGLEVEL = 5;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
implementation
uses
        sysutils;
{----------------------------------------------------------------------------------------------------------------------}

{---- t_log_file ------------------------------------------------------------------------------------------------------}
constructor t_log_file.Create(ltz: word = 0);
begin
        inherited Create();

        fmtx := t_mutex.Create();
        tz := ltz;
end;
{----------------------------------------------------------------------------------------------------------------------}
destructor t_log_file.Destroy();
begin
        fmtx.Free();

        inherited Destroy();
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_log_file.open(const FName: string; level: byte): bool;
begin
        fmtx.Lock();

        assignFile(ffile, FName);
    {$I-}
        if (fileExists(FName)) then
            Append(ffile)
        else
            reWrite(ffile);
    {$I+}
        result := (IOResult() = 0);

        if (result) then
            flevel:= level;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_log_file.close(const Str: string): bool;
begin
        self.write(LOG_SYS, Str);

        fmtx.Lock();

    {$I-}
        closeFile(ffile);
    {$I+}
        result := (IOResult() = 0);

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_log_file.set_level(level: byte);
begin
        fmtx.Lock();
        flevel := level;
        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_log_file.write(level: byte; const Str: string);
begin
        if (level <= flevel) then
        begin
        {$I-}
            writeln(ffile, format('[%s] %s', [datetime_to_str(get_datetime(tz)), Str]));
            flush(ffile);
        {$I+}

            if (IOResult() <> 0) then
                writeln('<FLOG> [S] .write(ffile, ) failed! I/O Error!');

            fmtx.unLock();
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_log_file.dump(const Str: string);
var
        FN, LSTR: string;
begin
        FN := 'dump-' + datetime_to_str(get_datetime(tz)) + '.log';

        fmtx.Lock();

        assignFile(dfile, FN);
    {$I-}
        if (fileExists(FN)) then
            Append(dfile)
        else
            reWrite(dfile);
    {$I+}

        if (IOResult() = 0) then
        begin
        {$I-}
            writeln(dfile, format('[%s] %s', [datetime_to_str(get_datetime(tz)), Str]));
            closeFile(dfile);
        {$I+}
        end;

        fmtx.unLock(
        );
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
