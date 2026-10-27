@echo off
setlocal
rem Zips the exported itch.io builds for uploading through the itch.io website
rem (if you'd rather not use butler). Double-click to run; the zips land in
rem build\itch\upload\. Uses tar.exe, which comes with Windows 10 and 11.
rem   CharmCombo-windows.zip   CharmCombo-linux.zip
rem   CharmCombo-mac.zip       CharmCombo-web.zip (index.html at the top, as
rem                            itch.io needs for a browser game)
rem Linux and Mac players get the "executable" permission right only through
rem butler or the itch app, so prefer push_to_itch.bat for those two.

cd /d "%~dp0.."
rem Windows' own tar (a Git for Windows tar on the PATH can't make zips).
set "TAR=%SystemRoot%\System32\tar.exe"
if not exist "%TAR%" goto no_tar
if not exist "build\itch\upload" mkdir "build\itch\upload"

if exist "build\itch\windows\CharmCombo.exe" (
  if exist "build\itch\upload\CharmCombo-windows.zip" del "build\itch\upload\CharmCombo-windows.zip"
  "%TAR%" -a -cf "build\itch\upload\CharmCombo-windows.zip" -C "build\itch\windows" CharmCombo.exe
  echo Made CharmCombo-windows.zip
)
if exist "build\itch\linux\CharmCombo.x86_64" (
  if exist "build\itch\upload\CharmCombo-linux.zip" del "build\itch\upload\CharmCombo-linux.zip"
  "%TAR%" -a -cf "build\itch\upload\CharmCombo-linux.zip" -C "build\itch\linux" CharmCombo.x86_64
  echo Made CharmCombo-linux.zip
)
if exist "build\itch\mac\CharmCombo.zip" (
  copy /y "build\itch\mac\CharmCombo.zip" "build\itch\upload\CharmCombo-mac.zip" >nul
  echo Made CharmCombo-mac.zip
)
if not exist "build\itch\web\index.html" goto done
set "WEBFILES="
for %%f in ("build\itch\web\*") do call set "WEBFILES=%%WEBFILES%% "%%~nxf""
if exist "build\itch\upload\CharmCombo-web.zip" del "build\itch\upload\CharmCombo-web.zip"
"%TAR%" -a -cf "build\itch\upload\CharmCombo-web.zip" -C "build\itch\web" %WEBFILES%
echo Made CharmCombo-web.zip

:done
echo.
echo The zips are in build\itch\upload
pause
exit /b 0

:no_tar
echo This needs tar.exe, which comes with Windows 10 (April 2018 update) and later.
pause
exit /b 1
