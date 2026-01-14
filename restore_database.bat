@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ========================================
REM SQL Server数据库交互式还原脚本
REM 支持选择备份文件和时间点还原
REM ========================================

echo ========================================
echo SQL Server数据库还原工具
echo ========================================

REM 加载配置
call "%~dp0backup_config.bat"

REM 检查zstd是否可用
%ZSTD_PATH% --version >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo 警告: zstd解压工具不可用，无法处理压缩备份文件
    set USE_COMPRESSION=0
) else (
    set USE_COMPRESSION=1
)

:SELECT_DATABASE
echo.
echo 可用的数据库:
set /a DB_COUNT=0
for %%D in (%DATABASES%) do (
    set /a DB_COUNT+=1
    echo !DB_COUNT!. %%D
    set DB_!DB_COUNT!=%%D
)

echo.
set /p DB_CHOICE=请选择要还原的数据库 (1-%DB_COUNT%):
if !DB_CHOICE! lss 1 goto SELECT_DATABASE
if !DB_CHOICE! gtr %DB_COUNT% goto SELECT_DATABASE

set SELECTED_DB=!DB_%DB_CHOICE%!
echo 已选择数据库: %SELECTED_DB%

:SELECT_BACKUP_TYPE
echo.
echo 备份类型:
echo 1. 全量备份 (FULL)
echo 2. 增量备份 (DIFF)
echo 3. 日志备份 (LOG)
echo 4. 显示所有备份文件

set /p BACKUP_TYPE_CHOICE=请选择备份类型 (1-4):

if "%BACKUP_TYPE_CHOICE%"=="1" (
    set BACKUP_TYPE=FULL
    set BACKUP_FOLDER=%BACKUP_BASE_PATH%\FULL
    set BACKUP_EXT=.bak
)
if "%BACKUP_TYPE_CHOICE%"=="2" (
    set BACKUP_TYPE=DIFF
    set BACKUP_FOLDER=%BACKUP_BASE_PATH%\DIFF
    set BACKUP_EXT=.dif
)
if "%BACKUP_TYPE_CHOICE%"=="3" (
    set BACKUP_TYPE=LOG
    set BACKUP_FOLDER=%BACKUP_BASE_PATH%\LOG
    set BACKUP_EXT=.trn
)
if "%BACKUP_TYPE_CHOICE%"=="4" goto SHOW_ALL_BACKUPS

if not defined BACKUP_TYPE goto SELECT_BACKUP_TYPE

:LIST_BACKUP_FILES
echo.
echo ========================================
echo %SELECTED_DB%数据库的%BACKUP_TYPE%备份文件:
echo ========================================

set /a FILE_COUNT=0
if !USE_COMPRESSION! equ 1 (
    for /f "tokens=*" %%F in ('dir "%BACKUP_FOLDER%\%SELECTED_DB%_*.zst" /b /o-d 2^>nul') do (
        set /a FILE_COUNT+=1
        set BACKUP_FILE_!FILE_COUNT!=%%F
        set FULL_PATH_!FILE_COUNT!=%BACKUP_FOLDER%\%%F

        REM 解析文件名获取时间信息
        set FILENAME=%%F
        set FILENAME=!FILENAME:%SELECTED_DB%_=!
        set FILENAME=!FILENAME:.zst=!
        set FILENAME=!FILENAME:%BACKUP_EXT%=!

        set YEAR=!FILENAME:~0,4!
        set MONTH=!FILENAME:~4,2!
        set DAY=!FILENAME:~6,2!
        set HOUR=!FILENAME:~9,2!
        set MINUTE=!FILENAME:~11,2!

        echo !FILE_COUNT!. %%F ^(!YEAR!-!MONTH!-!DAY! !HOUR!:!MINUTE!^)
    )
) else (
    for /f "tokens=*" %%F in ('dir "%BACKUP_FOLDER%\%SELECTED_DB%_*%BACKUP_EXT%" /b /o-d 2^>nul') do (
        set /a FILE_COUNT+=1
        set BACKUP_FILE_!FILE_COUNT!=%%F
        set FULL_PATH_!FILE_COUNT!=%BACKUP_FOLDER%\%%F

        REM 解析文件名获取时间信息
        set FILENAME=%%F
        set FILENAME=!FILENAME:%SELECTED_DB%_=!
        set FILENAME=!FILENAME:%BACKUP_EXT%=!

        set YEAR=!FILENAME:~0,4!
        set MONTH=!FILENAME:~4,2!
        set DAY=!FILENAME:~6,2!
        set HOUR=!FILENAME:~9,2!
        set MINUTE=!FILENAME:~11,2!

        echo !FILE_COUNT!. %%F ^(!YEAR!-!MONTH!-!DAY! !HOUR!:!MINUTE!^)
    )
)

