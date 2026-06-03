@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "TEZZC_ENV=%TEZZC%"
set "TEZZC="
set "PROBE=%ROOT%\tools\probes\tls_connect_ex_probe.tn"

if defined TEZZC_ENV if exist "%TEZZC_ENV%" (
  if exist "%PROBE%" (
    "%TEZZC_ENV%" check "%PROBE%" >nul 2>nul
    if not errorlevel 1 set "TEZZC=%TEZZC_ENV%"
  ) else (
    set "TEZZC=%TEZZC_ENV%"
  )
)
if not defined TEZZC if exist "%ROOT%\bin\tezzc.exe" (
  if exist "%PROBE%" (
    "%ROOT%\bin\tezzc.exe" check "%PROBE%" >nul 2>nul
    if not errorlevel 1 set "TEZZC=%ROOT%\bin\tezzc.exe"
  ) else (
    set "TEZZC=%ROOT%\bin\tezzc.exe"
  )
)
if not defined TEZZC if exist "%ROOT%\bin\tezzc-windows-x64.exe" (
  if exist "%PROBE%" (
    "%ROOT%\bin\tezzc-windows-x64.exe" check "%PROBE%" >nul 2>nul
    if not errorlevel 1 set "TEZZC=%ROOT%\bin\tezzc-windows-x64.exe"
  ) else (
    set "TEZZC=%ROOT%\bin\tezzc-windows-x64.exe"
  )
)
if not defined TEZZC if exist "%ROOT%\build\tezzc.exe" (
  if exist "%PROBE%" (
    "%ROOT%\build\tezzc.exe" check "%PROBE%" >nul 2>nul
    if not errorlevel 1 set "TEZZC=%ROOT%\build\tezzc.exe"
  ) else (
    set "TEZZC=%ROOT%\build\tezzc.exe"
  )
)
if not defined TEZZC if exist "%ROOT%\tezzc.exe" (
  if exist "%PROBE%" (
    "%ROOT%\tezzc.exe" check "%PROBE%" >nul 2>nul
    if not errorlevel 1 set "TEZZC=%ROOT%\tezzc.exe"
  ) else (
    set "TEZZC=%ROOT%\tezzc.exe"
  )
)
if not defined TEZZC for /f "delims=" %%P in ('where tezzc.exe 2^>nul') do if not defined TEZZC (
  if exist "%PROBE%" (
    "%%P" check "%PROBE%" >nul 2>nul
    if not errorlevel 1 set "TEZZC=%%P"
  ) else (
    set "TEZZC=%%P"
  )
)
if not defined TEZZC for /f "delims=" %%P in ('where tezzc-windows-x64.exe 2^>nul') do if not defined TEZZC (
  if exist "%PROBE%" (
    "%%P" check "%PROBE%" >nul 2>nul
    if not errorlevel 1 set "TEZZC=%%P"
  ) else (
    set "TEZZC=%%P"
  )
)
if not defined TEZZC if exist "%ROOT%\tools\build_core_strict.ps1" (
  powershell -ExecutionPolicy Bypass -File "%ROOT%\tools\build_core_strict.ps1" >nul 2>nul
  if not defined TEZZC if exist "%ROOT%\bin\tezzc.exe" (
    if exist "%PROBE%" (
      "%ROOT%\bin\tezzc.exe" check "%PROBE%" >nul 2>nul
      if not errorlevel 1 set "TEZZC=%ROOT%\bin\tezzc.exe"
    ) else (
      set "TEZZC=%ROOT%\bin\tezzc.exe"
    )
  )
  if not defined TEZZC if exist "%ROOT%\build\tezzc.exe" (
    if exist "%PROBE%" (
      "%ROOT%\build\tezzc.exe" check "%PROBE%" >nul 2>nul
      if not errorlevel 1 set "TEZZC=%ROOT%\build\tezzc.exe"
    ) else (
      set "TEZZC=%ROOT%\build\tezzc.exe"
    )
  )
)

if not defined TEZZC if defined TEZZC_ENV if exist "%TEZZC_ENV%" set "TEZZC=%TEZZC_ENV%"
if not defined TEZZC if exist "%ROOT%\bin\tezzc.exe" set "TEZZC=%ROOT%\bin\tezzc.exe"
if not defined TEZZC if exist "%ROOT%\bin\tezzc-windows-x64.exe" set "TEZZC=%ROOT%\bin\tezzc-windows-x64.exe"
if not defined TEZZC if exist "%ROOT%\build\tezzc.exe" set "TEZZC=%ROOT%\build\tezzc.exe"
if not defined TEZZC if exist "%ROOT%\tezzc.exe" set "TEZZC=%ROOT%\tezzc.exe"
if not defined TEZZC for /f "delims=" %%P in ('where tezzc.exe 2^>nul') do if not defined TEZZC set "TEZZC=%%P"
if not defined TEZZC for /f "delims=" %%P in ('where tezzc-windows-x64.exe 2^>nul') do if not defined TEZZC set "TEZZC=%%P"

if not defined TEZZC (
  echo tezz: compiler not found ^(expected bin\tezzc.exe, a source build via tools\build_core_strict.ps1, or PATH tezzc.exe^).
  exit /b 1
)

set "TOOL=%ROOT%\tools\tezz.tn"
if not exist "%TOOL%" (
  echo tezz: tools\tezz.tn not found next to launcher.
  exit /b 1
)

set "PATH=%ROOT%\bin;%ROOT%\build;%ROOT%;%PATH%"
set "TEZZ_SDK_ROOT=%ROOT%"

"%TEZZC%" run --bc "%TOOL%" -- %* --tezzc "%TEZZC%" --sdk-root "%ROOT%"
exit /b %ERRORLEVEL%
