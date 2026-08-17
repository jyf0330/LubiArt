#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const GODOT_ROOT = '/Users/ywh/Documents/godot';
const YSBZS_ROOT = '/Users/ywh/Documents/ysbzs';
const OUTPUT_DIR = path.join(GODOT_ROOT, 'output');
const JSON_OUT = path.join(OUTPUT_DIR, 'core_io_golden_diff.json');
const MD_OUT = path.join(OUTPUT_DIR, 'core_io_golden_diff.md');

const REQUIRED_RESPONSE_FIELDS = [
  'ok',
  'accepted',
  'command',
  'commandEnvelopeType',
  'stateVersion',
  'stateHash',
  'viewModelKeys'
];
const REQUIRED_VM_FIELDS = [
  'phase',
  'stateVersion',
  'stateHash',
  'gold',
  'round',
  'period',
  'heroes',
  'enemies',
  'board',
  'selected',
  'nextActions'
];
const REQUIRED_CELL_FIELDS = ['r', 'c', 'key', 'unitId', 'unitSide'];

function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const jsDump = buildYsbzsDump();
  const godotDump = buildGodotDump();
  const report = compareDumps(jsDump, godotDump);
  fs.writeFileSync(JSON_OUT, `${JSON.stringify(report, null, 2)}\n`);
  fs.writeFileSync(MD_OUT, buildMarkdown(report));
  console.log(`CORE_IO_GOLDEN_DIFF_${report.contractStatus} ${JSON_OUT} ${MD_OUT}`);
  if (report.contractStatus !== 'PASS') {
    for (const item of report.failures) console.error(`FAIL ${item.id}: ${item.message}`);
    process.exit(1);
  }
}

function buildYsbzsDump() {
  const { createServerAuthorityAdapter } = require(path.join(YSBZS_ROOT, 'src/adapters/serverAuthorityAdapter.cjs'));
  const adapter = createServerAuthorityAdapter({
    day: 1,
    period: '上午',
    gold: 8,
    seed: 'core-io-golden',
    activePets: ['pal_001'],
    battleId: 'core_io_golden'
  });
  const initialVm = adapter.getViewModel('p1');
  const stale = adapter.run({ type: 'START_BATTLE', commandId: 'js_stale_start', playerId: 'p1', baseStateVersion: Number(initialVm.stateVersion || 0) - 1 });
  const start = adapter.run({ type: 'START_BATTLE', commandId: 'js_start', playerId: 'p1', baseStateVersion: Number(initialVm.stateVersion || 0) });
  const heroId = String(start.viewModel?.heroes?.[0]?.id || start.viewModel?.heroes?.[0]?.unitId || '');
  const select = adapter.run({ type: 'SELECT_UNIT', unitId: heroId, commandId: 'js_select', playerId: 'p1', baseStateVersion: start.stateVersion });
  const beforeReplayVersion = select.stateVersion;
  const beforeReplayHash = select.stateHash;
  const replay = adapter.run({ type: 'EXPORT_REPLAY', commandId: 'js_replay', playerId: 'p1' });
  const afterReplayVm = adapter.getViewModel('p1');
  const save = adapter.exportSave('p1', { createdAt: 'core-io-golden' });
  return {
    engine: 'ysbzs',
    initial: snapshotSummary(initialVm),
    responses: {
      staleStart: responseSummary(stale),
      startBattle: responseSummary(start),
      selectUnit: responseSummary(select),
      exportReplay: responseSummary(replay)
    },
    stateAfterReplay: snapshotSummary(afterReplayVm),
    replayImmutability: {
      beforeVersion: beforeReplayVersion,
      afterVersion: afterReplayVm.stateVersion,
      beforeHash: beforeReplayHash,
      afterHash: afterReplayVm.stateHash
    },
    save: saveSummary(save)
  };
}

function buildGodotDump() {
  const result = spawnSync('godot', [
    '--headless',
    '--path',
    GODOT_ROOT,
    '--script',
    'res://tests/core/dump_core_io.gd'
  ], {
    cwd: YSBZS_ROOT,
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 16
  });
  if (result.error) throw result.error;
  const output = `${result.stdout || ''}\n${result.stderr || ''}`;
  if (result.status !== 0) {
    throw new Error(`Godot dump failed with ${result.status}\n${output}`);
  }
  const line = output.split(/\r?\n/).find(item => item.startsWith('CORE_IO_DUMP_JSON '));
  if (!line) throw new Error(`Godot dump did not emit CORE_IO_DUMP_JSON\n${output}`);
  return JSON.parse(line.slice('CORE_IO_DUMP_JSON '.length));
}

