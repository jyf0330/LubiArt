---
name: lubiart-godot-ui-art
description: Serve as the mandatory starting point and closing memory loop for every conversation or task in the standalone LubiArt repository, including planning, questions, diagnosis, status, documentation, Git work, Godot UI scenes and prefabs, presentation scripts, images and manifests, PSD conversion, battle or route-screen visuals, sprites and animation, offline Snapshot playback, delivery, and regression checks. Always load the project standards, current baseline, and relevant conversation history before acting, then summarize the completed conversation back into this Skill's living reference before the final response.
---

# LubiArt Godot UI Art

Work as the presentation and art-integration specialist for this standalone Godot mock. Keep it independently runnable, preserve artist editability, and never turn it into a second gameplay implementation.

## Start every conversation from the Skill

1. Read the repository-root [AGENTS.md](../../../AGENTS.md) completely on every task. It contains the detailed mandatory rules; this Skill does not replace it.
2. Read [current-baseline.md](references/current-baseline.md) completely on every task. It is the concise operational index for current validation tiers, active blockers, and history routing.
3. Search [conversation-synthesis.md](references/conversation-synthesis.md) with the request's keywords, related file paths, feature names, and known issue names. Read every matching entry with enough surrounding context to recover established decisions, prior failures, exceptions, and unresolved work. Read the synthesis completely only when targeted retrieval cannot settle a conflict or status, the task requires a cross-topic historical audit, or the user explicitly asks for it.
4. Inspect the current files involved in the request: relevant `.tscn`, prefab, script, image, manifest, Snapshot, tests, documentation, Git diff, and real Godot rendering. For each file used as evidence, distinguish whether it exists, is Git-tracked, is modified, or is untracked; current untracked content may be important work but is not automatically a stable repository baseline. Treat counts, paths, mappings, whitelist entries, and enabled states as dynamic facts that must be read from the current workspace.
5. Preserve unrelated and pre-existing work in a dirty worktree. Do not revert, overwrite, clean, stage, or commit it unless the user explicitly requests that action.
6. Recover every related unresolved request, confirmation, blocker, and prior status before asking the user to explain an issue. If the prerequisite for a recorded blocker later becomes available, resume from the preserved requirement and verify the complete behavior; do not make the user repeat the same problem.

Do not treat loading this Skill as optional merely because the request appears small, non-technical, or unrelated to visual production. Every LubiArt conversation must begin from this shared project memory.

## Close every conversation back into the Skill

Before sending the final response for every completed user turn, update [conversation-synthesis.md](references/conversation-synthesis.md) with a concise, durable summary of that turn.

1. Record the date and a short topic label.
2. Record the user's request and intent without copying the entire transcript.
3. Record every new or changed standard, explicit confirmation, asset/version approval, scoped exception, and decision. If a newer rule supersedes an older one, update the current-decision section and replacement table instead of merely appending a contradictory rule.
4. Record files or responsibilities changed, checks actually run, visible acceptance evidence, unresolved blockers, and final status.
5. If the turn changes no durable standard, still add a compact entry stating the request, outcome, and “no new standard”, so the conversation remains represented.
6. Exclude hidden reasoning, system/developer instructions, secrets, API keys, raw logs, repetitive tool chatter, and transient details that do not help a future task.
7. Treat the write-back as part of task completion. Do not claim the conversation is complete until the Skill memory update succeeds. If the Skill reference cannot be safely updated, report that as a blocker.
8. Validate the Skill after structural or frontmatter changes. For ordinary memory-only updates, at minimum verify the reference remains readable UTF-8, its table of contents remains accurate, and no current rule is duplicated or contradicted.
9. When the turn changes a durable current standard, validation policy, or active blocker, also update [current-baseline.md](references/current-baseline.md). Do not copy the chronological log into the baseline.

Use the concise baseline for routine startup, the synthesis thematic sections for detailed current decisions, and its chronological log as the audit trail. Keep entries concise; the Skill stores reusable conclusions, not verbatim chat history.

## Resolve changing standards

