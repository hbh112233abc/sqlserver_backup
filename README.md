# SQL Server 数据库自动备份脚本 (SQL Server 2016兼容)

这是一套用于Windows Server的SQL Server数据库自动备份解决方案，支持全量、增量、日志备份，使用zstd压缩，并支持计划任务定时执行。

## 文件说明

- `backup_config.bat` - 配置文件，包含SQL Server连接信息和备份参数
- `sqlserver_backup.bat` - 主备份脚本，支持传参指定备份类型
- `setup_scheduled_task.bat` - 创建Windows计划任务的脚本
- `test_backup.bat` - 测试连接和配置的脚本
- `restore_database.bat` - 交互式数据库还原脚本
- `install_zstd.bat` - zstd压缩工具安装向导

## 新功能特性

- **多种备份类型**: 支持全量(FULL)、增量(DIFF)、日志(LOG)备份
- **zstd压缩**: 自动压缩备份文件，节省存储空间
- **灵活的保留策略**: 不同备份类型可设置不同的保留天数
- **交互式还原**: 可视化选择备份文件进行还原
- **SQL Server 2016兼容**: 针对SQL Server 2016进行优化

## 使用步骤

### 0. 安装sqlcmd

```cmd
winget install sqlcmd
```

### 1. 安装zstd压缩工具

运行安装向导：
```cmd
install_zstd.bat
```

或手动下载zstd.exe放到脚本目录。

### 2. 配置数据库连接信息

编辑 `backup_config.bat` 文件，修改以下参数：

```batch
# SQL Server连接配置
set SERVER_NAME=127.0.0.1
set SQL_USER=sa
set SQL_PASSWORD=your_password
set SQL_AUTH_MODE=SQL

# 备份路径
set BACKUP_BASE_PATH=%~dp0\backup

# 全量备份配置
set FULL_BACKUP_KEEP_DAYS=30

# 增量备份配置
set DIFF_BACKUP_KEEP_DAYS=7

# 日志备份配置
set LOG_BACKUP_KEEP_DAYS=3

# 压缩配置
set COMPRESSION_LEVEL=3
```

### 3. 测试配置

运行测试脚本：
```cmd
test_backup.bat
```

### 4. 手动测试备份

测试不同类型的备份：
```cmd
# 全量备份
sqlserver_backup.bat FULL

# 增量备份
sqlserver_backup.bat DIFF

# 日志备份
sqlserver_backup.bat LOG
```

### 5. 创建计划任务

以管理员身份运行：
```cmd
setup_scheduled_task.bat
```

这将创建三个计划任务：
- SQL Server Full Backup (全量备份)
- SQL Server Diff Backup (增量备份)
- SQL Server Log Backup (日志备份)

## 备份策略说明

### 备份类型

1. **全量备份 (FULL)**
   - 备份完整的数据库
   - 默认每周日凌晨2:00执行
   - 保留30天
   - 文件扩展名: .bak

2. **增量备份 (DIFF)**
   - 备份自上次全量备份后的变化
   - 默认每天中午12:00执行
   - 保留7天
   - 文件扩展名: .dif

3. **日志备份 (LOG)**
   - 备份事务日志
   - 默认每小时执行
   - 保留3天
   - 文件扩展名: .trn

### 备份文件结构

```
backup/
├── FULL/          # 全量备份
│   ├── HYCD_20240115_0200.bak.zst
│   └── HYTB_20240115_0200.bak.zst
├── DIFF/          # 增量备份
│   ├── HYCD_20240115_1200.dif.zst
│   └── HYTB_20240115_1200.dif.zst
└── LOG/           # 日志备份
    ├── HYCD_20240115_1300.trn.zst
    └── HYTB_20240115_1300.trn.zst
```

## 数据库还原

运行交互式还原脚本：
```cmd
restore_database.bat
```

还原脚本功能：
- 选择要还原的数据库
- 选择备份类型
- 显示可用的备份文件和时间点
- 自动解压压缩的备份文件
- 执行还原操作

## SQL Server 2016兼容性

脚本已针对SQL Server 2016进行优化：
- 使用兼容的BACKUP语法
- 支持压缩备份 (WITH COMPRESSION)
- 包含校验和验证 (WITH CHECKSUM)
- 显示备份进度 (STATS = 10)

## 计划任务管理

查看所有备份任务：
```cmd
schtasks /query /tn "SQL Server*"
```

删除特定任务：
```cmd
schtasks /delete /tn "SQL Server Full Backup" /f
schtasks /delete /tn "SQL Server Diff Backup" /f
schtasks /delete /tn "SQL Server Log Backup" /f
```

修改任务时间：
```cmd
schtasks /change /tn "SQL Server Full Backup" /st 03:00
```

## 故障排除

### 常见问题

1. **zstd命令未找到**
   - 运行 `install_zstd.bat` 安装压缩工具
   - 或将zstd.exe复制到脚本目录

2. **备份失败**
   - 检查SQL Server服务状态
   - 验证数据库名称和连接信息
   - 确认备份路径有写入权限

3. **无法打开备份设备错误**
   - **重要**: 如果遇到"无法打开备份设备"错误，这通常是由于备份路径问题导致的
   - 备份路径必须是SQL Server服务器上的本地路径，而不是运行脚本的客户端机器的路径
   - 例如，如果您的脚本在机器A上运行，但连接到机器B上的SQL Server，则备份路径必须是机器B上的有效路径
   - 确保SQL Server服务账户对备份目录具有完全访问权限
   - 可以使用如 `C:\SQLServerBackup` 这样的本地路径，或者使用SQL Server服务账户有权限访问的共享路径

3. **还原失败**
   - 确保数据库不在使用中
   - 检查备份文件完整性
   - 验证还原路径权限

4. **计划任务不执行**
   - 检查任务是否启用
   - 验证执行账户权限
   - 查看任务历史记录

### 日志文件

备份日志位置：`logs\backup_log.txt`

查看最近的备份日志：
```cmd
type logs\backup_log.txt | find /i "2024"
```

## 性能优化建议

1. **存储优化**
   - 将备份文件存储在独立的高速磁盘
   - 定期清理过期备份文件

2. **压缩优化**
   - 调整压缩级别 (1-22，默认3)
   - 较高级别压缩率更好但速度较慢

3. **备份策略优化**
   - 根据业务需求调整备份频率
   - 在业务低峰期执行全量备份

## 注意事项

1. 确保运行脚本的账户有SQL Server备份权限
2. 定期测试备份文件的完整性和可还原性
3. 监控磁盘空间，确保有足够的存储空间
4. 建议将备份文件复制到异地存储
5. 定期检查和更新zstd压缩工具版本
