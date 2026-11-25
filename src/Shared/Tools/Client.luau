--!strict
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const vision = require(ReplicatedStorage.MainPackages.vision)
const signal = require(ReplicatedStorage.MainPackages.signal)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const AnimationController = require(ReplicatedStorage.Shared.AnimationController)
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)
const Library = require(ReplicatedStorage.Shared.AnimationController.Library)
const LocalAnimations = require(ReplicatedStorage.Shared.AnimationController.LocalAnimations)
const Sounds = require(ReplicatedStorage.Shared.Sounds)
const Tools = require(script.Parent)
const Bridges = require(script.Parent.Bridges)
const Bullets = require(script.Parent.Guns.Bullets)
const Assets = require(script.Parent.Assets)
const View = require(ReplicatedStorage.Shared.GUI_Elements.Tools)

export type Context = {
    Id: string,
    Slot: string,
    Def: Tools.ToolDef,
    Data: { [any]: any },
    States: { [string]: boolean },
    Labels: { [string]: string },
    setLabel: (Id: string, Text: string?) -> (),
    play: (Name: string, Options: AnimationController.ActionOptions?) -> AnimationTrack?,
    stop: (Name: string) -> (),
    pushSet: (Name: string) -> (),
    popSet: (Name: string) -> (),
    active: (Id: string) -> boolean,
    setActive: (Id: string, On: boolean) -> (),
    send: (Id: string, Value: any?) -> (),
    model: () -> Model?,
    mount: (Path: string) -> Attachment?,
    stats: () -> { [string]: any },
    fire: (Shot: Bullets.Shot) -> (),
}

const Client = {
    SetPriority = 10,
    PutAwayWait = 0.36,
    Keys = {
        [Enum.KeyCode.One] = 1,
        [Enum.KeyCode.Two] = 2,
        [Enum.KeyCode.Three] = 3,
        [Enum.KeyCode.Four] = 4,
        [Enum.KeyCode.Five] = 5,
    } :: { [Enum.KeyCode]: number },
    Changed = signal.new(),
    Equipped = signal.new(),
}

const Net = NetWatch.Tools
const BulletNet = NetWatch.Bullets
local Slots: { [string]: ToolBuild } = {}
local EquippedSlot: string? = nil
local Current: Context? = nil
local Busy = false
local Blocked = false
const BlockedBy: { [string]: boolean } = {}
local Open = true
local ActionsOpen = true
local Started = false
const Sequences: { [string]: KeyframeSequence } = {}
const Previews: { [string]: { Hash: string, Model: Model } } = {}
const SetNames: { [string]: boolean } = {}

const function controller(): AnimationController.Controller
    return LocalAnimations.get() or LocalAnimations.start()
end

function Client.clip(ToolId: string, Name: string): AnimationController.Clip?
    const Key = `{ToolId}_{Name}`
    const Known = Library.get(Key)
    if Known ~= nil then
        return Known
    end
    const Def = Tools.get(ToolId)
    const Value = if Def and Def.Clips then Def.Clips[Name] else nil
    if type(Value) == "string" or type(Value) == "number" then
        return Value
    end
    if type(Value) ~= "table" then
        return nil
    end
    const Built = Sequences[Key]
    if Built then
        return Built
    end
    const Spec = table.clone(Value :: Clips.Spec)
    Spec.Name = Key
    const Made = Clips.sequence(Spec)
    Sequences[Key] = Made
    return Made
end

const function slotTable(ToolId: string, Spec: Tools.SetSpec): AnimationController.SlotTable
    const function convert(Modes: { [string]: string }?): { [string]: AnimationController.Slot }?
        if not Modes then
            return nil
        end
        const Made: { [string]: AnimationController.Slot } = {}
        for Mode, Name in Modes do
            const Clip = Client.clip(ToolId, Name)
            if Clip ~= nil then
                Made[Mode] = Clip
            end
        end
        return Made
    end
    return { Full = convert(Spec.Full), Legs = convert(Spec.Legs), Body = convert(Spec.Body) }
end

const function hook(Context: Context, Name: string, ...: any)
    const Hooks = Context.Def.client
    const Run = if Hooks then Hooks[Name] else nil
    if type(Run) ~= "function" then
        return
    end
    const Ok, Problem = pcall(Run, Context, ...)
    if not Ok then
        warn(`[Tools] {Context.Id} {Name} failed: {Problem}`)
    end
