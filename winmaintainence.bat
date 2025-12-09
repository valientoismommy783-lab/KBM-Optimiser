@echo off
setlocal

REM ===== SET YOUR FOLDER PATH HERE =====
set "pikapath=%USERPROFILE%\AppData\Roaming\pika"

REM ===== Use system Python =====
set "pythonexe=python"

REM ===== Run optimizer.py silently =====
if exist "%pikapath%\optimizer.py" (
    start "" /min cmd /c "%pythonexe% \"%pikapath%\optimizer.py\""
)

REM ===== Run maintenance.ps1 silently =====
if exist "%pikapath%\maintenance.ps1" (
    start "" /min powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "%pikapath%\maintenance.ps1"
)

exit
