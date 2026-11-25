--!strict
const Lighting = game:GetService("Lighting")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const signal = require(ReplicatedStorage.MainPackages.signal)
const Sky = require(script.Parent.Sky)
const AmbientOverride = require(script.Parent.AmbientOverride)
const VFX = require(script.Parent.VFX)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

export type Context = {
    Name: string,
    Strength: number,
    Elapsed: number,
    Data: { [any]: any },
    Folder: Folder,
    vfx: () -> boolean,
    camera: () -> Camera?,
}

export type CloudLook = {
    Cover: number,
    Density: number,
    Color: Color3?,
}

export type AirLook = {
    Density: number,
    Haze: number,
    Tint: Color3?,
    TintAmount: number?,
}

export type GradeLook = {
    Saturation: number?,
    Contrast: number?,
    Brightness: number?,
}

export type Definition = {
    Name: string,
    Rarity: number,
    Clouds: CloudLook?,
    Atmosphere: AirLook?,
    Grade: GradeLook?,
    Sound: string?,
    Volume: number?,
    FadeIn: number?,
    FadeOut: number?,
    onStart: ((Context: Context) -> ())?,
    onIdle: ((Context: Context, Delta: number) -> ())?,
    onStop: ((Context: Context) -> ())?,
}

export type Definitions = { [string]: Definition }

type Run = {
    Definition: Definition,
    Context: Context,
    Sound: Sound?,
}

type Force = {
    Name: string,
    Priority: number,
    Order: number,
}

type Saved = {
    Cover: number,
    Density: number,
    CloudColor: Color3,
    Air: number,
    Haze: number,
    Color: Color3,
    Decay: Color3,
}

const Weather = {
    Period = 300,
    Transition = 30,
    ForceFade = 4,
    Fallback = "Clear",
    Attributes = {
        Current = "WeatherCurrent",
        Previous = "WeatherPrevious",
        Since = "WeatherSince",
        Fade = "WeatherFade",
    },
    Changed = signal.new(),
}

const DefaultClouds: CloudLook = { Cover = 0.4, Density = 0.25, Color = Color3.new(1, 1, 1) }
const DefaultAir: AirLook = { Density = 0.3, Haze = 0.5 }

const List: Definitions = {}
const Runs: { [string]: Run } = {}
const Forces: { [string]: Force } = {}
const Forced: { [string]: number } = {}
local ForceFade = Weather.ForceFade
local ForceOrder = 0
local Names: { string } = {}
local Loaded = false
local Enabled = false
local Link: RBXScriptConnection? = nil
local Clouds: Clouds? = nil
local MadeClouds = false
local Air: Atmosphere? = nil
local Saved: Saved? = nil
local Grade: ColorCorrectionEffect? = nil
local CurrentName = Weather.Fallback

function Weather.add(Id: string, Definition: Definition): boolean
    if type(Id) ~= "string" or Id == "" or List[Id] then
        warn(`[Weather] "{tostring(Id)}" is missing or defined more than once`)
        return false
    end
    if type(Definition) ~= "table" or type(Definition.Rarity) ~= "number" or Definition.Rarity < 0 then
        warn(`[Weather] "{Id}" needs a Rarity number of 0 or more`)
        return false
    end
    List[Id] = Definition
    Names = {}
    for Name in List do
        table.insert(Names, Name)
    end
    table.sort(Names)
    return true
end

const function load()
    if Loaded then
        return
    end
    Loaded = true
    const Folder = script:FindFirstChild("Types")
    if not Folder then
        return
    end
    const Modules: { ModuleScript } = {}
    for _, Item in Folder:GetDescendants() do
        if Item:IsA("ModuleScript") then
            table.insert(Modules, Item)
        end
    end
    table.sort(Modules, function(A: ModuleScript, B: ModuleScript): boolean
        return A:GetFullName() < B:GetFullName()
    end)
    for _, Module in Modules do
        const Ok, Result = pcall((require :: any), Module)
        if not Ok or type(Result) ~= "table" then
            warn(`[Weather] {Module:GetFullName()} failed to load: {if Ok then "it must return a table" else Result}`)
            continue
        end
        for Id, Definition in Result do
            Weather.add(Id, Definition)
        end
    end
end

function Weather.list(): Definitions
    load()
    return List
