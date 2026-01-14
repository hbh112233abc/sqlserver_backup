@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ========================================
REM SQL Server数据库自动备份脚本 (SQL Server 2016兼容)
REM 支持全量、增量、日志备份
REM 支持zstd压缩
REM ========================================

REM 注意：备份路径必须是SQL Server服务器上的本地路径或SQL Server服务账户有权访问的网络路径
REM 如果使用远程备份路径，请确保SQL Server服务账户具有写入权限

REM 参数处理
set BACKUP_TYPE=%1
if "%BACKUP_TYPE%"=="" set BACKUP_TYPE=FULL

REM 验证备份类型
if /i not "%BACKUP_TYPE%"=="FULL" if /i not "%BACKUP_TYPE%"=="DIFF" if /i not "%BACKUP_TYPE%"=="LOG" (
    echo 错误: 无效的备份类型 "%BACKUP_TYPE%"
    echo 用法: %0 [FULL^|DIFF^|LOG]
    echo   FULL - 全量备份 ^(默认^)
    echo   DIFF - 增量备份
    echo   LOG  - 日志备份
    exit /b 1
)

echo ========================================
echo SQL Server数据库%BACKUP_TYPE%备份开始
echo 开始时间: %date% %time%
echo ========================================

REM 加载配置
call "%~dp0backup_config.bat"

REM 创建必要目录
echo 正在创建备份目录...
echo 备份基础路径: "%BACKUP_BASE_PATH%"
mkdir "%BACKUP_BASE_PATH%" 2>nul
if not exist "%BACKUP_BASE_PATH%" (
    echo 错误: 无法创建备份基础目录 "%BACKUP_BASE_PATH%"
    exit /b 1
)
mkdir "%BACKUP_BASE_PATH%\FULL" 2>nul
mkdir "%BACKUP_BASE_PATH%\DIFF" 2>nul
mkdir "%BACKUP_BASE_PATH%\LOG" 2>nul
mkdir "%~dp0logs" 2>nul
echo 目录创建完成

REM 确保备份目录存在且可访问
if not exist "%BACKUP_BASE_PATH%\FULL" (
    echo 错误: 无法创建FULL备份目录 "%BACKUP_BASE_PATH%\FULL"
    exit /b 1
)
if not exist "%BACKUP_BASE_PATH%\DIFF" (
    echo 错误: 无法创建DIFF备份目录 "%BACKUP_BASE_PATH%\DIFF"
    exit /b 1
)
if not exist "%BACKUP_BASE_PATH%\LOG" (
    echo 错误: 无法创建LOG备份目录 "%BACKUP_BASE_PATH%\LOG"
    exit /b 1
)
if not exist "%~dp0logs" (
    echo 错误: 无法创建日志目录 "%~dp0logs"
    exit /b 1
)

REM 检查zstd是否可用
%ZSTD_PATH% --version >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo 警告: zstd压缩工具不可用，将跳过压缩步骤
    set USE_COMPRESSION=0
) else (
    set USE_COMPRESSION=1
)

REM 创建日志文件
if not exist "%LOG_FILE%" echo. > "%LOG_FILE%"

REM 记录开始时间到日志
echo [%date% %time%] %BACKUP_TYPE%备份任务开始 >> "%LOG_FILE%"

REM 设置时间戳
REM 使用wmic获取标准格式的日期时间以确保纯数字输出
for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value ^| find "LocalDateTime"') do (
    set DATETIME=%%a
)
set YEAR=!DATETIME:~0,4!
set MONTH=!DATETIME:~4,2!
set DAY=!DATETIME:~6,2!
set HOUR=!DATETIME:~8,2!
set MINUTE=!DATETIME:~10,2!
set SECOND=!DATETIME:~12,2!

REM 不需要额外的格式化，wmic返回标准化的数值
set BACKUP_TIMESTAMP=!YEAR!!MONTH!!DAY!_!HOUR!!MINUTE!!SECOND!

