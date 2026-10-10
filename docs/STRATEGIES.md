# Strategy data and provider contract

## Content status

Pack 0.1.2 targets 12.1.0. It combines limited Skill Capped-informed summaries with original general rules; neither the addon nor its rules have been reviewed or endorsed by Skill Capped. All 40 cataloged specializations receive role/style fallbacks, not 40 bespoke expert guides.

`Knowledge.lua` records two public sources, their URLs, publication dates, patch and check date. Solo Shuffle target rules require a fully known enemy roster and a damage-role player. Candidates are unranked and sorted by spec ID solely for stable display; casters receive positioning-based advice. No rule selects a target merely because it occupies the first enemy slot. Other modes retain general target advice.

Initial class-counter coverage includes Warrior, Mage, Druid, Warlock, Rogue and Monk; at most two class reminders are shown. Conditional spell prompts cover Cyclone and Affliction/Destruction cast control. Demonology does not receive the Affliction/Destruction interrupt prompt. No rule asserts that a spell was cast or that its cooldown is available. Higher-priority composition rules can override sourced advice.

A detected client version outside 12.1.x disables sourced rules. Unknown builds and previews use the bundled content. Map profiles, opening plans, other composition rules and post-match reflection prompts remain original general advice. Partial enemy rosters never trigger whole-composition claims.

## Sources and review provenance

Tactical references checked 2026-10-03 (public pages label patch 12.1):

- Skill Capped, Best Targets — Solo Shuffle Guide: https://www.skill-capped.com/wowarticles/general/best-targets/
- Skill Capped, How to Counter Every Class in WoW PvP: https://www.skill-capped.com/wowarticles/general/class-ability-counters/

These support the limited `sc.*` rules, not every recommendation or map profile. Full guides and paid content are not bundled. There is no runtime network connection, authenticated API, automatic refresh or publisher endorsement.

API and identifier references:

- Blizzard's addon design policy: https://worldofwarcraft.blizzard.com/en-gb/news/24246290
- Blizzard PvP API documentation mirrored from client source: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/PvpInfoDocumentation.lua
- Blizzard specialization API documentation mirrored from client source: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua
- Local installed Retail build metadata: 12.1.0.69587; specialization IDs cross-checked against installed addon specialization tables, including Devourer 1480.

The API and identifier references establish API/design context and identifiers, **not tactical authority**. Before promoting a draft to reviewed content, a PvP reviewer must record the reviewer, date, build, affected rule IDs, evidence/source, and example matchups in this file; then update `AB.pack.review`. No such expert review has occurred yet.

## Interface

`AB.RegisterProvider(name, function(context) ... end)` registers a pure strategy provider; `AB.Evaluate(context, name)` defaults/falls back to `bundled`. Providers cannot call WoW APIs. The core selects only bundled in v1.

Context: `{mode, size, playerSpec, friendly, enemy, complete, sources, mapID, mapName, clientVersion}`. Team arrays contain exactly `size` entries (2 or 3), use spec IDs, and use 0 for unknown. Friendly slot 1 is the player. Sources are parallel arrays of `detected`, `manual`, `unknown`, or `example`. Contexts contain no identities.

Result: `{provider, packVersion, patch, review, complete, recommendations, matchedRuleIDs}`. Exactly five recommendations in order: target, opening, cc, threats, positioning. Each has `{category, title, text, why, ruleID, priority, sourceID?, source?}`. Category selection takes the greatest priority; ties retain the first rule. This prevents contradictory statements competing for the same category. Rule IDs in `Strategy.lua` and `Knowledge.lua` identify their behavior and tests. Sourced entries carry publisher-independent source metadata; the UI, chat labels and saved briefings preserve provenance.

A future AI companion must separately define a supported import/export mechanism, validation and trust boundaries. Registration alone does not enable network access from Lua, live requests, or hot file loading. V1 contains no network or credential code.

## Map profiles

`mapID` is the instance ID (return 8 from GetInstanceInfo), not a UI map ID. `mapName` is an optional non-secret client string for unknown-map display. Both are part of the refresh signature. Result `mapID` and `mapLabel` expose map context to consumers. Known terrain adds a priority-50 positioning rule; its explanation retains the previous composition text. Map rule IDs encode the instance and tactical variant. Incomplete rosters never trigger enemy archetype variants; role-specific or general terrain advice remains available.

Identifiers were checked against the installed DBM-Test client-data catalog (`Tools/Shared/Data/Instances.lua`): Retail Nagrand is 1505, Blade's Edge 1672. Old IDs 559 and 562 are deliberately not used as Retail aliases. No active map rotation is inferred. Terrain profiles are conservative authored heuristics, still under the pack's draft review status. Cage of Carnage is name-only until its layout is reviewed.

Blizzard's Nokhudon layout description (ramps, pillars, central wall): https://worldofwarcraft.blizzard.com/en-gb/news/23892221/dragonflight-season-1-content-update-notes . This historical announcement supplies geometry context, not current rotation or balance advice.

## Post-match review

History schema is isolated from strategy providers: character-local records contain an ID, status, timestamp, preparation context, saved briefing and observed rounds; final personal statistics are allowlisted numbers. The recorder never persists the temporary player GUID used to query the final score row. Readable finite numbers only are accepted; zero is a valid result and unavailable fields remain absent.

Review prompts are original reflection questions, not detected mistakes or expert conclusions. A recorded death can trigger a defensive-coordination review question but never an assertion of cause. Map/role prompts use the saved preparation plan. Per-round results and Shuffle session win/loss remain unknown without supported evidence. Mid-session reloads produce explicitly incomplete fragments.

The data source is Blizzard's documented C_PvP GetScoreInfoByPlayerGuid, GetActiveMatchWinner and GetActiveMatchDuration APIs, queried only at Complete while still inside an arena. Result interpretation must be verified live before release promotion. No C_DamageMeter or combat-log parsing is included.