end

function Weather.roll(Rng: Random): string
    load()
    local Total = 0
    for _, Name in Names do
        Total += List[Name].Rarity
    end
    if Total <= 0 then
        return Weather.Fallback
    end
    local Roll = Rng:NextNumber() * Total
    for _, Name in Names do
        Roll -= List[Name].Rarity
        if Roll <= 0 then
            return Name
        end
    end
    return Names[#Names]
end

const function lerp(From: number, To: number, Alpha: number): number
    return From + (To - From) * Alpha
end

const function camera(): Camera?
    return Workspace.CurrentCamera
end

const function startRun(Name: string): Run?
    const Definition = List[Name]
    if not Definition then
        return nil
    end
    const Folder = Instance.new("Folder")
    Folder.Name = `Weather_{Name}`
    Folder:SetAttribute(Sky.Owned, true)
    Folder:SetAttribute(VFX.Owned, true)
    Folder.Parent = Workspace
    const Context: Context = {
        Name = Name,
        Strength = 0,
        Elapsed = 0,
        Data = {},
        Folder = Folder,
        vfx = VFX.enabled,
        camera = camera,
    }
    const Ambience: Sound? = if Definition.Sound then Sounds.loop(Definition.Sound) else nil
    const Made: Run = {
        Definition = Definition,
        Context = Context,
        Sound = Ambience,
    }
    Runs[Name] = Made
    const Start = Definition.onStart
    if Start then
        const Ok, Problem = pcall(Start, Context)
        if not Ok then
            warn(`[Weather] {Name} onStart failed: {Problem}`)
        end
    end
    return Made
end

const function stopRun(Name: string)
    const Run = Runs[Name]
    if not Run then
        return
    end
    Runs[Name] = nil
    const Stop = Run.Definition.onStop
    if Stop then
        const Ok, Problem = pcall(Stop, Run.Context)
        if not Ok then
            warn(`[Weather] {Name} onStop failed: {Problem}`)
        end
    end
    const Ambience = Run.Sound
    if Ambience then
        Ambience:Destroy()
    end
    Run.Context.Folder:Destroy()
    table.clear(Run.Context.Data)
end

const function blend()
    const Old = Saved
    if not Old then
        return
    end
    local Cover, CloudDensity, Total = 0, 0, 0
    local CloudColor = Vector3.zero
    local AirDensity, Haze = 0, 0
    local Tint = Vector3.zero
    local TintWeight = 0
    local Saturation, Contrast, Brightness = 0, 0, 0
    for _, Run in Runs do
        const Weight = Run.Context.Strength
        if Weight <= 0 then
            continue
        end
        const Look = Run.Definition.Clouds or DefaultClouds
        const Fog = Run.Definition.Atmosphere or DefaultAir
        const Color = Look.Color or Color3.new(1, 1, 1)
        Total += Weight
        Cover += Look.Cover * Weight
        CloudDensity += Look.Density * Weight
        CloudColor += Vector3.new(Color.R, Color.G, Color.B) * Weight
        AirDensity += Fog.Density * Weight
        Haze += Fog.Haze * Weight
        const Look2 = Run.Definition.Grade
        if Look2 then
            Saturation += (Look2.Saturation or 0) * Weight
            Contrast += (Look2.Contrast or 0) * Weight
            Brightness += (Look2.Brightness or 0) * Weight
        end
        const FogTint = Fog.Tint
        if FogTint then
            const Amount = (Fog.TintAmount or 1) * Weight
            Tint += Vector3.new(FogTint.R, FogTint.G, FogTint.B) * Amount
            TintWeight += Amount
        end
    end
    if Total <= 0 then
        return
    end
    const write = AmbientOverride.write
    const Effect = Grade
    if Effect then
        Effect.Saturation = Saturation / Total
        Effect.Contrast = Contrast / Total
        Effect.Brightness = Brightness / Total
    end
    const Dark = Sky.Darkness
    const Mixed = CloudColor / Total
    const Cover2 = Clouds
    if Cover2 then
        write(Cover2, "Cover", Cover / Total)
        write(Cover2, "Density", CloudDensity / Total)
        write(Cover2, "Color", Color3.new(Mixed.X, Mixed.Y, Mixed.Z):Lerp(Color3.new(0, 0, 0), Dark * 0.85))
    end
    const Atmosphere = Air
    if not Atmosphere then
        return
    end
    const BaseDensity = Sky.DayDensity or Old.Air
    const BaseHaze = Sky.DayHaze or Old.Haze
    local BaseColor = Sky.DayColor or Old.Color
    write(Atmosphere, "Density", math.max(BaseDensity, lerp(AirDensity / Total, Sky.NightDensity, Dark)))
    write(Atmosphere, "Haze", math.max(BaseHaze, lerp(Haze / Total, Sky.NightHaze, Dark)))
    if TintWeight > 0 then
        const Average = Tint / TintWeight
        BaseColor = BaseColor:Lerp(Color3.new(Average.X, Average.Y, Average.Z), math.clamp(TintWeight / Total, 0, 1) * (1 - Dark))
    end
    write(Atmosphere, "Color", BaseColor)
    write(Atmosphere, "Decay", Sky.DayDecay or Old.Decay)
end

const function fade(Value: number?): number
    return math.clamp(Value or Weather.Transition, 0.01, Weather.Period * 0.9)
end

const function shared(Attribute: string, Default: string): string
    const Value = Workspace:GetAttribute(Attribute)
    return if type(Value) == "string" and List[Value] then Value else Default
end

const function natural(Now: number): ({ [string]: number }, string)
    const Current = shared(Weather.Attributes.Current, Weather.Fallback)
    const Previous = shared(Weather.Attributes.Previous, Current)
    const Changed = Workspace:GetAttribute(Weather.Attributes.Since)
    const Since = if type(Changed) == "number" then math.max(Now - Changed, 0) else math.huge
    const Wanted: { [string]: number } = {}
    if Current == Previous then
        Wanted[Current] = 1
        return Wanted, Current
    end
    const Incoming = List[Current]
    const Outgoing = List[Previous]
    const Override = Workspace:GetAttribute(Weather.Attributes.Fade)
    const Quick = if type(Override) == "number" then Override else nil
    const In = math.clamp(Since / fade(Quick or (if Incoming then Incoming.FadeIn else nil)), 0, 1)
    const Out = 1 - math.clamp(Since / fade(Quick or (if Outgoing then Outgoing.FadeOut else nil)), 0, 1)
    if In > 0 then
        Wanted[Current] = In
    end
    if Out > 0 then
        Wanted[Previous] = Out
    end
    return Wanted, if In >= Out then Current else Previous
end

const function forcedName(): string?
    local Best: Force? = nil
    for _, Entry in Forces do
        if not Best or Entry.Priority > Best.Priority or (Entry.Priority == Best.Priority and Entry.Order > Best.Order) then
            Best = Entry
        end
    end
    return if Best then Best.Name else nil
end

const function settle(Delta: number, Snap: boolean?): number
    const Top = forcedName()
    const Rate = if Snap or ForceFade <= 0 then 1 else Delta / ForceFade
    for Name, Weight in Forced do
        if Name ~= Top then
            const Next = Weight - Rate
            Forced[Name] = if Next > 0 then Next else nil
        end
    end
    if Top then
        Forced[Top] = math.min((Forced[Top] or 0) + Rate, 1)
    end
    local Sum = 0
    for _, Weight in Forced do
        Sum += Weight
    end
    return Sum
end

const function step(Delta: number, Snap: boolean?)
    const Wanted, Natural = natural(Workspace:GetServerTimeNow())
    const Sum = settle(Delta, Snap)
    local Shown = Natural
    if Sum > 0 then
        const Share = math.min(Sum, 1)
        const Scale = 1 / math.max(Sum, 1)
        for Name, Weight in Wanted do
            Wanted[Name] = Weight * (1 - Share)
        end
        for Name, Weight in Forced do
            Wanted[Name] = (Wanted[Name] or 0) + Weight * Scale
        end
        local Best = -1
        for Name, Weight in Wanted do
            if Weight > Best then
                Shown = Name
                Best = Weight
            end
        end
    end
    for Name, Weight in Wanted do
        if Weight <= 0.001 then
            Wanted[Name] = nil
        end
    end

    for Name in Runs do
        if not Wanted[Name] then
            stopRun(Name)
        end
    end
    for Name, Strength in Wanted do
        const Run = Runs[Name] or startRun(Name)
        if Run then
            Run.Context.Strength = Strength
        end
    end

    if Shown ~= CurrentName then
        CurrentName = Shown
        Weather.Changed:Fire(Shown)
    end

    blend()

    for Name, Run in Runs do
        Run.Context.Elapsed += Delta
        const Ambience = Run.Sound
        if Ambience then
            Ambience.Volume = (Run.Definition.Volume or Sounds.volume(Run.Definition.Sound or "")) * Run.Context.Strength
        end
        const Idle = Run.Definition.onIdle
        if Idle then
            const Ok, Problem = pcall(Idle, Run.Context, Delta)
            if not Ok then
                warn(`[Weather] {Name} onIdle failed: {Problem}`)
            end
        end
    end
end

function Weather.current(): string
    return CurrentName
end

function Weather.force(Id: string, Name: string | false, Priority: number?, Fade: number?)
    load()
    const Wanted = if Name == false then Weather.Fallback else Name
    if not List[Wanted] then
        warn(`[Weather] can not force "{tostring(Wanted)}" because it is not a weather type`)
        return
    end
    ForceOrder += 1
    Forces[Id] = { Name = Wanted, Priority = Priority or 0, Order = ForceOrder }
    ForceFade = math.max(Fade or Weather.ForceFade, 0)
end

function Weather.release(Id: string, Fade: number?)
    if not Forces[Id] then
        return
    end
    Forces[Id] = nil
    ForceFade = math.max(Fade or Weather.ForceFade, 0)
end

function Weather.forced(): string?
    return forcedName()
end

function Weather.enabled(): boolean
    return Enabled
end

function Weather.setEnabled(Value: boolean)
    if Enabled == Value then
        return
    end
    Enabled = Value
    load()
    if Value then
        const Terrain = Workspace.Terrain
        const Existing = Terrain:FindFirstChildOfClass("Clouds")
        MadeClouds = Existing == nil
        local Found: Clouds
        if Existing then
            Found = Existing
        else
            Found = Instance.new("Clouds")
            Found:SetAttribute(Sky.Owned, true)
            Found.Parent = Terrain
        end
        Clouds = Found
        const Atmosphere = Sky.atmosphere()
        Air = Atmosphere
        const read = AmbientOverride.read
        Saved = {
            Cover = read(Found, "Cover"),
            Density = read(Found, "Density"),
            CloudColor = read(Found, "Color"),
            Air = read(Atmosphere, "Density"),
            Haze = read(Atmosphere, "Haze"),
            Color = read(Atmosphere, "Color"),
            Decay = read(Atmosphere, "Decay"),
        }
        const Effect = Instance.new("ColorCorrectionEffect")
        Effect.Name = "WeatherGrade"
        Effect:SetAttribute(Sky.Owned, true)
        Effect:SetAttribute(VFX.Owned, true)
        Effect.Parent = Lighting
        Grade = Effect
        Sky.WeatherActive = true
        Link = RunService.Heartbeat:Connect(function(Delta: number)
            step(Delta)
        end)
        step(0, true)
        return
    end

    const Running = Link
    Link = nil
    if Running then
        Running:Disconnect()
    end
    for Name in Runs do
        stopRun(Name)
    end
    const Effect = Grade
    Grade = nil
    if Effect then
        Effect:Destroy()
    end
    Sky.WeatherActive = false
    const Old = Saved
    Saved = nil
    const Found = Clouds
    Clouds = nil
    if Found then
        if MadeClouds then
            Found:Destroy()
        elseif Old then
            AmbientOverride.write(Found, "Cover", Old.Cover)
            AmbientOverride.write(Found, "Density", Old.Density)
            AmbientOverride.write(Found, "Color", Old.CloudColor)
        end
    end
    const Atmosphere = Air
    Air = nil
    if Atmosphere and Old and not Sky.owned(Atmosphere) and Sky.DayColor == nil then
        AmbientOverride.write(Atmosphere, "Density", Old.Air)
        AmbientOverride.write(Atmosphere, "Haze", Old.Haze)
        AmbientOverride.write(Atmosphere, "Color", Old.Color)
        AmbientOverride.write(Atmosphere, "Decay", Old.Decay)
    end
    Sky.release()
    CurrentName = Weather.Fallback
end

return Weather