if !FILE_COUNT! equ 0 (
    echo 没有找到%SELECTED_DB%数据库的%BACKUP_TYPE%备份文件
    echo 按任意键返回选择...
    pause >nul
    goto SELECT_BACKUP_TYPE
)

echo.
echo 0. 返回备份类型选择
set /p FILE_CHOICE=请选择要还原的备份文件 (0-%FILE_COUNT%):

if "%FILE_CHOICE%"=="0" goto SELECT_BACKUP_TYPE
if !FILE_CHOICE! lss 1 goto LIST_BACKUP_FILES
if !FILE_CHOICE! gtr %FILE_COUNT% goto LIST_BACKUP_FILES

set SELECTED_FILE=!BACKUP_FILE_%FILE_CHOICE%!
set SELECTED_PATH=!FULL_PATH_%FILE_CHOICE%!

echo 已选择备份文件: %SELECTED_FILE%

REM 新增：根据备份类型执行相应的还原策略
if /i "%BACKUP_TYPE%"=="FULL" (
    call :RESTORE_FULL_BACKUP
) else if /i "%BACKUP_TYPE%"=="DIFF" (
    call :RESTORE_DIFF_BACKUP
) else if /i "%BACKUP_TYPE%"=="LOG" (
    call :RESTORE_LOG_BACKUP
)

goto END

REM 还原全量备份的函数
:RESTORE_FULL_BACKUP
echo.
echo ========================================
echo 执行全量数据库还原
echo ========================================

REM 创建临时目录用于解压
set TEMP_DIR=%TEMP%\sqlserver_restore_%RANDOM%
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

set RESTORE_FILE=%SELECTED_PATH%

REM 如果是压缩文件，先解压
if !USE_COMPRESSION! equ 1 (
    if /i "%SELECTED_PATH:~-4%"==".zst" (
        echo 正在解压备份文件...
        set RESTORE_FILE=%TEMP_DIR%\%SELECTED_FILE:.zst=%
        %ZSTD_PATH% -d "%SELECTED_PATH%" -o "!RESTORE_FILE!"
        if !ERRORLEVEL! neq 0 (
            echo 错误: 备份文件解压失败！
            goto CLEANUP
        )
        echo 备份文件解压完成
    )
)

REM 构建还原SQL命令
set RESTORE_CMD=RESTORE DATABASE [%SELECTED_DB%] FROM DISK = '%RESTORE_FILE%' WITH REPLACE, CHECKSUM, STATS = 10

echo 正在执行还原操作...
echo SQL命令: !RESTORE_CMD!

REM 执行还原命令
if "%SQL_AUTH_MODE%"=="WIN" (
    sqlcmd -S "%SERVER_NAME%" -E -Q "!RESTORE_CMD!" -b
) else (
    sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -Q "!RESTORE_CMD!" -b
)

if !ERRORLEVEL! equ 0 (
    echo.
    echo ========================================
    echo 数据库全量还原成功！
    echo ========================================
    echo 数据库: %SELECTED_DB%
    echo 备份文件: %SELECTED_FILE%
    echo 完成时间: %date% %time%
) else (
    echo.
    echo ========================================
    echo 数据库全量还原失败！
    echo ========================================
    echo 请检查错误信息并重试
)

goto CLEANUP

REM 还原增量备份的函数
:RESTORE_DIFF_BACKUP
echo.
echo ========================================
echo 执行增量数据库还原（包括依赖的全量备份）
echo ========================================

REM 查找所选增量备份之前的最新全量备份
call :FIND_CLOSEST_FULL_BACKUP "%SELECTED_PATH%"

if not defined CLOSEST_FULL_BACKUP (
    echo 错误: 未找到所选增量备份之前的全量备份
    goto CLEANUP
)

echo 找到最近的全量备份: !CLOSEST_FULL_BACKUP!
echo 正在还原全量备份...

REM 还原最近的全量备份
call :EXECUTE_RESTORE_COMMAND "!CLOSEST_FULL_BACKUP!" "FULL" "WITH REPLACE, CHECKSUM, STATS = 10"