function compareDumps(jsDump, godotDump) {
  const checks = [];
  const failures = [];
  const knownDeltas = [];
  const addCheck = (id, passed, message, details = {}) => {
    const entry = { id, passed, message, details };
    checks.push(entry);
    if (!passed) failures.push(entry);
  };

  for (const [name, jsResponse] of Object.entries(jsDump.responses)) {
    const gdResponse = godotDump.responses[name];
    addCheck(`${name}.exists`, !!gdResponse, `${name} exists in both dumps`);
    if (!gdResponse) continue;
    for (const key of REQUIRED_RESPONSE_FIELDS) {
      addCheck(`${name}.field.${key}`, hasOwn(jsResponse, key) && hasOwn(gdResponse, key), `${name} exposes ${key}`);
    }
    addCheck(`${name}.command`, jsResponse.command === gdResponse.command, `${name} normalized command matches`, { ysbzs: jsResponse.command, godot: gdResponse.command });
    addCheck(`${name}.envelope`, jsResponse.commandEnvelopeType === gdResponse.commandEnvelopeType, `${name} commandEnvelope.type matches`, { ysbzs: jsResponse.commandEnvelopeType, godot: gdResponse.commandEnvelopeType });
    addCheck(`${name}.hash16`, isHash16(jsResponse.stateHash) && isHash16(gdResponse.stateHash), `${name} stateHash is a 16-char hash`);
    for (const field of REQUIRED_VM_FIELDS) {
      addCheck(`${name}.viewModel.${field}`, jsResponse.viewModelKeys.includes(field) && gdResponse.viewModelKeys.includes(field), `${name} viewModel exposes ${field}`);
    }
    for (const field of REQUIRED_CELL_FIELDS) {
      addCheck(`${name}.boardCell.${field}`, jsResponse.viewModel.board.firstCellKeys.includes(field) && gdResponse.viewModel.board.firstCellKeys.includes(field), `${name} board cell exposes ${field}`);
    }
    addCheck(`${name}.board64`, jsResponse.viewModel.board.cellCount === 64 && gdResponse.viewModel.board.cellCount === 64, `${name} board has 64 cells`, { ysbzs: jsResponse.viewModel.board.cellCount, godot: gdResponse.viewModel.board.cellCount });
  }

  addCheck('staleStart.rejected', !jsDump.responses.staleStart.ok && !godotDump.responses.staleStart.ok, 'stale START_BATTLE rejects on both engines');
  addCheck('staleStart.errorCode', jsDump.responses.staleStart.errorCode === 'STATE_VERSION_MISMATCH' && godotDump.responses.staleStart.errorCode === 'STATE_VERSION_MISMATCH', 'stale START_BATTLE uses STATE_VERSION_MISMATCH');
  addCheck('startBattle.accepted', jsDump.responses.startBattle.accepted && godotDump.responses.startBattle.accepted, 'START_BATTLE accepted on both engines');
  addCheck('startBattle.versionAdvance', jsDump.responses.startBattle.stateVersion === 1 && godotDump.responses.startBattle.stateVersion === 1, 'START_BATTLE advances to stateVersion 1');
  addCheck('selectUnit.ephemeral', jsDump.responses.selectUnit.ephemeral && godotDump.responses.selectUnit.ephemeral, 'SELECT_UNIT is ephemeral on both engines');
  addCheck('selectUnit.versionStable', jsDump.responses.selectUnit.stateVersion === jsDump.responses.startBattle.stateVersion && godotDump.responses.selectUnit.stateVersion === godotDump.responses.startBattle.stateVersion, 'SELECT_UNIT does not advance stateVersion');
  addCheck('selectUnit.selected', jsDump.responses.selectUnit.viewModel.selectedUnitId !== '' && godotDump.responses.selectUnit.viewModel.selectedUnitId !== '', 'SELECT_UNIT returns selected.unitId on both engines', {
    ysbzs: jsDump.responses.selectUnit.viewModel.selectedUnitId,
    godot: godotDump.responses.selectUnit.viewModel.selectedUnitId
  });
  addCheck('exportReplay.readOnly', jsDump.responses.exportReplay.readOnly && godotDump.responses.exportReplay.readOnly, 'EXPORT_REPLAY is readOnly on both engines');
  addCheck('exportReplay.schema', jsDump.responses.exportReplay.resultSchema === 'ysbzs.replay' && godotDump.responses.exportReplay.resultSchema === 'ysbzs.replay', 'EXPORT_REPLAY result schema matches ysbzs.replay');
  addCheck('exportReplay.versionStable', jsDump.replayImmutability.beforeVersion === jsDump.replayImmutability.afterVersion && godotDump.replayImmutability.beforeVersion === godotDump.replayImmutability.afterVersion, 'EXPORT_REPLAY does not advance stateVersion');
  addCheck('exportReplay.hashStable', jsDump.replayImmutability.beforeHash === jsDump.replayImmutability.afterHash && godotDump.replayImmutability.beforeHash === godotDump.replayImmutability.afterHash, 'EXPORT_REPLAY does not change stateHash');
  addCheck('save.schema', jsDump.save.schema === 'ysbzs.save' && godotDump.save.schema === 'ysbzs.save', 'save schema matches ysbzs.save');
  addCheck('save.checksum', jsDump.save.hasChecksum && godotDump.save.hasChecksum, 'save documents include checksum');
  addCheck('save.goldAlias', jsDump.save.state.gold === jsDump.save.state.coins && godotDump.save.state.gold === godotDump.save.state.coins, 'save gold aliases coins on both engines');
  addCheck('save.roundAlias', jsDump.save.state.round === jsDump.save.state.battle_round && godotDump.save.state.round === godotDump.save.state.battle_round, 'save round aliases battle_round on both engines');
  addCheck('save.periodAlias', jsDump.save.state.period === jsDump.save.state.battle_period && godotDump.save.state.period === godotDump.save.state.battle_period, 'save period aliases battle_period on both engines');

  pushDelta(knownDeltas, 'initial.phase', jsDump.initial.phase, godotDump.initial.phase, 'ysbzs adapter starts at init; Godot singleplayer starts at route.');
  pushDelta(knownDeltas, 'initial.gold', jsDump.initial.gold, godotDump.initial.gold, 'ysbzs test adapter uses gold=8; Godot data snapshot currently starts at coins=16.');
  pushDelta(knownDeltas, 'startBattle.viewModel.phase', jsDump.responses.startBattle.viewModel.phase, godotDump.responses.startBattle.viewModel.phase, 'ysbzs battle phase is player_turn; Godot singleplayer battle screen phase is battle.');
  pushDelta(knownDeltas, 'startBattle.enemyCount', jsDump.responses.startBattle.viewModel.enemyCount, godotDump.responses.startBattle.viewModel.enemyCount, 'Two engines still use different encounter/wave fixtures for this golden smoke.');
  pushDelta(knownDeltas, 'startBattle.nextActionTypes', jsDump.responses.startBattle.viewModel.nextActionTypes, godotDump.responses.startBattle.viewModel.nextActionTypes, 'Godot exposes additional singleplayer action controls; ysbzs exposes browser battle command set.');

  return {
    generatedAt: new Date().toISOString(),
    contractStatus: failures.length === 0 ? 'PASS' : 'FAIL',
    summary: {
      checks: checks.length,
      passed: checks.filter(item => item.passed).length,
      failed: failures.length,
      knownDeltas: knownDeltas.length
    },
    checks,
    failures,
    knownDeltas,
    dumps: {
      ysbzs: jsDump,
      godot: godotDump
    },
    outputFiles: {
      json: JSON_OUT,
      markdown: MD_OUT
    }
  };
}

