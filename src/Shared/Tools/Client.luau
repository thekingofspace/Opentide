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
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const Tools = require(script.Parent)
const Bridges = require(script.Parent.Bridges)
const Bullets = require(script.Parent.Guns.Bullets)
const Assets = require(script.Parent.Assets)
const Throwables = require(script.Parent.Throwables)
const UI = require(ReplicatedStorage.Shared.UI)
const View = UI.view("Tools")

export type Hand = "Right" | "Left"
export type Side = "Body" | "Right" | "Left"

export type PlayOptions = AnimationController.ActionOptions & {
    Whole: boolean?,
}

export type Pair = {
    Main: Context,
    Off: Context,
    Right: Context,
    Left: Context,
    Data: { [any]: any },
}

export type Context = {
    Id: string,
    Slot: string,
    Hand: Hand,
    Side: Side,
    Def: Tools.ToolDef,
    Data: { [any]: any },
    States: { [string]: boolean },
    Labels: { [string]: string },
    Pair: Pair?,
    setLabel: (Id: string, Text: string?) -> (),
    play: (Name: string, Options: PlayOptions?) -> AnimationTrack?,
    stop: (Name: string) -> (),
    pushSet: (Name: string) -> (),
    popSet: (Name: string) -> (),
    active: (Id: string) -> boolean,
    setActive: (Id: string, On: boolean) -> (),
    send: (Id: string, Value: any?) -> (),
    model: () -> Model?,
    build: () -> ToolBuild?,
    mount: (Path: string) -> Attachment?,
    stats: () -> { [string]: any },
    fire: (Shot: Bullets.Shot) -> (),
    other: () -> Context?,
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
local Links: { [string]: string } = {}
local EquippedSlot: string? = nil
local Current: Context? = nil
local Offhand: Context? = nil
local LinkFrom: number? = nil
local Busy = false
local Blocked = false
const BlockedBy: { [string]: boolean } = {}
local Open = true
local ActionsOpen = true
local Started = false
const Sequences: { [string]: KeyframeSequence } = {}
const Previews: { [string]: { Hash: string, Model: Model } } = {}

const function controller(): AnimationController.Controller
    return LocalAnimations.get() or LocalAnimations.start()
end

function Client.clip(ToolId: string, Name: string, Way: Side?, Whole: boolean?): AnimationController.Clip?
    const Key = `{ToolId}_{Name}`
    const Known = Library.get(Key)
    if Known ~= nil then
        return Known
    end
    const Def = Tools.get(ToolId)
    const Chosen: Side = Way or "Body"
    const Single = if Def and Def.Clips and Chosen ~= "Body" and not Whole then Def.Clips[`{Name}_OneHand`] else nil
    const Value = Single or (if Def and Def.Clips then Def.Clips[Name] else nil)
    if type(Value) == "string" or type(Value) == "number" then
        return Value
    end
    if type(Value) ~= "table" then
        return nil
    end
    const Cached = `{Key}_{Chosen}{if Whole then "_Whole" else ""}`
    const Built = Sequences[Cached]
    if Built then
        return Built
    end
    const Source = Value :: Clips.Spec
    local Spec: Clips.Spec
    if Chosen == "Body" or (Whole and Chosen == "Right") then
        Spec = table.clone(Source)
    elseif Whole then
        Spec = Clips.reflect(Source)
    else
        Spec = Clips.side(Source, Chosen)
    end
    Spec.Name = Cached
    const Made = Clips.sequence(Spec)
    Sequences[Cached] = Made
    return Made
end

const function slotTable(ToolId: string, Spec: Tools.SetSpec, Way: Side): AnimationController.SlotTable
    const function convert(Modes: { [string]: string }?): { [string]: AnimationController.Slot }?
        if not Modes then
            return nil
        end
        const Made: { [string]: AnimationController.Slot } = {}
        for Mode, Name in Modes do
            const Clip = Client.clip(ToolId, Name, Way)
            if Clip ~= nil then
                Made[Mode] = Clip
            end
        end
        return Made
    end
    if Way == "Right" then
        return { Right = convert(Spec.Body) }
    elseif Way == "Left" then
        return { Left = convert(Spec.Body) }
    end
    return { Full = convert(Spec.Full), Legs = convert(Spec.Legs), Body = convert(Spec.Body) }
end

const function hook(Context: Context, Name: string, ...: any): any
    const Hooks = Context.Def.client
    const Run = if Hooks then Hooks[Name] else nil
    if type(Run) ~= "function" then
        return nil
    end
    const Ok, Result = pcall(Run, Context, ...)
    if not Ok then
        warn(`[Tools] {Context.Id} {Name} failed: {Result}`)
        return nil
    end
    return Result
end

const function held(): { Context }
    const Made: { Context } = {}
    if Current then
        table.insert(Made, Current :: Context)
    end
    if Offhand then
        table.insert(Made, Offhand :: Context)
    end
    return Made
end

const function modelIn(Hand: Hand): Model?
    const Character = Players.LocalPlayer.Character
    const Folder = if Character then Character:FindFirstChild("Tools") else nil
    const Found = if Folder then Folder:FindFirstChild(`Equipped_{Hand}`) else nil
    return if Found and Found:IsA("Model") then Found else nil
end

const function refreshBar()
    const Main = Current
    if not Main or Blocked then
        View.ActionBar(false)
        return
    end
    const Actions: { Bridges.ActionView } = {}
    const Seen: { [string]: boolean } = {}
    for _, Context in held() do
        for _, Action in Context.Def.Actions or {} do
            if Seen[Action.Id] then
                continue
            end
            Seen[Action.Id] = true
            table.insert(Actions, {
                Id = Action.Id,
                Label = Main.Labels[Action.Id] or Context.Labels[Action.Id] or Action.Label,
                Key = if Action.Key then Action.Key.Name else nil,
                On = Main.States[Action.Id] == true or Context.States[Action.Id] == true,
            })
        end
    end
    if #Actions == 0 then
        View.ActionBar(false)
        return
    end
    View.ActionBar({ Actions = Actions })
    View.ActionBarOpen(ActionsOpen)
end

const function makeContext(ToolId: string, Def: Tools.ToolDef, Slot: string, Hand: Hand, Way: Side): Context
    const Played: { [string]: boolean } = {}
    const Stats = Tools.stats(Slots[Slot])
    const Prefix = `Tool_{Way}_{ToolId}_`
    local Context: Context
    Context = {
        Id = ToolId,
        Slot = Slot,
        Hand = Hand,
        Side = Way,
        Def = Def,
        Data = {},
        States = {},
        Labels = {},
        Pair = nil :: Pair?,
        setLabel = function(Id: string, Text: string?)
            if Context.Data.Live then
                Context.Labels[Id] = Text
                refreshBar()
            end
        end,
        play = function(Name: string, Options: PlayOptions?): AnimationTrack?
            const Given: PlayOptions = Options or {}
            const Clip = Client.clip(ToolId, Name, Way, Given.Whole)
            if Clip == nil then
                return nil
            end
            Played[Name] = true
            return controller():play(`Tool_{Way}_{Name}`, Clip, {
                Part = if Way == "Body" or Given.Whole then Given.Part or "Body" else Way,
                Priority = Given.Priority or (if Way == "Body" then nil else Enum.AnimationPriority.Action3),
                Speed = Given.Speed,
                Weight = Given.Weight,
                FadeTime = Given.FadeTime,
                Looped = Given.Looped,
            })
        end,
        stop = function(Name: string)
            controller():stop(`Tool_{Way}_{Name}`)
        end,
        pushSet = function(Name: string)
            const Spec = if Def.Sets then Def.Sets[Name] else nil
            if Spec then
                controller():pushSet(Prefix .. Name, slotTable(ToolId, Spec, Way), Client.SetPriority)
            end
        end,
        popSet = function(Name: string)
            controller():popSet(Prefix .. Name)
        end,
        active = function(Id: string): boolean
            return Context.States[Id] == true
        end,
        setActive = function(Id: string, On: boolean)
            Context.States[Id] = On
            refreshBar()
        end,
        send = function(Id: string, Value: any?)
            Net:Emit("@Tools/Action", Id, Value, Hand)
        end,
        model = function(): Model?
            return modelIn(Hand)
        end,
        build = function(): ToolBuild?
            return Slots[Slot]
        end,
        stats = function(): { [string]: any }
            return Stats
        end,
        fire = function(Shot: Bullets.Shot)
            Net:Emit("@Tools/Fire", Shot.Origin, Shot.Hit, Shot.Normal, Hand)
        end,
        mount = function(Path: string): Attachment?
            const Model = modelIn(Hand)
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
        other = function(): Context?
            const Paired = Context.Pair
            if not Paired then
                return nil
            end
            return if Paired.Main == Context then Paired.Off else Paired.Main
        end,
    }
    Context.Data.Played = Played
    Context.Data.Prefix = Prefix
    return Context
end

const function finish(Context: Context)
    Context.Data.Live = false
    hook(Context, "onUnequip")
    const Animations = LocalAnimations.get()
    if Animations then
        if Context.Def.Sets then
            for Name in Context.Def.Sets do
                Animations:popSet(Context.Data.Prefix .. Name)
            end
        end
        const Played: { [string]: boolean } = Context.Data.Played or {}
        for Name in Played do
            if Name ~= Context.Def.Unequip then
                Animations:stop(`Tool_{Context.Side}_{Name}`)
            end
        end
    end
end

const function finishAll()
    const Main = Current
    const Off = Offhand
    Current = nil
    Offhand = nil
    if Main then
        finish(Main)
    end
    if Off then
        finish(Off)
    end
    refreshBar()
    if Main then
        Client.Equipped:Fire(nil)
    end
end

const function begin(Hands: { [string]: string }, MainSlot: string)
    const Paired = Hands.Right ~= nil and Hands.Left ~= nil
    const Made: { [Hand]: Context } = {}
    for _, Hand in { "Right", "Left" } :: { Hand } do
        const Slot = Hands[Hand]
        const Build = if Slot then Slots[Slot] else nil
        const Def = if Build then Tools.get(Build.Tool) else nil
        if not Slot or not Build or not Def then
            continue
        end
        const Way: Side = if Paired or Hand == "Left" or Def.OneHand then Hand else "Body"
        const Context = makeContext(Build.Tool, Def, Slot, Hand, Way)
        Context.Data.Live = true
        Made[Hand] = Context
        if Slot == MainSlot then
            Current = Context
        else
            Offhand = Context
        end
    end
    const Main = Current
    if not Main then
        return
    end
    const Off = Offhand
    if Off then
        const Link: Pair = {
            Main = Main,
            Off = Off,
            Right = Made.Right,
            Left = Made.Left,
            Data = {},
        }
        Main.Pair = Link
        Off.Pair = Link
    end
    for _, Context in held() do
        if Context.Def.Equip then
            Context.play(Context.Def.Equip)
        end
        hook(Context, "onEquip")
    end
    Sounds.play("ToolEquip")
    refreshBar()
    Client.Equipped:Fire(Main.Id)
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

const function holding(Key: string): boolean
    for _, Context in held() do
        if Context.Slot == Key then
            return true
        end
    end
    return false
end

function Client.refresh()
    const Views: { Bridges.SlotView } = {}
    for Slot = 1, Tools.Config.Slots do
        const Key = tostring(Slot)
        const Build = Slots[Key]
        const Def = if Build then Tools.get(Build.Tool) else nil
        const Partner = Links[Key]
        table.insert(Views, {
            Slot = Slot,
            Name = if Def then string.lower(Def.Name) else "empty",
            Tool = if Def and Build then Build.Tool else nil,
            Model = if Def then Client.preview(`slot{Key}`, Build) else nil,
            Active = holding(Key),
            Linked = if Partner then tonumber(Partner) else nil,
            Linking = LinkFrom == Slot,
            Linkable = Def ~= nil and Def.Dual ~= nil and not holding(Key),
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

function Client.offhand(): Context?
    return Offhand
end

function Client.slots(): { [string]: ToolBuild }
    return Slots
end

function Client.allows(Flag: string): boolean
    for _, Context in held() do
        if (Context.Def :: any)[Flag] ~= true then
            return false
        end
    end
    return true
end

function Client.unequip()
    const Main = Current
    if not Main or Busy then
        return
    end
    Busy = true
    local Waits = false
    for _, Context in held() do
        if Context.Def.Unequip then
            Context.play(Context.Def.Unequip)
            Waits = true
        end
    end
    if Waits then
        Sounds.play("ToolPutAway")
        task.wait(Client.PutAwayWait)
    end
    Net:Call("@Tools/Equip", nil)
    if Current == Main then
        finishAll()
    end
    Busy = false
    Client.refresh()
end

function Client.unequipNow()
    const Had = Current ~= nil
    finishAll()
    if EquippedSlot or Had then
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
    if Current and (not Build or holding(Key)) then
        Client.unequip()
        return
    end
    if not Build then
        return
    end
    Busy = true
    finishAll()
    const Reply = Net:Call("@Tools/Equip", Slot)
    Busy = false
    if type(Reply) == "table" and Reply.Ok and type(Reply.Hands) == "table" then
        begin(Reply.Hands, Key)
    elseif type(Reply) == "table" and type(Reply.Error) == "string" then
        warn(`[Tools] {Reply.Error}`)
    end
    Client.refresh()
end

function Client.link(Slot: number)
    const Key = tostring(Slot)
    if not Links[Key] and holding(Key) then
        LinkFrom = nil
        PropPlacer.toast("Put your tool away to link it", "Info")
        Client.refresh()
        return
    end
    if Links[Key] then
        LinkFrom = nil
        task.spawn(function()
            Net:Call("@Tools/Unlink", Slot)
        end)
        Sounds.play("ToggleOff")
        Client.refresh()
        return
    end
    const From = LinkFrom
    if not From or From == Slot then
        LinkFrom = if From == Slot then nil else Slot
        if LinkFrom then
            PropPlacer.toast("Now press link on the slot to pair it with", "Info")
        end
        Sounds.play("Select")
        Client.refresh()
        return
    end
    LinkFrom = nil
    task.spawn(function()
        const Reply = Net:Call("@Tools/Link", From, Slot)
        if type(Reply) == "table" and Reply.Ok then
            Sounds.play("ToggleOn")
            PropPlacer.toast(`Linked slot {From} and slot {Slot}`, "Info")
        else
            PropPlacer.toast(if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "Those could not be linked", "Error")
        end
        Client.refresh()
    end)
    Client.refresh()
end

function Client.unlinkAll()
    LinkFrom = nil
    if next(Links) == nil then
        return
    end
    table.clear(Links)
    Net:Call("@Tools/UnlinkAll")
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

const function findAction(Context: Context, Id: string): Tools.Action?
    for _, Entry in Context.Def.Actions or {} do
        if Entry.Id == Id then
            return Entry
        end
    end
    return nil
end

const function pairHandler(Link: Pair): ((Pair, string) -> ())?
    for _, Context in { Link.Main, Link.Off } do
        const Hooks = Context.Def.client
        const Run = if Hooks then Hooks.onPairAction else nil
        if type(Run) == "function" then
            return Run
        end
    end
    return nil
end

function Client.runAction(Context: Context, Id: string)
    const Found = findAction(Context, Id)
    if not Found then
        return
    end
    if Found.Toggle then
        Context.States[Id] = not Context.States[Id]
    end
    hook(Context, "onAction", Id, Context.States[Id] == true)
end

const function action(Id: string)
    const Main = Current
    if not Main or Blocked then
        return
    end
    Sounds.play("ToggleOn")
    const Link = Main.Pair
    if Link then
        const Handler = pairHandler(Link)
        if Handler then
            const Ok, Problem = pcall(Handler, Link, Id)
            if not Ok then
                warn(`[Tools] pair action {Id} failed: {Problem}`)
            end
        else
            for _, Context in held() do
                Client.runAction(Context, Id)
            end
        end
    else
        Client.runAction(Main, Id)
    end
    refreshBar()
end

const function alternate(Link: Pair)
    const First: Context = if Link.Data.NextHand == "Left" then Link.Left else Link.Right
    const Second: Context = if First == Link.Right then Link.Left else Link.Right
    for _, Context in { First, Second } do
        if Context.Def.Click == false then
            continue
        end
        if hook(Context, "onActivate") ~= false then
            Link.Data.NextHand = if Context.Hand == "Right" then "Left" else "Right"
            Link.Data.Clicked = Context
            return
        end
    end
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
    const Main = Current
    if not Main or Busy then
        return
    end
    const Link = Main.Pair
    if Input.UserInputType == Enum.UserInputType.MouseButton2 then
        return
    end
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        if Link then
            for _, Context in { Link.Main, Link.Off } do
                const Hooks = Context.Def.client
                const Run = if Hooks then Hooks.onPairActivate else nil
                if type(Run) == "function" then
                    const Ok, Handled = pcall(Run, Link)
                    if Ok and Handled then
                        return
                    elseif not Ok then
                        warn(`[Tools] pair activate failed: {Handled}`)
                    end
                    break
                end
            end
            alternate(Link)
        else
            hook(Main, "onActivate")
        end
        return
    end
    for _, Context in held() do
        for _, Entry in Context.Def.Actions or {} do
            if Entry.Key and Entry.Key == Input.KeyCode then
                action(Entry.Id)
                return
            end
        end
    end
end

const function onRelease(Input: InputObject)
    const Main = Current
    if not Main or Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end
    const Link = Main.Pair
    const Target: Context? = if Link then Link.Data.Clicked else Main
    if Target then
        hook(Target, "onRelease")
    end
end

function Client.start()
    if Started or not RunService:IsClient() then
        return
    end
    Started = true
    Assets.start()
    Tools.setSource(Assets.get)
    Throwables.start()
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
    UI.mount("Tools", Gui)

    Bridges.Hud:Bind(function(Action: string, Value: any)
        if Action == "Slot" and type(Value) == "number" then
            task.spawn(Client.equip, Value)
        elseif Action == "Link" and type(Value) == "number" then
            Client.link(Value)
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
        Links = if type(State.Links) == "table" then State.Links else {}
        EquippedSlot = if type(State.Equipped) == "string" then State.Equipped else nil
        const Hands: { [string]: string } = if type(State.Hands) == "table" then State.Hands else {}
        if not Busy then
            for _, Context in held() do
                if Hands[Context.Hand] ~= Context.Slot then
                    finishAll()
                    break
                end
            end
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
        finishAll()
        Client.refresh()
    end)

    UserInputService.InputBegan:Connect(onInput)
    UserInputService.InputEnded:Connect(onRelease)
    Client.refresh()
end

return Client