if !ERRORLEVEL! neq 0 (
    echo 错误: 全量备份还原失败
    goto CLEANUP
)

REM 查找从全量备份到所选增量备份之间的所有增量备份
call :FIND_INTERMEDIATE_DIFF_BACKUPS "!CLOSEST_FULL_BACKUP!" "%SELECTED_PATH%"

REM 依次还原中间的增量备份
if defined INTERMEDIATE_DIFF_FILES (
    for %%F in (!INTERMEDIATE_DIFF_FILES!) do (
        echo 正在还原中间增量备份: %%F
        call :EXECUTE_RESTORE_COMMAND "%%F" "DIFF" "WITH NORECOVERY, CHECKSUM, STATS = 10"
        if !ERRORLEVEL! neq 0 (
            echo 错误: 中间增量备份还原失败: %%F
            goto CLEANUP
        )
    )
)

REM 最后还原所选的增量备份
echo 正在还原所选的增量备份: %SELECTED_PATH%
call :EXECUTE_RESTORE_COMMAND "%SELECTED_PATH%" "DIFF" "WITH NORECOVERY, CHECKSUM, STATS = 10"

if !ERRORLEVEL! equ 0 (
    echo.
    echo ========================================
    echo 数据库增量还原序列成功完成！
    echo ========================================
    echo 数据库: %SELECTED_DB%
    echo 完成时间: %date% %time%
) else (
    echo.
    echo ========================================
    echo 数据库增量还原序列失败！
    echo ========================================
    echo 请检查错误信息并重试
)

goto CLEANUP

REM 还原日志备份的函数
:RESTORE_LOG_BACKUP
echo.
echo ========================================
echo 执行日志数据库还原（包括依赖的全量和增量备份）
echo ========================================

REM 查找所选日志备份之前的最新全量备份
call :FIND_CLOSEST_FULL_BACKUP "%SELECTED_PATH%"

if not defined CLOSEST_FULL_BACKUP (
    echo 错误: 未找到所选日志备份之前的全量备份
    goto CLEANUP
)

echo 找到最近的全量备份: !CLOSEST_FULL_BACKUP!
echo 正在还原全量备份...

REM 还原最近的全量备份
call :EXECUTE_RESTORE_COMMAND "!CLOSEST_FULL_BACKUP!" "FULL" "WITH REPLACE, CHECKSUM, STATS = 10"

if !ERRORLEVEL! neq 0 (
    echo 错误: 全量备份还原失败
    goto CLEANUP
)

REM 查找从全量备份到所选日志备份之间的所有增量备份
call :FIND_INTERMEDIATE_DIFF_BACKUPS "!CLOSEST_FULL_BACKUP!" "%SELECTED_PATH%"

REM 依次还原中间的增量备份
if defined INTERMEDIATE_DIFF_FILES (
    for %%F in (!INTERMEDIATE_DIFF_FILES!) do (
        echo 正在还原中间增量备份: %%F
        call :EXECUTE_RESTORE_COMMAND "%%F" "DIFF" "WITH NORECOVERY, CHECKSUM, STATS = 10"
        if !ERRORLEVEL! neq 0 (
            echo 错误: 中间增量备份还原失败: %%F
            goto CLEANUP
        )
    )
)

REM 查找从最后一个增量备份到所选日志备份之间的所有日志备份
call :FIND_INTERMEDIATE_LOG_BACKUPS "!CLOSEST_FULL_BACKUP!" "%SELECTED_PATH%"

REM 依次还原中间的日志备份以及所选的日志备份
if defined ALL_LOG_FILES (
    for %%F in (!ALL_LOG_FILES!) do (
        echo 正在还原日志备份: %%F
        call :EXECUTE_RESTORE_COMMAND "%%F" "LOG" "WITH NORECOVERY, CHECKSUM, STATS = 10"
        if !ERRORLEVEL! neq 0 (
            echo 错误: 日志备份还原失败: %%F
            goto CLEANUP
        )
    )
)

REM 最后恢复数据库
echo 正在恢复数据库至正常状态...
set RESTORE_RECOVERY_CMD=RESTORE DATABASE [%SELECTED_DB%] WITH RECOVERY
if "%SQL_AUTH_MODE%"=="WIN" (
    sqlcmd -S "%SERVER_NAME%" -E -Q "!RESTORE_RECOVERY_CMD!" -b
) else (
    sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -Q "!RESTORE_RECOVERY_CMD!" -b
)

