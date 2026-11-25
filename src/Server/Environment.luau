--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const Weather = require(ReplicatedStorage.Shared.Utility.Weather)
const DayNight = require(ReplicatedStorage.Shared.Utility.DayNight)

const Environment = {
    Check = 1,
    WeatherFrozenAttribute = "WeatherFrozen",
}

const Rng = Random.new()
local Started = false
local NextChange = 0

function Environment.weather(): string
    const Value = Workspace:GetAttribute(Weather.Attributes.Current)
    return if type(Value) == "string" then Value else Weather.Fallback
end

function Environment.setWeather(Name: string, Fade: number?): boolean
    if not Weather.list()[Name] then
        warn(`[Environment] "{Name}" is not a weather type`)
        return false
    end
    const Now = Workspace:GetServerTimeNow()
    Workspace:SetAttribute(Weather.Attributes.Previous, Environment.weather())
    Workspace:SetAttribute(Weather.Attributes.Current, Name)
    Workspace:SetAttribute(Weather.Attributes.Fade, Fade)
    Workspace:SetAttribute(Weather.Attributes.Since, Now)
    NextChange = Now + Weather.Period
    return true
end

function Environment.hour(): number
    return DayNight.hour()
end

function Environment.timeFrozen(): boolean
    return type(Workspace:GetAttribute(DayNight.FrozenAttribute)) == "number"
end

function Environment.weatherFrozen(): boolean
    return Workspace:GetAttribute(Environment.WeatherFrozenAttribute) == true
end

function Environment.setHour(Hour: number)
    if Environment.timeFrozen() then
        Workspace:SetAttribute(DayNight.FrozenAttribute, Hour % 24)
        return
    end
    const Now = Workspace:GetServerTimeNow()
    const Ahead = ((Hour - DayNight.StartHour) % 24) / 24 * DayNight.DayLength
    Workspace:SetAttribute(DayNight.EpochAttribute, Now - Ahead)
end

function Environment.freezeTime(On: boolean)
    if On == Environment.timeFrozen() then
        return
    end
    const Hour = DayNight.hour()
    if On then
        Workspace:SetAttribute(DayNight.FrozenAttribute, Hour)
    else
        Workspace:SetAttribute(DayNight.FrozenAttribute, nil)
        Environment.setHour(Hour)
    end
end

function Environment.freezeWeather(On: boolean)
    Workspace:SetAttribute(Environment.WeatherFrozenAttribute, if On then true else nil)
    if not On then
        NextChange = Workspace:GetServerTimeNow() + Weather.Period
    end
end

function Environment.start()
    if Started then
        return
    end
    Started = true
    const Now = Workspace:GetServerTimeNow()
    Workspace:SetAttribute(DayNight.EpochAttribute, Now)

    const First = Weather.roll(Rng)
    Workspace:SetAttribute(Weather.Attributes.Previous, First)
    Workspace:SetAttribute(Weather.Attributes.Current, First)
    Workspace:SetAttribute(Weather.Attributes.Since, Now)
    NextChange = Now + Weather.Period

    task.spawn(function()
        while true do
            task.wait(Environment.Check)
            if not Environment.weatherFrozen() and Workspace:GetServerTimeNow() >= NextChange then
                Environment.setWeather(Weather.roll(Rng))
            end
        end
    end)
end

return Environment