REM 设置备份类型相关参数
if /i "%BACKUP_TYPE%"=="FULL" (
    set "BACKUP_FOLDER=%BACKUP_BASE_PATH%\FULL"
    set "BACKUP_EXTENSION=.bak"
    set "SQL_BACKUP_TYPE=DATABASE"
    set "KEEP_DAYS=%FULL_BACKUP_KEEP_DAYS%"
)
if /i "%BACKUP_TYPE%"=="DIFF" (
    set "BACKUP_FOLDER=%BACKUP_BASE_PATH%\DIFF"
    set "BACKUP_EXTENSION=.dif"
    set "SQL_BACKUP_TYPE=DATABASE"
    set "KEEP_DAYS=%DIFF_BACKUP_KEEP_DAYS%"
)
if /i "%BACKUP_TYPE%"=="LOG" (
    set "BACKUP_FOLDER=%BACKUP_BASE_PATH%\LOG"
    set "BACKUP_EXTENSION=.trn"
    set "SQL_BACKUP_TYPE=LOG"
    set "KEEP_DAYS=%LOG_BACKUP_KEEP_DAYS%"
)

REM 验证备份目录存在
if not exist "!BACKUP_FOLDER!" (
    echo 错误: 备份目录不存在 "!BACKUP_FOLDER!"
    mkdir "!BACKUP_FOLDER!"
    if !ERRORLEVEL! neq 0 (
        echo 错误: 无法创建备份目录 "!BACKUP_FOLDER!"
        exit /b 1
    )
    echo 成功创建备份目录: "!BACKUP_FOLDER!"
)

REM 备份每个数据库
for %%D in (%DATABASES%) do (
    echo.
    echo 正在执行%%D数据库的%BACKUP_TYPE%备份...
    echo [%date% %time%] 开始%%D数据库的%BACKUP_TYPE%备份 >> "%LOG_FILE%"

    set "BACKUP_FILE=!BACKUP_FOLDER!\%%D_!BACKUP_TIMESTAMP!!BACKUP_EXTENSION!"
    REM 确保备份文件路径有效
    echo 正在验证备份文件路径: !BACKUP_FILE!
    if not exist "!BACKUP_FOLDER!\" (
        echo 错误: 备份文件夹不存在: !BACKUP_FOLDER!
        exit /b 1
    )

    REM 创建一个临时测试文件以验证SQL Server是否可以访问该路径
    set "TEST_FILE=!BACKUP_FOLDER!\test_access_!BACKUP_TIMESTAMP!.tmp"
    echo 测试 > "!TEST_FILE!"
    if exist "!TEST_FILE!" (
        echo 成功: SQL Server应该可以访问备份目录
        del "!TEST_FILE!" 2>nul
    ) else (
        echo 警告: 可能存在权限问题，SQL Server服务可能无法访问路径: !BACKUP_FOLDER!
        echo 请确保SQL Server服务账户对备份目录具有完全控制权限
    )

    REM 再次确认备份目录存在
    if not exist "!BACKUP_FOLDER!" (
        echo 错误: 备份目录在执行备份前仍未创建 "!BACKUP_FOLDER!"
        exit /b 1
    )

    REM 构建SQL备份命令 (SQL Server 2016兼容)
    if /i "%BACKUP_TYPE%"=="FULL" (
        set SQL_BACKUP_CMD=BACKUP DATABASE [%%D] TO DISK = N'!BACKUP_FILE!' WITH FORMAT, INIT, COMPRESSION, CHECKSUM, STATS = 10
    )
    if /i "%BACKUP_TYPE%"=="DIFF" (
        set SQL_BACKUP_CMD=BACKUP DATABASE [%%D] TO DISK = N'!BACKUP_FILE!' WITH DIFFERENTIAL, FORMAT, INIT, COMPRESSION, CHECKSUM, STATS = 10
    )
    if /i "%BACKUP_TYPE%"=="LOG" (
        set SQL_BACKUP_CMD=BACKUP LOG [%%D] TO DISK = N'!BACKUP_FILE!' WITH FORMAT, INIT, COMPRESSION, CHECKSUM, STATS = 10
    )

    REM 执行SQL命令
    if "%SQL_AUTH_MODE%"=="WIN" (
        sqlcmd -S "%SERVER_NAME%" -E -N -C -Q "!SQL_BACKUP_CMD!" -b
    ) else (
        sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -N -C -Q "!SQL_BACKUP_CMD!" -b
    )

    if !ERRORLEVEL! equ 0 (
        echo %%D数据库%BACKUP_TYPE%备份成功: !BACKUP_FILE!
        echo [%date% %time%] %%D数据库%BACKUP_TYPE%备份成功: !BACKUP_FILE! >> "%LOG_FILE%"

        REM 压缩备份文件
        if !USE_COMPRESSION! equ 1 (
            echo 正在压缩备份文件...
            %ZSTD_PATH% -!COMPRESSION_LEVEL! --rm "!BACKUP_FILE!" -o "!BACKUP_FILE!.zst"
            if !ERRORLEVEL! equ 0 (
                echo 备份文件压缩完成: !BACKUP_FILE!.zst
                echo [%date% %time%] 备份文件压缩完成: !BACKUP_FILE!.zst >> "%LOG_FILE%"
            ) else (
                echo 警告: 备份文件压缩失败
                echo [%date% %time%] 警告: 备份文件压缩失败 >> "%LOG_FILE%"
            )
        )
    ) else (
        echo 错误: %%D数据库%BACKUP_TYPE%备份失败！
        echo [%date% %time%] 错误: %%D数据库%BACKUP_TYPE%备份失败！ >> "%LOG_FILE%"
    )
)

