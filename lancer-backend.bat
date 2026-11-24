@echo off
setlocal
cd /d "%~dp0backend"
if errorlevel 1 (
  echo Impossible d'acceder au dossier backend.
  pause
  exit /b 1
)

set "PORT_STATUS="
set "BACKEND_PID="
set "PORT_CHECK_FILE=port-check-result.tmp"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0backend\check-backend-port.ps1" > "%PORT_CHECK_FILE%" 2>nul
for /f "usebackq tokens=1,2" %%A in ("%PORT_CHECK_FILE%") do (
  set "PORT_STATUS=%%A"
  set "BACKEND_PID=%%B"
)
del "%PORT_CHECK_FILE%" >nul 2>&1
if /i "%PORT_STATUS%"=="RUNNING" goto BackendAlreadyRunning
if /i "%PORT_STATUS%"=="STALE" goto BackendNeedsRestart
if /i "%PORT_STATUS%"=="OCCUPIED" goto PortOccupied
goto PortIsClear

:BackendAlreadyRunning
echo Le backend TP7 repond deja sur le port 8081 (processus %BACKEND_PID%).
echo Aucune seconde instance ne sera demarree.
pause
exit /b 0

:BackendNeedsRestart
echo Une ancienne instance du backend TP7 utilise le port 8081 (processus %BACKEND_PID%).
echo Elle ne contient pas la configuration CORS necessaire pour Chrome.
echo Fermez sa fenetre avec Ctrl+C, puis relancez ce fichier.
pause
exit /b 1

:PortOccupied
echo Le port 8081 est utilise par un autre service (processus %BACKEND_PID%).
echo L'API TP7 ne repond pas sur ce port. Arretez ce service puis relancez ce fichier.
pause
exit /b 1

:PortIsClear

set "REQUESTED_JAVA_HOME=%JAVA_HOME%"
set "JAVA_HOME="
if defined REQUESTED_JAVA_HOME call :TryJava "%REQUESTED_JAVA_HOME%"
if not defined JAVA_HOME if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe" call :TryJava "%ProgramFiles%\Android\Android Studio\jbr"
if not defined JAVA_HOME if exist "%ProgramFiles%\JetBrains\IntelliJ IDEA 2026.2.3\jbr\bin\java.exe" call :TryJava "%ProgramFiles%\JetBrains\IntelliJ IDEA 2026.2.3\jbr"
if not defined JAVA_HOME if exist "%USERPROFILE%\.jdks\openjdk-25\bin\java.exe" call :TryJava "%USERPROFILE%\.jdks\openjdk-25"
if not defined JAVA_HOME for /d %%J in ("%ProgramFiles%\JetBrains\*\jbr") do if not defined JAVA_HOME call :TryJava "%%~J"

if not defined JAVA_HOME (
  echo JDK 25 introuvable ou incompatible.
  echo Installez un JDK 25 ou configurez JAVA_HOME vers un JDK 25.
  pause
  exit /b 1
)

set "PATH=%JAVA_HOME%\bin;%PATH%"
echo Java utilise : %JAVA_HOME%
echo Demarrage du backend Spring Boot sur le port 8081...
call gradlew.bat --console=plain bootRun
set "BACKEND_EXIT=%ERRORLEVEL%"
if not "%BACKEND_EXIT%"=="0" (
  echo.
  echo Le backend s'est arrete avec une erreur, code %BACKEND_EXIT%.
  echo Verifiez les messages ci-dessus, le port 8081 et la configuration H2.
  pause
)
exit /b %BACKEND_EXIT%

:TryJava
if not exist "%~1\bin\java.exe" exit /b 1
set "JAVA_VERSION="
set "JAVA_MAJOR="
set "JAVA_INFO=%TEMP%\tp7-java-%RANDOM%.txt"
"%~1\bin\java.exe" -version > "%JAVA_INFO%" 2>&1
for /f "tokens=3" %%V in ('findstr /i "version" "%JAVA_INFO%"') do set "JAVA_VERSION=%%~V"
del "%JAVA_INFO%" >nul 2>&1
for /f "tokens=1 delims=." %%M in ("%JAVA_VERSION%") do set "JAVA_MAJOR=%%M"
if not "%JAVA_MAJOR%"=="25" exit /b 1
set "JAVA_HOME=%~1"
exit /b 0
