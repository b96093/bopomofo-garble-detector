@echo off
rem Launch in a separate window and exit immediately.
rem The update overwrites files in this folder, including this .cmd --
rem cmd.exe reads batch files incrementally, so waiting here would make it
rem resume from a wrong offset once the file is replaced.
rem See update.ps1 for what this actually does.
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1"
