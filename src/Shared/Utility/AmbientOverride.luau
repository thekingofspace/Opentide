--!strict
const Lighting = game:GetService("Lighting")
const RunService = game:GetService("RunService")
const SoundService = game:GetService("SoundService")
const TweenService = game:GetService("TweenService")
const Workspace = game:GetService("Workspace")

const Sky = require(script.Parent.Sky)

export type Look = {
    Hour: number?,
    Lighting: { [string]: any }?,
    Atmosphere: { [string]: any }?,
    Clouds: { [string]: any }?,
    Grade: { [string]: any }?,
    Sound: { [string]: any }?,
}

export type Options = {
    TweenTime: number?,
    Priority: number?,
    Style: Enum.EasingStyle?,
}

type Entry = {
    Target: string,
    Property: string,
    Value: any,
}

type Layer = {
    Id: string,
    Entries: { Entry },
    Priority: number,
    Order: number,
    Progress: number,
    Goal: number,
    Time: number,
    Style: Enum.EasingStyle,
    Weight: number,
}

const AmbientOverride = {
    TweenTime = 2,
    Style = Enum.EasingStyle.Sine,
    Targets = { "Lighting", "Atmosphere", "Clouds", "Grade", "Sound" },
}

const Layers: { [string]: Layer } = {}
local Sorted: { Layer } = {}
local Touched: { [string]: { [string]: boolean } } = {}
const Naturals: { [Instance]: { [string]: any } } = {}
const Watching: { [Instance]: RBXScriptConnection } = {}
local Link: RBXScriptConnection? = nil
local Grade: ColorCorrectionEffect? = nil
local HoldingAir = false
local Counter = 0

const function kind(Object: Instance): string?
    if Object == Lighting then
        return "Lighting"
    elseif Object:IsA("Atmosphere") then
        return "Atmosphere"
    elseif Object:IsA("Clouds") then
        return "Clouds"
    elseif Object == Grade then
        return "Grade"
    elseif Object == SoundService then
        return "Sound"
    end
    return nil
end

const function grade(): ColorCorrectionEffect
    const Known = Grade
    if Known then
        return Known
    end
    const Made = Instance.new("ColorCorrectionEffect")
    Made.Name = "AmbientGrade"
    Made:SetAttribute(Sky.Owned, true)
    Made.Parent = Lighting
    Grade = Made
    return Made
end

const function target(Name: string): Instance?
    if Name == "Lighting" then
        return Lighting
    elseif Name == "Atmosphere" then
        return Lighting:FindFirstChildOfClass("Atmosphere")
    elseif Name == "Clouds" then
        return Workspace.Terrain:FindFirstChildOfClass("Clouds")
    elseif Name == "Grade" then
        return grade()
    elseif Name == "Sound" then
        return SoundService
    end
    return nil
end

const function forget(Object: Instance, Property: string?)
    const Known = Naturals[Object]
    if not Known then
        return
    end
    if Property then
        Known[Property] = nil
        if next(Known) ~= nil then
            return
        end
    end
    Naturals[Object] = nil
    const Watch = Watching[Object]
    Watching[Object] = nil
    if Watch then
        Watch:Disconnect()
    end
end

const function remember(Object: Instance, Property: string, Value: any)
    local Known = Naturals[Object]
    if not Known then
        Known = {}
        Naturals[Object] = Known
        Watching[Object] = Object.Destroying:Connect(function()
            forget(Object)
        end)
    end
    Known[Property] = Value
end

const function natural(Object: Instance, Property: string): any
    const Known = Naturals[Object]
    if Known and Known[Property] ~= nil then
        return Known[Property]
    end
    const Current = (Object :: any)[Property]
    remember(Object, Property, Current)
    return Current
end

const function mix(Property: string, From: any, To: any, Alpha: number): any
    if Alpha <= 0 then
        return From
    elseif Alpha >= 1 then
        return To
    end
    if Property == "ClockTime" and type(From) == "number" and type(To) == "number" then
        local Gap = (To - From) % 24
        if Gap > 12 then
            Gap -= 24
        end
        return (From + Gap * Alpha) % 24
    end
    const Kind = typeof(From)
    if Kind ~= typeof(To) then
        return if Alpha >= 0.5 then To else From
    end
    if Kind == "number" then
        return From + (To - From) * Alpha
    elseif Kind == "Color3" then
        return (From :: Color3):Lerp(To :: Color3, Alpha)
    elseif Kind == "Vector3" then
        return (From :: Vector3):Lerp(To :: Vector3, Alpha)
    elseif Kind == "Vector2" then
        return (From :: Vector2):Lerp(To :: Vector2, Alpha)
    elseif Kind == "UDim2" then
        return (From :: UDim2):Lerp(To :: UDim2, Alpha)
    elseif Kind == "CFrame" then
        return (From :: CFrame):Lerp(To :: CFrame, Alpha)
    end
    return if Alpha >= 0.5 then To else From
end

const function blend(Target: string, Property: string, Natural: any): any
    local Value = Natural
    for _, Layer in Sorted do
        if Layer.Weight <= 0 then
            continue
        end
        for _, Entry in Layer.Entries do
            if Entry.Target == Target and Entry.Property == Property then
                Value = mix(Property, Value, Entry.Value, Layer.Weight)
            end
        end
    end
    return Value
end