if !ERRORLEVEL! equ 0 (
    echo.
    echo ========================================
    echo 数据库日志还原序列成功完成！
    echo ========================================
    echo 数据库: %SELECTED_DB%
    echo 完成时间: %date% %time%
) else (
    echo.
    echo ========================================
    echo 数据库日志还原序列失败！
    echo ========================================
    echo 请检查错误信息并重试
)

goto CLEANUP

REM 查找最接近的全量备份
:FIND_CLOSEST_FULL_BACKUP
set BACKUP_FILE_PATH=%~1
REM 提取备份文件的时间戳
for /f "tokens=*" %%F in ("%BACKUP_FILE_PATH%") do (
    set FILENAME=%%~nxF
    set FILENAME=!FILENAME:%SELECTED_DB%_=!
    set FILENAME=!FILENAME:.zst=!
    for /f "tokens=1 delims=." %%G in ("!FILENAME!") do set FILENAME=%%G
    set FILENAME=!FILENAME:.bak=!
    set FILENAME=!FILENAME:.dif=!
    set FILENAME=!FILENAME:.trn=!
    set CHOSEN_TIMESTAMP=!FILENAME!
)

REM 查找此数据库的最新全量备份（时间早于所选备份文件）
set CLOSEST_FULL_BACKUP=
for /f "tokens=*" %%F in ('dir "%BACKUP_BASE_PATH%\FULL\%SELECTED_DB%_*.zst" /b /o-d 2^>nul') do (
    set FULL_FILENAME=%%F
    set FULL_FILENAME=!FULL_FILENAME:%SELECTED_DB%_=!
    set FULL_FILENAME=!FULL_FILENAME:.zst=!
    set FULL_FILENAME=!FULL_FILENAME:.bak=!
    set FULL_TIMESTAMP=!FULL_FILENAME!

    REM 比较时间戳
    if !FULL_TIMESTAMP! lss !CHOSEN_TIMESTAMP! (
        set FULL_PATH=%BACKUP_BASE_PATH%\FULL\%%F
        set CLOSEST_FULL_BACKUP=!FULL_PATH!
        goto :EOF
    )
)

REM 如果没有压缩的全量备份，尝试查找未压缩的
if not defined CLOSEST_FULL_BACKUP (
    for /f "tokens=*" %%F in ('dir "%BACKUP_BASE_PATH%\FULL\%SELECTED_DB%_*.bak" /b /o-d 2^>nul') do (
        set FULL_FILENAME=%%F
        set FULL_FILENAME=!FULL_FILENAME:%SELECTED_DB%_=!
        set FULL_FILENAME=!FULL_FILENAME:.bak=!
        set FULL_TIMESTAMP=!FULL_FILENAME!

        REM 比较时间戳
        if !FULL_TIMESTAMP! lss !CHOSEN_TIMESTAMP! (
            set FULL_PATH=%BACKUP_BASE_PATH%\FULL\%%F
            set CLOSEST_FULL_BACKUP=!FULL_PATH!
            goto :EOF
        )
    )
)

goto :EOF

REM 查找中间的增量备份
:FIND_INTERMEDIATE_DIFF_BACKUPS
set FULL_BACKUP_PATH=%~1
set TARGET_BACKUP_PATH=%~2

REM 提取全量备份时间戳
for /f "tokens=*" %%F in ("%FULL_BACKUP_PATH%") do (
    set FULL_FILENAME=%%~nxF
    set FULL_FILENAME=!FULL_FILENAME:%SELECTED_DB%_=!
    set FULL_FILENAME=!FULL_FILENAME:.zst=!
    set FULL_FILENAME=!FULL_FILENAME:.bak=!
    set FULL_TIMESTAMP=!FULL_FILENAME!
)

REM 提取目标备份时间戳
for /f "tokens=*" %%F in ("%TARGET_BACKUP_PATH%") do (
    set TARGET_FILENAME=%%~nxF
    set TARGET_FILENAME=!TARGET_FILENAME:%SELECTED_DB%_=!
    set TARGET_FILENAME=!TARGET_FILENAME:.zst=!
    set TARGET_FILENAME=!TARGET_FILENAME:.dif=!
    set TARGET_FILENAME=!TARGET_FILENAME:.trn=!
    set TARGET_TIMESTAMP=!TARGET_FILENAME!
)

set INTERMEDIATE_DIFF_FILES=

