# Validation

## Automated checks

Run `python3 scripts/test.py` (Lua 5.1 via lupa). The suite runs under enUS, zhCN, and unsupported deDE (English fallback), with checks for translated advice, labels, glossary, formatting, and stable rule IDs. The mock suite executes all runtime files, verifies TOC load order, exercises UI construction/rendering and callbacks, and tests strategies, secret filtering, settings, lifecycle, and six simulated Shuffle rounds. Mocks do not establish actual WoW API availability, visual layout, or freedom from taint in the client.

## Skill Capped rule checks

The automated suite has 62 checks per locale. Source-specific checks cover roster-order independence, unranked candidates, Solo Shuffle and complete-roster restrictions, caster advice, patch mismatch fallback, six class reminders, spell-specific control guidance, Chinese translations, panel/chat labels and saved provenance.

Live checks still required: hover sourced rows and verify readable URLs, patch/date and the single source note below the advice; confirm individual rows have no source badges. Compare Shuffle advice across caster/melee players, and verify sourced target suggestions do not appear in 2v2/3v3. Check Chinese text and candidate lists for clipping at supported UI scales, shared messages for useful content within the byte limit, and saved source URLs after reload. Revalidate the public guides before changing the supported source patch.

## Live-client release gate — NOT YET RUN

Installed build inspected: Retail 12.1.0.69587. For each of 2v2, 3v3 and Solo Shuffle:

- Enable Lua errors (`/console scriptErrors 1`) and `/arenabrief debug`.
- Verify the detected instance ID and map name on each supported arena. Compare terrain with the real layout and check unknown-map fallback. Confirm late map data updates during preparation only, and shared advice includes the current map without truncating Chinese text.
- Confirm automatic opening during preparation, correct player spec and accurate enemy slots. Check late-arriving opponents and unavailable friendly inspections.
- For first-run teammate detection, enter with a fresh login/reload and without inspecting teammates first. Verify both teammate specs populate during preparation, including when the first teammate is temporarily out of range. Repeat with the normal addon setup (especially other inspection addons), standard inspect/talent windows open, delayed responses, a party-slot swap, and a teammate specialization change. Dismiss the briefing while requests are pending: results must update without reopening it. Confirm requests stop at combat and old results cannot fill new Shuffle teammates.
- On a Chinese client, toggle **Use English (including team messages)** in settings. Confirm the current briefing, roster/spec labels, controls and both outgoing chat destinations switch immediately; toggle off to restore Chinese. Verify persistence after reload, unchanged manual selections, no automatic chat sends, and readable checkbox layout at supported scales. Saved historical briefings must keep their original text.
- Choose missing specs in settings, confirm `[manual]` labels and tailored advice. Clear an override to return to automatic detection. Change scale and drag the panel; reload and verify persistence.
- Check all five advice rows at UI scales 0.8, 1.0 and 1.4. Scroll to the final row, test glossary tooltips, settings selectors and the close button. Test a non-English client (this installation uses Chinese assets).
- Confirm no strategy changes after the gates open. Test default hide, keep-visible and manual reopen. Ensure selectors cannot change a combat briefing.
- For all six Shuffle rounds, confirm changed teams produce a fresh briefing; previous manual selections and recommendations must not leak into the next round.
- Reload during preparation and combat. A combat reload must wait for preparation rather than reuse a previous match.
- Test both share buttons in a premade party and Shuffle. Verify the actual recipient channel, five localized advice lines, UTF-8 text, 10-second cooldown, disabled previews/combat, and no automatic sends after round changes. Check for protected-call errors on the current client.
- Leave and re-enter arenas; confirm no stale team data and no errors. Verify absent APIs/unknown specs fall back safely, never branch on secret values, and do not poll combat rosters.
- Check the client's Lua error and taint logs while also using the existing addon setup. Record exact build, mode, steps and sanitized diagnostic output.

Do not label automatic arena detection or the addon release-validated until these checks pass. Diagnostics only prove observed transitions, not correctness of strategic advice; that needs separate PvP review.

## Match history release checks — NOT YET RUN

- Capture a completed 2v2 and 3v3 match. Verify the local player's scoreboard row, team index/winner mapping, zero vs missing values, rating change, and final duration against Blizzard's UI.
- Capture six Shuffle rounds. Verify one session with six observed rounds, the correct saved roster/briefing for each, unknown round results, and whole-session personal totals only. Test delayed scoreboard updates and leaving before they arrive.
- Test manual history opening, older/newer/round navigation, automatic opening after combat ends, disabling automatic opening, and hiding for the next preparation/combat. Visually inspect scrolling and English/Chinese text.
- Reload during preparation, during combat, and after completion. Verify incomplete fragments are labeled, finished history survives reload/logout, and character histories remain separate. Test early exit without result data.
- Confirm no scoreboard reads while the match is active, no saved player names/GUIDs, no automatic sharing of history, and no Lua/secret-value errors in the current live client.

Automated tests cover these state transitions with mocks; they do not prove actual live scoreboard availability or team-index semantics.
