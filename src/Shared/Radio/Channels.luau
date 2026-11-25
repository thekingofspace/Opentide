--!strict
export type Clip = {
    Name: string,
    Id: number | string,
    Speed: number?,
    Volume: number?,
    Weight: number?,
}

export type Channel = {
    Id: string,
    Name: string,
    Description: string?,
    Order: number?,
    Volume: number?,
    Shuffle: boolean?,
    TuneIn: boolean?,
    Tracks: { Clip },
    Breaks: { Clip }?,
    BreakChance: number?,
    Chatter: { Clip }?,
    ChatterEvery: { number }?,
    Duck: number?,
}

const Channels: { Channel } = {
    {
        Id = "Chill",
        Name = "chill fm",
        Description = "slow songs and smooth jazz",
        Order = 1,
        Volume = 0.8,
        Tracks = {
            { Name = "poolside", Id = 9046863253, Speed = 1 },
            { Name = "chill jazz", Id = 1845341094, Speed = 1 },
        },
        Breaks = {
            { Name = "station jingle", Id = 1839086768, Weight = 4 },
            { Name = "afternoon news", Id = 1835999258, Weight = 1 },
        },
        BreakChance = 0.5,
    },
    {
        Id = "Rock",
        Name = "rock 101",
        Description = "loud guitars all day",
        Order = 2,
        Volume = 0.7,
        Tracks = {
            { Name = "chaos", Id = 1843497734, Speed = 1 },
            { Name = "angry guitar riff", Id = 1836019934, Speed = 1 },
            { Name = "full force", Id = 1842801942, Speed = 1 },
        },
        Breaks = {
            { Name = "station jingle", Id = 1839086768, Weight = 1 },
        },
        BreakChance = 0.3,
        Chatter = {
            { Name = "radio chatter", Id = 9112851363, Volume = 0.6, Weight = 5 },
            { Name = "police line", Id = 9125774208, Volume = 0.5, Weight = 1 },
        },
        ChatterEvery = { 45, 120 },
        Duck = 0.35,
    },
    {
        Id = "Scanner",
        Name = "police scanner",
        Description = "you should not be listening to this",
        Order = 3,
        Volume = 0.9,
        Tracks = {
            { Name = "light chatter", Id = 9112851363, Speed = 1 },
            { Name = "line feed", Id = 9125774208, Speed = 1 },
        },
    },
}

return Channels
