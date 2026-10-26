@echo off
setlocal
title Server Operator MTs Roudhotut Thowalib
color 0A

echo ====================================================================
echo     MEMULAI SERVER LOKAL OPERATOR - MTS ROUDHOTUT THOWALIB
echo ====================================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "SERVER_DIR=%SCRIPT_DIR%server"
set "PYTHON_EXE=%SERVER_DIR%\.venv\Scripts\python.exe"

if not exist "%PYTHON_EXE%" (
    color 0C
    echo [ERROR] Python environment tidak ditemukan di:
    echo %PYTHON_EXE%
    echo.
    pause
    exit /b 1
)

cd /d "%SERVER_DIR%"

echo Menjalankan server lokal...
echo.

"%PYTHON_EXE%" run_server.py

echo.
echo Server telah dimatikan.
pause