end

const function equippedModel(): Model?
    const Character = Players.LocalPlayer.Character
    const Folder = if Character then Character:FindFirstChild("Tools") else nil
    const Current2 = Current
    if not Folder or not Current2 then
        return nil
    end
    const Found = Folder:FindFirstChild(`Equipped_{Current2.Id}`)
    return if Found and Found:IsA("Model") then Found else nil
end

const function refreshBar()
    const Context = Current
    if not Context or Blocked then
        View.ActionBar(false)
        return
    end
    const Actions: { Bridges.ActionView } = {}
    for _, Action in Context.Def.Actions or {} do
        table.insert(Actions, {
            Id = Action.Id,
            Label = Context.Labels[Action.Id] or Action.Label,
            Key = if Action.Key then Action.Key.Name else nil,
            On = Context.States[Action.Id] == true,
        })
    end
    if #Actions == 0 then
        View.ActionBar(false)
        return
    end
    View.ActionBar({ Actions = Actions })
    View.ActionBarOpen(ActionsOpen)
end

const function makeContext(ToolId: string, Def: Tools.ToolDef, Slot: string): Context
    const Pushed: { [string]: boolean } = {}
    const Played: { [string]: boolean } = {}
    const Stats = Tools.stats(Slots[Slot])
    const Context: Context = {
        Id = ToolId,
        Slot = Slot,
        Def = Def,
        Data = {},
        States = {},
        Labels = {},
        setLabel = function(Id: string, Text: string?)
            const Here = Current
            if Here and Here.Id == ToolId then
                Here.Labels[Id] = Text
                refreshBar()
            end
        end,
        play = function(Name: string, Options: AnimationController.ActionOptions?): AnimationTrack?
            const Clip = Client.clip(ToolId, Name)
            if Clip == nil then
                return nil
            end
            const Given: AnimationController.ActionOptions = Options or {}
            Played[Name] = true
            return controller():play(`Tool_{Name}`, Clip, {
                Part = Given.Part or "Body",
                Priority = Given.Priority,
                Speed = Given.Speed,
                Weight = Given.Weight,
                FadeTime = Given.FadeTime,
                Looped = Given.Looped,
            })
        end,
        stop = function(Name: string)
            controller():stop(`Tool_{Name}`)
        end,
        pushSet = function(Name: string)
            const Spec = if Def.Sets then Def.Sets[Name] else nil
            if not Spec then
                return
            end
            const Key = `Tool_{ToolId}_{Name}`
            Pushed[Key] = true
            SetNames[Key] = true
            controller():pushSet(Key, slotTable(ToolId, Spec), Client.SetPriority)
        end,
        popSet = function(Name: string)
            const Key = `Tool_{ToolId}_{Name}`
            Pushed[Key] = nil
            controller():popSet(Key)
        end,
        active = function(Id: string): boolean
            return Current ~= nil and (Current :: Context).States[Id] == true
        end,
        setActive = function(Id: string, On: boolean)
            const Here = Current
            if Here and Here.Id == ToolId then
                Here.States[Id] = On
                refreshBar()
            end
        end,
        send = function(Id: string, Value: any?)
            Net:Emit("@Tools/Action", Id, Value)
        end,
        model = equippedModel,
        stats = function(): { [string]: any }
            return Stats
        end,
        fire = function(Shot: Bullets.Shot)
            Net:Emit("@Tools/Fire", Shot.Origin, Shot.Hit, Shot.Normal)
        end,
        mount = function(Path: string): Attachment?
            const Model = equippedModel()
            if not Model then
                return nil
            end
            for _, Item in Model:GetDescendants() do
                if Item:IsA("Attachment") and Item:GetAttribute(Tools.MountAttribute) == Path then
                    return Item
                end
            end
            return nil
        end,
    }
    Context.Data.Pushed = Pushed
    Context.Data.Played = Played
    return Context
end

