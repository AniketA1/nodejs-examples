@echo off
setlocal enabledelayedexpansion

if defined DEBUG ( set _DEBUG=1 ) else ( set _DEBUG=0 )

rem ##########################################################################
rem ## Environment setup

set _BASENAME=%~n0

set _EXITCODE=0

call :args %*
if not %_EXITCODE%==0 goto end

rem ##########################################################################
rem ## Main

set _GIT_PATH=
set _MONGO_PATH=

call :npm
if not %_EXITCODE%==0 goto end

call :git
if not %_EXITCODE%==0 goto end

call :pm2
if not %_EXITCODE%==0 goto end

call :mongod
if not %_EXITCODE%==0 goto end

goto end

rem ##########################################################################
rem ## Subroutines

rem input parameter: %*
:args
set _VERBOSE=0
set __N=0
:args_loop
set __ARG=%~1
if not defined __ARG (
    goto args_done
) else if not "%__ARG:~0,1%"=="-" (
    set /a __N=!__N!+1
)
if /i "%__ARG%"=="help" ( call :help & goto :eof
) else if /i "%__ARG%"=="-verbose" ( set _VERBOSE=1
) else (
    echo %_BASENAME%: Unknown subcommand %__ARG%
    set _EXITCODE=1
    goto :eof
)
shift
goto :args_loop
:args_done
goto :eof

:help
echo Usage: setenv { options ^| subcommands }
echo   Options:
echo     -verbose         display environment settings
echo   Subcommands:
echo     help             display this help message
goto :eof

rem postcondition: NODE_HOME is defined and valid
:npm
where /q npm.cmd
if %ERRORLEVEL%==0 (
    if not defined NODE_HOME (
        for /f %%i in ('where /f npm.cmd') do set NODE_HOME=%%~dpsi
    )
    goto :eof
)
if defined NODE_HOME (
    set _NODE_HOME=%NODE_HOME%
    if %_DEBUG%==1 echo [%_BASENAME%] Using environment variable NODE_HOME
) else (
    where /q node.exe
    if !ERRORLEVEL!==0 (
        for /f "delims=" %%i in ('where /f node.exe') do set _NODE_HOME=%%~dpsi
        if %_DEBUG%==1 echo [%_BASENAME%] Using path of Node executable found in PATH
    ) else (
        set __PATH=C:\opt
        for /f %%f in ('dir /ad /b "!__PATH!\node-v8*" 2^>NUL') do set _NODE_HOME=!__PATH!\%%f
        if not defined _NODE_HOME (
            set __PATH=C:\progra~1
            for /f %%f in ('dir /ad /b "!__PATH!\node-v8*" 2^>NUL') do set _NODE_HOME=!__PATH!\%%f
        )
        if defined _NODE_HOME (
            rem path name of installation directory may contain spaces
            for /f "delims=" %%f in ("!_NODE_HOME!") do set _NODE_HOME=%%~sf
            if %_DEBUG%==1 echo [%_BASENAME%] Using default Node installation directory !_NODE_HOME!
        )
    )
)
if not exist "%_NODE_HOME%\nodevars.bat" (
    echo Node installation directory not found ^(%_NODE_HOME%^)
    set _EXITCODE=1
    goto :eof
)
if not exist "%_NODE_HOME%\npm.cmd" (
    echo npm not found in Node installation directory ^(%_NODE_HOME%^)
    set _EXITCODE=1
    goto :eof
)
set NODE_HOME=%_NODE_HOME%
call %NODE_HOME%\nodevars.bat
goto :eof


:git
where /q git.exe
if %ERRORLEVEL%==0 goto :eof

if defined GIT_HOME (
    set _GIT_HOME=%GIT_HOME%
    if %_DEBUG%==1 echo [%_BASENAME%] Using environment variable GIT_HOME
) else (
    set __PATH=C:\opt
    if exist "!__PATH!\Git\" ( set _GIT_HOME=!__PATH!\Git
    ) else (
        for /f %%f in ('dir /ad /b "!__PATH!\Git*" 2^>NUL') do set _GIT_HOME=!__PATH!\%%f
        if not defined _GIT_HOME (
            set __PATH=C:\Progra~1
            for /f %%f in ('dir /ad /b "!__PATH!\Git*" 2^>NUL') do set _GIT_HOME=!__PATH!\%%f
        )
    )
    if defined _GIT_HOME (
        if %_DEBUG%==1 echo [%_BASENAME%] Using default Git installation directory !_GIT_HOME!
    )
)
if not exist "%_GIT_HOME%\bin\git.exe" (
    echo Git executable not found ^(%_GIT_HOME%^)
    set _EXITCODE=1
    goto :eof
)
set "_GIT_PATH=;%_GIT_HOME%\bin"
goto :eof

