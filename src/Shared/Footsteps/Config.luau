--!strict
export type Group = {
    Ids: { number | string },
    Materials: { string },
    Volume: number?,
    Pitch: { number }?,
}

return {
    Enabled = true,
    MuteDefault = true,
    Range = 70,
    StepLength = 3.4,
    MinSpeed = 1.5,
    Volume = 0.45,
    Pitch = { 0.92, 1.08 },
    RollOff = 45,
    Default = "Stone",
    Groups = {
        Grass = {
            Ids = { 135037154891351, 129956418693357, 110522236020035 },
            Materials = { "Grass", "LeafyGrass", "Ground", "Mud" },
            Volume = 0.5,
        },
        Stone = {
            Ids = { 87061775498714 },
            Materials = { "Concrete", "Slate", "Brick", "Cobblestone", "Pavement", "Asphalt", "Rock", "Basalt", "Limestone", "Granite", "Marble", "Pebble", "Sandstone", "SmoothPlastic", "Plastic" },
        },
        Wood = {
            Ids = { 92705710431057 },
            Materials = { "Wood", "WoodPlanks", "CardboardTexture" },
        },
        Sand = {
            Ids = { 98912102275037 },
            Materials = { "Sand", "Salt", "CrackedLava" },
        },
        Snow = {
            Ids = { 135918121539048, 108480745011651 },
            Materials = { "Snow", "Glacier", "Ice" },
        },
    } :: { [string]: Group },
}
