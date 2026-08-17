extends RefCounted

## Small deterministic semantic-version value helper used by content manifests.
## Content loading only needs numeric major/minor/patch compatibility; prerelease
## and build labels are retained for identity but sort below the matching release.


static func parse(value: String) -> Dictionary:
	var normalized := value.strip_edges()
	if normalized == "":
		return {"ok": false, "error": "SEMVER_REQUIRED"}
	var build_split := normalized.split("+", false, 1)
	var without_build := String(build_split[0])
	var prerelease_split := without_build.split("-", false, 1)
	var core := String(prerelease_split[0])
	var parts := core.split(".", false)
	if parts.size() != 3:
		return {"ok": false, "error": "SEMVER_CORE_INVALID"}
	var numbers: Array[int] = []
	for part_value in parts:
		var part := String(part_value)
		if part == "" or not part.is_valid_int() or (part.length() > 1 and part.begins_with("0")):
			return {"ok": false, "error": "SEMVER_CORE_INVALID"}
		var number := int(part)
		if number < 0:
			return {"ok": false, "error": "SEMVER_CORE_INVALID"}
		numbers.append(number)
	var prerelease := String(prerelease_split[1]) if prerelease_split.size() == 2 else ""
	if not _valid_label(prerelease, true):
		return {"ok": false, "error": "SEMVER_PRERELEASE_INVALID"}
	var build := String(build_split[1]) if build_split.size() == 2 else ""
	if not _valid_label(build):
		return {"ok": false, "error": "SEMVER_BUILD_INVALID"}
	return {
		"ok": true,
		"value": normalized,
		"major": numbers[0],
		"minor": numbers[1],
		"patch": numbers[2],
		"prerelease": prerelease,
		"build": build,
	}


static func compare(left: String, right: String) -> int:
	var left_value := parse(left)
	var right_value := parse(right)
	if not bool(left_value.get("ok", false)) or not bool(right_value.get("ok", false)):
		return 0
	for key in ["major", "minor", "patch"]:
		var left_number := int(left_value.get(key, 0))
		var right_number := int(right_value.get(key, 0))
		if left_number != right_number:
			return -1 if left_number < right_number else 1
	var left_pre := String(left_value.get("prerelease", ""))
	var right_pre := String(right_value.get("prerelease", ""))
	if left_pre == right_pre:
		return 0
	if left_pre == "":
		return 1
	if right_pre == "":
		return -1
	return _compare_prerelease(left_pre, right_pre)


static func _compare_prerelease(left: String, right: String) -> int:
	var left_parts := left.split(".", false)
	var right_parts := right.split(".", false)
	for index in range(min(left_parts.size(), right_parts.size())):
		var left_part := String(left_parts[index])
		var right_part := String(right_parts[index])
		if left_part == right_part:
			continue
		var left_numeric := left_part.is_valid_int()
		var right_numeric := right_part.is_valid_int()
		if left_numeric and right_numeric:
			return -1 if int(left_part) < int(right_part) else 1
		if left_numeric != right_numeric:
			return -1 if left_numeric else 1
		return -1 if left_part < right_part else 1
	if left_parts.size() == right_parts.size():
		return 0
	return -1 if left_parts.size() < right_parts.size() else 1


static func _valid_label(value: String, reject_numeric_leading_zero: bool = false) -> bool:
	if value == "":
		return true
	for segment_value in value.split(".", true):
		var segment := String(segment_value)
		if segment == "":
			return false
		if reject_numeric_leading_zero and segment.is_valid_int() and segment.length() > 1 and segment.begins_with("0"):
			return false
		for character in segment:
			var code := character.unicode_at(0)
			if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or character == "-"):
				return false
	return true
