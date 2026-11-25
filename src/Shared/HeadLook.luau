--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)

type Look = {
    Yaw: number,
    Pitch: number,
    ShownYaw: number,
    ShownPitch: number,
}

const HeadLook = {
    SendRate = 0.1,
    MinChange = 2,
    MaxYaw = 75,
    MaxPitch = 50,
    Smooth = 10,
}

const Net = NetWatch.Look
const Looks: { [Player]: Look } = {}
local Enabled = true
local Started = false
local SentYaw = 0
local SentPitch = 0
local Waited = 0

const function lookOf(Player: Player): Look
    local Found = Looks[Player]
    if not Found then
        Found = { Yaw = 0, Pitch = 0, ShownYaw = 0, ShownPitch = 0 }
        Looks[Player] = Found
    end
    return Found :: Look
end

const function aim(): Vector2?
    const Character = Players.LocalPlayer.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    const Camera = Workspace.CurrentCamera
    if not Root or not Root:IsA("BasePart") or not Camera then
        return nil
    end
    const Local = Root.CFrame:VectorToObjectSpace(Camera.CFrame.LookVector)
    const Yaw = math.deg(math.atan2(-Local.X, -Local.Z))
    const Pitch = math.deg(math.asin(math.clamp(Local.Y, -1, 1)))
    return Vector2.new(math.clamp(Yaw, -HeadLook.MaxYaw, HeadLook.MaxYaw), math.clamp(Pitch, -HeadLook.MaxPitch, HeadLook.MaxPitch))
end

const function neckOf(Character: Model?): (Motor6D | AnimationConstraint)?
    const Head = if Character then Character:FindFirstChild("Head") else nil
    const Neck = if Head then Head:FindFirstChild("Neck") else nil
    if Neck and (Neck:IsA("Motor6D") or Neck:IsA("AnimationConstraint")) then
        return Neck
    end
    return nil
end

const function apply(Delta: number)
    const Blend = 1 - math.exp(-HeadLook.Smooth * Delta)
    for Player, Look in Looks do
        if not Player.Parent then
            Looks[Player] = nil
            continue
        end
        Look.ShownYaw += (Look.Yaw - Look.ShownYaw) * Blend
        Look.ShownPitch += (Look.Pitch - Look.ShownPitch) * Blend
        const Neck = neckOf(Player.Character)
        if Neck then
            Neck.Transform *= CFrame.Angles(math.rad(Look.ShownPitch), math.rad(Look.ShownYaw), 0)
        end
    end
end

const function send(Delta: number)
    Waited += Delta
    if Waited < HeadLook.SendRate then
        return
    end
    Waited = 0
    const Angles = aim()
    if not Angles then
        return
    end
    const Yaw = Angles.X
    const Pitch = Angles.Y
    if Enabled then
        const Mine = lookOf(Players.LocalPlayer)
        Mine.Yaw = Yaw
        Mine.Pitch = Pitch
    end
    if math.abs(Yaw - SentYaw) < HeadLook.MinChange and math.abs(Pitch - SentPitch) < HeadLook.MinChange then
        return
    end
    SentYaw = Yaw
    SentPitch = Pitch
    Net:Emit("@Look/Set", Yaw, Pitch)
end

function HeadLook.setEnabled(Value: boolean)
    Enabled = Value
    if not Value then
        table.clear(Looks)
    end
    if Started then
        Net:Emit("@Look/Listen", Value)
    end
end

function HeadLook.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    Net:Emit("@Look/Listen", Enabled)
    Net:On("@Look/Update", function(Player: Player, Yaw: number, Pitch: number)
        if not Enabled or typeof(Player) ~= "Instance" or type(Yaw) ~= "number" or type(Pitch) ~= "number" then
            return
        end
        const Look = lookOf(Player)
        Look.Yaw = Yaw
        Look.Pitch = Pitch
    end)
    RunService.Heartbeat:Connect(send)
    RunService.Stepped:Connect(function(_, Delta: number)
        if Enabled then
            apply(Delta)
        end
    end)
end

return HeadLook
