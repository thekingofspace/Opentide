--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const signal = require(ReplicatedStorage.MainPackages.signal)
const ToolData = require(ReplicatedStorage.Shared.Tools)
const Format = require(ReplicatedStorage.Shared.Customize.Format)
const PropConfig = require(ReplicatedStorage.Shared.PropData.Config)

export type Result = {
    Ok: boolean,
    Error: string?,
    Build: ToolBuild?,
    Tool: string?,
}

type Hand = "Right" | "Left"

export type Held = {
    Tool: string,
    Slot: string,
    Model: Model,
    Stats: { [string]: any },
    Fired: number,
}

type Owner = {
    Player: Player,
    Data: PlayerData,
    Equipped: string?,
    Slot: string?,
    Hands: { [Hand]: Held },
    Holsters: { [string]: Model },
    Hidden: { [string]: boolean },
    Stamp: number,
    Links: { RBXScriptConnection },
    Queued: boolean,
}

const Tools = {
    FolderName = "Tools",
    EquippedAttribute = "EquippedTool",
    OffhandAttribute = "EquippedOffhand",
    MaxMuzzleGap = 15,
    FireSlack = 0.7,
    RelayRange = 400,
    ShownAttribute = "ShownAlpha",
    Changed = signal.new(),
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
    if type(Data.Links) ~= "table" then
        Data.Links = {}
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

const function linksOf(Owner: Owner): { [string]: string }
    return dataOf(Owner).Links :: { [string]: string }
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

const function partnerOf(Owner: Owner, Slot: string): string?
    const Links = linksOf(Owner)
    const Other = Links[Slot]
    if not Other then
        return nil
    end
    const Slots = dataOf(Owner).Slots
    const First = Slots[Slot]
    const Second = Slots[Other]
    if Other == Slot or not First or not Second or not ToolData.canPair(First.Tool, Second.Tool) then
        Links[Slot] = nil
        if Links[Other] == Slot then
            Links[Other] = nil
        end
        return nil
    end
    return Other
end

const function heldSlots(Owner: Owner): { [string]: boolean }
    const Made: { [string]: boolean } = {}
    for _, Item in Owner.Hands do
        Made[Item.Slot] = true
    end
    return Made
end

const function push(Owner: Owner)
    const Data = dataOf(Owner)
    for Slot in Data.Slots do
        partnerOf(Owner, Slot)
    end
    const Hands: { [string]: string } = {}
    for Hand, Item in Owner.Hands do
        Hands[Hand] = Item.Slot
    end
    Net:BroadcastTo(Owner.Player, "@Tools/State", {
        Slots = Data.Slots,
        Equipped = Owner.Slot,
        Links = Data.Links,
        Hands = Hands,
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

const function conceal(Model: Model, On: boolean)
    for _, Item in Model:GetDescendants() do
        if not Item:IsA("BasePart") and not Item:IsA("Decal") then
            continue
        end
        const Piece = Item :: BasePart | Decal
        const Saved = Piece:GetAttribute(Tools.ShownAttribute)
        if On then
            if type(Saved) ~= "number" then
                Piece:SetAttribute(Tools.ShownAttribute, Piece.Transparency)
            end
            Piece.Transparency = 1
        elseif type(Saved) == "number" then
            Piece.Transparency = Saved
            Piece:SetAttribute(Tools.ShownAttribute, nil)
        end
    end
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
    const Holding = heldSlots(Owner)
    for Slot in dataOf(Owner).Slots do
        if Holding[Slot] or Owner.Hidden[Slot] then
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
    const Hands = Owner.Hands
    Owner.Hands = {}
    Owner.Equipped = nil
    Owner.Slot = nil
    for _, Item in Hands do
        Item.Model:Destroy()
        hook(Item.Tool, "onUnequip", Owner.Player)
    end
    const Character = Owner.Player.Character
    if Character then
        Character:SetAttribute(Tools.EquippedAttribute, nil)
        Character:SetAttribute(Tools.OffhandAttribute, nil)
    end
end

const function place(Owner: Owner, Character: Model, Slot: string, Build: ToolBuild, Hand: Hand): string?
    const Def = ToolData.get(Build.Tool)
    const Part = Character:FindFirstChild(`{Hand}Hand`)
    if not Def or not Part or not Part:IsA("BasePart") then
        return "That tool could not be held"
    end
    const Model = ToolData.assemble(Build)
    if not Model then
        return "That tool could not be built"
    end
    Model.Name = `Equipped_{Hand}`
    Model:SetAttribute("ToolSlot", Slot)
    weld(Model, Part, ToolData.grip(Def, Part))
    if Owner.Hidden[Slot] then
        conceal(Model, true)
    end
    Model.Parent = folderOf(Character)
    Owner.Hands[Hand] = {
        Tool = Build.Tool,
        Slot = Slot,
        Model = Model,
        Stats = ToolData.stats(Build),
        Fired = 0,
    }
    hook(Build.Tool, "onEquip", Owner.Player, Model, Hand)
    return nil
end

const function equip(Owner: Owner, Slot: string): string?
    const Character = Owner.Player.Character
    const Humanoid = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
    if not Character or not Humanoid or Humanoid.Health <= 0 then
        return "You need to be spawned in"
    end
    const Build = buildOf(Owner, Slot)
    const Def = if Build then ToolData.get(Build.Tool) else nil
    if not Def or not Build then
        return "That slot is empty"
    end
    const Owns = ownsFor(Owner)
    if not Owns(Def.Pack) then
        return `You need the {Def.Pack} pack for that`
    end
    unequip(Owner)
    const Partner = partnerOf(Owner, Slot)
    const Other = if Partner then buildOf(Owner, Partner) else nil
    const OtherDef = if Other then ToolData.get(Other.Tool) else nil
    const Paired = Partner ~= nil and Other ~= nil and OtherDef ~= nil and Owns(OtherDef.Pack)
    const MainHand, OffHand = ToolData.hands(Build.Tool, if Paired and Other then Other.Tool else nil)
    const Problem = place(Owner, Character, Slot, Build, MainHand)
    if Problem then
        unequip(Owner)
        return Problem
    end
    if Paired and Partner and Other then
        place(Owner, Character, Partner, Other, OffHand)
    end
    Owner.Equipped = Build.Tool
    Owner.Slot = Slot
    Character:SetAttribute(Tools.EquippedAttribute, Build.Tool)
    Character:SetAttribute(Tools.OffhandAttribute, if Paired and Other then Other.Tool else nil)
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
        if Character then
            for Hand, Item in Owner.Hands do
                const Part = Character:FindFirstChild(`{Hand}Hand`)
                const Def = ToolData.get(Item.Tool)
                if Def and Part and Part:IsA("BasePart") then
                    weld(Item.Model, Part, ToolData.grip(Def, Part))
                end
            end
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
    Owner.Hands = {}
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

const function refreshHeld(Owner: Owner, Touched: { string })
    const Holding = heldSlots(Owner)
    for _, Key in Touched do
        if Holding[Key] then
            const Main = Owner.Slot
            if Main and dataOf(Owner).Slots[Main] then
                equip(Owner, Main)
            else
                unequip(Owner)
            end
            return
        end
    end
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
    Tools.Changed:Fire(Player, { Key })
    partnerOf(Owner, Key)
    refreshHeld(Owner, { Key })
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
    if heldSlots(Owner)[Key] then
        unequip(Owner)
    end
    dataOf(Owner).Slots[Key] = nil
    Tools.Changed:Fire(Player, { Key })
    partnerOf(Owner, Key)
    holster(Owner)
    push(Owner)
    return { Ok = true }
end

const function link(Player: Player, First: unknown, Second: unknown): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    const A = slotKey(First)
    const B = slotKey(Second)
    if not A or not B or A == B then
        return fail("Pick two different slots")
    end
    const Slots = dataOf(Owner).Slots
    const ToolA = Slots[A]
    const ToolB = Slots[B]
    if not ToolA or not ToolB then
        return fail("Both slots need a tool")
    end
    const Holding = heldSlots(Owner)
    if Holding[A] or Holding[B] then
        return fail("Put your tool away to link it")
    end
    if not ToolData.canPair(ToolA.Tool, ToolB.Tool) then
        const NameA = ToolData.get(ToolA.Tool)
        const NameB = ToolData.get(ToolB.Tool)
        return fail(`{if NameA then string.lower(NameA.Name) else "that"} and {if NameB then string.lower(NameB.Name) else "that"} can not be held together`)
    end
    const Links = linksOf(Owner)
    for _, Key in { A, B } do
        const Old = Links[Key]
        if Old then
            Links[Old] = nil
            Links[Key] = nil
        end
    end
    Links[A] = B
    Links[B] = A
    refreshHeld(Owner, { A, B })
    holster(Owner)
    push(Owner)
    return { Ok = true }
end

const function unlink(Player: Player, Slot: unknown): Result
    const Owner = Owners[Player]
    const Key = slotKey(Slot)
    if not Owner or not Key then
        return fail("That slot does not exist")
    end
    const Links = linksOf(Owner)
    const Other = Links[Key]
    Links[Key] = nil
    if Other then
        Links[Other] = nil
    end
    const Holding = heldSlots(Owner)
    if Holding[Key] or (Other and Holding[Other]) then
        unequip(Owner)
    end
    holster(Owner)
    push(Owner)
    return { Ok = true }
end

const function unlinkAll(Player: Player): Result
    const Owner = Owners[Player]
    if not Owner then
        return fail("Your data is still loading")
    end
    dataOf(Owner).Links = {}
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
    if not Key or heldSlots(Owner)[Key] or not dataOf(Owner).Slots[Key] then
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
    const Hands: { [string]: string } = {}
    for Hand, Item in Owner.Hands do
        Hands[Hand] = Item.Slot
    end
    return { Ok = true, Tool = Owner.Equipped, Hands = Hands } :: any
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
    const Data = dataOf(Owner)
    const Old: { string } = {}
    for Key in Data.Slots do
        table.insert(Old, Key)
    end
    Data.Slots = Slots
    Data.Links = {}
    Tools.Changed:Fire(Player, Old)
    holster(Owner)
    push(Owner)
    return { Ok = true }
end

const function heldBy(Owner: Owner, Hand: unknown): Held?
    if Hand == "Right" or Hand == "Left" then
        return Owner.Hands[Hand]
    end
    const Main = Owner.Slot
    for _, Item in Owner.Hands do
        if Item.Slot == Main then
            return Item
        end
    end
    return nil
end

const function fire(Player: Player, Origin: unknown, Hit: unknown, Normal: unknown, Hand: unknown)
    const Owner = Owners[Player]
    const Item = if Owner then heldBy(Owner, Hand) else nil
    const Character = Player.Character
    const Root = if Character then Character:FindFirstChild("HumanoidRootPart") else nil
    if not Owner or not Item or typeof(Origin) ~= "Vector3" or typeof(Hit) ~= "Vector3" then
        return
    end
    if not Root or not Root:IsA("BasePart") or (Origin - Root.Position).Magnitude > Tools.MaxMuzzleGap then
        return
    end
    const Stats = Item.Stats
    if type(Stats.Bullet) ~= "string" then
        return
    end
    const Now = os.clock()
    if Now - Item.Fired < (Stats.FireRate or 0.2) * Tools.FireSlack then
        return
    end
    Item.Fired = Now
    const Range = (Stats.Range or 500) + 5
    const Gap = Hit - Origin
    const Landed = if Gap.Magnitude > Range then Origin + Gap.Unit * Range else Hit
    const Side = if typeof(Normal) == "Vector3" then Normal else nil
    hook(Item.Tool, "onFire", Player, Item.Model, { Origin = Origin, Hit = Landed, Normal = Side }, Stats)
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

const function act(Player: Player, Id: unknown, Value: unknown, Hand: unknown)
    const Owner = Owners[Player]
    const Item = if Owner then heldBy(Owner, Hand) else nil
    if not Item or type(Id) ~= "string" then
        return
    end
    hook(Item.Tool, "onAction", Player, Item.Model, Id, Value)
end

function Tools.held(Player: Player, Hand: unknown): (Held?, ToolBuild?)
    const Owner = Owners[Player]
    const Item = if Owner then heldBy(Owner, Hand) else nil
    if not Owner or not Item then
        return nil, nil
    end
    return Item, buildOf(Owner, Item.Slot)
end

function Tools.build(Player: Player, Slot: string): ToolBuild?
    const Owner = Owners[Player]
    return if Owner then buildOf(Owner, Slot) else nil
end

function Tools.hide(Player: Player, Slot: string, On: boolean)
    const Owner = Owners[Player]
    if not Owner or (Owner.Hidden[Slot] == true) == On then
        return
    end
    Owner.Hidden[Slot] = if On then true else nil
    for _, Item in Owner.Hands do
        if Item.Slot == Slot then
            conceal(Item.Model, On)
        end
    end
    holster(Owner)
end

function Tools.equipped(Player: Player): (string?, Model?)
    const Owner = Owners[Player]
    const Item = if Owner then heldBy(Owner, nil) else nil
    if not Owner or not Item then
        return nil, nil
    end
    return Owner.Equipped, Item.Model
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
        Hands = {},
        Holsters = {},
        Hidden = {},
        Stamp = 0,
        Links = {},
        Queued = false,
    }
    Owners[Player] = Owner
    const Fresh = dataOf(Owner)
    Fresh.Slots = {}
    Fresh.Links = {}
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
    Net:When("@Tools/Link", link)
    Net:When("@Tools/Unlink", unlink)
    Net:When("@Tools/UnlinkAll", unlinkAll)
    Net:When("@Tools/LoadSave", loadSave)
    Net:On("@Tools/Action", act)
    Net:On("@Tools/Fire", fire)
    Players.PlayerRemoving:Connect(Tools.detach)
end

return Tools
