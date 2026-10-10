local _, AB = ...
-- Instance IDs (GetInstanceInfo return 8), NOT UI map IDs.
AB.maps = {
    [1505]={name="Nagrand Arena",terrain="pillars"},
    [1672]={name="Blade's Edge Arena",terrain="bridge"},
    [572]={name="Ruins of Lordaeron",terrain="tomb"},
    [617]={name="Dalaran Sewers",terrain="sewers"},
    [980]={name="Tol'Viron Arena",terrain="pillars"},
    [1134]={name="The Tiger's Peak",terrain="pillars"},
    [1504]={name="Black Rook Hold Arena",terrain="cover"},
    [1552]={name="Ashamane's Fall",terrain="pillars"},
    [1825]={name="Hook Point",terrain="cover"},
    [1911]={name="Mugambala",terrain="levels"},
    [2167]={name="The Robodrome",terrain="pillars"},
    [2373]={name="Empyrean Domain",terrain="pillars"},
    [2509]={name="Maldraxxus Coliseum",terrain="pillars"},
    [2547]={name="Enigma Crucible",terrain="pillars"},
    [2563]={name="Nokhudon Proving Grounds",terrain="wall"},
    -- Recognized but no reviewed terrain profile: use composition-only guidance.
    [2759]={name="Cage of Carnage"},
}
AB.terrain = {
    pillars="Choose a pillar as your team's retreat point; cross open ground together.",
    bridge="Agree on a bridge or lower-level fight; don't chase off the bridge alone.",
    tomb="Use the central tomb for cover without circling out of your team's sight.",
    sewers="Stay within reach after leaving the starting ledge; use the crates for cover.",
    cover="Choose nearby cover together before pushing; keep a clear route back.",
    levels="Move between upper and lower levels together; don't strand a teammate upstairs.",
    wall="Use the middle wall for cover; agree on a ramp before changing levels.",
}
function AB.MapLabel(ctx)
    local map=AB.maps[ctx.mapID]
    if map then return AB.L(map.name) end
    return ctx.mapName or AB.L("Unknown arena")
end
function AB.MapPosition(ctx, facts)
    local map=AB.maps[ctx.mapID]
    if not map or not map.terrain then return nil end
    local variant, extra="general","Keep your partner in sight."
    if facts.healerless then variant="healerless"; extra="Retreat together to recover without a healer."
    elseif facts.enemyKnown and facts.melee>=2 then variant="melee"; extra="Spread enough to limit double-melee pressure."
    elseif facts.enemyKnown and facts.caster>=2 then variant="casters"; extra="Use cover to break simultaneous enemy casts."
    elseif facts.own and facts.own.role=="healer" then variant="healer"; extra="Keep both teammates in healing sight."
    elseif facts.own and facts.own.style=="melee" then variant="melee-player"; extra="Do not chase beyond your team's support."
    end
    return AB.L(AB.terrain[map.terrain]).." "..AB.L(extra), "map."..ctx.mapID.."."..variant
end
