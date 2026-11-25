--!strict
const Subzones = require(script.Parent.Parent)

const Zones: Subzones.Definitions = {
    Cave = {
        Priority = 3,
        TweenTime = 2.5,
        Weather = false,
        Sound = "ZoneCave",
        Ambient = {
            Hour = 0,
            Lighting = {
                Brightness = 0,
                ExposureCompensation = -1.2,
                Ambient = Color3.fromRGB(10, 10, 14),
                OutdoorAmbient = Color3.fromRGB(6, 6, 10),
            },
            Atmosphere = { Density = 0.6, Haze = 3 },
            Sound = { AmbientReverb = Enum.ReverbType.Cave },
        },
    },
}

return Zones
