--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const ToolData = require(ReplicatedStorage.Shared.Tools)
const Format = require(ReplicatedStorage.Shared.Customize.Format)
const PropConfig = require(ReplicatedStorage.Shared.PropData.Config)

export type Result = {
    Ok: boolean,
    Error: string?,
    Build: ToolBuild?,
    Tool: string?,
}

type Owner = {
    Player: Player,
    Data: PlayerData,
    Equipped: string?,
    Slot: string?,
    Model: Model?,
    Stats: { [string]: any },
    Fired: number,
    Holsters: { [string]: Model },
    Stamp: number,
    Links: { RBXScriptConnection },
    Queued: boolean,
}

const Tools = {
    FolderName = "Tools",
    EquippedAttribute = "EquippedTool",
    MaxMuzzleGap = 15,
    FireSlack = 0.7,
    RelayRange = 400,
}

const Net = NetWatch.Tools
const BulletNet = NetWatch.Bullets
const Owners: { [Player]: Owner } = {}
local Started = false

const function fail(Message: string): Result
    return { Ok = false, Error = Message }
end

const function dataOf(Owner: Owner): ToolsData
    local Data = Owner.Data.Tools :: ToolsData
    if type(Data) ~= "table" then
        const Made: ToolsData = { Slots = {} }
        Owner.Data.Tools = Made
        Data = Made
    end
    if type(Data.Slots) ~= "table" then
        Data.Slots = {}
    end
    const Old = Data.Builds
    for Key, Value in Data.Slots :: { [string]: any } do
        if type(Value) == "string" then
            const Saved = if type(Old) == "table" then Old[Value] else nil
            Data.Slots[Key] = Saved or { Tool = Value, Parts = {} }
        elseif type(Value) ~= "table" then
            Data.Slots[Key] = nil
        end
    end
    Data.Builds = nil
    return Data
end

const function ownsFor(Owner: Owner): ToolData.Owns
    const All = PropConfig.StudioOwnsAll and RunService:IsStudio()
    return function(Pack: string?): boolean
        if Pack and PropConfig.FreePacks[Pack] then
            return true
        end
        return ToolData.owns(Pack, Owner.Data.OwnedPacks, All)
    end
end

const function buildOf(Owner: Owner, Slot: string): ToolBuild?
    const Saved = dataOf(Owner).Slots[Slot]
    if type(Saved) ~= "table" or type(Saved.Tool) ~= "string" then
        return nil
    end
    return ToolData.clean(Saved.Tool, Saved, ownsFor(Owner))
end

const function push(Owner: Owner)
    const Data = dataOf(Owner)
    Net:BroadcastTo(Owner.Player, "@Tools/State", {
        Slots = Data.Slots,
        Equipped = Owner.Slot,
    })
end

const function folderOf(Character: Model): Folder
    const Existing = Character:FindFirstChild(Tools.FolderName)
    if Existing and Existing:IsA("Folder") then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = Tools.FolderName
    Made.Parent = Character
    return Made
end

const function weld(Model: Model, Part: BasePart, Offset: CFrame)
    const Root = Model.PrimaryPart
    if not Root then
        return
    end
    const Old = Root:FindFirstChild("HoldWeld")
    if Old then
        Old:Destroy()
    end
    const Joint = Instance.new("Weld")
    Joint.Name = "HoldWeld"
    Joint.Part0 = Part
    Joint.Part1 = Root
    Joint.C0 = Offset
    Root.CFrame = Part.CFrame * Offset
    Joint.Parent = Root
end

const function clearHolsters(Owner: Owner)
    for Id, Model in Owner.Holsters do
        Owner.Holsters[Id] = nil
        Model:Destroy()
    end
end

const function holster(Owner: Owner)
    clearHolsters(Owner)
    const Character = Owner.Player.Character
    if not Character or not Character.Parent then
        return
    end
    for Slot in dataOf(Owner).Slots do
        if Slot == Owner.Slot then
            continue
        end
        const Build = buildOf(Owner, Slot)
        const Spot = if Build then Build.Holster else nil
        if not Build or not Spot or not Spot.On then
            continue
        end
        const Part = Character:FindFirstChild(Spot.Attach)
        if not Part or not Part:IsA("BasePart") then
            continue
        end
        const Model = ToolData.assemble(Build)
        if not Model then
            continue
        end
        Model.Name = `Holster_{Slot}`
        if math.abs(Spot.Size - 1) > 1e-3 then
            Model:ScaleTo(Spot.Size)
        end
        weld(Model, Part, Format.frame(Spot.Offset))
        Model.Parent = folderOf(Character)
        Owner.Holsters[Slot] = Model
    end
end

const function hook(ToolId: string?, Name: string, ...: any)
    const Def = if ToolId then ToolData.get(ToolId) else nil
    const Server = if Def then Def.server else nil
    const Run = if Server then Server[Name] else nil
    if type(Run) == "function" then
        const Ok, Problem = pcall(Run, ...)
        if not Ok then
            warn(`[Tools] {ToolId} {Name} failed: {Problem}`)
        end
    end
