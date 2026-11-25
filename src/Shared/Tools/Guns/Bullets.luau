--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const Workspace = game:GetService("Workspace")

export type Shot = {
    Shooter: Player?,
    Origin: Vector3,
    Hit: Vector3,
    Normal: Vector3?,
    Part: BasePart?,
    Bullet: string,
}

export type BulletDef = {
    Name: string,
    Color: Color3,
    Width: number,
    Speed: number,
    Length: number?,
    Life: number?,
    draw: ((Shot: Shot, Def: BulletDef) -> ())?,
    onHit: ((Shot: Shot) -> ())?,
}

const Bullets = {
    FolderName = "Bullets",
    Fallback = "Standard",
    MaxTravel = 2,
    FirstFrame = 1 / 30,
}

const Defs: { [string]: BulletDef } = {}
local Folder: Folder? = nil

const function folder(): Folder
    const Known = Folder
    if Known and Known.Parent then
        return Known
    end
    const Made = Instance.new("Folder")
    Made.Name = Bullets.FolderName
    Made.Parent = Workspace.CurrentCamera or Workspace
    Folder = Made
    return Made
end

const function streak(Def: BulletDef, Length: number): Part
    const Made = Instance.new("Part")
    Made.Name = "Bullet"
    Made.Anchored = true
    Made.CanCollide = false
    Made.CanQuery = false
    Made.CanTouch = false
    Made.CastShadow = false
    Made.Material = Enum.Material.Neon
    Made.Color = Def.Color
    Made.Size = Vector3.new(Def.Width, Def.Width, math.max(Length, 0.05))
    Made.Parent = folder()
    return Made
end

const function tracer(Shot: Shot, Def: BulletDef)
    const Distance = (Shot.Hit - Shot.Origin).Magnitude
    if Distance < 0.05 then
        return
    end
    const Direction = (Shot.Hit - Shot.Origin).Unit
    if Def.Speed <= 0 then
        const Beam = streak(Def, Distance)
        Beam.CFrame = CFrame.lookAt(Shot.Origin + Direction * Distance / 2, Shot.Hit)
        const Fade = TweenService:Create(Beam, TweenInfo.new(Def.Life or 0.12), {
            Transparency = 1,
            Size = Vector3.new(0, 0, Distance),
        })
        Fade:Play()
        Fade.Completed:Once(function()
            Beam:Destroy()
        end)
        return
    end
    const Length = math.min(Def.Length or 2.5, Distance)
    const Piece = streak(Def, Length)
    const Travel = math.min(Distance / Def.Speed, Bullets.MaxTravel)
    local Time = 0
    local Link: RBXScriptConnection? = nil
    const function place(Alpha: number)
        const Head = Shot.Origin + Direction * Distance * Alpha
        const Tail = if Time <= Bullets.FirstFrame then Shot.Origin else Head - Direction * math.min(Length, Distance * Alpha)
        Piece.Size = Vector3.new(Def.Width, Def.Width, math.max((Head - Tail).Magnitude, 0.05))
        Piece.CFrame = CFrame.lookAt((Head + Tail) / 2, Head + Direction)
    end
    place(0)
    Link = RunService.RenderStepped:Connect(function(Delta: number)
        Time += Delta
        const Alpha = if Travel > 0 then math.min(Time / Travel, 1) else 1
        place(Alpha)
        if Alpha >= 1 then
            const Done = Link
            if Done then
                Done:Disconnect()
            end
            Piece:Destroy()
        end
    end)
end

function Bullets.add(Id: string, Def: BulletDef)
    if Defs[Id] then
        warn(`[Bullets] "{Id}" is defined more than once`)
        return
    end
    Defs[Id] = Def
end

function Bullets.get(Id: string?): BulletDef
    return (if Id then Defs[Id] else nil) or Defs[Bullets.Fallback]
end

function Bullets.locate(Shot: Shot)
    if Shot.Part then
        return
    end
    const Gap = Shot.Hit - Shot.Origin
    if Gap.Magnitude < 0.05 then
        return
    end
    const Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    const Skip: { Instance } = { folder() }
    const Shooter = Shot.Shooter
    const Character = if Shooter then Shooter.Character else nil
    if Character then
        table.insert(Skip, Character)
    end
    Params.FilterDescendantsInstances = Skip
    const Result = Workspace:Raycast(Shot.Origin, Gap.Unit * (Gap.Magnitude + 0.5), Params)
    if Result and Result.Instance:IsA("BasePart") then
        Shot.Part = Result.Instance
        Shot.Normal = Result.Normal
    end
end

function Bullets.fire(Shot: Shot)
    if not RunService:IsClient() then
        return
    end
    const Def = Bullets.get(Shot.Bullet)
    const Draw = Def.draw or tracer
    const Ok, Problem = pcall(function()
        Draw(Shot, Def)
    end)
    if not Ok then
        warn(`[Bullets] {Shot.Bullet} draw failed: {Problem}`)
    end
    const Hit = Def.onHit
    if not Hit then
        return
    end
    const Delay = if Def.Speed > 0 then math.min((Shot.Hit - Shot.Origin).Magnitude / Def.Speed, Bullets.MaxTravel) else 0
    task.delay(Delay, function()
        Bullets.locate(Shot)
        if not Shot.Part then
            return
        end
        const Fine, Why = pcall(function()
            Hit(Shot)
        end)
        if not Fine then
            warn(`[Bullets] {Shot.Bullet} onHit failed: {Why}`)
        end
    end)
end

function Bullets.mine(Shot: Shot): boolean
    return Shot.Shooter == Players.LocalPlayer
end

Bullets.add("Standard", {
    Name = "Standard",
    Color = Color3.fromRGB(255, 220, 140),
    Width = 0.06,
    Speed = 400,
    Length = 3,
    onHit = function(_Shot: Shot) end,
})

Bullets.add("Tracer", {
    Name = "Tracer",
    Color = Color3.fromRGB(255, 90, 50),
    Width = 0.12,
    Speed = 300,
    Length = 4,
    onHit = function(_Shot: Shot) end,
})

Bullets.add("LaserRed", {
    Name = "Red Laser",
    Color = Color3.fromRGB(255, 60, 60),
    Width = 0.12,
    Speed = 0,
    Life = 0.15,
    onHit = function(_Shot: Shot) end,
})

Bullets.add("LaserBlue", {
    Name = "Blue Laser",
    Color = Color3.fromRGB(70, 150, 255),
    Width = 0.16,
    Speed = 0,
    Life = 0.2,
    onHit = function(_Shot: Shot) end,
})

return Bullets
