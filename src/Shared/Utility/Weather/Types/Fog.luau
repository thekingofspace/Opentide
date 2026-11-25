--!strict
const Weather = require(script.Parent.Parent)

const Types: Weather.Definitions = {
    Fog = {
        Name = "Fog",
        Rarity = 0.15,
        Sound = "WeatherFog",
        FadeIn = 40,
        FadeOut = 60,
        Clouds = { Cover = 0.7, Density = 0.45, Color = Color3.fromRGB(215, 218, 222) },
        Atmosphere = { Density = 0.74, Haze = 6, Tint = Color3.fromRGB(200, 205, 210), TintAmount = 0.85 },
        Grade = { Saturation = -0.2, Contrast = -0.05 },
    },
}

return Types
