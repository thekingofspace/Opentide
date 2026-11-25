--!strict
const Weather = require(script.Parent.Parent)

const Types: Weather.Definitions = {
    Clear = {
        Name = "Clear",
        Rarity = 0.65,
        Clouds = { Cover = 0.4, Density = 0.25, Color = Color3.new(1, 1, 1) },
        Atmosphere = { Density = 0.3, Haze = 0.5 },
    },
}

return Types
