@echo off
title Server Operator MTs Roudhotut Thowalib
color 0A

echo ====================================================================
echo     MEMULAI SERVER LOKAL OPERATOR - MTS ROUDHOTUT THOWALIB
echo ====================================================================
echo.

cd /d "%~dp0server"

if not exist ".venv\Scripts\python.exe" (
    color 0C
    echo [ERROR] Virtual environment (.venv) tidak ditemukan di folder server!
    echo Silakan pastikan python venv sudah terpasang di folder:
    echo %~dp0server\.venv
    echo.
    pause
    exit /b 1
)

echo Memeriksa dan menjalankan server...
echo.

".venv\Scripts\python.exe" run_server.py

if %ERRORLEVEL% neq 0 (
    echo.
    echo Server berhenti dengan kode error %ERRORLEVEL%.
    pause
)
