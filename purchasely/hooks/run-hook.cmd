:; # -*- mode: sh -*-
:; # Polyglot wrapper: runs as cmd.exe on Windows and as /bin/sh elsewhere.
:; # On POSIX shells the leading ':;' lines are no-ops; the cmd-side @goto
:; # jumps past them into the Windows branch.
:;
:; # --- POSIX branch ---------------------------------------------------------
:; DIR=$(cd -- "$(dirname -- "$0")" && pwd)
:; HOOK_NAME=${1:-session-start}
:; shift 2>/dev/null || true
:; if [ -x "$DIR/$HOOK_NAME" ]; then
:;   exec "$DIR/$HOOK_NAME" "$@"
:; elif [ -f "$DIR/$HOOK_NAME" ]; then
:;   exec sh "$DIR/$HOOK_NAME" "$@"
:; else
:;   echo "run-hook.cmd: hook not found: $DIR/$HOOK_NAME" >&2
:;   exit 1
:; fi
:; exit 0

@echo off
setlocal
set "DIR=%~dp0"
set "HOOK_NAME=%~1"
if "%HOOK_NAME%"=="" set "HOOK_NAME=session-start"
shift
if exist "%DIR%%HOOK_NAME%" (
  where sh >nul 2>nul
  if %ERRORLEVEL%==0 (
    sh "%DIR%%HOOK_NAME%" %*
    exit /b %ERRORLEVEL%
  ) else (
    where bash >nul 2>nul
    if %ERRORLEVEL%==0 (
      bash "%DIR%%HOOK_NAME%" %*
      exit /b %ERRORLEVEL%
    ) else (
      echo run-hook.cmd: no POSIX shell on PATH; install Git Bash or WSL. 1>&2
      exit /b 1
    )
  )
) else (
  echo run-hook.cmd: hook not found: %DIR%%HOOK_NAME% 1>&2
  exit /b 1
)
