--!strict
const Debris = game:GetService("Debris")
const Players = game:GetService("Players")
const UserInputService = game:GetService("UserInputService")
const Workspace = game:GetService("Workspace")

const Bullets = require(script.Bullets)

const Guns = {
    Bullets = Bullets,
    MuzzleName = "Muzzle",
    PathAttribute = "ToolPath",
    ReloadClip = 1.2,
    Poses = {
        Lower = "Down",
        Raise = "Up",
    } :: { [string]: string },
    SoundRange = 250,
    Variance = 0.05,
}

const Rng = Random.new()

const function depthOf(Item: Instance): number
    local Here: Instance? = Item
    while Here do
        const Path = Here:GetAttribute(Guns.PathAttribute)
        if type(Path) == "string" then
            local Count = 0
            for _ in string.gmatch(Path, "[^/]+") do
                Count += 1
            end
            return Count
        end
        Here = Here.Parent
    end
    return 0
end

function Guns.muzzle(Model: Model?): Attachment?
    if not Model then
        return nil
    end
    local Best: Attachment? = nil
    local Deepest = -1
    for _, Item in Model:GetDescendants() do
        if Item:IsA("Attachment") and Item.Name == Guns.MuzzleName then
            const Depth = depthOf(Item)
            if Depth > Deepest then
                Deepest = Depth
                Best = Item
            end
        end
    end
    return Best
end

const function soundId(Value: any): string
    if type(Value) == "number" then
        return `rbxassetid://{Value}`
    end
    if type(Value) == "string" then
        return if string.match(Value, "^%d+$") then `rbxassetid://{Value}` else Value
    end
    return ""
end

function Guns.serverSound(Model: Model?, Id: any, Volume: number?, Speed: number?)
    const Id2 = soundId(Id)
    const Holder: Instance? = Guns.muzzle(Model) or (if Model then Model.PrimaryPart else nil)
    if Id2 == "" or not Holder then
        return
    end
    const Made = Instance.new("Sound")
    Made.Name = "FireSound"
    Made.SoundId = Id2
    Made.Volume = Volume or 0.8
    Made.PlaybackSpeed = (Speed or 1) * (1 + (Rng:NextNumber() * 2 - 1) * Guns.Variance)
    Made.RollOffMaxDistance = Guns.SoundRange
    Made.Parent = Holder
    Made:Play()
    Debris:AddItem(Made, 5)
end

const function aimPoint(Range: number, Skip: { Instance }): Vector3?
    const Camera = Workspace.CurrentCamera
    if not Camera then
        return nil
    end
    const Mouse = UserInputService:GetMouseLocation()
    const Ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = Skip
    const Hit = Workspace:Raycast(Ray.Origin, Ray.Direction * Range, Params)
    return if Hit then Hit.Position else Ray.Origin + Ray.Direction * Range
end

const function spread(Direction: Vector3, Degrees: number): Vector3
    if Degrees <= 0 then
        return Direction
    end
    const Frame = CFrame.lookAt(Vector3.zero, Direction)
    const Angle = math.rad(Rng:NextNumber(0, Degrees))
    const Around = Rng:NextNumber(0, math.pi * 2)
    return (Frame * CFrame.Angles(0, 0, Around) * CFrame.Angles(Angle, 0, 0)).LookVector
end

function Guns.shoot(Context: any): Bullets.Shot?
    const Stats = Context.stats()
    const Model = Context.model()
    const Muzzle = Guns.muzzle(Model)
    const Character = Players.LocalPlayer.Character
    if not Model or not Character then
        return nil
    end
    const Origin = if Muzzle then Muzzle.WorldPosition else (Model :: Model):GetPivot().Position
    const Range = Stats.Range or 500
    const Skip: { Instance } = { Character }
    const Target = aimPoint(Range, Skip)
    if not Target then
        return nil
    end
    const Degrees = Stats.Spread or 0
    const Direction = spread((Target - Origin).Unit, Degrees)
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = Skip
    const Result = Workspace:Raycast(Origin, Direction * Range, Params)
    const Shot: Bullets.Shot = {
        Shooter = Players.LocalPlayer,
        Origin = Origin,
        Hit = if Result then Result.Position else Origin + Direction * Range,
        Normal = if Result then Result.Normal else nil,
        Part = if Result and Result.Instance:IsA("BasePart") then Result.Instance else nil,
        Bullet = Stats.Bullet or Bullets.Fallback,
    }
    Bullets.fire(Shot)
    Context.fire(Shot)
    return Shot
end

function Guns.setPose(Context: any, Id: string, On: boolean)
    for Pose, Set in Guns.Poses do
        const Wanted = On and Pose == Id
        if Context.active(Pose) ~= Wanted then
            Context.setActive(Pose, Wanted)
        end
        if Wanted then
            Context.pushSet(Set)
        else
            Context.popSet(Set)
        end
    end
end

