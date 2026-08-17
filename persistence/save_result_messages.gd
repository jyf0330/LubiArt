extends RefCounted

## Compatibility-facing text mapping for repository result codes.


static func write_error(error: String) -> String:
	match error:
		"INVALID_SLOT":
			return "保存失败：存档槽无效。"
		"TEMP_WRITE_FAILED":
			return "保存失败：无法写入临时文件。"
		"BACKUP_UPDATE_FAILED":
			return "保存失败：无法更新备份。"
		"PRIMARY_REPLACE_FAILED":
			return "保存失败：无法替换主存档。"
	return "保存失败：未知存档错误。"
