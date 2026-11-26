--!strict
const Debris = game:GetService("Debris")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const Config = require(script.Config)

type Walker = {
    Travelled: number,
    Last: Vector3?,
}

const Footsteps = {
    Config = Config,
}

const Walkers: { [Model]: Walker } = {}
const ByMaterial: { [string]: Config.Group } = {}
const Rng = Random.new()
local Started = false

const function soundId(Value: number | string): string
    if type(Value) == "number" then
        return `rbxassetid://{Value}`
    end
    return if string.match(Value, "^%d+$") then `rbxassetid://{Value}` else Value
end

const function index()
    table.clear(ByMaterial)
    for _, Group in Config.Groups do
        for _, Name in Group.Materials do
            ByMaterial[Name] = Group
        end
    end
end

const function groupFor(Material: Enum.Material): Config.Group?
    return ByMaterial[Material.Name] or Config.Groups[Config.Default]
end

const function play(Root: BasePart, Group: Config.Group)
    if #Group.Ids == 0 then
        return
    end
    const Sound = Instance.new("Sound")
    Sound.Name = "Footstep"
    Sound.SoundId = soundId(Group.Ids[Rng:NextInteger(1, #Group.Ids)])
    Sound.Volume = Config.Volume * (Group.Volume or 1)
    const Range = Group.Pitch or Config.Pitch
    Sound.PlaybackSpeed = Rng:NextNumber(Range[1], Range[2] or Range[1])
    Sound.RollOffMaxDistance = Config.RollOff
    Sound.Parent = Root
    Sound:Play()
    Debris:AddItem(Sound, 2)
end

const function mute(Root: BasePart)
    if not Config.MuteDefault then
        return
    end
    const function quiet(Child: Instance)
        if Child:IsA("Sound") and Child.Name == "Running" then
            Child.Volume = 0
        end
    end
    for _, Child in Root:GetChildren() do
        quiet(Child)
    end
    Root.ChildAdded:Connect(quiet)
end

const function step(Delta: number)
    const Camera = Workspace.CurrentCamera
    const Eye = if Camera then Camera.CFrame.Position else Vector3.zero
    for _, Player in Players:GetPlayers() do
        const Character = Player.Character
        const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
        const Humanoid = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
        if not Character or not Root or not Root:IsA("BasePart") or not Humanoid then
            continue
        end
        local Found = Walkers[Character]
        if not Found then
            const Made: Walker = { Travelled = 0, Last = nil }
            Walkers[Character] = Made
            Found = Made
            mute(Root)
            Character.Destroying:Connect(function()
                Walkers[Character] = nil
            end)
        end
        const Walker = Found :: Walker
        const Here = Root.Position
        const Last = Walker.Last
        Walker.Last = Here
        if not Last or (Here - Eye).Magnitude > Config.Range or Humanoid.FloorMaterial == Enum.Material.Air or Humanoid.FloorMaterial == Enum.Material.Water then
            continue
        end
        const Moved = Vector3.new(Here.X - Last.X, 0, Here.Z - Last.Z).Magnitude
        if Moved / math.max(Delta, 1e-3) < Config.MinSpeed then
            continue
        end
        const Walked = Walker.Travelled + Moved
        if Walked >= Config.StepLength then
            Walker.Travelled = 0
            const Group = groupFor(Humanoid.FloorMaterial)
            if Group then
                play(Root, Group)
            end
        else
            Walker.Travelled = Walked
        end
    end
end

function Footsteps.start()
    if Started or not RunService:IsClient() or not Config.Enabled then
        return
    end
    Started = true
    index()
    RunService.Heartbeat:Connect(step)
end

return Footsteps
