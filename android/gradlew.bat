@echo off
setlocal

set "GRADLE_BAT=C:\Users\myasp\.gradle\wrapper\dists\gradle-9.3.1-all\9ot9r568e8zfvvd4mn8rbu1j0\gradle-9.3.1\bin\gradle.bat"
set "JAVA_HOME=C:\Program Files\Amazon Corretto\jdk17.0.20_10"

if exist "%GRADLE_BAT%" (
  call "%GRADLE_BAT%" %*
  exit /b %ERRORLEVEL%
)

echo Gradle 9.3.1 was not found at:
echo %GRADLE_BAT%
echo Run flutter once on this machine or install Gradle 9.3.1, then retry.
exit /b 1
