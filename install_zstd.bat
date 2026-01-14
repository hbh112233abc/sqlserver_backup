@echo off
chcp 65001 >nul
REM ========================================
REM zstd压缩工具安装脚本
REM ========================================

echo ========================================
echo zstd压缩工具安装向导
echo ========================================

echo 检查zstd是否已安装...
zstd --version >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo zstd已经安装并可用
    zstd --version
    pause
    exit /b 0
)

echo zstd未安装，开始安装过程...
echo.

echo 安装选项:
echo 1. 下载预编译版本 (推荐)
echo 2. 使用Chocolatey安装
echo 3. 使用Scoop安装
echo 4. 手动安装说明

set /p INSTALL_CHOICE=请选择安装方式 (1-4): 

if "%INSTALL_CHOICE%"=="1" goto DOWNLOAD_PREBUILT
if "%INSTALL_CHOICE%"=="2" goto CHOCOLATEY_INSTALL
if "%INSTALL_CHOICE%"=="3" goto SCOOP_INSTALL
if "%INSTALL_CHOICE%"=="4" goto MANUAL_INSTALL

:DOWNLOAD_PREBUILT
echo.
echo ========================================
echo 下载预编译版本
echo ========================================

echo 正在创建工具目录...
set TOOLS_DIR=%~dp0tools
if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%"

echo.
echo 请手动执行以下步骤:
echo 1. 访问 https://github.com/facebook/zstd/releases
echo 2. 下载最新的 zstd-v*-win64.zip 文件
echo 3. 解压到 %TOOLS_DIR% 目录
echo 4. 将 %TOOLS_DIR% 添加到系统PATH环境变量
echo.
echo 或者将zstd.exe复制到当前目录

pause
goto END

:CHOCOLATEY_INSTALL
echo.
echo ========================================
echo 使用Chocolatey安装
echo ========================================

choco --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Chocolatey未安装，请先安装Chocolatey
    echo 访问: https://chocolatey.org/install
    pause
    goto END
)

echo 正在使用Chocolatey安装zstd...
choco install zstandard -y

if %ERRORLEVEL% equ 0 (
    echo zstd安装成功！
) else (
    echo zstd安装失败，请检查错误信息
)

pause
goto END

:SCOOP_INSTALL
echo.
echo ========================================
echo 使用Scoop安装
echo ========================================

scoop --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Scoop未安装，请先安装Scoop
    echo 在PowerShell中执行:
    echo Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    echo irm get.scoop.sh ^| iex
    pause
    goto END
)

echo 正在使用Scoop安装zstd...
scoop install zstd

if %ERRORLEVEL% equ 0 (
    echo zstd安装成功！
) else (
    echo zstd安装失败，请检查错误信息
)

pause
goto END

:MANUAL_INSTALL
echo.
echo ========================================
echo 手动安装说明
echo ========================================

echo 手动安装zstd的步骤:
echo.
echo 1. 访问 https://github.com/facebook/zstd/releases
echo 2. 下载最新的 Windows 版本 (zstd-v*-win64.zip)
echo 3. 解压下载的文件
echo 4. 将 zstd.exe 复制到以下位置之一:
echo    - 当前脚本目录: %~dp0
echo    - 系统PATH中的任意目录 (如 C:\Windows\System32)
echo    - 创建专门的工具目录并添加到PATH
echo.
echo 5. 打开新的命令提示符窗口
echo 6. 运行 'zstd --version' 验证安装

pause
goto END

:END
echo.
echo 安装完成后，请运行 test_backup.bat 验证zstd是否可用
pause