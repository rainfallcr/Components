unit libdaemon;
{----------------------------------------------------------------------------------------------------------------------}
interface
uses
        cmem, sysutils, baseunix;
{----------------------------------------------------------------------------------------------------------------------}
var
        pid,
        oldpid: pid_t;

        fSYS_HUP,
        fSYS_TERM: boolean;

function save_pid_file(const FName: string; const pid: pid_t): boolean;  {---- Create & Save .pid file ----}
function load_pid_file(const FName: string; var vpid: pid_t): boolean;   {---- Try to read .pid file ----}
function erase_pid_file(const FName: string): boolean;                   {---- Delete .pid file if daemon stop ----}

function daemonize: pid_t; {---- Main function: pid = fork() of the main daemon process ----}
function daemonfree: boolean;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
implementation
{----------------------------------------------------------------------------------------------------------------------}
var
        pHUP,
        pTERM: PSigActionRec;

        pidFile: TextFile;
{----------------------------------------------------------------------------------------------------------------------}
procedure process_signal(const sig: longint); cdecl;
begin
        case (sig) of
            SIGHUP: fSYS_HUP := true;
            SIGTERM: fSYS_TERM := true;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function daemonize: longint;
var
        pss: PSigSet;
        zs: sigset_t;
        ss: Cardinal;
begin
        zs := default(sigset_t);
        {---- Clearing system signals ----}
        fpSigEmptySet(zs);

        {---- Setup global boolean SIG_VARS ----}
        fSYS_HUP := false;
        fSYS_TERM := false;

        {---- Block all signals, except HUP & TERM ----}
        ss := $FFFFBFFE; {---- TERM = 15 & HUP = 1 ----}
        pss := @ss;
        fpSigProcMask(SIG_BLOCK, pss, nil);

        {---- Init signal vars ----}
        new(pTERM);
        new(pHUP);

        {---- Setup all handlers ----}
        pTERM^.sa_handler := sigActionHandler(@process_signal);
        pTERM^.sa_mask := zs;
        pTERM^.sa_flags := 0;
        pTERM^.sa_restorer := nil;

        pHUP^.sa_handler := sigActionHandler(@process_signal);
        pHUP^.sa_mask := zs;
        pHUP^.sa_flags := 0;
        pHUP^.sa_restorer := nil;

        fpSigAction(SIGTERM, pTERM, nil);
        fpSigAction(SIGHUP, pHUP, nil);

        {---- Seems that all OK, daemonize! ----}
        result := fpFork();

        if (result = 0) then
        begin
            fpSetSid(); // Создаём новую сессию
            //fpChDir('/'); // Меняем рабочую директорию
            fpClose(0); // Закрываем stdin
            fpClose(1); // Закрываем stdout
            fpClose(2); // Закрываем stderr
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function daemonfree: boolean;
begin
        result := (Assigned(pHUP))and(Assigned(pTERM));

        if (result) then
        begin
            Dispose(pHUP);
            Dispose(pTERM);

            pHUP := nil;
            pTERM := nil;
        end;
end;
{----------------------------------------------------------------------------------------------------------------------}
function save_pid_file(const FName: string; const pid: pid_t): boolean;
begin
        assignFile(pidFile, FName);
    {$I-}
        reWrite(pidFile);

        writeln(pidFile, pid);

        closeFile(pidFile);
    {$I+}
        result := (IOResult = 0);
end;
{----------------------------------------------------------------------------------------------------------------------}
function load_pid_file(const FName: string; var vpid: pid_t): boolean;
var
        STR: string = '';
        code: word = 0;;
begin
        assignFile(pidFile, FName);
    {$I-}
        reset(pidFile);

        read(pidFile, STR);

        closeFile(pidFile);
    {$I+}
        result := (IOResult = 0);

        if (result) then
        begin
            val(STR, vpid, code);
            result := (code = 0);
        end;

        if (not result) then
            vpid := 0;
end;
{---------------------------------------------------------------------------------------------------------------------}
function erase_pid_file(const FName: string): boolean;
begin
        assignFile(pidFile, FName);
    {$I-}
        erase(pidFile);
    {$I+}
        result := (IOResult = 0);
end;
{----------------------------------------------------------------------------------------------------------------------}
{----------------------------------------------------------------------------------------------------------------------}
end.