REM 查找时间在全量备份和目标备份之间的增量备份
for /f "tokens=*" %%F in ('dir "%BACKUP_BASE_PATH%\DIFF\%SELECTED_DB%_*.zst" /b /o-d 2^>nul') do (
    set DIFF_FILENAME=%%F
    set DIFF_FILENAME=!DIFF_FILENAME:%SELECTED_DB%_=!
    set DIFF_FILENAME=!DIFF_FILENAME:.zst=!
    set DIFF_FILENAME=!DIFF_FILENAME:.dif=!
    set DIFF_TIMESTAMP=!DIFF_FILENAME!

    REM 检查时间戳是否在范围内
    if !DIFF_TIMESTAMP! gtr !FULL_TIMESTAMP! if !DIFF_TIMESTAMP! lss !TARGET_TIMESTAMP! (
        set CURRENT_FILE=%BACKUP_BASE_PATH%\DIFF\%%F
        if defined INTERMEDIATE_DIFF_FILES (
            set INTERMEDIATE_DIFF_FILES=!INTERMEDIATE_DIFF_FILES! "!CURRENT_FILE!"
        ) else (
            set INTERMEDIATE_DIFF_FILES="!CURRENT_FILE!"
        )
    )
)

REM 如果没有压缩的增量备份，尝试查找未压缩的
if not defined INTERMEDIATE_DIFF_FILES (
    for /f "tokens=*" %%F in ('dir "%BACKUP_BASE_PATH%\DIFF\%SELECTED_DB%_*.dif" /b /o-d 2^>nul') do (
        set DIFF_FILENAME=%%F
        set DIFF_FILENAME=!DIFF_FILENAME:%SELECTED_DB%_=!
        set DIFF_FILENAME=!DIFF_FILENAME:.dif=!
        set DIFF_TIMESTAMP=!DIFF_FILENAME!

        REM 检查时间戳是否在范围内
        if !DIFF_TIMESTAMP! gtr !FULL_TIMESTAMP! if !DIFF_TIMESTAMP! lss !TARGET_TIMESTAMP! (
            set CURRENT_FILE=%BACKUP_BASE_PATH%\DIFF\%%F
            if defined INTERMEDIATE_DIFF_FILES (
                set INTERMEDIATE_DIFF_FILES=!INTERMEDIATE_DIFF_FILES! "!CURRENT_FILE!"
            ) else (
                set INTERMEDIATE_DIFF_FILES="!CURRENT_FILE!"
            )
        )
    )
)

goto :EOF

REM 查找中间的日志备份
:FIND_INTERMEDIATE_LOG_BACKUPS
set FULL_OR_DIFF_BACKUP_PATH=%~1
set TARGET_LOG_PATH=%~2

REM 提取起始备份时间戳
for /f "tokens=*" %%F in ("%FULL_OR_DIFF_BACKUP_PATH%") do (
    set START_FILENAME=%%~nxF
    set START_FILENAME=!START_FILENAME:%SELECTED_DB%_=!
    set START_FILENAME=!START_FILENAME:.zst=!
    set START_FILENAME=!START_FILENAME:.bak=!
    set START_FILENAME=!START_FILENAME:.dif=!
    set START_TIMESTAMP=!START_FILENAME!
)

REM 提取目标日志备份时间戳
for /f "tokens=*" %%F in ("%TARGET_LOG_PATH%") do (
    set TARGET_FILENAME=%%~nxF
    set TARGET_FILENAME=!TARGET_FILENAME:%SELECTED_DB%_=!
    set TARGET_FILENAME=!TARGET_FILENAME:.zst=!
    set TARGET_FILENAME=!TARGET_FILENAME:.trn=!
    set TARGET_TIMESTAMP=!TARGET_FILENAME!
)

set ALL_LOG_FILES=

REM 查找时间在起始备份和目标日志备份之间的所有日志备份
for /f "tokens=*" %%F in ('dir "%BACKUP_BASE_PATH%\LOG\%SELECTED_DB%_*.zst" /b /o-d 2^>nul') do (
    set LOG_FILENAME=%%F
    set LOG_FILENAME=!LOG_FILENAME:%SELECTED_DB%_=!
    set LOG_FILENAME=!LOG_FILENAME:.zst=!
    set LOG_FILENAME=!LOG_FILENAME:.trn=!
    set LOG_TIMESTAMP=!LOG_TIMESTAMP!

    REM 检查时间戳是否在范围内
    if !LOG_TIMESTAMP! gtr !START_TIMESTAMP! if !LOG_TIMESTAMP! leq !TARGET_TIMESTAMP! (
        set CURRENT_FILE=%BACKUP_BASE_PATH%\LOG\%%F
        if defined ALL_LOG_FILES (
            set ALL_LOG_FILES=!ALL_LOG_FILES! "!CURRENT_FILE!"
        ) else (
            set ALL_LOG_FILES="!CURRENT_FILE!"
        )
    )
)

