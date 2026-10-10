# Arena Briefing

A standalone Retail WoW addon that shows a short arena strategy before the gates open. Supports 2v2, 3v3, and per-round Solo Shuffle preparation. English and Simplified Chinese UI and advice, all 40 currently cataloged specs, no account or external service required.

**Status: 0.1.2 alpha. Automated tests are separate from in-game validation. Automatic detection, all three arena modes, UI layout, and taint behavior still require live-client testing. Strategy content combines Skill Capped-informed rules with general advice; this addon has not been reviewed or endorsed by Skill Capped.**

## Install

1. Copy the `ArenaBriefing` folder into `World of Warcraft/_retail_/Interface/AddOns/`, or extract the release ZIP there. The final path must be `AddOns/ArenaBriefing/ArenaBriefing.toc`.
2. Restart the client if installing while WoW is running, then enable Arena Briefing in the character-selection AddOns list.
3. Run `/arenabrief preview` to check the panel. `/arenabrief settings` opens scaling, position reset, visibility, and team selectors.

The manifest targets interface **120100**, based on the locally installed Retail 12.1.0 client. Check the installed build when updating it; changing the number does not prove compatibility.

## 简体中文支持

客户端语言为简体中文（`zhCN`）时，插件会自动显示中文界面、战术建议、术语说明及职业/专精名称，无需额外设置。其他客户端语言目前使用英文。

将 `ArenaBriefing` 文件夹放入 `_retail_/Interface/AddOns/`，启用插件后输入 `/arenabrief preview` 预览，或输入 `/arenabrief settings` 打开设置。命令仍使用英文；设置中的职业和专精菜单已翻译。升级时覆盖同名插件文件夹即可，已有设置保留。

策略结合 Skill Capped 公开指南的简短总结和通用建议，尚未经 Skill Capped 审核或认可；中文字体与实际游戏内布局仍需在客户端验证。

## Use

In **Settings / teams** (`/arenabrief settings`), enable **Use English (including team messages)** to switch the current briefing, labels, and both **Send to party** and **Send to instance** messages to English immediately. The preference is saved across reloads. Turn it off to follow your client language again. Change this setting outside combat; switching language does not send messages automatically. Historical briefings retain their original saved language.

**中文：** 在“设置 / 队伍”中勾选“使用英文（包括发送到队伍的消息）”，当前简报、界面以及发送到小队或副本的消息会立即改为英文，重载后仍保留。取消勾选后恢复客户端语言。请在战斗外切换；切换语言不会自动发送消息。历史简报保留记录时的语言。

During arena preparation, the panel shows both teams and five recommendations. Unknown slots are explicit. Open **Settings / teams** to supply unavailable specs; the selector lists classes and specializations. Friendly slot 1 is you, slots 2–3 are party1–2; enemy slots correspond to arena1–3. Manual choices last only for the current preparation/round and are marked `[manual]`.

Teammate detection now requests inspections during preparation instead of relying on an already populated inspect cache. Requests run one at a time, at least two seconds apart, and unanswered requests time out after five seconds so the other teammate can be checked. The existing panel updates as results arrive. Results are held in memory by player identity for the current preparation and reset between rounds; identities are never saved or logged. Out-of-range or unavailable specs remain unknown and can still be selected manually. Automatic requests pause while the standard inspection or inspected-talents window is open.

**中文：** 首次使用时，准备阶段会依次请求队友信息，收到后自动更新简报。暂时无法获取的专精仍显示“未知专精”，可在设置中手动选择。

The panel updates during preparation and freezes when combat starts. It hides by default; enable **Keep briefing visible during combat** to retain it, or reopen with `/arenabrief`. There are no live cooldown decisions, automatic targeting, casts, or chat messages. Hover over a recommendation for terminology help.

| Command | Behavior |
| --- | --- |
| `/arenabrief` or `show` | Reopen the last available briefing |
| `/arenabrief hide` | Hide the panel |
| `/arenabrief settings` | Settings and manual team selection |
| `/arenabrief preview 2v2` | Sample two-player matchup outside arenas |
| `/arenabrief preview 3v3` | Sample three-player matchup |
| `/arenabrief preview shuffle` | Sample Shuffle matchup |
| `/arenabrief set enemy 1 64` | Manually choose Frost Mage for enemy 1 |
| `/arenabrief set enemy 1 auto` | Remove that manual override |
| `/arenabrief debug` | Toggle opt-in diagnostics |
| `/arenabrief diagnostics` | Print the capped diagnostic log locally |