const function flatten(Look: Look): { Entry }
    const Made: { Entry } = {}
    if type(Look.Hour) == "number" then
        table.insert(Made, { Target = "Lighting", Property = "ClockTime", Value = Look.Hour % 24 })
    end
    for _, Name in AmbientOverride.Targets do
        const Group = (Look :: any)[Name]
        if type(Group) ~= "table" then
            continue
        end
        for Property, Value in Group do
            if type(Property) == "string" then
                table.insert(Made, { Target = Name, Property = Property, Value = Value })
            end
        end
    end
    return Made
end

const function set(Object: Instance, Property: string, Value: any)
    const Ok, Problem = pcall(function()
        (Object :: any)[Property] = Value
    end)
    if not Ok then
        warn(`[AmbientOverride] could not set {Object.ClassName}.{Property}: {Problem}`)
    end
end

const function holdAir(Wanted: boolean)
    if Wanted == HoldingAir then
        return
    end
    HoldingAir = Wanted
    if Wanted then
        Sky.atmosphere()
    else
        Sky.release()
    end
end

const function rebuild()
    Sorted = {}
    for _, Layer in Layers do
        table.insert(Sorted, Layer)
    end
    table.sort(Sorted, function(A: Layer, B: Layer): boolean
        if A.Priority ~= B.Priority then
            return A.Priority < B.Priority
        end
        return A.Order < B.Order
    end)

    const Old = Touched
    const New: { [string]: { [string]: boolean } } = {}
    for _, Layer in Sorted do
        for _, Entry in Layer.Entries do
            local Group = New[Entry.Target]
            if not Group then
                Group = {}
                New[Entry.Target] = Group
            end
            Group[Entry.Property] = true
        end
    end
    Touched = New
    if New.Atmosphere then
        holdAir(true)
    end

    for Name, Group in Old do
        const Object = if Name == "Grade" then Grade else target(Name)
        if not Object then
            continue
        end
        for Property in Group do
            if New[Name] and New[Name][Property] then
                continue
            end
            const Known = Naturals[Object]
            if Known and Known[Property] ~= nil then
                set(Object, Property, Known[Property])
            end
            forget(Object, Property)
        end
    end

    if not New.Grade then
        const Effect = Grade
        Grade = nil
        if Effect then
            forget(Effect)
            Effect:Destroy()
        end
    end
    if not New.Atmosphere then
        holdAir(false)
    end
end

const function apply()
    for Name, Group in Touched do
        const Object = target(Name)
        if not Object then
            continue
        end
        for Property in Group do
            set(Object, Property, blend(Name, Property, natural(Object, Property)))
        end
    end
end

const function step(Delta: number)
    local Removed = false
    for Id, Layer in Layers do
        if Layer.Progress ~= Layer.Goal then
            const Amount = if Layer.Time > 0 then Delta / Layer.Time else 1
            Layer.Progress = if Layer.Goal > Layer.Progress
                then math.min(Layer.Progress + Amount, Layer.Goal)
                else math.max(Layer.Progress - Amount, Layer.Goal)
        end
        Layer.Weight = TweenService:GetValue(Layer.Progress, Layer.Style, Enum.EasingDirection.InOut)
        if Layer.Goal <= 0 and Layer.Progress <= 0 then
            Layers[Id] = nil
            Removed = true
        end
    end
    if Removed then
        rebuild()
    end
    apply()
    if next(Layers) == nil then
        const Running = Link
        Link = nil
        if Running then
            Running:Disconnect()
        end
    end
end

const function run()
    if not Link then
        Link = RunService.Heartbeat:Connect(step)
    end
end

function AmbientOverride.push(Id: string, Look: Look, Given: Options?)
    const Options: Options = Given or {}
    const Time = math.max(Options.TweenTime or AmbientOverride.TweenTime, 0)
    local Layer = Layers[Id]
    if Layer then
        Layer.Entries = flatten(Look)
        Layer.Priority = Options.Priority or Layer.Priority
        Layer.Style = Options.Style or Layer.Style
    else
        Counter += 1
        Layer = {
            Id = Id,
            Entries = flatten(Look),
            Priority = Options.Priority or 0,
            Order = Counter,
            Progress = 0,
            Goal = 1,
            Time = Time,
            Style = Options.Style or AmbientOverride.Style,
            Weight = 0,
        }
        Layers[Id] = Layer
    end
    Layer.Goal = 1
    Layer.Time = Time
    rebuild()
    run()
    step(0)
end

function AmbientOverride.pop(Id: string, TweenTime: number?)
    const Layer = Layers[Id]
    if not Layer then
        return
    end
    Layer.Goal = 0
    if TweenTime then
        Layer.Time = math.max(TweenTime, 0)
    end
    run()
    step(0)
end

function AmbientOverride.active(Id: string): boolean
    const Layer = Layers[Id]
    return Layer ~= nil and Layer.Goal > 0
end

function AmbientOverride.weight(Id: string): number
    const Layer = Layers[Id]
    return if Layer then Layer.Weight else 0
end

function AmbientOverride.write(Object: Instance, Property: string, Value: any)
    const Name = kind(Object)
    const Group = if Name then Touched[Name] else nil
    if Name and Group and Group[Property] then
        remember(Object, Property, Value)
        set(Object, Property, blend(Name, Property, Value))
        return
    end
    set(Object, Property, Value)
end

function AmbientOverride.read(Object: Instance, Property: string): any
    const Known = Naturals[Object]
    if Known and Known[Property] ~= nil then
        return Known[Property]
    end
    return (Object :: any)[Property]
end

function AmbientOverride.hour(Natural: number): number
    return blend("Lighting", "ClockTime", Natural % 24)
end

return AmbientOverride
