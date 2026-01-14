@echo off
chcp 65001 >nul
setlocal

echo ========================================
echo SQL Server备份路径诊断工具
echo ========================================
echo.

REM 加载配置
call "%~dp0backup_config.bat"

echo 当前配置:
echo 服务器: %SERVER_NAME%
echo 备份路径: %BACKUP_BASE_PATH%
echo 数据库: %DATABASES%
echo.

echo ========================================
echo 正在测试连接到SQL Server...
echo ========================================
sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -Q "SELECT @@SERVERNAME AS ServerName, @@VERSION AS Version" -h -1 2>nul
if %ERRORLEVEL% neq 0 (
    echo 错误: 无法连接到SQL Server
    goto End
) else (
    echo 连接成功！
)
echo.

echo ========================================
echo 检查SQL Server服务器上的路径...
echo ========================================
REM 创建一个临时的SQL查询脚本来检查路径
echo DECLARE @path NVARCHAR(4000) = '%BACKUP_BASE_PATH%' > "%TEMP%\check_path.sql"
echo SELECT @path AS CheckPath >> "%TEMP%\check_path.sql"
echo IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'xp_create_subdir') BEGIN >> "%TEMP%\check_path.sql"
echo   PRINT 'xp_create_subdir 扩展存储过程可用' >> "%TEMP%\check_path.sql"
echo END >> "%TEMP%\check_path.sql"
echo EXEC master.dbo.xp_create_subdir @path >> "%TEMP%\check_path.sql" 2>> "%TEMP%\check_path.sql"
echo SELECT 'Path exists and accessible' AS Result >> "%TEMP%\check_path.sql"

sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -i "%TEMP%\check_path.sql" -h -1
if %ERRORLEVEL% neq 0 (
    echo.
    echo 警告: 可能存在路径访问问题！
    echo 提示: 请确保 '%BACKUP_BASE_PATH%' 是SQL Server服务器上的有效路径，
    echo 并且SQL Server服务账户对该路径有写入权限。
) else (
    echo 路径检查完成，没有发现明显问题。
)
echo.

echo ========================================
echo 建议的操作:
echo ========================================
echo 1. 如果备份路径是本地路径（如 C:\...），请确保它存在于SQL Server服务器上
echo 2. 如果需要使用网络路径，请确保SQL Server服务账户有访问权限
echo 3. 检查SQL Server服务运行的账户权限
echo 4. 参考 CONFIG_GUIDE.md 获取更多详细配置说明
echo.

REM 清理临时文件
if exist "%TEMP%\check_path.sql" del "%TEMP%\check_path.sql"

:End
pause