Diagnostics record phase changes and spec IDs/sources, never character names, GUIDs, combat logs, or messages to other players. They persist in `ArenaBriefingDB` (at most 80 entries). Delete that addon's saved variables to reset all settings/logs.

## Match history and post-match review

Click **History / 历史记录** on the briefing panel, or run `/arenabrief history` (alias `/arenabrief review`). Use **Newer**, **Older**, and **Next round** to browse. The review opens automatically when a recorded session ends; disable **Auto-open** in that panel to keep it manual. It closes when the next round or combat starts.

History stores the latest **100 sessions per character**, with the preparation composition and map, original briefing, observed round durations, and accessible final personal scoreboard values: damage, healing, deaths, killing blows, rating and rating change. The panel displays rating change alongside the other performance totals. Missing or restricted values remain **Unavailable**, never fabricated zeros. Ordinary arena wins/losses require both a readable final player team index and a readable winning team index; otherwise the result is **Unknown**.

Solo Shuffle stays one session with separate observed-round contexts. Personal scoreboard numbers are labeled **whole-session totals** and never copied into individual rounds. Per-round outcomes and an overall Shuffle win/loss are left unknown. Final scoreboard data is retried for up to 30 seconds while still in the completed arena, so leaving immediately can prevent collection.

The review offers reflection prompts based on the saved plan and available facts. It does not claim to detect bad positioning, missed interrupts, overlapping defensives, or causes of death. No combat-event timeline is captured. Previews do not create history.

Leaving early marks the session incomplete. Reloading during an unfinished match retains the previous fragment as incomplete; subsequent observed combat becomes a new partial record, with missing preparation context explicitly labeled. These fragments are not merged or presented as full matches. Observed durations can be unavailable or approximate; they are distinct from the client's final session duration.

History lives in the character-specific `ArenaBriefingHistoryDB` SavedVariables. WoW writes SavedVariables to disk on UI reload/logout, so an abrupt client crash can lose unsaved history. No player names, GUIDs, opponent score rows, combat logs, or review text are uploaded or sent to team chat. Delete the character's ArenaBriefing SavedVariables while WoW is closed to reset history; account-wide settings live separately.

**中文：** 点击“历史记录”或输入 `/arenabrief history` 查看复盘。每个角色最多保存 100 场记录；单排轮斗按整场保存，逐轮保留阵容和原始简报。整场统计不会被当作单轮数据。缺失信息显示“不可用”，复盘问题不代表插件检测到了失误。可在复盘面板关闭“自动打开”。

## Skill Capped knowledge base

Version 0.1.2 bundles short, independently worded summaries informed by two public Skill Capped guides, checked on **2026-10-03** for **12.1**:

- [Best Targets — Solo Shuffle Guide](https://www.skill-capped.com/wowarticles/general/best-targets/): unranked target candidates for melee/ranged physical damage players, and positioning-based target selection for casters. These rules require Solo Shuffle and a fully known enemy roster. Candidate order is not a kill-priority ranking.
- [How to Counter Every Class in WoW PvP](https://www.skill-capped.com/wowarticles/general/class-ability-counters/): initial counter reminders for Warrior, Mage, Druid, Warlock, Rogue and Monk, plus conditional control/interrupt prompts for Cyclone, Unstable Affliction and Chaos Bolt.

The panel and shared briefing end with one source note: “Skill Capped references + general rules; not endorsed.” Individual recommendations have no source badges. Hover over a recommendation to see its source URL, patch and check date. History retains source details with the original briefing. Map advice and uncovered matchups use general rules. All new advice and labels support Simplified Chinese.

This is a limited curated knowledge base, not the complete Skill Capped library, a live feed, or an endorsed integration. Source updates require an addon update. A detected client version outside 12.1.x disables these sourced rules and displays a general-rules fallback notice. Previews and contexts without a detectable build use the bundled 12.1 content. The patch check is a compatibility guard, not proof of tactical accuracy.

**中文：** 简报底部统一说明参考 Skill Capped 与通用规则，不再逐条显示来源标签；鼠标悬停可查看来源、版本及核查日期，历史记录也保留来源。单排轮斗目标候选不代表击杀优先级，地图及未覆盖阵容仍使用通用规则。本插件未获 Skill Capped 官方审核或认可，资料随插件更新，不会在线自动同步。

## Arena maps

The briefing now combines the arena layout with team composition and your role. It detects the instance ID during preparation, displays the map above the rosters, and updates if map information arrives late. Positioning changes for pillars, bridges, tomb cover, crates, elevation changes and the Nokhudon middle wall. Against double melee it also suggests spreading; against double casters it emphasizes breaking simultaneous casts; healerless teams get a coordinated retreat reminder. The previous composition advice remains in the explanation.

There are terrain profiles for 15 arenas: Nagrand, Blade's Edge, Ruins of Lordaeron, Dalaran Sewers, Tol'Viron, Tiger's Peak, Black Rook Hold, Ashamane's Fall, Hook Point, Mugambala, Robodrome, Empyrean Domain, Maldraxxus Coliseum, Enigma Crucible and Nokhudon. Cage of Carnage is recognized but uses general terrain advice pending a profile. Unknown maps also keep the composition guidance, explicitly labeled as general terrain advice. This catalog does not assert current queue availability.

Use `/arenabrief preview 3v3 1505` for Nagrand and `/arenabrief preview 3v3 1672` for Blade's Edge to compare the same matchup. Other preview instance IDs are listed in `Maps.lua`. Default previews use Nagrand (2v2), Dalaran Sewers (3v3), and Nokhudon (Shuffle). Map advice and names support Simplified Chinese. Shared briefings include the arena name on the first line and terrain advice on the positioning line.

**中文：** 简报会结合地图地形、敌我阵容和你的职责给出站位建议。输入 `/arenabrief preview 3v3 1505` 和 `/arenabrief preview 3v3 1672`，可对比同一阵容在纳格兰与刀锋山的建议。

## Share with teammates

Click **Send to party** for your home party (`PARTY`), or **Send to instance** for the current instance group (`INSTANCE_CHAT`, including Shuffle when available). Each button is enabled only when that channel is available during live arena preparation. Hover for an explanation when disabled.

Sharing sends the five advice lines followed by a source note from the displayed briefing, without the longer explanations. Partial rosters are labeled. English or Simplified Chinese follows your client language. Messages are limited to 255 bytes without splitting Chinese characters. A shared 10-second cooldown prevents repeated clicks from flooding chat. Previews, combat, and expired briefings cannot be sent; nothing is sent automatically or queued for later. A successful API call does not guarantee server delivery.

**中文：** 点击“发送到小队”或“发送到副本”，即可在准备阶段向对应频道发送当前五条建议。预览不会发送，连续发送需间隔 10 秒。

## Detection limitations

The adapter reads public preparation information, rejects secret values before comparisons, and falls back to manual selection. If the opponent count describes a larger lobby rather than two or three enemies, it refuses to treat the first slots as the enemy team. It does not inspect hidden enemy talents or infer them from combat. Teammate inspection requests run during preparation, but responses are best-effort and do not require teammates to run the addon. Missing teammate specs can be entered manually.

Match state is event-driven with a half-second state check to catch missed transitions. Roster reads and strategy evaluation happen only during known preparation states outside combat. If preparation state itself is unavailable, automatic briefings remain inactive. After a mid-combat reload, the addon waits for the next preparation period rather than reconstructing a combat strategy. Shuffle mode naming uses a capability-checked API when available; the 3v3 label is a fallback, and round handling uses match-state transitions regardless of label.

## Versioning

Version numbering restarts at **0.1.0** with all existing features retained. For subsequent releases, increment only the patch number (0.1.1, 0.1.2, …) unless the user explicitly requests a minor-version bump. Keep the addon manifest, strategy pack, package filename and current documentation versions aligned.

## Develop

No runtime addon libraries are required. Tests use Lua 5.1 through Python's `lupa` package:

```sh
python3 -m pip install lupa
python3 scripts/test.py
python3 scripts/package.py
```

If lupa is installed in a separate directory, supply `PYTHONPATH=/path/to/deps`. The ZIP contains only the addon manifest, runtime sources, README and LICENSE. See `docs/VALIDATION.md` for the mandatory live-client acceptance checklist and `docs/STRATEGIES.md` for strategy provenance and the future provider contract.

## License

Arena Briefing is licensed under the [MIT License](LICENSE). Referenced third-party articles and trademarks remain subject to their respective owners' rights.