REM 如果没有压缩的日志备份，尝试查找未压缩的
if not defined ALL_LOG_FILES (
    for /f "tokens=*" %%F in ('dir "%BACKUP_BASE_PATH%\LOG\%SELECTED_DB%_*.trn" /b /o-d 2^>nul') do (
        set LOG_FILENAME=%%F
        set LOG_FILENAME=!LOG_FILENAME:%SELECTED_DB%_=!
        set LOG_FILENAME=!LOG_FILENAME:.trn=!
        set LOG_TIMESTAMP=!LOG_FILENAME!

        REM 检查时间戳是否在范围内
        if !LOG_TIMESTAMP! gtr !START_TIMESTAMP! if !LOG_TIMESTAMP! leq !TARGET_TIMESTAMP! (
            set CURRENT_FILE=%BACKUP_BASE_PATH%\LOG\%%F
            if defined ALL_LOG_FILES (
                set ALL_LOG_FILES=!ALL_LOG_FILES! "!CURRENT_FILE!"
            ) else (
                set ALL_LOG_FILES="!CURRENT_FILE!"
            )
        )
    )
)

goto :EOF

REM 执行还原命令的通用函数
:EXECUTE_RESTORE_COMMAND
set BACKUP_PATH=%~1
set BACKUP_TYPE_PARAM=%~2
set RESTORE_OPTIONS=%~3

REM 创建临时目录用于解压（如果需要）
set TEMP_DIR=%TEMP%\sqlserver_restore_%RANDOM%
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

set RESTORE_FILE=!BACKUP_PATH!

REM 如果是压缩文件，先解压
if !USE_COMPRESSION! equ 1 (
    if /i "!BACKUP_PATH:~-4!"==".zst" (
        echo 正在解压备份文件...
        for /f "tokens=*" %%F in ("!BACKUP_PATH!") do set RESTORE_FILE=%TEMP_DIR%\%%~nF
        set RESTORE_FILE=!RESTORE_FILE:.zst=!
        %ZSTD_PATH% -d "!BACKUP_PATH!" -o "!RESTORE_FILE!"
        if !ERRORLEVEL! neq 0 (
            echo 错误: 备份文件解压失败！
            rmdir /s /q "%TEMP_DIR%" 2>nul
            exit /b 1
        )
        echo 备份文件解压完成: !RESTORE_FILE!
    )
)

REM 构建还原SQL命令
if /i "!BACKUP_TYPE_PARAM!"=="FULL" (
    set RESTORE_CMD=RESTORE DATABASE [%SELECTED_DB%] FROM DISK = '!RESTORE_FILE!' WITH !RESTORE_OPTIONS!
) else if /i "!BACKUP_TYPE_PARAM!"=="DIFF" (
    set RESTORE_CMD=RESTORE DATABASE [%SELECTED_DB%] FROM DISK = '!RESTORE_FILE!' WITH !RESTORE_OPTIONS!
) else if /i "!BACKUP_TYPE_PARAM!"=="LOG" (
    set RESTORE_CMD=RESTORE LOG [%SELECTED_DB%] FROM DISK = '!RESTORE_FILE!' WITH !RESTORE_OPTIONS!
)

echo SQL命令: !RESTORE_CMD!

REM 执行还原命令
if "%SQL_AUTH_MODE%"=="WIN" (
    sqlcmd -S "%SERVER_NAME%" -E -Q "!RESTORE_CMD!" -b
) else (
    sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -Q "!RESTORE_CMD!" -b
)

set EXIT_CODE=!ERRORLEVEL!

REM 清理临时文件（如果不是最终还原步骤）
rmdir /s /q "%TEMP_DIR%" 2>nul

exit /b !EXIT_CODE!

