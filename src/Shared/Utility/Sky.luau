--!strict
const Lighting = game:GetService("Lighting")

const Sky = {
    Owned = "UtilityOwned",
    Darkness = 0,
    WeatherActive = false,
    NightDensity = 0.62,
    NightHaze = 6,
    DayColor = nil :: Color3?,
    DayDecay = nil :: Color3?,
    DayDensity = nil :: number?,
    DayHaze = nil :: number?,
}

local Created: Atmosphere? = nil
local Users = 0

function Sky.atmosphere(): Atmosphere
    Users += 1
    const Existing = Lighting:FindFirstChildOfClass("Atmosphere")
    if Existing then
        return Existing
    end
    const Made = Instance.new("Atmosphere")
    Made.Name = "UtilityAtmosphere"
    Made.Density = 0.3
    Made.Offset = 0.25
    Made.Color = Color3.fromRGB(199, 199, 199)
    Made.Decay = Color3.fromRGB(106, 112, 125)
    Made.Glare = 0
    Made.Haze = 0
    Made:SetAttribute(Sky.Owned, true)
    Made.Parent = Lighting
    Created = Made
    return Made
end

function Sky.release()
    Users = math.max(Users - 1, 0)
    const Made = Created
    if Users == 0 and Made then
        Created = nil
        Made:Destroy()
    end
end

function Sky.owned(Item: Instance): boolean
    return Item:GetAttribute(Sky.Owned) == true
end

return Sky
