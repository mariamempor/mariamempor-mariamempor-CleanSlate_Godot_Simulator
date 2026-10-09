@echo off
echo ============================================
echo   Iniciando Help Desk API...
echo ============================================
echo.

set JAVA_HOME=C:\JDK\openJdk-25
set PATH=%JAVA_HOME%\bin;%PATH%

java -cp bin helpdesk.api.HelpDeskAPI

pause