:CONFIRM_RESTORE
echo.
echo ========================================
echo 还原确认
echo ========================================
echo 数据库: %SELECTED_DB%
echo 备份文件: %SELECTED_FILE%
echo 备份路径: %SELECTED_PATH%
echo.
echo 警告: 还原操作将覆盖现有数据库！
echo.
set /p CONFIRM=确认执行还原操作? (Y/N):

if /i not "%CONFIRM%"=="Y" (
    echo 还原操作已取消
    goto END
)

:EXECUTE_RESTORE
echo.
echo ========================================
echo 执行数据库还原
echo ========================================

REM 创建临时目录用于解压
set TEMP_DIR=%TEMP%\sqlserver_restore_%RANDOM%
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

set RESTORE_FILE=%SELECTED_PATH%

REM 如果是压缩文件，先解压
if !USE_COMPRESSION! equ 1 (
    if /i "%SELECTED_PATH:~-4%"==".zst" (
        echo 正在解压备份文件...
        set RESTORE_FILE=%TEMP_DIR%\%SELECTED_FILE:.zst=%
        %ZSTD_PATH% -d "%SELECTED_PATH%" -o "!RESTORE_FILE!"
        if !ERRORLEVEL! neq 0 (
            echo 错误: 备份文件解压失败！
            goto CLEANUP
        )
        echo 备份文件解压完成
    )
)

REM 构建还原SQL命令
if /i "%BACKUP_TYPE%"=="FULL" (
    set RESTORE_CMD=RESTORE DATABASE [%SELECTED_DB%] FROM DISK = '%RESTORE_FILE%' WITH REPLACE, CHECKSUM, STATS = 10
)
if /i "%BACKUP_TYPE%"=="DIFF" (
    set RESTORE_CMD=RESTORE DATABASE [%SELECTED_DB%] FROM DISK = '%RESTORE_FILE%' WITH NORECOVERY, CHECKSUM, STATS = 10
)
if /i "%BACKUP_TYPE%"=="LOG" (
    set RESTORE_CMD=RESTORE LOG [%SELECTED_DB%] FROM DISK = '%RESTORE_FILE%' WITH CHECKSUM, STATS = 10
)

echo 正在执行还原操作...
echo SQL命令: !RESTORE_CMD!

REM 执行还原命令
if "%SQL_AUTH_MODE%"=="WIN" (
    sqlcmd -S "%SERVER_NAME%" -E -Q "!RESTORE_CMD!" -b
) else (
    sqlcmd -S "%SERVER_NAME%" -U "%SQL_USER%" -P "%SQL_PASSWORD%" -Q "!RESTORE_CMD!" -b
)

if !ERRORLEVEL! equ 0 (
    echo.
    echo ========================================
    echo 数据库还原成功！
    echo ========================================
    echo 数据库: %SELECTED_DB%
    echo 备份文件: %SELECTED_FILE%
    echo 完成时间: %date% %time%
) else (
    echo.
    echo ========================================
    echo 数据库还原失败！
    echo ========================================
    echo 请检查错误信息并重试
)

:CLEANUP
REM 清理临时文件
if exist "%TEMP_DIR%" (
    echo 清理临时文件...
    rmdir /s /q "%TEMP_DIR%" 2>nul
)

goto END

:SHOW_ALL_BACKUPS
echo.
echo ========================================
echo %SELECTED_DB%数据库的所有备份文件:
echo ========================================

echo.
echo 全量备份文件:
if !USE_COMPRESSION! equ 1 (
    dir "%BACKUP_BASE_PATH%\FULL\%SELECTED_DB%_*.zst" /b /o-d 2>nul
) else (
    dir "%BACKUP_BASE_PATH%\FULL\%SELECTED_DB%_*.bak" /b /o-d 2>nul
)

echo.
echo 增量备份文件:
if !USE_COMPRESSION! equ 1 (
    dir "%BACKUP_BASE_PATH%\DIFF\%SELECTED_DB%_*.zst" /b /o-d 2>nul
) else (
    dir "%BACKUP_BASE_PATH%\DIFF\%SELECTED_DB%_*.dif" /b /o-d 2>nul
)

echo.
echo 日志备份文件:
if !USE_COMPRESSION! equ 1 (
    dir "%BACKUP_BASE_PATH%\LOG\%SELECTED_DB%_*.zst" /b /o-d 2>nul
) else (
    dir "%BACKUP_BASE_PATH%\LOG\%SELECTED_DB%_*.trn" /b /o-d 2>nul
)

echo.
pause
goto SELECT_BACKUP_TYPE

:END
echo.
pause
endlocal
