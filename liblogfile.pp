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
            dfile: Text;

            flevel: byte;

        public
            constructor Create(ltz: byte = 0);
            destructor  Destroy; override;

            function Open(const FName: string; level: byte): bool;
            function Close(const Str: string): bool;

            procedure set_level(level: byte);

            procedure Write(level: byte; const Str: string);
            procedure Dump(const Str: string);

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
constructor t_log_file.Create(ltz: byte = 0);
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
function t_log_file.Open(const FName: string; level: byte): bool;
begin
        fmtx.Lock();

        AssignFile(ffile, FName);
    {$I-}
        if (FileExists(FName)) then
            Append(ffile)
        else
            ReWrite(ffile);
    {$I+}
        result := (IOResult() = 0);

        if (result) then
            flevel:= level;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
function t_log_file.Close(const Str: string): bool;
begin
        self.Write(LOG_SYS, Str);

        fmtx.Lock();

    {$I-}
        CloseFile(ffile);
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
procedure t_log_file.Write(level: byte; const Str: string);
begin
        if (level <= flevel) then
        begin
            fmtx.Lock();
        {$I-}
            writeln(ffile, format('[%s] %s', [datetime_to_str(get_datetime(tz)), Str]));
            Flush(ffile);
        {$I+}
            fmtx.unLock();

            if (IOResult() <> 0) then
                writeln('<FLOG> [S] .write(ffile, ) failed! I/O Error!');
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
procedure t_log_file.Dump(const Str: string);
var
        FName: string;
begin
        FName := 'dump-' + datetime_to_str(get_datetime(tz)) + '.log';

        fmtx.Lock();

        AssignFile(dfile, FName);
    {$I-}
        if (FileExists(FName)) then
            Append(dfile)
        else
            ReWrite(dfile);
    {$I+}

        if (IOResult() = 0) then
        begin
        {$I-}
            writeln(dfile, format('[%s] %s', [datetime_to_str(get_datetime(tz)), Str]));
            CloseFile(dfile);
        {$I+}
        end;

        fmtx.unLock();
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