:pm2
where /q pm2.cmd
if %ERRORLEVEL%==0 goto :eof

if not exist "%NODE_HOME%\pm2.cmd" (
    echo pm2 command not found in Node installation directory ^(%NODE_HOME% ^)
    set /p __PM2_ANSWER="Execute 'npm -g install pm2 --prefix %NODE_HOME%' (Y/N)? "
    if /i "!__PM2_ANSWER!"=="y" (
        %NODE_HOME%\npm.cmd -g install pm2 --prefix %NODE_HOME%
    ) else (
        set _EXITCODE=1
        goto :eof
    )
)
goto :eof

:mongod
where /q mongod.exe
if %ERRORLEVEL%==0 goto :eof

if defined MONGO_HOME (
    set _MONGO_HOME=%MONGO_HOME%
    if %_DEBUG%==1 echo [%_BASENAME%] Using environment variable MONGO_HOME
) else (
    where /q mongod.exe
    if !ERRORLEVEL!==0 (
        for /f %%i in ('where /f mongod.exe') do set _MONGO_HOME=%%~dpsi
        if %_DEBUG%==1 echo [%_BASENAME%] Using path of MongoDB executable found in PATH
    ) else (
        set _PATH=C:\Progra~1
        for /f %%f in ('dir /ad /b "!_PATH!\MongoDB*" 2^>NUL') do set _MONGO_HOME=!_PATH!\%%f
        if defined _MONGO_HOME (
            if %_DEBUG%==1 echo [%_BASENAME%] Using default MongoDB installation directory !_MONGO_HOME!
        )
    )
)
if not defined _MONGO_BIN_DIR (
    for /f "delims=" %%i in ('where /f /r "%_MONGO_HOME%" mongod.exe 2^>NUL') do set _MONGO_BIN_DIR=%%~dpsi
)
if not exist "%_MONGO_BIN_DIR%\mongod.exe" (
    echo MongoDB executable not found ^(%_MONGO_HOME%^)
    set _EXITCODE=1
    goto :eof
)
set "_MONGO_PATH=;%_MONGO_BIN_DIR%"
goto :eof

:print_env
set __WHERE_ARGS=
where /q npm.cmd
if %ERRORLEVEL%==0 (
    for /f %%i in ('node.exe --version') do echo NODE_VERSION=%%i
    for /f %%i in ('npm.cmd --version') do echo NPM_VERSION=%%i
    set __WHERE_ARGS=%__WHERE_ARGS% node.exe npm.cmd
)
where /q git.exe
if %ERRORLEVEL%==0 (
    for /f "tokens=1,2,*" %%i in ('git.exe --version') do echo GIT_VERSION=%%k
    set __WHERE_ARGS=%__WHERE_ARGS% git.exe
)
where /q mongod.exe
if %ERRORLEVEL%==0 (
    for /f "tokens=1,2,*" %%i in ('mongod.exe --version ^| findstr "^db"') do echo MONGOD_VERSION=%%k
    set __WHERE_ARGS=%__WHERE_ARGS% mongod.exe
)
where %__WHERE_ARGS%
goto :eof

rem ##########################################################################
rem ## Cleanups

:end
endlocal & (
    if not defined NODE_HOME set NODE_HOME=%_NODE_HOME%
    if not defined NODE_PATH set NODE_PATH=%~dp0\node_modules
    set "PATH=%PATH%%_GIT_PATH%%_MONGO_PATH%"
    if %_VERBOSE%==1 call :print_env
    if %_DEBUG%==1 echo [%_BASENAME%] _EXITCODE=%_EXITCODE%
    for /f "delims==" %%i in ('set ^| findstr /b "_"') do set %%i=
)
