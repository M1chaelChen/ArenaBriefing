# Expert-source integration audit

Checked: 2026-10-03. This is a public documentation and license audit, not an authenticated API integration test. No provider was contacted, no paid content was accessed, and no content feed was installed.

## Current addon

Core.lua calls AB.Evaluate(ctx); Strategy.lua registers only the bundled provider. As of 0.1.0, Knowledge.lua bundles limited original summaries informed by two public Skill Capped articles, with source URLs and a 12.1 patch guard. There is no remote API integration with Skill Capped, Icy Veins, Murlok, or WoW Arena Logs. No documented supported strategy API was located for these sources in this audit. This is a search finding, not proof that private/partner APIs do not exist.

## Findings

- **Skill Capped:** Public tactical articles are accessible. No public developer documentation or grant to redistribute a strategy feed was verified. Attempted public terms URLs were unavailable, so reuse rights remain unresolved. Used as a research reference for the limited curated rules documented in STRATEGIES.md; this does not establish a license to redistribute a copied feed.
  - https://www.skill-capped.com/wowarticles/
- **Icy Veins:** FAQ explicitly allows copying guides on noncommercial websites with attribution and a visible source link, and authorizes website translations with attribution/link requirements. It does not explicitly cover distributing guides or translated content inside an addon. Public terms do not establish a guide API contract. Confirm addon distribution with the publisher; do not equate the website allowance with an addon license.
  - https://www.icy-veins.com/faq
  - https://www.icy-veins.com/terms
- **Murlok:** Official pages describe top-player build aggregation from Blizzard data; that is not matchup coaching. No supported public developer API contract or redistribution grant was verified. A third-party addon's claim to use JSON endpoints does not establish Murlok's permission, support, or stability. Do not treat undocumented endpoints as a supported integration.
  - https://murlok.io/
  - https://murlok.io/privacy-policy
- **WoW Arena Logs:** Public repository LICENSE says CC BY-NC-ND 4.0. This is not a permissive software license. Its attribution, noncommercial and no-derivatives conditions limit reuse; distribution of adapted code requires separate permission. That code license does not independently grant access to hosted match data or a service API. The repository was checked through both its raw LICENSE and GitHub's license endpoint (GitHub reports NOASSERTION; the file itself names the license).
  - https://github.com/wowarenalogs/wowarenalogs/blob/main/LICENSE
  - https://creativecommons.org/licenses/by-nc-nd/4.0/

## Integration decision

No third-party automated strategy feed is verified for immediate incorporation. Icy Veins is a promising licensing enquiry because it publishes explicit reuse guidance; Skill Capped now supplies the public research references for the limited curated rules. For a deployable data pack, use independently authored, expert-reviewed rules with provenance, or secure written rights covering extraction, adaptation, Simplified Chinese translation, addon distribution, commercial scope, and updates. Obtain a documented export/API and validate a sample payload before claiming a working integration.

For post-fight analysis, independently parse user-provided combat logs rather than assume we may adapt WoW Arena Logs' code or ingest its hosted dataset. This remains separate from acquiring expert tactical content.
