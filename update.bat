@echo off
setlocal EnableDelayedExpansion

:: --- CONFIGURATION ---
set "SourceURL=https://raw.githubusercontent.com/Dimitarleomitkov/DiscordListManagementBot/refs/heads/master/backups/SimpleRollDB.lua"
set "FileName=SimpleRollDB.lua"
:: ---------------------

echo ========================================================
echo   			SimpleRoll
echo ========================================================
echo.

:: ----------------------------------------------------------
:: Downloading the lua file from github
:: ----------------------------------------------------------
:AskUpdate
set /p "UserUpdate=Do you want to UPDATE %FileName% from GitHub? (Y/N): "
if /i "%UserUpdate%"=="Y" goto DoUpdate
if /i "%UserUpdate%"=="N" goto AskDelete
goto AskUpdate

:DoUpdate
echo.
echo [Status] Downloading latest version...
curl --ssl-no-revoke -L -o "%FileName%" "%SourceURL%"

if %errorlevel% neq 0 (
    echo [ERROR] Download failed.
) else (
    echo [Success] %FileName% has been updated.
)
echo.

:: ----------------------------------------------------------
:: PART 2: DELETE SAVED VARIABLES
:: ----------------------------------------------------------
:AskDelete
echo --------------------------------------------------------
set /p "UserDelete=Do you want to do clean-up the addon? (Y/N): "
if /i "%UserDelete%"=="Y" goto DoDelete
if /i "%UserDelete%"=="N" goto End
goto AskDelete

:DoDelete
echo.
echo [Status] Locating WTF folder...

:: Navigate 3 levels up from "Interface\AddOns\SimpleRoll" to the WoW Root
:: Then go down into "WTF\Account"
set "RelPath=..\..\..\WTF\Account"

if exist "%RelPath%" (
    pushd "%RelPath%"
    echo [Status] Searching inside: %CD%
    
    :: /s = Search all subfolders (Accounts, Realms, Characters) recursively
    :: /q = Quiet mode (don't ask for confirmation for every single file)
    
    echo [Status] Deleting SimpleRoll.lua...
    if exist "SimpleRoll.lua" del /s /q "SimpleRoll.lua" >nul 2>&1
    del /s /q "SimpleRoll.lua"
    
    echo [Status] Deleting SimpleRoll.lua.bak...
    if exist "SimpleRoll.lua.bak" del /s /q "SimpleRoll.lua.bak" >nul 2>&1
    del /s /q "SimpleRoll.lua.bak"
    
    popd
    echo.
    echo [Success] All SavedVariables for SimpleRoll have been wiped.
) else (
)

:End
echo.
echo ========================================================
echo   Done.

pause
