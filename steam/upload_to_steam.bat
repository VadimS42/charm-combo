@echo off
setlocal
rem Uploads the exported "Windows (Steam)" build to Steam (SteamPipe).
rem Double-click to run. One-time setup is in docs\STEAM_SETUP.md, step 8:
rem   - set STEAMCMD below to steamcmd.exe from the Steamworks SDK
rem     (sdk\tools\ContentBuilder\builder\steamcmd.exe)
rem   - set STEAM_USER below to the Steam account that uploads builds
rem   - put your App ID and depot ID into app_build.vdf, next to this file
rem steamcmd asks for the password (and a Steam Guard code) itself; never
rem write your password into this file.

set "STEAMCMD=C:\steamworks_sdk\tools\ContentBuilder\builder\steamcmd.exe"
set "STEAM_USER="

cd /d "%~dp0"
if not exist "%STEAMCMD%" goto no_steamcmd
if "%STEAM_USER%"=="" goto no_user
rem (comment lines skipped: they mention the placeholders too)
findstr /v /c:"//" app_build.vdf | findstr /c:"YOUR_" >nul && goto no_ids
if not exist "..\build\steam\windows\CharmCombo.exe" goto no_build

echo Uploading build\steam\windows to Steam...
"%STEAMCMD%" +login %STEAM_USER% +run_app_build "%~dp0app_build.vdf" +quit
echo.
echo Done. Set the build live in Steamworks: your app, SteamPipe, Builds.
echo Upload logs are in build\steam_output.
pause
exit /b 0

:no_steamcmd
echo Can't find steamcmd.exe at:
echo   %STEAMCMD%
echo Edit the STEAMCMD line at the top of this file, see docs\STEAM_SETUP.md.
pause
exit /b 1

:no_user
echo Put your Steam account name on the STEAM_USER line at the top of this file.
pause
exit /b 1

:no_ids
echo Put your App ID and depot ID into steam\app_build.vdf first.
pause
exit /b 1

:no_build
echo No build to upload yet. In Godot: Project, Export, pick "Windows (Steam)",
echo Export Project, and keep the path build/steam/windows/CharmCombo.exe.
pause
exit /b 1