function responseSummary(response) {
  const vm = response.viewModel || {};
  return {
    ok: !!response.ok,
    accepted: !!response.accepted,
    readOnly: !!response.readOnly,
    ephemeral: !!response.ephemeral,
    command: String(response.command || ''),
    commandEnvelopeType: String(response.commandEnvelope?.type || ''),
    stateVersion: Number(response.stateVersion ?? -1),
    stateHash: String(response.stateHash || ''),
    errorCode: String(response.error?.code || ''),
    resultSchema: String(response.result?.schema || ''),
    eventCount: Array.isArray(response.events) ? response.events.length : 0,
    traceEventCount: traceEventCount(response.trace),
    viewModelKeys: sortedKeys(vm),
    viewModel: {
      phase: String(vm.phase || ''),
      gold: Number(vm.gold ?? -1),
      round: Number(vm.round ?? -1),
      period: String(vm.period || ''),
      heroCount: Array.isArray(vm.heroes) ? vm.heroes.length : 0,
      enemyCount: Array.isArray(vm.enemies) ? vm.enemies.length : 0,
      selectedUnitId: String(vm.selected?.unitId || ''),
      board: boardSummary(vm.board || {}),
      nextActionTypes: Array.isArray(vm.nextActions) ? vm.nextActions.map(item => String(item.type || '')) : []
    }
  };
}

