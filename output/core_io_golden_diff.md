# Godot / ysbzs Core I/O Golden Diff

- Status: `PASS`
- Checks: 128/128 passed
- Known semantic deltas: 4

## Contract Checks

| ID | Result | Message |
|---|---|---|
| `staleStart.exists` | PASS | staleStart exists in both dumps |
| `staleStart.field.ok` | PASS | staleStart exposes ok |
| `staleStart.field.accepted` | PASS | staleStart exposes accepted |
| `staleStart.field.command` | PASS | staleStart exposes command |
| `staleStart.field.commandEnvelopeType` | PASS | staleStart exposes commandEnvelopeType |
| `staleStart.field.stateVersion` | PASS | staleStart exposes stateVersion |
| `staleStart.field.stateHash` | PASS | staleStart exposes stateHash |
| `staleStart.field.viewModelKeys` | PASS | staleStart exposes viewModelKeys |
| `staleStart.command` | PASS | staleStart normalized command matches |
| `staleStart.envelope` | PASS | staleStart commandEnvelope.type matches |
| `staleStart.hash16` | PASS | staleStart stateHash is a 16-char hash |
| `staleStart.viewModel.phase` | PASS | staleStart viewModel exposes phase |
| `staleStart.viewModel.stateVersion` | PASS | staleStart viewModel exposes stateVersion |
| `staleStart.viewModel.stateHash` | PASS | staleStart viewModel exposes stateHash |
| `staleStart.viewModel.gold` | PASS | staleStart viewModel exposes gold |
| `staleStart.viewModel.round` | PASS | staleStart viewModel exposes round |
| `staleStart.viewModel.period` | PASS | staleStart viewModel exposes period |
| `staleStart.viewModel.heroes` | PASS | staleStart viewModel exposes heroes |
| `staleStart.viewModel.enemies` | PASS | staleStart viewModel exposes enemies |
| `staleStart.viewModel.board` | PASS | staleStart viewModel exposes board |
| `staleStart.viewModel.selected` | PASS | staleStart viewModel exposes selected |
| `staleStart.viewModel.nextActions` | PASS | staleStart viewModel exposes nextActions |
| `staleStart.boardCell.r` | PASS | staleStart board cell exposes r |
| `staleStart.boardCell.c` | PASS | staleStart board cell exposes c |
| `staleStart.boardCell.key` | PASS | staleStart board cell exposes key |
| `staleStart.boardCell.unitId` | PASS | staleStart board cell exposes unitId |
| `staleStart.boardCell.unitSide` | PASS | staleStart board cell exposes unitSide |
| `staleStart.board64` | PASS | staleStart board has 64 cells |
| `startBattle.exists` | PASS | startBattle exists in both dumps |
| `startBattle.field.ok` | PASS | startBattle exposes ok |
| `startBattle.field.accepted` | PASS | startBattle exposes accepted |
| `startBattle.field.command` | PASS | startBattle exposes command |
| `startBattle.field.commandEnvelopeType` | PASS | startBattle exposes commandEnvelopeType |
| `startBattle.field.stateVersion` | PASS | startBattle exposes stateVersion |
| `startBattle.field.stateHash` | PASS | startBattle exposes stateHash |
| `startBattle.field.viewModelKeys` | PASS | startBattle exposes viewModelKeys |
| `startBattle.command` | PASS | startBattle normalized command matches |
| `startBattle.envelope` | PASS | startBattle commandEnvelope.type matches |
| `startBattle.hash16` | PASS | startBattle stateHash is a 16-char hash |
| `startBattle.viewModel.phase` | PASS | startBattle viewModel exposes phase |
| `startBattle.viewModel.stateVersion` | PASS | startBattle viewModel exposes stateVersion |
| `startBattle.viewModel.stateHash` | PASS | startBattle viewModel exposes stateHash |
| `startBattle.viewModel.gold` | PASS | startBattle viewModel exposes gold |
| `startBattle.viewModel.round` | PASS | startBattle viewModel exposes round |
| `startBattle.viewModel.period` | PASS | startBattle viewModel exposes period |
| `startBattle.viewModel.heroes` | PASS | startBattle viewModel exposes heroes |
| `startBattle.viewModel.enemies` | PASS | startBattle viewModel exposes enemies |
| `startBattle.viewModel.board` | PASS | startBattle viewModel exposes board |
| `startBattle.viewModel.selected` | PASS | startBattle viewModel exposes selected |
| `startBattle.viewModel.nextActions` | PASS | startBattle viewModel exposes nextActions |
| `startBattle.boardCell.r` | PASS | startBattle board cell exposes r |
| `startBattle.boardCell.c` | PASS | startBattle board cell exposes c |
| `startBattle.boardCell.key` | PASS | startBattle board cell exposes key |
| `startBattle.boardCell.unitId` | PASS | startBattle board cell exposes unitId |
| `startBattle.boardCell.unitSide` | PASS | startBattle board cell exposes unitSide |
| `startBattle.board64` | PASS | startBattle board has 64 cells |
| `selectUnit.exists` | PASS | selectUnit exists in both dumps |
| `selectUnit.field.ok` | PASS | selectUnit exposes ok |
| `selectUnit.field.accepted` | PASS | selectUnit exposes accepted |
| `selectUnit.field.command` | PASS | selectUnit exposes command |
| `selectUnit.field.commandEnvelopeType` | PASS | selectUnit exposes commandEnvelopeType |
| `selectUnit.field.stateVersion` | PASS | selectUnit exposes stateVersion |
| `selectUnit.field.stateHash` | PASS | selectUnit exposes stateHash |
| `selectUnit.field.viewModelKeys` | PASS | selectUnit exposes viewModelKeys |
| `selectUnit.command` | PASS | selectUnit normalized command matches |
| `selectUnit.envelope` | PASS | selectUnit commandEnvelope.type matches |
| `selectUnit.hash16` | PASS | selectUnit stateHash is a 16-char hash |
| `selectUnit.viewModel.phase` | PASS | selectUnit viewModel exposes phase |
| `selectUnit.viewModel.stateVersion` | PASS | selectUnit viewModel exposes stateVersion |
| `selectUnit.viewModel.stateHash` | PASS | selectUnit viewModel exposes stateHash |
| `selectUnit.viewModel.gold` | PASS | selectUnit viewModel exposes gold |
| `selectUnit.viewModel.round` | PASS | selectUnit viewModel exposes round |
| `selectUnit.viewModel.period` | PASS | selectUnit viewModel exposes period |
| `selectUnit.viewModel.heroes` | PASS | selectUnit viewModel exposes heroes |
| `selectUnit.viewModel.enemies` | PASS | selectUnit viewModel exposes enemies |
| `selectUnit.viewModel.board` | PASS | selectUnit viewModel exposes board |
| `selectUnit.viewModel.selected` | PASS | selectUnit viewModel exposes selected |
| `selectUnit.viewModel.nextActions` | PASS | selectUnit viewModel exposes nextActions |
| `selectUnit.boardCell.r` | PASS | selectUnit board cell exposes r |
| `selectUnit.boardCell.c` | PASS | selectUnit board cell exposes c |
| `selectUnit.boardCell.key` | PASS | selectUnit board cell exposes key |
| `selectUnit.boardCell.unitId` | PASS | selectUnit board cell exposes unitId |
| `selectUnit.boardCell.unitSide` | PASS | selectUnit board cell exposes unitSide |
| `selectUnit.board64` | PASS | selectUnit board has 64 cells |
| `exportReplay.exists` | PASS | exportReplay exists in both dumps |
| `exportReplay.field.ok` | PASS | exportReplay exposes ok |
| `exportReplay.field.accepted` | PASS | exportReplay exposes accepted |
| `exportReplay.field.command` | PASS | exportReplay exposes command |
| `exportReplay.field.commandEnvelopeType` | PASS | exportReplay exposes commandEnvelopeType |
| `exportReplay.field.stateVersion` | PASS | exportReplay exposes stateVersion |
| `exportReplay.field.stateHash` | PASS | exportReplay exposes stateHash |
| `exportReplay.field.viewModelKeys` | PASS | exportReplay exposes viewModelKeys |
| `exportReplay.command` | PASS | exportReplay normalized command matches |
| `exportReplay.envelope` | PASS | exportReplay commandEnvelope.type matches |
| `exportReplay.hash16` | PASS | exportReplay stateHash is a 16-char hash |
| `exportReplay.viewModel.phase` | PASS | exportReplay viewModel exposes phase |
| `exportReplay.viewModel.stateVersion` | PASS | exportReplay viewModel exposes stateVersion |
| `exportReplay.viewModel.stateHash` | PASS | exportReplay viewModel exposes stateHash |
| `exportReplay.viewModel.gold` | PASS | exportReplay viewModel exposes gold |
| `exportReplay.viewModel.round` | PASS | exportReplay viewModel exposes round |
| `exportReplay.viewModel.period` | PASS | exportReplay viewModel exposes period |
| `exportReplay.viewModel.heroes` | PASS | exportReplay viewModel exposes heroes |
| `exportReplay.viewModel.enemies` | PASS | exportReplay viewModel exposes enemies |
| `exportReplay.viewModel.board` | PASS | exportReplay viewModel exposes board |
| `exportReplay.viewModel.selected` | PASS | exportReplay viewModel exposes selected |
| `exportReplay.viewModel.nextActions` | PASS | exportReplay viewModel exposes nextActions |
| `exportReplay.boardCell.r` | PASS | exportReplay board cell exposes r |
| `exportReplay.boardCell.c` | PASS | exportReplay board cell exposes c |
| `exportReplay.boardCell.key` | PASS | exportReplay board cell exposes key |
| `exportReplay.boardCell.unitId` | PASS | exportReplay board cell exposes unitId |
| `exportReplay.boardCell.unitSide` | PASS | exportReplay board cell exposes unitSide |
| `exportReplay.board64` | PASS | exportReplay board has 64 cells |
| `staleStart.rejected` | PASS | stale START_BATTLE rejects on both engines |
| `staleStart.errorCode` | PASS | stale START_BATTLE uses STATE_VERSION_MISMATCH |
| `startBattle.accepted` | PASS | START_BATTLE accepted on both engines |
| `startBattle.versionAdvance` | PASS | START_BATTLE advances to stateVersion 1 |
| `selectUnit.ephemeral` | PASS | SELECT_UNIT is ephemeral on both engines |
| `selectUnit.versionStable` | PASS | SELECT_UNIT does not advance stateVersion |
| `selectUnit.selected` | PASS | SELECT_UNIT returns selected.unitId on both engines |
| `exportReplay.readOnly` | PASS | EXPORT_REPLAY is readOnly on both engines |
| `exportReplay.schema` | PASS | EXPORT_REPLAY result schema matches ysbzs.replay |
| `exportReplay.versionStable` | PASS | EXPORT_REPLAY does not advance stateVersion |
| `exportReplay.hashStable` | PASS | EXPORT_REPLAY does not change stateHash |
| `save.schema` | PASS | save schema matches ysbzs.save |
| `save.checksum` | PASS | save documents include checksum |
| `save.goldAlias` | PASS | save gold aliases coins on both engines |
| `save.roundAlias` | PASS | save round aliases battle_round on both engines |
| `save.periodAlias` | PASS | save period aliases battle_period on both engines |

