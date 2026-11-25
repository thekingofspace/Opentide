--!strict
export type Kind = "Toggle" | "Number"
export type Value = boolean | number

export type Setting = {
    Id: string,
    Name: string,
    Kind: Kind,
    Default: Value,
    Min: number?,
    Max: number?,
    Step: number?,
}

const SettingsList: { Setting } = {
    { Id = "MetaRange", Name = "meta vision range", Kind = "Number", Default = 120, Min = 20, Max = 400, Step = 20 },
    { Id = "VFX", Name = "vfx", Kind = "Toggle", Default = true },
    { Id = "DayNight", Name = "realistic day / night", Kind = "Toggle", Default = true },
    { Id = "Weather", Name = "weather", Kind = "Toggle", Default = true },
    { Id = "NoHeadTurn", Name = "disable head turning", Kind = "Toggle", Default = false },
}

return SettingsList