function snapshotSummary(vm) {
  return {
    phase: String(vm.phase || ''),
    stateVersion: Number(vm.stateVersion ?? -1),
    stateHash: String(vm.stateHash || ''),
    gold: Number(vm.gold ?? -1),
    round: Number(vm.round ?? -1),
    period: String(vm.period || ''),
    heroCount: Array.isArray(vm.heroes) ? vm.heroes.length : 0,
    enemyCount: Array.isArray(vm.enemies) ? vm.enemies.length : 0,
    board: boardSummary(vm.board || {}),
    nextActionTypes: Array.isArray(vm.nextActions) ? vm.nextActions.map(item => String(item.type || '')) : [],
    viewModelKeys: sortedKeys(vm)
  };
}

function boardSummary(board) {
  const cells = Array.isArray(board.cells) ? board.cells : [];
  const first = cells[0] || {};
  return {
    size: Number(board.size ?? 0),
    cellCount: cells.length,
    firstCellKeys: sortedKeys(first),
    firstCell: {
      r: first.r ?? null,
      c: first.c ?? null,
      key: first.key ?? null,
      unitId: first.unitId ?? null,
      unitSide: first.unitSide ?? null,
      x: first.x ?? null,
      y: first.y ?? null
    }
  };
}

function saveSummary(doc) {
  const state = doc.state || {};
  return {
    schema: String(doc.schema || ''),
    schemaVersion: Number(doc.schemaVersion ?? -1),
    hasChecksum: String(doc.checksum || '') !== '',
    stateKeys: sortedKeys(state),
    state: {
      coins: Number(state.coins ?? state.gold ?? -1),
      gold: Number(state.gold ?? state.coins ?? -1),
      battle_round: Number(state.battle_round ?? state.round ?? -1),
      round: Number(state.round ?? state.battle_round ?? -1),
      battle_period: String(state.battle_period ?? state.period ?? ''),
      period: String(state.period ?? state.battle_period ?? '')
    }
  };
}

function buildMarkdown(report) {
  const lines = [];
  lines.push('# Godot / ysbzs Core I/O Golden Diff');
  lines.push('');
  lines.push(`- Status: \`${report.contractStatus}\``);
  lines.push(`- Checks: ${report.summary.passed}/${report.summary.checks} passed`);
  lines.push(`- Known semantic deltas: ${report.summary.knownDeltas}`);
  lines.push('');
  lines.push('## Contract Checks');
  lines.push('');
  lines.push('| ID | Result | Message |');
  lines.push('|---|---|---|');
  for (const check of report.checks) {
    lines.push(`| \`${escapeCell(check.id)}\` | ${check.passed ? 'PASS' : 'FAIL'} | ${escapeCell(check.message)} |`);
  }
  lines.push('');
  lines.push('## Known Semantic Deltas');
  lines.push('');
  lines.push('| Field | ysbzs | Godot | Note |');
  lines.push('|---|---|---|---|');
  for (const delta of report.knownDeltas) {
    lines.push(`| \`${escapeCell(delta.field)}\` | \`${escapeCell(JSON.stringify(delta.ysbzs))}\` | \`${escapeCell(JSON.stringify(delta.godot))}\` | ${escapeCell(delta.note)} |`);
  }
  lines.push('');
  lines.push('## Output');
  lines.push('');
  lines.push(`- JSON: \`${JSON_OUT}\``);
  lines.push(`- Markdown: \`${MD_OUT}\``);
  lines.push('');
  return `${lines.join('\n')}\n`;
}

function traceEventCount(trace) {
  if (Array.isArray(trace)) return trace.length;
  if (trace && Array.isArray(trace.events)) return trace.events.length;
  return 0;
}

function sortedKeys(value) {
  if (!value || typeof value !== 'object') return [];
  return Object.keys(value).sort();
}

function hasOwn(value, key) {
  return Object.prototype.hasOwnProperty.call(value || {}, key);
}

function isHash16(value) {
  return typeof value === 'string' && value.length === 16;
}

function pushDelta(out, field, jsValue, gdValue, note) {
  if (JSON.stringify(jsValue) !== JSON.stringify(gdValue)) {
    out.push({ field, ysbzs: jsValue, godot: gdValue, note });
  }
}

function escapeCell(value) {
  return String(value).replace(/\|/g, '\\|').replace(/\n/g, ' ');
}

main();
