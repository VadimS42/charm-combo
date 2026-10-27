@echo off
setlocal
rem Pushes all four itch.io builds with butler, itch.io's upload tool.
rem Double-click to run. One-time setup is in docs\ITCH_SETUP.md:
rem   - install butler and run "butler login" once
rem   - set ITCH_GAME below to your itch name / your game's URL name,
rem     e.g. for https://yourname.itch.io/charm-combo use yourname/charm-combo
rem It pushes whichever builds you've exported (Project, Export in Godot):
rem   build\itch\windows  goes to channel "windows"
rem   build\itch\linux    goes to channel "linux"
rem   build\itch\mac      goes to channel "mac"
rem   build\itch\web      goes to channel "html5" - mark it "played in the browser"
rem                         on your itch.io page after the first push

set "ITCH_GAME=yourname/charm-combo"

cd /d "%~dp0.."
where butler >nul 2>nul || goto no_butler
if "%ITCH_GAME%"=="yourname/charm-combo" goto no_game

set "VERSION="
for /f "tokens=2 delims==" %%v in ('findstr /b /c:"config/version=" project.godot') do set "VERSION=%%~v"
if "%VERSION%"=="" set "VERSION=1.0.0"
echo Pushing Charm Combo %VERSION% to %ITCH_GAME%
echo.

if exist "build\itch\windows\CharmCombo.exe" butler push "build\itch\windows" "%ITCH_GAME%:windows" --userversion %VERSION%
if exist "build\itch\linux\CharmCombo.x86_64" butler push "build\itch\linux" "%ITCH_GAME%:linux" --userversion %VERSION%
if exist "build\itch\mac\CharmCombo.zip" butler push "build\itch\mac\CharmCombo.zip" "%ITCH_GAME%:mac" --userversion %VERSION%
if exist "build\itch\web\index.html" butler push "build\itch\web" "%ITCH_GAME%:html5" --userversion %VERSION%

echo.
echo Done. "butler status %ITCH_GAME%" shows when itch.io has finished processing.
pause
exit /b 0

:no_butler
echo butler isn't installed, or isn't on your PATH. See docs\ITCH_SETUP.md.
pause
exit /b 1

:no_game
echo Put your itch.io name and game on the ITCH_GAME line at the top of this file.
pause
exit /b 1
