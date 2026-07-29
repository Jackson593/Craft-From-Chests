@echo off
REM CraftFromChests - one-time setup.
REM Windows blocks scripts that came from a downloaded zip, so this unblocks the
REM files first and then runs the generator with the policy bypassed for this
REM process only (nothing about your system's settings is changed).

echo.
echo  CraftFromChests - building recipe data from your own Icarus install...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse -File | Unblock-File" 2>nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-data.ps1"

echo.
echo  If you saw an error above, see the Troubleshooting section of README.md.
echo.
pause