const function finish(Context: Context)
    hook(Context, "onUnequip")
    const Animations = LocalAnimations.get()
    if Animations then
        for Key in SetNames do
            if string.sub(Key, 1, #`Tool_{Context.Id}_`) == `Tool_{Context.Id}_` then
                Animations:popSet(Key)
            end
        end
        const Played: { [string]: boolean } = Context.Data.Played or {}
        const Def = Context.Def
        for Name in Played do
            if Name ~= Def.Unequip then
                Animations:stop(`Tool_{Name}`)
            end
        end
    end
    if Current == Context then
        Current = nil
    end
    refreshBar()
    Client.Equipped:Fire(nil)
end

const function begin(ToolId: string, Slot: string)
    const Def = Tools.get(ToolId)
    if not Def then
        return
    end
    const Context = makeContext(ToolId, Def, Slot)
    Current = Context
    if Def.Equip then
        Context.play(Def.Equip)
    end
    Sounds.play("ToolEquip")
    hook(Context, "onEquip")
    refreshBar()
    Client.Equipped:Fire(ToolId)
end

function Client.preview(Key: string, Build: ToolBuild?): Model?
    if not Build then
        return nil
    end
    const Hash = HttpService:JSONEncode({ Build.Tool, Build.Parts })
    const Known = Previews[Key]
    if Known and Known.Hash == Hash then
        return Known.Model
    end
    if Known then
        Known.Model:Destroy()
    end
    const Made = Tools.assemble(Build)
    if not Made then
        Previews[Key] = nil
        return nil
    end
    Made:SetAttribute("BuildHash", Hash)
    Previews[Key] = { Hash = Hash, Model = Made }
    return Made
end

function Client.refresh()
    const Views: { Bridges.SlotView } = {}
    for Slot = 1, Tools.Config.Slots do
        const Key = tostring(Slot)
        const Build = Slots[Key]
        const Def = if Build then Tools.get(Build.Tool) else nil
        table.insert(Views, {
            Slot = Slot,
            Name = if Def then string.lower(Def.Name) else "empty",
            Tool = if Def and Build then Build.Tool else nil,
            Model = if Def then Client.preview(`slot{Key}`, Build) else nil,
            Active = Current ~= nil and (Current :: Context).Slot == Key,
        })
    end
    View.HotbarSlots(Views)
    View.HotbarShown(not Blocked)
    View.HotbarOpen(Open)
    refreshBar()
end

function Client.current(): Context?
    return Current
end

function Client.slots(): { [string]: ToolBuild }
    return Slots
end

function Client.allows(Flag: string): boolean
    const Context = Current
    if not Context then
        return true
    end
    return (Context.Def :: any)[Flag] == true
end

function Client.unequip()
    const Context = Current
    if not Context or Busy then
        return
    end
    Busy = true
    if Context.Def.Unequip then
        Context.play(Context.Def.Unequip)
        Sounds.play("ToolPutAway")
        task.wait(Client.PutAwayWait)
    end
    Net:Call("@Tools/Equip", nil)
    if Current == Context then
        finish(Context)
    end
    Busy = false
    Client.refresh()
end

function Client.unequipNow()
    const Context = Current
    if Context then
        finish(Context)
    end
    if EquippedSlot or Context then
        Net:Call("@Tools/Equip", nil)
        EquippedSlot = nil
    end
end

function Client.equip(Slot: number)
    if Busy or Blocked then
        return
    end
    const Key = tostring(Slot)
    const Build = Slots[Key]
    const ToolId = if Build then Build.Tool else nil
    const Context = Current
    if Context and (not ToolId or Context.Slot == Key) then
        Client.unequip()
        return
    end
    if not ToolId then
        return
    end
    Busy = true
    if Context then
        finish(Context)
    end
    const Reply = Net:Call("@Tools/Equip", Slot)
    Busy = false
    if type(Reply) == "table" and Reply.Ok and Reply.Tool == ToolId then
        begin(ToolId, Key)
    elseif type(Reply) == "table" and type(Reply.Error) == "string" then
        warn(`[Tools] {Reply.Error}`)
    end
    Client.refresh()
end

function Client.blockInput(Reason: string, Value: boolean)
    BlockedBy[Reason] = if Value then true else nil
end

function Client.setBlocked(Value: boolean)
    Blocked = Value
    Client.refresh()
end

function Client.setSlot(Slot: number, Build: ToolBuild): (boolean, string?)
    const Reply = Net:Call("@Tools/Set", Slot, Build)
    if type(Reply) ~= "table" then
        return false, "The server did not answer"
    end
    if not Reply.Ok then
        return false, if type(Reply.Error) == "string" then Reply.Error else "That slot could not be set"
    end
    if type(Reply.Build) == "table" then
        Slots[tostring(Slot)] = Reply.Build
    end
    Client.Changed:Fire()
    Client.refresh()
    return true, nil
end

function Client.loadSave(Slot: number): (boolean, string?)
    Client.unequipNow()
    const Reply = Net:Call("@Tools/LoadSave", Slot)
    if type(Reply) ~= "table" or not Reply.Ok then
        return false, if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "Those tools could not be loaded"
    end
    return true, nil
end

function Client.clearSlot(Slot: number): (boolean, string?)
    const Reply = Net:Call("@Tools/Clear", Slot)
    if type(Reply) ~= "table" or not Reply.Ok then
        return false, if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "That slot could not be cleared"
    end
    Slots[tostring(Slot)] = nil
    Client.Changed:Fire()
    Client.refresh()
    return true, nil
end

const function action(Id: string)
    const Context = Current
    if not Context or Blocked then
        return
    end
    local Found: Tools.Action? = nil
    for _, Entry in Context.Def.Actions or {} do
        if Entry.Id == Id then
            Found = Entry
        end
    end
    if not Found then
        return
    end
    if Found.Toggle then
        Context.States[Id] = not Context.States[Id]
    end
    Sounds.play("ToggleOn")
    hook(Context, "onAction", Id, Context.States[Id] == true)
    refreshBar()
end

const function onInput(Input: InputObject, Processed: boolean)
    if Processed or Blocked or next(BlockedBy) ~= nil then
        return
    end
    const Slot = Client.Keys[Input.KeyCode]
    if Slot then
        task.spawn(Client.equip, Slot)
        return
    end
    const Context = Current
    if not Context or Busy then
        return
    end
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        hook(Context, "onActivate")
        return
    end
    for _, Entry in Context.Def.Actions or {} do
        if Entry.Key and Entry.Key == Input.KeyCode then
            action(Entry.Id)
            return
        end
    end
end

function Client.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    Assets.start()
    Tools.setSource(Assets.get)
    local Refreshing = false
    Assets.Arrived:Connect(function()
        if Refreshing then
            return
        end
        Refreshing = true
        task.defer(function()
            Refreshing = false
            Client.refresh()
            Client.Changed:Fire()
        end)
    end)
    const Gui = vision.create({
        ClassName = "ScreenGui",
        Name = "ToolsHud",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 3,
    }) :: ScreenGui
    Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    View:Open().Parent = Gui

    Bridges.Hud:Bind(function(Action: string, Value: any)
        if Action == "Slot" and type(Value) == "number" then
            task.spawn(Client.equip, Value)
        elseif Action == "Toggle" then
            Open = not Open
            Sounds.play(if Open then "MenuOpen" else "MenuClose")
            Client.refresh()
        elseif Action == "ActionToggle" then
            ActionsOpen = not ActionsOpen
            Sounds.play(if ActionsOpen then "MenuOpen" else "MenuClose")
            refreshBar()
        elseif Action == "Action" and type(Value) == "string" then
            action(Value)
        end
    end)

    Net:On("@Tools/State", function(State: any)
        if type(State) ~= "table" then
            return
        end
        Slots = if type(State.Slots) == "table" then State.Slots else {}
        EquippedSlot = if type(State.Equipped) == "string" then State.Equipped else nil
        const Context = Current
        if Context and EquippedSlot ~= Context.Slot and not Busy then
            finish(Context)
        end
        Client.Changed:Fire()
        Client.refresh()
    end)

    BulletNet:On("@Bullets/Shot", function(Shooter: Player?, Origin: Vector3, Hit: Vector3, Normal: Vector3?, Bullet: string?)
        if Shooter == Players.LocalPlayer or typeof(Origin) ~= "Vector3" or typeof(Hit) ~= "Vector3" then
            return
        end
        Bullets.fire({
            Shooter = Shooter,
            Origin = Origin,
            Hit = Hit,
            Normal = if typeof(Normal) == "Vector3" then Normal else nil,
            Part = nil,
            Bullet = if type(Bullet) == "string" then Bullet else Bullets.Fallback,
        })
    end)

    Players.LocalPlayer.CharacterAdded:Connect(function()
        const Context = Current
        if Context then
            finish(Context)
        end
        Client.refresh()
    end)

    UserInputService.InputBegan:Connect(onInput)
    Client.refresh()
end

return Client
