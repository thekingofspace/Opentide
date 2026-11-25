--!strict
const Lighting = game:GetService("Lighting")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const Sky = require(script.Parent.Sky)
const AmbientOverride = require(script.Parent.AmbientOverride)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

type Key = {
    Hour: number,
    Ambient: Color3,
    Outdoor: Color3,
    Top: Color3,
    Bottom: Color3,
    Brightness: number,
    Exposure: number,
    Air: Color3,
    Decay: Color3,
    Density: number,
    Haze: number,
    Dark: number,
}

type Saved = {
    ClockTime: number,
    Ambient: Color3,
    Outdoor: Color3,
    Top: Color3,
    Bottom: Color3,
    Brightness: number,
    Exposure: number,
    Air: Color3?,
    Decay: Color3?,
    Density: number?,
    Haze: number?,
}

const DayNight = {
    DayLength = 1200,
    StartHour = 8,
    Interval = 0.1,
    EpochAttribute = "DayEpoch",
    FrozenAttribute = "DayFrozen",
}

const function rgb(R: number, G: number, B: number): Color3
    return Color3.fromRGB(R, G, B)
end

type Look = {
    Ambient: Color3,
    Outdoor: Color3,
    Top: Color3,
    Bottom: Color3,
    Brightness: number,
    Exposure: number,
    Air: Color3,
    Decay: Color3,
    Density: number,
    Haze: number,
    Dark: number,
}

const function key(Hour: number, Given: Look): Key
    return {
        Hour = Hour,
        Ambient = Given.Ambient,
        Outdoor = Given.Outdoor,
        Top = Given.Top,
        Bottom = Given.Bottom,
        Brightness = Given.Brightness,
        Exposure = Given.Exposure,
        Air = Given.Air,
        Decay = Given.Decay,
        Density = Given.Density,
        Haze = Given.Haze,
        Dark = Given.Dark,
    }
end

const Night: Look = {
    Ambient = rgb(3, 3, 6),
    Outdoor = rgb(4, 5, 9),
    Top = rgb(8, 10, 18),
    Bottom = rgb(0, 0, 0),
    Brightness = 0.05,
    Exposure = -1.4,
    Air = rgb(0, 0, 0),
    Decay = rgb(0, 0, 0),
    Density = 0.62,
    Haze = 6,
    Dark = 1,
}

const Late: Look = {
    Ambient = rgb(10, 10, 16),
    Outdoor = rgb(14, 14, 22),
    Top = rgb(30, 30, 50),
    Bottom = rgb(0, 0, 0),
    Brightness = 0.25,
    Exposure = -0.9,
    Air = rgb(10, 10, 14),
    Decay = rgb(5, 5, 8),
    Density = 0.55,
    Haze = 5,
    Dark = 0.85,
}

const Golden: Look = {
    Ambient = rgb(60, 48, 52),
    Outdoor = rgb(120, 90, 85),
    Top = rgb(255, 150, 100),
    Bottom = rgb(40, 20, 10),
    Brightness = 1,
    Exposure = -0.3,
    Air = rgb(200, 140, 120),
    Decay = rgb(120, 70, 60),
    Density = 0.42,
    Haze = 2.5,
    Dark = 0.35,
}

const Morning: Look = {
    Ambient = rgb(110, 105, 105),
    Outdoor = rgb(170, 160, 150),
    Top = rgb(255, 220, 190),
    Bottom = rgb(0, 0, 0),
    Brightness = 2.2,
    Exposure = 0,
    Air = rgb(215, 215, 220),
    Decay = rgb(120, 120, 130),
    Density = 0.3,
    Haze = 0.8,
    Dark = 0,
}

const Noon: Look = {
    Ambient = rgb(120, 120, 125),
    Outdoor = rgb(165, 165, 170),
    Top = rgb(255, 252, 245),
    Bottom = rgb(0, 0, 0),
    Brightness = 3,
    Exposure = 0,
    Air = rgb(199, 215, 235),
    Decay = rgb(106, 112, 125),
    Density = 0.28,
    Haze = 0.4,
    Dark = 0,
}

const Afternoon: Look = {
    Ambient = rgb(118, 112, 108),
    Outdoor = rgb(165, 155, 145),
    Top = rgb(255, 230, 200),
    Bottom = rgb(0, 0, 0),
    Brightness = 2.6,
    Exposure = 0,
    Air = rgb(210, 210, 215),
    Decay = rgb(120, 115, 115),
    Density = 0.3,
    Haze = 0.8,
    Dark = 0,
}

const Keys: { Key } = {
    key(0, Night),
    key(4.5, Night),
    key(6, Golden),
    key(7.5, Morning),
    key(12, Noon),
    key(16.5, Afternoon),
    key(18.25, Golden),
    key(19.5, Late),
    key(21, Night),
    key(24, Night),
}

local Enabled = false
local Saved: Saved? = nil
local Air: Atmosphere? = nil
local Link: RBXScriptConnection? = nil
local Waited = 0
local DaySound: Sound? = nil
local NightSound: Sound? = nil

function DayNight.hour(): number
    const Frozen = Workspace:GetAttribute(DayNight.FrozenAttribute)
    if type(Frozen) == "number" then
        return Frozen % 24
    end
    const Epoch = Workspace:GetAttribute(DayNight.EpochAttribute)
    const Since = Workspace:GetServerTimeNow() - (if type(Epoch) == "number" then Epoch else 0)
    return (Since / DayNight.DayLength * 24 + DayNight.StartHour) % 24
