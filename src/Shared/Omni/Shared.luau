--!strict
export type Range = {
    Name: string,
    Min: number,
    Max: number,
    Default: number,
    Step: number,
    Order: number,
}

const Shared = {
    AmbientAttribute = "OmniAmbient",
    PinAttribute = "OmniPinned",
    Ambient = {
        Brightness = { Name = "brightness", Min = 0, Max = 8, Default = 2, Step = 0.5, Order = 1 },
        Exposure = { Name = "exposure", Min = -3, Max = 3, Default = 0, Step = 0.25, Order = 2 },
        Density = { Name = "fog", Min = 0, Max = 1, Default = 0.3, Step = 0.05, Order = 3 },
        Haze = { Name = "haze", Min = 0, Max = 10, Default = 0, Step = 0.5, Order = 4 },
        Saturation = { Name = "color", Min = -1, Max = 1, Default = 0, Step = 0.1, Order = 5 },
        Contrast = { Name = "contrast", Min = -1, Max = 1, Default = 0, Step = 0.1, Order = 6 },
    } :: { [string]: Range },
    Tints = {
        { Id = "White", Name = "none", Color = { 255, 255, 255 } },
        { Id = "Warm", Name = "warm", Color = { 255, 228, 190 } },
        { Id = "Cool", Name = "cool", Color = { 200, 220, 255 } },
        { Id = "Red", Name = "red", Color = { 255, 140, 130 } },
        { Id = "Green", Name = "green", Color = { 190, 255, 190 } },
        { Id = "Purple", Name = "purple", Color = { 230, 200, 255 } },
    },
    Presets = {
        { Id = "Gloomy", Name = "gloomy", Values = { Brightness = 1, Exposure = -0.5, Density = 0.45, Haze = 2, Saturation = -0.5, Contrast = 0.1 }, Tint = "Cool" },
        { Id = "Golden", Name = "golden hour", Values = { Brightness = 3, Exposure = 0.25, Density = 0.25, Haze = 1, Saturation = 0.3, Contrast = 0.1 }, Tint = "Warm" },
        { Id = "BloodMoon", Name = "blood moon", Values = { Brightness = 1, Exposure = -0.25, Density = 0.4, Haze = 2, Saturation = -0.2, Contrast = 0.2 }, Tint = "Red" },
        { Id = "Dreamy", Name = "dreamy", Values = { Brightness = 2.5, Exposure = 0.5, Density = 0.35, Haze = 3, Saturation = 0.3, Contrast = -0.2 }, Tint = "Purple" },
    },
}

function Shared.sortedAmbient(): { string }
    const Keys: { string } = {}
    for Key in Shared.Ambient do
        table.insert(Keys, Key)
    end
    table.sort(Keys, function(A: string, B: string): boolean
        return Shared.Ambient[A].Order < Shared.Ambient[B].Order
    end)
    return Keys
end

function Shared.look(Values: { [string]: any }): { [string]: any }
    const Lighting: { [string]: any } = {}
    const Atmosphere: { [string]: any } = {}
    const Grade: { [string]: any } = {}
    if type(Values.Brightness) == "number" then
        Lighting.Brightness = Values.Brightness
    end
    if type(Values.Exposure) == "number" then
        Lighting.ExposureCompensation = Values.Exposure
    end
    if type(Values.Density) == "number" then
        Atmosphere.Density = Values.Density
    end
    if type(Values.Haze) == "number" then
        Atmosphere.Haze = Values.Haze
    end
    if type(Values.Saturation) == "number" then
        Grade.Saturation = Values.Saturation
    end
    if type(Values.Contrast) == "number" then
        Grade.Contrast = Values.Contrast
    end
    const Tint = Values.Tint
    if type(Tint) == "table" and #Tint == 3 then
        Grade.TintColor = Color3.fromRGB(Tint[1], Tint[2], Tint[3])
    end
    return { Lighting = Lighting, Atmosphere = Atmosphere, Grade = Grade }
end

return Shared
