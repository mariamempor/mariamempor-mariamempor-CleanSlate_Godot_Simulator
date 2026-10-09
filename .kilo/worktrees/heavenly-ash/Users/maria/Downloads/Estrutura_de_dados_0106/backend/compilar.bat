@echo off
echo ============================================
echo   Compilando Help Desk API...
echo ============================================

set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25
set PATH=%JAVA_HOME%\bin;%PATH%

if not exist "bin" mkdir bin

javac -encoding UTF-8 -d bin src/estruturas/*.java src/modelo/*.java src/util/*.java src/api/*.java

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Compilacao concluida com sucesso!
    echo Para executar, rode: executar.bat
) else (
    echo.
    echo ERRO na compilacao!
)
pause
