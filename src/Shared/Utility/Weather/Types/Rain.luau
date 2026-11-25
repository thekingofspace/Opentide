--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const Weather = require(script.Parent.Parent)
const Images = require(ReplicatedStorage.Shared.Images)

const Settings = {
    Rate = 700,
    Radius = 75,
    Height = 300,
    Reach = 900,
    Span = 60,
    Speed = 110,
    Pool = 1100,
    PerFrame = 110,
    SplashRange = 120,
    Parked = CFrame.new(0, -10000, 0),
    DropSize = Vector3.new(0.1, 2, 0.1),
    DropTransparency = 0.6,
    DropColor = Color3.fromRGB(190, 205, 225),
}

type Drop = {
    Part: BasePart,
    From: Vector3,
    To: Vector3,
    Time: number,
    Total: number,
}

type State = {
    Free: { BasePart },
    Active: { Drop },
    Params: RaycastParams,
    Splash: Attachment,
    Emitter: ParticleEmitter,
    Ripple: ParticleEmitter,
    Owed: number,
}

const function drop(Folder: Instance): BasePart
    const Made = Instance.new("Part")
    Made.Name = "Drop"
    Made.Size = Settings.DropSize
    Made.Color = Settings.DropColor
    Made.Material = Enum.Material.Glass
    Made.Transparency = Settings.DropTransparency
    Made.Anchored = true
    Made.CanCollide = false
    Made.CanQuery = false
    Made.CanTouch = false
    Made.CastShadow = false
    Made.CFrame = Settings.Parked
    Made.Parent = Folder
    return Made
end

const function splashes(Folder: Instance): (Attachment, ParticleEmitter, ParticleEmitter)
    const Holder = Instance.new("Part")
    Holder.Name = "SplashHolder"
    Holder.Anchored = true
    Holder.CanCollide = false
    Holder.CanQuery = false
    Holder.CanTouch = false
    Holder.Transparency = 1
    Holder.Size = Vector3.one
    Holder.CFrame = CFrame.identity
    Holder.Parent = Folder
    const Point = Instance.new("Attachment")
    Point.Parent = Holder
    const Emitter = Instance.new("ParticleEmitter")
    Emitter.Rate = 0
    Emitter.EmissionDirection = Enum.NormalId.Top
    Emitter.SpreadAngle = Vector2.new(70, 70)
    Emitter.Speed = NumberRange.new(4, 8)
    Emitter.Lifetime = NumberRange.new(0.2, 0.3)
    Emitter.Acceleration = Vector3.new(0, -40, 0)
    Emitter.Size = NumberSequence.new(0.08, 0)
    Emitter.Transparency = NumberSequence.new(0.3, 1)
    Emitter.Color = ColorSequence.new(Settings.DropColor)
    Emitter.LockedToPart = false
    Emitter.Parent = Point

    const Ripple = Instance.new("ParticleEmitter")
    Ripple.Name = "Ripple"
    Ripple.Rate = 0
    Ripple.Texture = Images.get("RainSplash") or ""
    Ripple.Speed = NumberRange.new(0.5, 1.5)
    Ripple.EmissionDirection = Enum.NormalId.Top
    Ripple.Lifetime = NumberRange.new(0.22, 0.32)
    Ripple.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(1, 0.8),
    })
    Ripple.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    Ripple.Color = ColorSequence.new(Settings.DropColor)
    Ripple.LockedToPart = false
    Ripple.Parent = Point
    return Point, Emitter, Ripple
end

const function state(Context: Weather.Context): State
    const Known = Context.Data.Rain
    if Known then
        return Known
    end
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = { Context.Folder }
    Params.RespectCanCollide = true
    const Point, Emitter, Ripple = splashes(Context.Folder)
    const Made: State = {
        Free = {},
        Active = {},
        Params = Params,
        Splash = Point,
        Emitter = Emitter,
        Ripple = Ripple,
        Owed = 0,
    }
    Context.Data.Rain = Made
    return Made
end

const function release(Rain: State, Index: number)
    const Entry = Rain.Active[Index]
    Rain.Active[Index] = Rain.Active[#Rain.Active]
    Rain.Active[#Rain.Active] = nil
    Entry.Part.CFrame = Settings.Parked
    table.insert(Rain.Free, Entry.Part)
end

const function spawnDrop(Context: Weather.Context, Rain: State, Center: Vector3)
    const Angle = math.random() * math.pi * 2
    const Distance = math.sqrt(math.random()) * Settings.Radius
    const Origin = Vector3.new(Center.X + math.cos(Angle) * Distance, Center.Y + Settings.Height, Center.Z + math.sin(Angle) * Distance)
    const Result = Workspace:Raycast(Origin, Vector3.new(0, -Settings.Reach, 0), Rain.Params)
    if not Result then
        return
    end
    const Part = table.remove(Rain.Free) or (if #Rain.Active < Settings.Pool then drop(Context.Folder) else nil)
    if not Part then
        return
    end
    const To = Result.Position
    const From = Vector3.new(To.X, math.min(To.Y + Settings.Span, Origin.Y), To.Z)
    table.insert(Rain.Active, {
        Part = Part,
        From = From,
        To = To,
        Time = 0,
        Total = math.max((From.Y - To.Y) / Settings.Speed, 0.02),
    })
end

const function splash(Rain: State, At: Vector3, Center: Vector3)
    if (At - Center).Magnitude > Settings.SplashRange then
        return
    end
    Rain.Splash.WorldPosition = At
    Rain.Ripple:Emit(1)
    Rain.Emitter:Emit(2)
end

const Types: Weather.Definitions = {
    Rain = {
        Name = "Rain",
        Rarity = 0.2,
        Sound = "WeatherRain",
        FadeIn = 40,
        FadeOut = 150,
        Clouds = { Cover = 0.86, Density = 0.72, Color = Color3.fromRGB(160, 166, 176) },
        Atmosphere = { Density = 0.5, Haze = 3.4, Tint = Color3.fromRGB(150, 156, 166), TintAmount = 0.6 },
        Grade = { Saturation = -0.25, Contrast = -0.03 },

        onStart = function(Context: Weather.Context)
            state(Context)
        end,

        onIdle = function(Context: Weather.Context, Delta: number)
            const Rain = state(Context)
            const Camera = Context.camera()
            if not Camera or not Context.vfx() then
                for Index = #Rain.Active, 1, -1 do
                    release(Rain, Index)
                end
                Rain.Owed = 0
                return
            end
            const Center = Camera.CFrame.Position
            const Heavy = 1 - (1 - math.clamp(Context.Strength, 0, 1)) ^ 2
            Rain.Owed = math.min(Rain.Owed + Settings.Rate * Heavy * Delta, Settings.PerFrame)
            while Rain.Owed >= 1 do
                Rain.Owed -= 1
                spawnDrop(Context, Rain, Center)
            end

            const Parts: { BasePart } = {}
            const Frames: { CFrame } = {}
            for Index = #Rain.Active, 1, -1 do
                const Entry = Rain.Active[Index]
                Entry.Time += Delta
                const Alpha = Entry.Time / Entry.Total
                if Alpha >= 1 then
                    splash(Rain, Entry.To, Center)
                    release(Rain, Index)
                else
                    table.insert(Parts, Entry.Part)
                    table.insert(Frames, CFrame.new(Entry.From:Lerp(Entry.To, Alpha)))
                end
            end
            if #Parts > 0 then
                Workspace:BulkMoveTo(Parts, Frames, Enum.BulkMoveMode.FireCFrameChanged)
            end
        end,
    },
}

return Types