end

const function unequip(Owner: Owner)
    const Was = Owner.Equipped
    const Model = Owner.Model
    Owner.Equipped = nil
    Owner.Slot = nil
    Owner.Model = nil
    Owner.Stats = {}
    if Model then
        Model:Destroy()
    end
    const Character = Owner.Player.Character
    if Character then
        Character:SetAttribute(Tools.EquippedAttribute, nil)
    end
    if Was then
        hook(Was, "onUnequip", Owner.Player)
    end
end

const function equip(Owner: Owner, Slot: string): string?
    const Character = Owner.Player.Character
    const Hand = if Character then Character:FindFirstChild("RightHand") else nil
    const Humanoid = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
    if not Character or not Hand or not Hand:IsA("BasePart") or not Humanoid or Humanoid.Health <= 0 then
        return "You need to be spawned in"
    end
    const Build = buildOf(Owner, Slot)
    const ToolId = if Build then Build.Tool else ""
    const Def = ToolData.get(ToolId)
    if not Def or not Build then
        return "That slot is empty"
    end
    if not ownsFor(Owner)(Def.Pack) then
        return `You need the {Def.Pack} pack for that`
    end
    unequip(Owner)
    const Model = ToolData.assemble(Build)
    if not Model then
        return "That tool could not be built"
    end
    Model.Name = `Equipped_{ToolId}`
    weld(Model, Hand, ToolData.grip(Def, Hand))
    Model.Parent = folderOf(Character)
    Owner.Equipped = ToolId
    Owner.Slot = Slot
    Owner.Model = Model
    Owner.Stats = ToolData.stats(Build)
    Character:SetAttribute(Tools.EquippedAttribute, ToolId)
    hook(ToolId, "onEquip", Owner.Player, Model)
    return nil
end

const function rewire(Owner: Owner)
    if Owner.Queued then
        return
    end
    Owner.Queued = true
    task.defer(function()
        Owner.Queued = false
        const Character = Owner.Player.Character
        const Model = Owner.Model
        const Hand = if Character then Character:FindFirstChild("RightHand") else nil
        const ToolId = Owner.Equipped
        const Def = if ToolId then ToolData.get(ToolId) else nil
        if Model and Def and Hand and Hand:IsA("BasePart") then
            weld(Model, Hand, ToolData.grip(Def, Hand))
        end
        holster(Owner)
    end)
end

const function watch(Owner: Owner, Character: Model)
    for _, Link in Owner.Links do
        Link:Disconnect()
    end
    table.clear(Owner.Links)
    Owner.Equipped = nil
    Owner.Slot = nil
    Owner.Model = nil
    table.clear(Owner.Holsters)
    table.insert(Owner.Links, Character.ChildAdded:Connect(function(Child: Instance)
        if Child:IsA("BasePart") and Format.isBody(Child.Name) then
            rewire(Owner)
        end
    end))
    task.spawn(function()
        if not Character:WaitForChild("RightHand", 10) then
            return
        end
        rewire(Owner)
        push(Owner)
    end)
end

const function slotKey(Slot: unknown): string?
    if type(Slot) ~= "number" or Slot ~= math.floor(Slot) or Slot < 1 or Slot > ToolData.Config.Slots then
        return nil
    end
    return tostring(Slot)
end