function Guns.lowered(Context: any): boolean
    for Pose in Guns.Poses do
        if Context.active(Pose) then
            return true
        end
    end
    return false
end

const function ammoText(Context: any): string?
    const Size = Context.stats().Magazine
    if type(Size) ~= "number" then
        return nil
    end
    return if Context.Data.Reloading then "..." else `{Context.Data.Ammo}/{math.floor(Size)}`
end

const function isGun(Context: any): boolean
    return Context ~= nil and type(Context.stats().Bullet) == "string"
end

const function ammoLabel(Context: any)
    const Paired = Context.Pair
    if Paired and isGun(Paired.Right) and isGun(Paired.Left) then
        const Text = `reload ({ammoText(Paired.Left) or "-"} | {ammoText(Paired.Right) or "-"})`
        Paired.Main.setLabel("Reload", Text)
        return
    end
    const Text = ammoText(Context)
    if Text then
        Context.setLabel("Reload", if Context.Data.Reloading then "reloading..." else `reload ({Text})`)
    end
end

function Guns.reload(Context: any)
    const Stats = Context.stats()
    const Size = if type(Stats.Magazine) == "number" then math.floor(Stats.Magazine) else nil
    if not Size or Context.Data.Reloading or Context.Data.Ammo >= Size then
        return
    end
    Context.Data.Reloading = true
    const Time = Stats.ReloadTime or 1.2
    Context.play("Reload", { Speed = Guns.ReloadClip / math.max(Time, 0.1) })
    ammoLabel(Context)
    task.delay(Time, function()
        if not Context.Data.Live then
            return
        end
        Context.Data.Reloading = false
        Context.Data.Ammo = Size
        ammoLabel(Context)
    end)
end

function Guns.trigger(Context: any): boolean
    if not Context or Guns.lowered(Context) or Context.Data.Reloading then
        return false
    end
    const Stats = Context.stats()
    if type(Stats.Magazine) == "number" and Context.Data.Ammo <= 0 then
        Guns.reload(Context)
        return false
    end
    const Now = os.clock()
    if Now - (Context.Data.LastShot or 0) < (Stats.FireRate or 0.2) then
        return false
    end
    Context.Data.LastShot = Now
    if not Guns.shoot(Context) then
        return false
    end
    if type(Stats.Magazine) == "number" then
        Context.Data.Ammo -= 1
        ammoLabel(Context)
    end
    return true
end

function Guns.runAction(Context: any, Id: string)
    if not Context then
        return
    end
    for _, Entry in Context.Def.Actions or {} do
        if Entry.Id == Id then
            if Entry.Toggle then
                Context.States[Id] = not Context.States[Id]
            end
            const Hooks = Context.Def.client
            const Run = if Hooks then Hooks.onAction else nil
            if type(Run) == "function" then
                Run(Context, Id, Context.States[Id] == true)
            end
            return
        end
    end
end

function Guns.client(): { [string]: any }
    return {
        onEquip = function(Context: any)
            Context.Data.Live = true
            Context.pushSet("Held")
            const Stats = Context.stats()
            Context.Data.Ammo = if type(Stats.Magazine) == "number" then math.floor(Stats.Magazine) else 0
            ammoLabel(Context)
        end,
        onUnequip = function(Context: any)
            Context.Data.Live = false
            for _, Set in Guns.Poses do
                Context.popSet(Set)
            end
            Context.popSet("Held")
        end,
        onActivate = function(Context: any): boolean
            return Guns.trigger(Context)
        end,
        onPairAction = function(Paired: any, Id: string)
            const Both = isGun(Paired.Right) and isGun(Paired.Left)
            if not Both then
                for _, Context in { Paired.Main, Paired.Off } do
                    Guns.runAction(Context, Id)
                end
                return
            end
            if Id == "Reload" then
                Guns.reload(Paired.Right)
                Guns.reload(Paired.Left)
                return
            end
            if not Guns.Poses[Id] then
                return
            end
            const Steps = Paired.Data.Steps or {}
            Paired.Data.Steps = Steps
            const Step = ((Steps[Id] or 0) + 1) % 4
            Steps[Id] = Step
            for Pose in Guns.Poses do
                if Pose ~= Id then
                    Steps[Pose] = 0
                end
            end
            Guns.setPose(Paired.Right, Id, Step == 1 or Step == 3)
            Guns.setPose(Paired.Left, Id, Step == 2 or Step == 3)
        end,
        onAction = function(Context: any, Id: string, On: boolean)
            if Id == "Reload" then
                Guns.reload(Context)
            elseif Guns.Poses[Id] then
                Guns.setPose(Context, Id, On)
            end
        end,
    }
end

function Guns.server(): { [string]: any }
    return {
        onFire = function(_Player: Player, Model: Model, _Shot: any, Stats: { [string]: any })
            Guns.serverSound(Model, Stats.FireSound, Stats.FireVolume, Stats.FireSpeed)
        end,
    }
end

return Guns
