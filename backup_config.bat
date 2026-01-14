@echo off
REM ========================================
REM SQL Server数据库备份配置文件
REM ========================================

REM SQL Server连接配置
set SERVER_NAME=127.0.0.1
set SQL_USER=sa
set SQL_PASSWORD=sa
set SQL_AUTH_MODE=SQL
REM 如果使用Windows认证，将SQL_AUTH_MODE设置为WIN

REM 备份配置
set "BACKUP_BASE_PATH=%~dp0backup"

REM 数据库列表（用空格分隔）
set DATABASES=DB1 DB2

REM 备份计划配置
REM 全量备份配置
set FULL_BACKUP_SCHEDULE=WEEKLY
set FULL_BACKUP_DAY=SUNDAY
set FULL_BACKUP_TIME=02:00
set FULL_BACKUP_KEEP_DAYS=30

REM 增量备份配置
set DIFF_BACKUP_SCHEDULE=DAILY
set DIFF_BACKUP_TIME=03:00
set DIFF_BACKUP_KEEP_DAYS=7

REM 日志备份配置
set LOG_BACKUP_SCHEDULE=HOURLY
set LOG_BACKUP_INTERVAL=1
set LOG_BACKUP_KEEP_DAYS=2

REM 压缩工具配置
set ZSTD_PATH=%~dp0\zstd\zstd.exe
set COMPRESSION_LEVEL=3

REM 备份文件名格式：数据库名_YYYYMMDD_HHMMSS.bak
REM 使用wmic获取标准格式的日期时间以确保纯数字输出
for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value ^| find "LocalDateTime"') do (
    set "DATETIME=%%a"
)
set "DATE_FORMAT=!DATETIME:~0,4!!DATETIME:~4,2!!DATETIME:~6,2!"
set "TIME_FORMAT=!DATETIME:~8,2!!DATETIME:~10,2!!DATETIME:~12,2!"

set "LOG_FILE=%~dp0logs\%DATE_FORMAT%.log"

echo 配置加载完成
echo 服务器: %SERVER_NAME%
echo 备份路径: %BACKUP_BASE_PATH%
echo 全量备份保留天数: %FULL_BACKUP_KEEP_DAYS%
echo 增量备份保留天数: %DIFF_BACKUP_KEEP_DAYS%
echo 日志备份保留天数: %LOG_BACKUP_KEEP_DAYS%
echo 数据库: %DATABASES%
