--!strict
export type Kind = "Translate" | "Rotate" | "Scale"

const Config = {
    MaxProps = 110,
    DefaultBuild = false,
    FreePacks = {} :: { [string]: boolean },
    StudioOwnsAll = true,

    ZoneSize = 256,
    JoinRange = 64,
    LeaveRange = 96,
    ForgetRange = 320,
    MembershipInterval = 0.5,

    MaxReach = 160,
    MinScale = 0.25,
    MaxScale = 4,
    MaxBatch = 200,
    ActionCooldown = 0.2,
    StateRate = 20,
    StateBurst = 40,

    SaveSlots = 5,
    MaxSaveName = 24,
    EditRange = 150,
    ArrivalWait = 1,

    Increments = {
        Translate = { 0, 0.5, 1, 2, 4 },
        Rotate = { 0, 15, 45, 90 },
        Scale = { 0, 0.05, 0.1, 0.25 },
    } :: { [Kind]: { number } },
}

return Config