end

const function sample(Hour: number): Key
    for Index = 1, #Keys - 1 do
        const From = Keys[Index]
        const To = Keys[Index + 1]
        if Hour >= From.Hour and Hour <= To.Hour then
            const Alpha = if To.Hour > From.Hour then (Hour - From.Hour) / (To.Hour - From.Hour) else 0
            return key(Hour, {
                Ambient = From.Ambient:Lerp(To.Ambient, Alpha),
                Outdoor = From.Outdoor:Lerp(To.Outdoor, Alpha),
                Top = From.Top:Lerp(To.Top, Alpha),
                Bottom = From.Bottom:Lerp(To.Bottom, Alpha),
                Brightness = From.Brightness + (To.Brightness - From.Brightness) * Alpha,
                Exposure = From.Exposure + (To.Exposure - From.Exposure) * Alpha,
                Air = From.Air:Lerp(To.Air, Alpha),
                Decay = From.Decay:Lerp(To.Decay, Alpha),
                Density = From.Density + (To.Density - From.Density) * Alpha,
                Haze = From.Haze + (To.Haze - From.Haze) * Alpha,
                Dark = From.Dark + (To.Dark - From.Dark) * Alpha,
            })
        end
    end
    return Keys[1]
end

const function apply()
    const Natural = DayNight.hour()
    const Now = sample(AmbientOverride.hour(Natural))
    const write = AmbientOverride.write
    write(Lighting, "ClockTime", Natural)
    write(Lighting, "Ambient", Now.Ambient)
    write(Lighting, "OutdoorAmbient", Now.Outdoor)
    write(Lighting, "ColorShift_Top", Now.Top)
    write(Lighting, "ColorShift_Bottom", Now.Bottom)
    write(Lighting, "Brightness", Now.Brightness)
    write(Lighting, "ExposureCompensation", Now.Exposure)
    Sky.Darkness = Now.Dark
    const Day = DaySound
    if Day then
        Day.Volume = Sounds.volume("AmbienceDay") * (1 - Now.Dark)
    end
    const Night = NightSound
    if Night then
        Night.Volume = Sounds.volume("AmbienceNight") * Now.Dark
    end
    Sky.DayColor = Now.Air
    Sky.DayDecay = Now.Decay
    Sky.DayDensity = Now.Density
    Sky.DayHaze = Now.Haze
    const Atmosphere = Air
    if Atmosphere and not Sky.WeatherActive then
        write(Atmosphere, "Color", Now.Air)
        write(Atmosphere, "Decay", Now.Decay)
        write(Atmosphere, "Density", Now.Density)
        write(Atmosphere, "Haze", Now.Haze)
    end
end

function DayNight.enabled(): boolean
    return Enabled
end

function DayNight.setEnabled(Value: boolean)
    if Enabled == Value then
        return
    end
    Enabled = Value
    if Value then
        const Atmosphere = Sky.atmosphere()
        Air = Atmosphere
        const read = AmbientOverride.read
        Saved = {
            ClockTime = read(Lighting, "ClockTime"),
            Ambient = read(Lighting, "Ambient"),
            Outdoor = read(Lighting, "OutdoorAmbient"),
            Top = read(Lighting, "ColorShift_Top"),
            Bottom = read(Lighting, "ColorShift_Bottom"),
            Brightness = read(Lighting, "Brightness"),
            Exposure = read(Lighting, "ExposureCompensation"),
            Air = read(Atmosphere, "Color"),
            Decay = read(Atmosphere, "Decay"),
            Density = read(Atmosphere, "Density"),
            Haze = read(Atmosphere, "Haze"),
        }
        Waited = 0
        DaySound = Sounds.loop("AmbienceDay")
        NightSound = Sounds.loop("AmbienceNight")
        Link = RunService.Heartbeat:Connect(function(Delta: number)
            Waited += Delta
            if Waited >= DayNight.Interval then
                Waited = 0
                apply()
            end
        end)
        apply()
        return
    end
    const Running = Link
    Link = nil
    if Running then
        Running:Disconnect()
    end
    for _, Ambience in { DaySound, NightSound } :: { Sound? } do
        if Ambience then
            Ambience:Destroy()
        end
    end
    DaySound = nil
    NightSound = nil
    const Old = Saved
    Saved = nil
    const write = AmbientOverride.write
    if Old then
        write(Lighting, "ClockTime", Old.ClockTime)
        write(Lighting, "Ambient", Old.Ambient)
        write(Lighting, "OutdoorAmbient", Old.Outdoor)
        write(Lighting, "ColorShift_Top", Old.Top)
        write(Lighting, "ColorShift_Bottom", Old.Bottom)
        write(Lighting, "Brightness", Old.Brightness)
        write(Lighting, "ExposureCompensation", Old.Exposure)
    end
    Sky.Darkness = 0
    Sky.DayColor = nil
    Sky.DayDecay = nil
    Sky.DayDensity = nil
    Sky.DayHaze = nil
    const Atmosphere = Air
    Air = nil
    if Atmosphere and Old and not Sky.owned(Atmosphere) and not Sky.WeatherActive then
        write(Atmosphere, "Color", Old.Air or Atmosphere.Color)
        write(Atmosphere, "Decay", Old.Decay or Atmosphere.Decay)
        write(Atmosphere, "Density", Old.Density or Atmosphere.Density)
        write(Atmosphere, "Haze", Old.Haze or Atmosphere.Haze)
    end
    Sky.release()
end

return DayNight