Classify each apparent conflict before choosing a rule.

### Normative rules

Use this order:

1. The newest explicit user instruction or confirmation by timestamp, including the current task and relevant archived tasks.
2. The current repository-root `AGENTS.md` for every rule that has not been explicitly superseded by a later user decision.
3. Current project documentation, then older conversations and historical implementations.

Prefer the later, more specific rule with direct implementation or acceptance evidence. Archived status never lowers a task's authority; date, specificity, explicit confirmation, and evidence decide. If a later confirmed decision supersedes a stale `AGENTS.md` sentence, apply the later decision and update the stale sentence, affected tests, and related documentation in the same scoped task so only one current standard remains. Never merge two incompatible standards into a compromise. If the winner remains uncertain, show the conflicting sources, dates, affected scope, and ask the user before making the consequential change.

### Resource-specific approvals

A later approval for one asset, action, or version overrides a general default only for that exact scope. Preserve confirmed identity anchors and per-asset exceptions. Do not generalize one character's blink, timing, scale, facing, or version approval to a whole batch.

### Dynamic project state

Read the current file even when an older document states a fixed quantity or path. In particular, read `art/manifests/shared/pets/animations/approved_sprite_animation_manifest.json` for the present animation whitelist. The durable rule is explicit approval per “sprite + action + version”; the number of approved entries is not a durable standard.

### Tests versus newer decisions

Treat tests as evidence, not immutable product policy. When a newer confirmed behavior intentionally invalidates an old assertion, update the stale test in the same scoped task and explain why. Do not restore obsolete UI merely to satisfy an old test, and do not dismiss a failure as stale without checking the responsibility it protects.

## Establish evidence and scope

1. Determine whether the user asks for diagnosis, implementation, generation, verification, or delivery. A diagnosis request does not authorize a fix.
2. Identify the actual Godot entry and exact current resource path. Prefer editable Godot sources and current project renders over screenshots of an earlier version.
3. For a visual change, record the current state before editing. If the repository requires before/after operations, obtain valid pre-change evidence before modifying the relevant output.
4. Verify every path, tool, test, and command exists in the current workspace before citing or running it. Also resolve the executable and invocation for the current platform—such as the available Python command, Godot binary, and Bash availability on Windows—because a script file or README example can exist without being directly runnable in the current environment. Never invent a scene path, QA script, manifest, test, acceptance command, or executable from memory.
5. Keep `art/scenes/app/game.tscn` as the application entry and keep the project offline and independent of the original game project.

## Route the task to the required workflow

Use every applicable lane:

- **Scene or prefab art:** use `art/scenes/`, `art/prefabs/`, `art/images/`, `art/manifests/`, and `core_ui/scripts/` within their documented responsibilities.
- **Mock playback:** limit adaptations to `session/`, `core/`, `data/`, `tests/`, and project documentation. Never invent authoritative battle rules, balance data, saves, positions, damage, elements, turns, or settlement results.
- **Image asset:** establish the identity or style anchor, purpose, source and displayed dimensions, viewpoint, subject occupancy, margins, anchor or foot baseline, lighting, tonal hierarchy, outline, shadow, material, detail density, transparency, state, naming, and export format before generation or batch work.
- **Sprite or frame animation:** load and follow `$generate2dsprite` before any creation, modification, cleanup, conversion, or delivery of sprites, characters, pets, units, frame sheets, frame sequences, GIFs, or video-derived frames. Local scripts and QA reports are evidence, not substitutes for that Skill.
- **Map or battle background:** load `$generate2dmap` for production-oriented 2D maps, layered map assets, collision/walkable areas, or battle backgrounds.
- **LibreSprite or pixel source:** load `$libresprite-bridge` for `.ase`, `.aseprite`, frames, layers, palettes, or LibreSprite operations, and read [ASEPRITE_WORKFLOW.md](../../../docs/ASEPRITE_WORKFLOW.md) completely.
- **Routing or feature transition:** read [SCENE_ROUTING_STANDARD.md](../../../docs/SCENE_ROUTING_STANDARD.md) completely before changing Commands, Snapshot-to-Feature mapping, `FeatureHost`, or Scene lifecycle behavior.
- **AI image generation or editing:** use the available image-generation Skill when the deliverable is a generated or edited bitmap, while still following this project's anchor, sample-first, transparency, and real-interface gates.