echo.
echo ========================================
echo 开始清理旧备份文件（保留最近!KEEP_DAYS!天）
echo ========================================

REM 清理旧备份文件
if !USE_COMPRESSION! equ 1 (
    forfiles /p "!BACKUP_FOLDER!" /s /m *.zst /d -!KEEP_DAYS! /c "cmd /c echo 删除压缩文件: @path && del @path" 2>nul
) else (
    if /i "%BACKUP_TYPE%"=="FULL" forfiles /p "!BACKUP_FOLDER!" /s /m *.bak /d -!KEEP_DAYS! /c "cmd /c echo 删除文件: @path && del @path" 2>nul
    if /i "%BACKUP_TYPE%"=="DIFF" forfiles /p "!BACKUP_FOLDER!" /s /m *.dif /d -!KEEP_DAYS! /c "cmd /c echo 删除文件: @path && del @path" 2>nul
    if /i "%BACKUP_TYPE%"=="LOG" forfiles /p "!BACKUP_FOLDER!" /s /m *.trn /d -!KEEP_DAYS! /c "cmd /c echo 删除文件: @path && del @path" 2>nul
)

if !ERRORLEVEL! equ 0 (
    echo 旧备份文件清理完成
    echo [%date% %time%] 旧备份文件清理完成 >> "%LOG_FILE%"
) else (
    echo 没有需要清理的旧备份文件
    echo [%date% %time%] 没有需要清理的旧备份文件 >> "%LOG_FILE%"
)

echo.
echo ========================================
echo %BACKUP_TYPE%备份任务完成
echo 结束时间: %date% %time%
echo ========================================

echo [%date% %time%] %BACKUP_TYPE%备份任务完成 >> "%LOG_FILE%"

REM 显示备份文件列表
echo.
echo 当前%BACKUP_TYPE%备份文件列表:
if !USE_COMPRESSION! equ 1 (
    dir "!BACKUP_FOLDER!\*.zst" /b /o-d 2>nul
) else (
    dir "!BACKUP_FOLDER!\*!BACKUP_EXTENSION!" /b /o-d 2>nul
)

endlocal