const function set(Player: Player, Slot: unknown, Raw: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Key = slotKey(Slot)
    if not Key then
        return fail("That slot does not exist")
    end
    const ToolId = if type(Raw) == "table" then (Raw :: any).Tool else nil
    const Def = ToolData.get(ToolId)
    if not Def or type(ToolId) ~= "string" then
        return fail("That tool does not exist")
    end
    if not ownsFor(Owner)(Def.Pack) then
        return fail(`You need the {Def.Pack} pack for that`)
    end
    const Clean = ToolData.clean(ToolId, Raw, ownsFor(Owner))
    if not Clean then
        return fail("That tool could not be saved")
    end
    dataOf(Owner).Slots[Key] = Clean
    if Owner.Slot == Key then
        equip(Owner, Key)
    end
    holster(Owner)
    push(Owner)
    return { Ok = true, Build = Clean }
end

const function clear(Player: Player, Slot: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Key = slotKey(Slot)
    if not Key then
        return fail("That slot does not exist")
    end
    if Owner.Slot == Key then
        unequip(Owner)
    end
    dataOf(Owner).Slots[Key] = nil
    holster(Owner)
    push(Owner)
    return { Ok = true }
end

const function equipSlot(Player: Player, Slot: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const Now = os.clock()
    if Now - Owner.Stamp < ToolData.Config.EquipCooldown and Slot ~= nil then
        return fail("Slow down a little")
    end
    Owner.Stamp = Now
    const Key = slotKey(Slot)
    if not Key or Key == Owner.Slot or not dataOf(Owner).Slots[Key] then
        unequip(Owner)
        holster(Owner)
        push(Owner)
        return { Ok = true }
    end
    const Problem = equip(Owner, Key)
    holster(Owner)
    push(Owner)
    if Problem then
        return fail(Problem)
    end
    return { Ok = true, Tool = Owner.Equipped }
end

const function loadSave(Player: Player, Slot: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    if type(Slot) ~= "number" then
        return fail("That save does not exist")
    end
    const Save = Owner.Data.LookSaves[tostring(Slot)]
    if not Save then
        return fail("That save does not exist")
    end
    const Saved = Save.Tools
    if type(Saved) ~= "table" then
        return { Ok = true }
    end
    const Owns = ownsFor(Owner)
    const Slots: { [string]: ToolBuild } = {}
    for Key, Build in Saved do
        const Number = tonumber(Key)
        if Number and slotKey(Number) and type(Build) == "table" and type(Build.Tool) == "string" then
            Slots[Key] = ToolData.clean(Build.Tool, Build, Owns)
        end
    end
    unequip(Owner)
    dataOf(Owner).Slots = Slots
    holster(Owner)
    push(Owner)
    return { Ok = true }
end

const function fire(Player: Player, Origin: unknown, Hit: unknown, Normal: unknown)
    const Owner = Owners[Player]
    const Model = if Owner then Owner.Model else nil
    const Character = Player.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    if not Owner or not Model or not Owner.Equipped or typeof(Origin) ~= "Vector3" or typeof(Hit) ~= "Vector3" then
        return
    end
    if not Root or not Root:IsA("BasePart") or (Origin - Root.Position).Magnitude > Tools.MaxMuzzleGap then
        return
    end
    const Stats = Owner.Stats
    if type(Stats.Bullet) ~= "string" then
        return
    end
    const Now = os.clock()
    if Now - Owner.Fired < (Stats.FireRate or 0.2) * Tools.FireSlack then
        return
    end
    Owner.Fired = Now
    const Range = (Stats.Range or 500) + 5
    const Gap = Hit - Origin
    const Landed = if Gap.Magnitude > Range then Origin + Gap.Unit * Range else Hit
    const Side = if typeof(Normal) == "Vector3" then Normal else nil
    hook(Owner.Equipped, "onFire", Player, Model, { Origin = Origin, Hit = Landed, Normal = Side }, Stats)
    const Near: { Player } = {}
    const Reach = Stats.RelayRange or Tools.RelayRange
    for _, Other in Players:GetPlayers() do
        const Body = Other.Character
        const Spot = if Body then Body:FindFirstChild("HumanoidRootPart") else nil
        if Other ~= Player and Spot and Spot:IsA("BasePart") and ((Spot.Position - Origin).Magnitude <= Reach or (Spot.Position - Landed).Magnitude <= Reach) then
            table.insert(Near, Other)
        end
    end
    if #Near > 0 then
        BulletNet:BroadcastTo(Near, "@Bullets/Shot", Player, Origin, Landed, Side, Stats.Bullet)
    end
end

const function act(Player: Player, Id: unknown, Value: unknown)
    const Owner = Owners[Player]
    if not Owner or type(Id) ~= "string" or not Owner.Equipped or not Owner.Model then
        return
    end
    hook(Owner.Equipped, "onAction", Player, Owner.Model, Id, Value)
end

function Tools.equipped(Player: Player): (string?, Model?)
    const Owner = Owners[Player]
    if not Owner then
        return nil, nil
    end
    return Owner.Equipped, Owner.Model
end

function Tools.snapshot(Player: Player): { [string]: ToolBuild }?
    const Owner = Owners[Player]
    if not Owner then
        return nil
    end
    const Copy: { [string]: ToolBuild } = {}
    for Key in dataOf(Owner).Slots do
        const Build = buildOf(Owner, Key)
        if Build then
            Copy[Key] = Build
        end
    end
    return Copy
end

function Tools.attach(Player: Player, Data: PlayerData)
    if Owners[Player] then
        return
    end
    const Owner: Owner = {
        Player = Player,
        Data = Data,
        Equipped = nil,
        Slot = nil,
        Model = nil,
        Stats = {},
        Fired = 0,
        Holsters = {},
        Stamp = 0,
        Links = {},
        Queued = false,
    }
    Owners[Player] = Owner
    dataOf(Owner).Slots = {}
    Player.CharacterAdded:Connect(function(Character: Model)
        if Owners[Player] == Owner then
            watch(Owner, Character)
        end
    end)
    const Character = Player.Character
    if Character then
        watch(Owner, Character)
    end
    push(Owner)
end

function Tools.detach(Player: Player)
    const Owner = Owners[Player]
    Owners[Player] = nil
    if Owner then
        for _, Link in Owner.Links do
            Link:Disconnect()
        end
    end
end

function Tools.start()
    if Started then
        return
    end
    Started = true
    Net:When("@Tools/Set", set)
    Net:When("@Tools/Clear", clear)
    Net:When("@Tools/Equip", equipSlot)
    Net:When("@Tools/LoadSave", loadSave)
    Net:On("@Tools/Action", act)
    Net:On("@Tools/Fire", fire)
    Players.PlayerRemoving:Connect(Tools.detach)
end

return Tools