## Known Semantic Deltas

| Field | ysbzs | Godot | Note |
|---|---|---|---|
| `initial.phase` | `"init"` | `"route"` | ysbzs adapter starts at init; Godot singleplayer starts at route. |
| `initial.gold` | `8` | `16` | ysbzs test adapter uses gold=8; Godot data snapshot currently starts at coins=16. |
| `startBattle.viewModel.phase` | `"player_turn"` | `"battle"` | ysbzs battle phase is player_turn; Godot singleplayer battle screen phase is battle. |
| `startBattle.nextActionTypes` | `["AUTO_POSITION_HEROES","MOVE_HERO","SET_ACTION_DIRECTION","USE_SLOT","END_PLAYER_TURN","BUILD_PREVIEW","ENTER_SHOP","RUN_BATTLE","RUN_FULL_DAY","RUN_FULL_RUN","SETUP_DAY7_FIRE_TRIAL"]` | `["AUTO_POSITION_HEROES","MOVE_HERO","SET_ACTION_DIRECTION","SET_ACTION_AP","USE_SLOT","USE_ACTION_SLOT","RUN_PLAYER_ALL_OUT","END_PLAYER_TURN"]` | Godot exposes additional singleplayer action controls; ysbzs exposes browser battle command set. |

## Output

- JSON: `/Users/ywh/Documents/godot/output/core_io_golden_diff.json`
- Markdown: `/Users/ywh/Documents/godot/output/core_io_golden_diff.md`
