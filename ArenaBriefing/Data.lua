local _, AB = ...
AB.pack = { version = "0.1.2", patch = "12.1.0", review = "Skill Capped references + general rules; not endorsed" }
AB.specs = {}
local function add(class, rows)
    for _, row in ipairs(rows) do
        AB.specs[row[1]] = { id = row[1], class = class, name = row[2], role = row[3], style = row[4] }
    end
end
add("Warrior", {{71,"Arms","damage","melee"},{72,"Fury","damage","melee"},{73,"Protection","tank","melee"}})
add("Paladin", {{65,"Holy","healer","ranged"},{66,"Protection","tank","melee"},{70,"Retribution","damage","melee"}})
add("Hunter", {{253,"Beast Mastery","damage","ranged"},{254,"Marksmanship","damage","ranged"},{255,"Survival","damage","melee"}})
add("Rogue", {{259,"Assassination","damage","melee"},{260,"Outlaw","damage","melee"},{261,"Subtlety","damage","melee"}})
add("Priest", {{256,"Discipline","healer","ranged"},{257,"Holy","healer","ranged"},{258,"Shadow","damage","caster"}})
add("Death Knight", {{250,"Blood","tank","melee"},{251,"Frost","damage","melee"},{252,"Unholy","damage","melee"}})
add("Shaman", {{262,"Elemental","damage","caster"},{263,"Enhancement","damage","melee"},{264,"Restoration","healer","ranged"}})
add("Mage", {{62,"Arcane","damage","caster"},{63,"Fire","damage","caster"},{64,"Frost","damage","caster"}})
add("Warlock", {{265,"Affliction","damage","caster"},{266,"Demonology","damage","caster"},{267,"Destruction","damage","caster"}})
add("Monk", {{268,"Brewmaster","tank","melee"},{269,"Windwalker","damage","melee"},{270,"Mistweaver","healer","ranged"}})
add("Druid", {{102,"Balance","damage","caster"},{103,"Feral","damage","melee"},{104,"Guardian","tank","melee"},{105,"Restoration","healer","ranged"}})
add("Demon Hunter", {{577,"Havoc","damage","melee"},{581,"Vengeance","tank","melee"},{1480,"Devourer","damage","caster"}})
add("Evoker", {{1467,"Devastation","damage","caster"},{1468,"Preservation","healer","ranged"},{1473,"Augmentation","damage","caster"}})
function AB.SpecLabel(id)
    local s = AB.specs[id]
    return s and (AB.L(s.name) .. (AB.locale == "zhCN" and "" or " ") .. AB.L(s.class)) or AB.L("Unknown spec")
end
AB.glossary = {
    target = "Kill target: the opponent your team plans to pressure together. A suggestion, not a prediction.",
    opening = "Burst: a short period of increased damage. Agree on your opening before using major abilities.",
    cc = "Crowd control (CC) temporarily limits actions. Repeating the same CC category causes diminishing returns (shorter effects).",
    threats = "Defensives reduce danger. Avoid using every defensive at once; coordinate with your healer.",
    positioning = "Line of sight: terrain can block spells. Kiting means moving to limit an enemy's attacks while staying in healing range.",
}
AB.personal = {
    healer = {"Start where you can heal both teammates.", "Keep an escape route; avoid following a teammate into enemy crowd control."},
    melee = {"Connect with your partner before committing burst.", "Save a way back to your healer instead of spending every movement ability to chase."},
    caster = {"Find a casting angle your healer can support.", "Use control to create a damage window instead of spending all your tools while being interrupted."},
    ranged = {"Establish range while staying connected to your team.", "Keep pressure on an accessible target without dragging your healer into the open."},
    tank = {"Stay with your team and help your damage dealer connect.", "Use control to protect teammates; avoid chasing alone."},
}
AB.examples = {
    ["2v2"] = {mapID=1505,mode="2v2",size=2,playerSpec=71,friendly={71,105},enemy={259,256},complete=true},
    ["3v3"] = {mapID=617,mode="3v3",size=3,playerSpec=64,friendly={64,258,256},enemy={71,70,105},complete=true},
    shuffle = {mapID=2563,mode="Solo Shuffle",size=3,playerSpec=270,friendly={270,577,253},enemy={64,267,256},complete=true},
}
