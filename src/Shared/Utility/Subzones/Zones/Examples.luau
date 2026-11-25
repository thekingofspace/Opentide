--!strict
const Subzones = require(script.Parent.Parent)

const Zones: Subzones.Definitions = {
    Midnight = {
        Priority = 2,
        TweenTime = 3,
        Weather = false,
        Sound = "ZoneMidnight",
        Ambient = {
            Hour = 0,
        },
    },

    Shelter = {
        TweenTime = 1.5,
        Weather = false,
    },

    Storm = {
        Priority = 1,
        TweenTime = 4,
        Weather = "Rain",
        Ambient = {
            Grade = { Saturation = -0.35, Contrast = 0.05 },
        },
    },
}

return Zones
