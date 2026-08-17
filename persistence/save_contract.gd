extends RefCounted

## Save document identity. Codec builds documents, migrations translate versions,
## and repositories only persist the resulting bytes.

const SCHEMA := "ysbzs.save"
const LEGACY_SCHEMA := "ysbzs.godot.save"
const SCHEMA_VERSION := 2