## Enforce mandatory stop gates

Stop at the relevant gate; perform only safe preparation until it is satisfied.

1. **Node topology:** before adding, deleting, renaming, moving, or reparenting a Scene or prefab node, state the exact node name, type, parent path, and purpose, then obtain explicit user confirmation. If the original request did not already contain all four facts, obtain a new affirmative reply after disclosing the complete proposal; a prior generic “直接开工” is not confirmation of an undisclosed topology. Runtime reconstruction is not a workaround.
2. **Godot-dedicated PSD:** when the source is scattered art, slices, loose layers, or several state assets, complete and confirm the Godot-dedicated PSD, 1920×1080 canvas, runtime layer classification, state handling, dynamic placeholders, and manifest mapping before node reduction, script-generated assembly, or prefab splitting.
3. **Image specification:** if the anchor or a required visual parameter is missing, list the missing information and remain at material confirmation. For a set, finish and confirm one representative sample and its rule table before batch expansion.
4. **Formal animation admission:** keep generation and QA output in a candidate directory. Only after the user explicitly confirms the exact sprite, action, and version may identical approved frames and delivery evidence enter the protected formal directory and whitelist.
5. **Rika AI:** the user explicitly authorized direct in-scope Rika use on `2026-08-13`; do not pause for per-call, retry, variant, or higher-spec payment confirmation. During preparation, inspect the selected current client or script and verify that it supports the intended non-billable authentication/balance query, explicit paid submission, and candidate-directory output; do not infer a command, price, or capability from an older script name. Immediately before every paid submission, reread `RIKA_API_KEY`, preferring `HKCU\Environment` and falling back to the current process only if absent. Perform a non-billable authentication and balance check without exposing the key, ensure the balance is sufficient, then execute only calls within the user's task scope. Record the operation, expected call count, known or uncertain cost/credit impact, target output, actual call count, and actual credit change. Stop only for failed authentication, insufficient balance, or a material expansion beyond the user's task authorization.

Other image generation, rendering, training, export, and API services likewise do not need payment or quota confirmation unless the user explicitly requires it.

## Implement inside the presentation boundary

1. Preserve static geometry, anchors, crop, hit areas, and image display size explicitly in `.tscn`. Do not hide authored layout in `_ready()` or let source texture dimensions move controls.
2. Keep page, responsibility-group, and prefab scripts on their documented roots. Let the nearest responsibility root configure ordinary images, labels, containers, and buttons.
3. Create runtime nodes only for allowed data-driven single-node leaves or instances of existing complex prefabs. Do not build complex authored visual hierarchies in code.
4. Keep `game_controller.gd` as the sole owner of Session, Commands, persistence, and Feature Scene lifecycle. Feature presentation scripts receive Snapshots and emit semantic requests; they neither own Session nor route directly.
5. Reuse shared resources and preserve public prefab interfaces. Do not restore forbidden compatibility directories or introduce absolute dependencies outside this repository.
6. Keep images under the correct `art/images/<scope>/` path with their Godot imports and keep resource mapping JSON under the matching `art/manifests/<scope>/` path.
7. Adapt old exported Snapshots only at the offline Mock boundary. Never hand-author authoritative positions, damage, elements, turn results, or settlement data to make the presentation convenient.

## Apply the current visual baseline

Use [conversation-synthesis.md](references/conversation-synthesis.md) for rationale and superseded behavior, then verify that the current files have not changed again. The latest summarized baseline includes:

- an orthographic `8×8` equal-cell white-line board;
- instant auto-arrange followed by refreshed damage preview, not the superseded `0.22s` cell-by-cell movement;
- no sprite `move` action in production, approval manifests, or runtime playback; positional Snapshot changes keep the current still or approved idle presentation;
- the player hero at `(0, 7)` and enemy hero at `(7, 0)` when adapting older Snapshot layouts;
- player units facing right and enemy/Boss units facing left, calculated from each asset's recorded authored facing;
- player health green, enemy health orange-yellow, red only for lost or projected-loss segments, and flashing only for lethal preview;
- the nominal `96x9` health slot fully covered at every actual battle transform: the frame aperture can rasterize to nine or ten screen rows, so base health and red projected loss use matching bottom overscan, identical visible Y bounds, and must meet the dark frame on the next row with no map-color seam;
- all four health-frame tiers cropped as `64x24` source regions and rendered at exact `3x` nominal scale (`192x72`), never stretching a `23px`-high crop to `72px` and thereby changing the slot raster between tiers;
- a separate blue-grey shield bar centered in the black slot below health, using its own full-width scale and no shield-number text;
- proportional actual health loss and a floating fading damage number, without changing the unit body's position, scale, or pivot for hit feedback;
- unapproved animation remaining static, and approved timing or facial-motion exceptions staying scoped to the exact asset version;
- the currently approved runtime idle whitelist containing only `SPR_014 / idle / 001`, which keeps its reviewed four-frame `4×400ms = 1600ms` exception; every newly rebuilt idle delivers sixteen reviewed `128×128` local-motion frames, freezes the face and all facial features, and waits for exact-version timing approval before runtime admission.

Do not hardcode this snapshot into runtime data. It is an execution guide for established presentation behavior and remains subordinate to newer explicit instructions and verified current files.

## Verify with real evidence

Run only checks that exist and are relevant, and retain inspectable evidence.

1. Check changed paths, resource references, manifests, parser errors, script contracts, signals, data boundaries, and relevant tests.
2. Run the actual project at the 1920×1080 baseline and inspect the real Godot entry; an editor-only preview is insufficient.
3. For every changed image, inspect source size, delivery size, actual display size, same-set side-by-side consistency, and the real interface. Check transparent edges on light, dark, and real backgrounds.
4. For characters, pets, units, or sprites in battle, inspect grid-relative scale, visual center and layering, and whether the ground shadow meets the foot contact point.
5. For sprite animation, complete all `$generate2dsprite` checks: original frames, at least 4× nearest-neighbor inspection, overview, light/dark/real-background transparency, slow and final-speed GIFs, canvas and margins, connectivity, body center and foot baseline, order and timing, disposal/clear-frame behavior, and decoded-GIF equivalence with the delivered PNGs.
6. When one item exposes a class-wide defect, define and inspect the full relevant set—such as all units, both factions, all directions, all frame tiers, or all health/shield states—instead of stopping after one example.
7. For structure-only work, perform the repository's required matched before/after operation captures and pixel comparison. For intentional visual changes, compare against the confirmed anchor or approved preview and still verify interaction and contracts.
8. Separate failures into current-task regression, pre-existing failure, stale expectation caused by an approved standard change, and missing evidence. None of these categories excuses an unverified current change.

## Deliver honestly

Report the files and responsibilities changed, whether node topology changed, the checks actually run, real Godot operation coverage, and exact evidence paths. State `BLOCKED` when a required visual, interface, data-boundary, approval, or animation check is absent or fails. Generated output, editor appearance, a passing smoke test, or Git presence alone never proves delivery acceptance.

Always label the task state precisely: `规则已确认` means only the requirement is recorded; `已实现未验收` means the scoped code or asset exists but required acceptance is incomplete; `已完成` requires the scoped implementation and required real evidence; `BLOCKED / 未修复` means the requested behavior is not delivered. Diagnosis, documentation, or identification of a missing prerequisite must never be described as a fix. Preserve the exact blocker and original requirement so later work can continue without another user report.

Before the final response, complete the mandatory conversation write-back described above. When a new project standard is confirmed, update the affected rule source, tests, and [conversation-synthesis.md](references/conversation-synthesis.md) so obsolete instructions do not remain presented as current. Preserve the historical failure lesson, but keep only one current rule.
