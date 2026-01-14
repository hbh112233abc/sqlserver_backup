@echo off
chcp 65001 >nul
setlocal
REM ========================================
REM 测试备份脚本
REM ========================================

echo 正在测试SQL Server连接和备份配置...
echo.

REM 加载配置
call "%~dp0backup_config.bat"

echo ========================================
echo 测试SQL Server连接
echo ========================================

REM 检查sqlcmd是否可用
where sqlcmd >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 错误: sqlcmd命令未找到，请确保SQL Server命令行工具已安装并添加到系统PATH
    goto EndScript
)

if "%SQL_AUTH_MODE%"=="WIN" (
    sqlcmd -S "%SERVER_NAME%" -E -Q "SELECT @@VERSION" -h -1 2>nul
) else (
    sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -Q "SELECT @@VERSION" -h -1 2>nul
)

set SQL_RESULT=%ERRORLEVEL%
echo.

if %SQL_RESULT% neq 0 goto ConnectionFailed

echo SQL Server连接成功！
echo.
echo ========================================
echo 检查数据库是否存在
echo ========================================

for %%D in (%DATABASES%) do (
    echo 检查数据库: %%D
    if "%SQL_AUTH_MODE%"=="WIN" (
        sqlcmd -S "%SERVER_NAME%" -E -Q "SELECT name FROM sys.databases WHERE name = '%%D'" -h -1 2>nul
    ) else (
        sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -Q "SELECT name FROM sys.databases WHERE name = '%%D'" -h -1 2>nul
    )
)

echo.
echo ========================================
echo 测试zstd压缩工具
echo ========================================
"%ZSTD_PATH%" --version
if %ERRORLEVEL% equ 0 (
    echo zstd压缩工具可用
) else (
    echo 警告: zstd压缩工具不可用，请安装zstd
)

echo.
echo ========================================
echo 检查备份路径配置
echo ========================================
echo 注意: 备份路径必须是SQL Server服务器上的路径，而非客户端路径
echo 当前备份基础路径: %BACKUP_BASE_PATH%
echo.
echo 如果遇到'无法打开备份设备'错误，请参考CONFIG_GUIDE.md
echo 或运行diagnose_path.bat进行详细的路径诊断

echo.
echo ========================================
echo 测试备份功能
echo ========================================
echo 1. 测试全量备份: sqlserver_backup.bat FULL
echo 2. 测试增量备份: sqlserver_backup.bat DIFF
echo 3. 测试日志备份: sqlserver_backup.bat LOG
echo.
set /p TEST_BACKUP=是否执行测试备份? (Y/N):

if /i "%TEST_BACKUP%"=="Y" (
    echo 执行测试全量备份...
    call "%~dp0sqlserver_backup.bat" FULL
)

echo.
echo 配置测试完成！
goto ShowConfig

:ConnectionFailed
echo SQL Server连接失败！请检查配置。

:ShowConfig
echo.
echo ========================================
echo 当前配置信息
echo ========================================
echo 服务器: %SERVER_NAME%
echo 认证模式: %SQL_AUTH_MODE%
echo 备份路径: %BACKUP_BASE_PATH%
echo 全量备份保留天数: %FULL_BACKUP_KEEP_DAYS%
echo 增量备份保留天数: %DIFF_BACKUP_KEEP_DAYS%
echo 日志备份保留天数: %LOG_BACKUP_KEEP_DAYS%
echo 数据库列表: %DATABASES%
echo 压缩工具: %ZSTD_PATH%
echo 压缩级别: %COMPRESSION_LEVEL%

:EndScript
pause
