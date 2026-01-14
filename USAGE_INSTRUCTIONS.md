# 使用说明

## 重要：配置备份路径

如果您在备份过程中遇到"无法打开备份设备"或"系统找不到指定的路径"错误，请按照以下步骤操作：

1. **编辑配置文件** [backup_config.bat](file:///f%3A/sqlserver_backup/backup_config.bat)
   - 修改 [BACKUP_BASE_PATH](file:///f%3A/sqlserver_backup/backup_config.bat#L17-L17) 为SQL Server服务器上的有效路径
   - 示例：`set "BACKUP_BASE_PATH=C:\SQLServerBackup"`

2. **运行诊断工具**
   ```
   diagnose_path.bat
   ```

3. **参考配置指南**
   详细说明请参阅 [CONFIG_GUIDE.md](file:///f%3A/sqlserver_backup/CONFIG_GUIDE.md)

## 基本使用流程

1. 配置数据库连接信息
2. 修改备份路径（如上所述）
3. 运行测试脚本验证配置
   ```
   test_backup.bat
   ```
4. 执行备份
   ```
   sqlserver_backup.bat FULL
   ```

## 其他工具

- [diagnose_path.bat](file:///f%3A/sqlserver_backup/diagnose_path.bat) - 诊断路径访问问题
- [CONFIG_GUIDE.md](file:///f%3A/sqlserver_backup/CONFIG_GUIDE.md) - 详细配置指南
- [test_backup.bat](file:///f%3A/sqlserver_backup/test_backup.bat) - 测试连接和配置
