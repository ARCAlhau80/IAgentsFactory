@echo off
cd /d "%~dp0"
title IAgentsFactory - New Project Wizard
color 0A

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0new-project.ps1" %*
exit /b %errorlevel%