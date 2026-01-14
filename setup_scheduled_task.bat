@echo off
chcp 65001 >nul
REM ========================================
REM 创建Windows计划任务脚本
REM 根据配置创建多个备份计划任务
REM ========================================

echo 正在创建SQL Server数据库备份计划任务...

REM 加载配置
call "%~dp0backup_config.bat"

REM 获取当前脚本路径
set SCRIPT_PATH=%~dp0sqlserver_backup.bat

echo.
echo ========================================
echo 创建全量备份计划任务
echo ========================================

REM 将星期几转换为schtasks兼容的格式
set DAY_VALUE=%FULL_BACKUP_DAY%
if /i "%FULL_BACKUP_DAY%"=="SUNDAY" set DAY_VALUE=SUN
if /i "%FULL_BACKUP_DAY%"=="MONDAY" set DAY_VALUE=MON
if /i "%FULL_BACKUP_DAY%"=="TUESDAY" set DAY_VALUE=TUE
if /i "%FULL_BACKUP_DAY%"=="WEDNESDAY" set DAY_VALUE=WED
if /i "%FULL_BACKUP_DAY%"=="THURSDAY" set DAY_VALUE=THU
if /i "%FULL_BACKUP_DAY%"=="FRIDAY" set DAY_VALUE=FRI
if /i "%FULL_BACKUP_DAY%"=="SATURDAY" set DAY_VALUE=SAT

REM 创建全量备份计划任务
if /i "%FULL_BACKUP_SCHEDULE%"=="WEEKLY" (
    schtasks /create /tn "SQL Server Full Backup" /tr "\"%SCRIPT_PATH%\" FULL" /sc weekly /d %DAY_VALUE% /st %FULL_BACKUP_TIME% /ru SYSTEM /f
) else (
    schtasks /create /tn "SQL Server Full Backup" /tr "\"%SCRIPT_PATH%\" FULL" /sc daily /st %FULL_BACKUP_TIME% /ru SYSTEM /f
)

if %ERRORLEVEL% equ 0 (
    echo 全量备份计划任务创建成功！
    echo 任务名称: SQL Server Full Backup
    echo 执行时间: %FULL_BACKUP_SCHEDULE% %FULL_BACKUP_TIME%
) else (
    echo 全量备份计划任务创建失败！
    echo 时间格式应为 HH:MM 格式 (例如 02:00 或 14:30)
)

echo.
echo ========================================
echo 创建增量备份计划任务
echo ========================================

REM 直接使用配置的时间，不进行额外验证
set FINAL_DIFF_TIME=%DIFF_BACKUP_TIME%

REM 创建增量备份计划任务
if /i "%DIFF_BACKUP_SCHEDULE%"=="DAILY" (
    schtasks /create /tn "SQL Server Diff Backup" /tr "\"%SCRIPT_PATH%\" DIFF" /sc daily /st %FINAL_DIFF_TIME% /ru SYSTEM /f
)

if %ERRORLEVEL% equ 0 (
    echo 增量备份计划任务创建成功！
    echo 任务名称: SQL Server Diff Backup
    echo 执行时间: %DIFF_BACKUP_SCHEDULE% %FINAL_DIFF_TIME%
) else (
    echo 增量备份计划任务创建失败！
    echo 时间格式应为 HH:MM 格式 (例如 02:00 或 14:30)
)

echo.
echo ========================================
echo 创建日志备份计划任务
echo ========================================

REM 创建日志备份计划任务
if /i "%LOG_BACKUP_SCHEDULE%"=="HOURLY" (
    schtasks /create /tn "SQL Server Log Backup" /tr "\"%SCRIPT_PATH%\" LOG" /sc hourly /mo %LOG_BACKUP_INTERVAL% /ru SYSTEM /f
) else (
    REM 如果不是每小时执行，那么需要一个时间，这里使用默认值 00:00
    schtasks /create /tn "SQL Server Log Backup" /tr "\"%SCRIPT_PATH%\" LOG" /sc daily /st 00:00 /ru SYSTEM /f
)

if %ERRORLEVEL% equ 0 (
    echo 日志备份计划任务创建成功！
    echo 任务名称: SQL Server Log Backup
    echo 执行时间: 每%LOG_BACKUP_INTERVAL%小时
) else (
    echo 日志备份计划任务创建失败！
)

echo.
echo ========================================
echo 计划任务创建完成
echo ========================================

echo 你可以通过以下方式管理计划任务:
echo 1. 打开"任务计划程序" ^(taskschd.msc^)
echo 2. 查看任务: schtasks /query /tn "SQL Server Full Backup"
echo 3. 删除任务: schtasks /delete /tn "SQL Server Full Backup" /f

echo.
echo 当前创建的计划任务:
schtasks /query /tn "SQL Server Full Backup" /fo LIST 2>nul
schtasks /query /tn "SQL Server Diff Backup" /fo LIST 2>nul
schtasks /query /tn "SQL Server Log Backup" /fo LIST 2>nul

echo.
echo 请确保在运行备份任务前：
echo 1. 修改 backup_config.bat 中的SQL Server连接信息
echo 2. 确认备份路径有足够的磁盘空间
echo 3. 安装zstd压缩工具并确保在PATH中
echo 4. 测试运行各种备份类型确保配置正确

pause
