--!strict
const Debris = game:GetService("Debris")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const TweenService = game:GetService("TweenService")
const Workspace = game:GetService("Workspace")

const Bullets = require(script.Bullets)

const Guns = {
    Bullets = Bullets,
    MuzzleName = "Muzzle",
    PathAttribute = "ToolPath",
    DefaultFov = 70,
    MaxPitch = math.rad(60),
    ReloadClip = 1.2,
    Poses = {
        Lower = "Down",
        Raise = "Up",
    } :: { [string]: string },
    ZoomTime = 0.15,
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
    const Aiming = Context.active("Aim")
    const Degrees = if Aiming then (Stats.AimSpread or (Stats.Spread or 0) * 0.4) else (Stats.Spread or 0)
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

const function zoom(Factor: number)
    const Camera = Workspace.CurrentCamera
    if Camera then
        TweenService:Create(Camera, TweenInfo.new(Guns.ZoomTime), { FieldOfView = Guns.DefaultFov / math.max(Factor, 0.1) }):Play()
    end
end

function Guns.setAim(Context: any, On: boolean)
    if Context.active("Aim") ~= On then
        Context.setActive("Aim", On)
    end
    zoom(if On then Context.stats().Zoom or 1 else 1)
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

const function jointOf(Part: Instance?, Name: string): (Motor6D | AnimationConstraint)?
    const Found = if Part then Part:FindFirstChild(Name) else nil
    if Found and (Found:IsA("Motor6D") or Found:IsA("AnimationConstraint")) then
        return Found
    end
    return nil
end

const function follow(Context: any)
    const Character = Players.LocalPlayer.Character
    if not Character then
        return
    end
    if Guns.lowered(Context) or Context.Data.Reloading then
        return
    end
    const Target = aimPoint(Context.stats().Range or 500, { Character })
    if not Target then
        return
    end
    const Arm = Character:FindFirstChild("RightUpperArm")
    const Shoulder = jointOf(Arm, "RightShoulder")
    if not Arm or not Arm:IsA("BasePart") or not Shoulder then
        return
    end
    const Gap = Target - Arm.Position
    const Pitch = math.clamp(math.asin(math.clamp(Gap.Unit.Y, -1, 1)), -Guns.MaxPitch, Guns.MaxPitch)
    const Turn = CFrame.Angles(Pitch, 0, 0)
    Shoulder.Transform *= Turn
    const Other = jointOf(Character:FindFirstChild("LeftUpperArm"), "LeftShoulder")
    if Other then
        Other.Transform *= Turn
    end
end

const function ammoLabel(Context: any)
    const Stats = Context.stats()
    const Size = Stats.Magazine
    if type(Size) ~= "number" then
        return
    end
    Context.setLabel("Reload", if Context.Data.Reloading then "reloading..." else `reload ({Context.Data.Ammo}/{math.floor(Size)})`)
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

function Guns.client(): { [string]: any }
    return {
        onEquip = function(Context: any)
            Context.Data.Live = true
            Context.pushSet("Held")
            const Stats = Context.stats()
            Context.Data.Ammo = if type(Stats.Magazine) == "number" then math.floor(Stats.Magazine) else 0
            ammoLabel(Context)
            const Links: { RBXScriptConnection } = {}
            table.insert(Links, UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
                if not Processed and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                    Guns.setAim(Context, true)
                end
            end))
            table.insert(Links, UserInputService.InputEnded:Connect(function(Input: InputObject)
                if Input.UserInputType == Enum.UserInputType.MouseButton2 and Context.active("Aim") then
                    Guns.setAim(Context, false)
                end
            end))
            table.insert(Links, RunService.Stepped:Connect(function()
                follow(Context)
            end))
            Context.Data.Links = Links
        end,
        onUnequip = function(Context: any)
            Context.Data.Live = false
            for _, Link in Context.Data.Links or {} do
                Link:Disconnect()
            end
            for _, Set in Guns.Poses do
                Context.popSet(Set)
            end
            Context.popSet("Held")
            zoom(1)
        end,
        onActivate = function(Context: any)
            if Guns.lowered(Context) or Context.Data.Reloading then
                return
            end
            const Stats = Context.stats()
            if type(Stats.Magazine) == "number" and Context.Data.Ammo <= 0 then
                Guns.reload(Context)
                return
            end
            const Now = os.clock()
            if Now - (Context.Data.LastShot or 0) < (Stats.FireRate or 0.2) then
                return
            end
            Context.Data.LastShot = Now
            if Guns.shoot(Context) and type(Stats.Magazine) == "number" then
                Context.Data.Ammo -= 1
                ammoLabel(Context)
            end
        end,
        onAction = function(Context: any, Id: string, On: boolean)
            if Id == "Aim" then
                Guns.setAim(Context, On)
            elseif Id == "Reload" then
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
