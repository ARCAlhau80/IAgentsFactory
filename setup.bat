@echo off
cd /d "%~dp0"
title IAgentsFactory - Setup Menu
color 0B

set "IAGENTSFACTORY_PATH=C:\Users\AR CALHAU\source\repos\IAgentsFactory"

:MENU
cls
echo.
echo  ============================================
echo   IAgentsFactory - Setup Menu
echo  ============================================
echo.
echo   Projeto: %CD%
echo   Template: %IAGENTSFACTORY_PATH%
echo.
echo  --- SETUP DO PROJETO ----------------------
echo   [1] Semi-Automatico  (detecta + confirma)
echo   [2] Automatico       (detecta + aplica)
echo   [3] Manual           (preenche tudo)
echo  --- KNOWLEDGE HUB -------------------------
echo   [6] Inicializar Factory (Knowledge Hub)
echo   [7] Registrar projeto na Factory
echo   [8] Buscar no Knowledge Hub
echo   [9] Capturar solucao
echo   [10] Metricas e Stats
echo   [11] Listar projetos
echo   [12] Novo projeto (wizard greenfield/existente)
echo  --- CONFIG ---------------------------------
echo   [4] Alterar caminho do template
echo   [5] Sair
echo  --------------------------------------------
echo.
set /p OPT="  Escolha [1-12]: "

if "%OPT%"=="1" goto SEMI
if "%OPT%"=="2" goto AUTO
if "%OPT%"=="3" goto MANUAL
if "%OPT%"=="4" goto TEMPLATE
if "%OPT%"=="5" goto FIM
if "%OPT%"=="6" goto FACTORY_INIT
if "%OPT%"=="7" goto FACTORY_REGISTER
if "%OPT%"=="8" goto FACTORY_SEARCH
if "%OPT%"=="9" goto FACTORY_CAPTURE
if "%OPT%"=="10" goto FACTORY_STATS
if "%OPT%"=="11" goto FACTORY_PROJECTS
if "%OPT%"=="12" goto FACTORY_NEW_PROJECT
echo.
echo   Opcao invalida!
timeout /t 2 >nul
goto MENU

:TEMPLATE
echo.
set /p IAGENTSFACTORY_PATH="  Novo caminho do template: "
if not exist "%IAGENTSFACTORY_PATH%\setup-ia-squad.ps1" (
    echo.
    echo   ERRO: setup-ia-squad.ps1 nao encontrado em "%IAGENTSFACTORY_PATH%"
    pause
)
goto MENU

:SEMI
echo.
echo   Modo Semi-Automatico: detecta projeto e pede confirmacao...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\setup-ia-squad.ps1"
goto DONE

:AUTO
echo.
echo   Modo Automatico: detecta projeto e aplica sem perguntas...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\setup-ia-squad.ps1" -Auto
goto DONE

:MANUAL
echo.
set /p P_NAME="  Nome do projeto: "
set /p P_DESC="  Descricao: "
set /p P_LANG="  Linguagem (ex: Java, Python, TypeScript): "
set /p P_FW="  Framework (ex: Spring Boot, FastAPI, React): "
set /p P_BUILD="  Comando de build: "
set /p P_TEST="  Comando de teste: "
set /p P_RUN="  Comando de run: "
set /p P_DB="  Banco de dados (ex: PostgreSQL, Oracle): "
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\setup-ia-squad.ps1" -Auto -ProjectName "%P_NAME%" -ProjectDesc "%P_DESC%" -Language "%P_LANG%" -Framework "%P_FW%" -BuildCmd "%P_BUILD%" -TestCmd "%P_TEST%" -RunCmd "%P_RUN%" -DbType "%P_DB%"
goto DONE

:DONE
echo.
echo  ============================================
echo   Setup concluido!
echo  ============================================
echo.
pause
goto MENU

:FACTORY_INIT
echo.
echo   Inicializando IAgentsFactory Knowledge Hub...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\iagents-factory.ps1" init
pause
goto MENU

:FACTORY_REGISTER
echo.
set /p REG_PATH="  Caminho do projeto (ou Enter para atual): "
if "%REG_PATH%"=="" set "REG_PATH=%CD%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\iagents-factory.ps1" register "%REG_PATH%"
pause
goto MENU

:FACTORY_SEARCH
echo.
set /p SEARCH_Q="  Buscar soluções: "
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\iagents-factory.ps1" search "%SEARCH_Q%"
pause
goto MENU

:FACTORY_CAPTURE
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\iagents-factory.ps1" capture
pause
goto MENU

:FACTORY_STATS
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\iagents-factory.ps1" stats
pause
goto MENU

:FACTORY_PROJECTS
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\iagents-factory.ps1" projects
pause
goto MENU

:FACTORY_NEW_PROJECT
echo.
echo   Abrindo wizard de novo projeto...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%IAGENTSFACTORY_PATH%\new-project.ps1"
pause
goto MENU

:FIM
echo.
echo   Ate mais!
echo.
timeout /t 1 >nul

