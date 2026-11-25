--!strict
const GuiService = game:GetService("GuiService")
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const vision = require(ReplicatedStorage.MainPackages.vision)
const signal = require(ReplicatedStorage.MainPackages.signal)
const Customize = require(script.Parent)
const Bridges = require(script.Parent.Bridges)
const Catalog = require(script.Parent.Catalog)
const Config = require(script.Parent.Config)
const Format = require(script.Parent.Format)
const Gizmo = require(script.Parent.Gizmo)
const View = require(ReplicatedStorage.Shared.GUI_Elements.Customize)
const PropPlacer = require(ReplicatedStorage.Shared.PropPlacer)
const Cache = require(ReplicatedStorage.Shared.PropPlacer.Cache)
const PropData = require(ReplicatedStorage.Shared.PropData)
const Shop = require(ReplicatedStorage.Shared.Shop)
const Tools = require(ReplicatedStorage.Shared.Tools)
const ToolsClient = require(ReplicatedStorage.Shared.Tools.Client)
const Bench = require(ReplicatedStorage.Shared.Tools.Bench)
const ToolAssets = require(ReplicatedStorage.Shared.Tools.Assets)
const Stats = require(ReplicatedStorage.Shared.Bio.Stats)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const World = require(ReplicatedStorage.Shared.PropPlacer.World)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

type EditKind = "Part" | "Group"

type Editing = {
    Kind: EditKind,
    Id: string,
}

type Picking = {
    Kind: "Skin" | "Part" | "Group",
    Ids: { string },
    Originals: { [string]: Color3 | false },
    Skin: Color3?,
    Color: Color3,
}

type Confirming = {
    Key: string,
    Token: number,
}

type Asking = {
    Kind: "Load" | "Clear",
    Slot: number,
}

const Menu = {
    Opened = signal.new(),
    Closed = signal.new(),
    ConfirmTime = 3,
    HoverRate = 0.08,
    DoneKey = Enum.KeyCode.F,
    Keys = {
        [Enum.KeyCode.T] = "Translate",
        [Enum.KeyCode.R] = "Rotate",
        [Enum.KeyCode.Y] = "Scale",
        [Enum.KeyCode.Q] = "None",
    } :: { [Enum.KeyCode]: Customize.Mode },
    Tags = {
        Body = "body",
        Default = "from my avatar",
        Asset = "added item",
        Builtin = "built in",
    } :: { [string]: string },
}

local Open = false
local Busy = false
local Page = "Body"
local Edit: Editing? = nil
local Pick: string? = nil
local Picker: Picking? = nil
local ShopOpen = false
local ShapesOpen = false
local InfoTab = "Profile"
local NicknameDraft: string? = nil
local DescriptionDraft: string? = nil
local ToolMode = "Categories"
local ToolCategory: string? = nil
local Draft: ToolBuild? = nil
local Mounting: string? = nil
local Equipping = false
local ToolAsk: Asking? = nil
local HolsterMode: Gizmo.Mode = "None"
local Handled: BasePart? = nil
local ShownHash = ""
local WornHash = ""
local ShopPick: string? = nil
local Gifting: string? = nil
local Confirm: Confirming? = nil
local Token = 0
local Queued = false
local Started = false
const Drafts: { [number]: string } = {}
const Typed: { [string]: string } = {}
const Searches: { [string]: string } = {}
const Models: { [string]: Instance | false } = {}
const Shapes: { [string]: Instance } = {}
const Loading: { [string]: boolean } = {}

const function toast(Text: string?, Info: boolean?)
    if Text and Text ~= "" then
        PropPlacer.toast(Text, if Info then "Info" else "Error")
    end
end

const function confirmed(Key: string): boolean
    const Waiting = Confirm
    if Waiting and Waiting.Key == Key then
        Confirm = nil
        return true
    end
    Token += 1
    const Mine = Token
    Confirm = { Key = Key, Token = Mine }
    Sounds.play("Confirm")
    task.delay(Menu.ConfirmTime, function()
        const Still = Confirm
        if Still and Still.Token == Mine then
            Confirm = nil
            View.NavReset(false)
            Menu.refresh()
        end
    end)
    return false
end

const function limbOf(Part: string): string?
    for Limb, Pieces in Catalog.Limbs do
        if table.find(Pieces, Part) then
            return Limb
        end
    end
    return nil
end

const function picked(): { string }
    const Current = Pick
    if not Current then
        return {}
    end
    const Limb = string.match(Current, "^limb:(.+)$")
    if Limb then
        return table.clone(Catalog.Limbs[Limb] or {})
    end
    return { Current }
end

const function pickedLimb(): string?
    const Current = Pick
    if not Current then
        return nil
    end
    return string.match(Current, "^limb:(.+)$") or limbOf(Current)
end

const function spaced(Name: string): string
    return string.lower((string.gsub(Name, "(%l)(%u)", "%1 %2")))
end

const function hiddenAll(Parts: { string }): boolean
    if #Parts == 0 then
        return false
    end
    for _, Part in Parts do
        const Body = Customize.bodyOf(Part)
        if not Body or not Body.Hidden then
            return false
        end
    end
    return true
end

const function membersOf(GroupId: string): { string }
    for _, Group in Customize.groups() do
        if Group.Id == GroupId then
            return Group.Members
        end
    end
    return {}
end

const function refreshBody()
    const Parts = picked()
    const Current = Pick
    const Limb = if Current then string.match(Current, "^limb:(.+)$") else nil
    const Label = if Limb then spaced(Limb) elseif Current then spaced(Current) else nil
    const Sizes: { [string]: string } = {}
    for Key in Config.Proportions do
        Sizes[Key] = string.format("%.2fx", Customize.getProportion(Key))
    end
    View.BodyState({
        Skin = Customize.getSkin(),
        Sizes = Sizes,
        ScaleParts = Customize.getScaleParts(),
        Pick = Current,
        PickLabel = if Label then `picked: {Label}` else "nothing picked",
        PickHidden = hiddenAll(Parts),
    })
    const Lit: { [string]: boolean } = {}
    for _, Part in Parts do
        Lit[Part] = true
    end
    View.BodyFigure(Lit)

    const Animations: { Bridges.Choice } = {}
    const Sets = Catalog.animations()
    for _, Id in Catalog.sorted(Sets) do
        table.insert(Animations, { Id = Id, Name = string.lower(Sets[Id].Name), Active = Id == Customize.getAnimation() })
    end
    View.BodyAnimations(Animations)

    const Swaps: { Bridges.Choice } = {}
    const Owner = pickedLimb()
    const Key = if Current then (string.match(Current, "^limb:(.+)$") or Current) else nil
    if Owner and Key then
        const Using = Customize.getSwap(Key)
        const Found: { string } = {}
        for Id, Swap in Catalog.swaps() do
            if table.find(Swap.Limbs, Owner) then
                table.insert(Found, Id)
            end
        end
        if #Found > 0 then
            table.sort(Found)
            table.insert(Swaps, { Id = "none", Name = if Limb then "normal limb" else "normal part", Active = Using == nil })
            for _, Id in Found do
                table.insert(Swaps, { Id = Id, Name = string.lower(Catalog.swaps()[Id].Name), Active = Using == Id })
            end
        end
    end
    View.BodySwaps(Swaps)
end

const function clothingCards(Kind: Catalog.ClothingKind): { Bridges.ClothingCard }
    const Search = string.lower(Searches[Kind] or "")
    const Current = Customize.getClothing(Kind)
    const Cards: { Bridges.ClothingCard } = {}
    if Search == "" or string.find("default your own", Search, 1, true) then
        table.insert(Cards, { Id = "default", Name = "default", Asset = nil, Active = Current == nil })
    end
    if Current and not Catalog.preset(Kind, Current) then
        table.insert(Cards, { Id = "custom", Name = "pasted id", Asset = Current, Active = true })
    end
    const List = Catalog.clothes()
    for _, Id in Catalog.sorted(List) do
        const Item = List[Id]
        if Item.Kind == Kind and (Search == "" or string.find(string.lower(Item.Name), Search, 1, true)) then
            table.insert(Cards, { Id = Id, Name = string.lower(Item.Name), Asset = Item.Asset, Active = Current == Item.Asset })
        end
    end
    return Cards
end

const function refreshClothes()
    const Shown = Open and Page == "Body" and not Edit and not ShopOpen
    View.ClothesState({
        Shown = Shown,
        Ids = Config.AllowClothingIds,
        Shirt = Typed.Shirt or "",
        Pants = Typed.Pants or "",
    })
    if Shown then
        View.ClothesShirtCards(clothingCards("Shirt"))
        View.ClothesPantsCards(clothingCards("Pants"))
    end
end

const function partRow(Entry: Customize.Entry): Bridges.PartRow
    return { Id = Entry.Id, Name = Entry.Name, Tag = Menu.Tags[Entry.Kind] or "" }
end

const function refreshRig()
    const Entries = Customize.listParts()
    const ById: { [string]: Customize.Entry } = {}
    local Count = 0
    for _, Entry in Entries do
        if Entry.Kind ~= "Body" then
            ById[Entry.Id] = Entry
            Count += 1
        end
    end
    const Groups: { Bridges.GroupRow } = {}
    for _, Group in Customize.groups() do
        const Members: { Bridges.PartRow } = {}
        for _, Id in Group.Members do
            const Entry = ById[Id]
            if Entry then
                table.insert(Members, partRow(Entry))
            end
        end
        table.insert(Groups, { Id = Group.Id, Name = Group.Name, Code = Group.Code, Members = Members })
    end
    const Loose: { Bridges.PartRow } = {}
    for _, Entry in Entries do
        if Entry.Kind ~= "Body" and not Entry.Group then
            table.insert(Loose, partRow(Entry))
        end
    end
    View.RigRows({ Groups = Groups, Loose = Loose })
    View.RigInfo({ Count = `{Count} / {Config.MaxRigParts} parts` })

    const Cards: { Bridges.ShapeCard } = {}
    if ShapesOpen then
        const List = Catalog.parts()
        for _, Id in Catalog.sorted(List) do
            local Model = Shapes[Id]
            if not Model then
                const Ok, Built = pcall(List[Id].build)
                if Ok and Built then
                    Shapes[Id] = Built
                    Model = Built
                end
            end
            table.insert(Cards, { Id = Id, Name = List[Id].Name, Model = Model })
        end
    end
    View.RigShapes(Cards)
end

const function refreshInfo()
    const Me = Players.LocalPlayer
    const Rows: { Bridges.StatRow } = {}
    for _, Def in Stats.sorted() do
        const Value = Stats.valueOf(Me, Def)
        table.insert(Rows, {
            Id = Def.Id,
            Name = Def.Name,
            Detail = Def.Description or "",
            Value = tostring(Value),
            Bonus = `{Stats.signed(Stats.bonus(Def, Value))} to rolls`,
        })
    end
    const Nickname = Me:GetAttribute("Nickname")
    const Description = Me:GetAttribute("Description")
    View.InfoView({
        Tab = InfoTab,
        Nickname = NicknameDraft or (if type(Nickname) == "string" then Nickname else ""),
        Description = DescriptionDraft or (if type(Description) == "string" then Description else ""),
        Stats = Rows,
    })
end

const function refreshSaves()
    const Views: { Bridges.SlotView } = {}
    const All = Customize.saves()
    const Waiting = Confirm
    for Slot = 1, Config.SaveSlots do
        const Save = All[tostring(Slot)]
        const Parts = if Save and type(Save.Look) == "table" and type(Save.Look.Parts) == "table" then #Save.Look.Parts else 0
        local Held = 0
        if Save and type(Save.Tools) == "table" then
            for _ in Save.Tools do
                Held += 1
            end
        end
        Views[Slot] = {
            Name = if Save then Save.Name else Drafts[Slot] or "",
            Detail = if Save then `{Parts} rig {if Parts == 1 then "part" else "parts"}, {Held} {if Held == 1 then "tool" else "tools"}` else "empty slot",
            Stamp = if Save and type(Save.Stamp) == "number" then string.lower(os.date("%b %d, %H:%M", Save.Stamp)) else "",
            Filled = Save ~= nil,
            Confirm = Waiting ~= nil and Waiting.Key == `Save{Slot}`,
            ConfirmClear = Waiting ~= nil and Waiting.Key == `Clear{Slot}`,
        }
    end
    View.SaveSlots(Views)
end

const function modelOf(Id: string): Instance?
    const Item = Shop.get(Id)
    const Ids = if Item then Item.Preview else nil
    if not Ids or #Ids == 0 then
        return nil
    end
    const Known = Models[Id]
    if Known ~= nil then
        return if Known then Known else nil
    end
    if not Loading[Id] then
        Loading[Id] = true
        task.spawn(function()
            const Found = Cache.fetch(Ids, 8)
            const Source = Found[Ids[1]]
            Models[Id] = if Source then Source:Clone() else false
            if Open and ShopOpen then
                Menu.refresh()
            end
        end)
    end
    return nil
end

const function priceOf(Item: Shop.Item): string
    if Item.Product <= 0 then
        return "soon"
    end
    const Price = Shop.known(Item)
    return if Price then `R$ {Price}` else "..."
end

const function refreshShop()
    const Cards: { Bridges.ShopCard } = {}
    const List = Shop.list()
    for _, Id in Shop.sorted() do
        const Item = List[Id]
        table.insert(Cards, {
            Id = Id,
            Name = Item.Name,
            Reward = Shop.reward(Item),
            Price = priceOf(Item),
            Model = modelOf(Id),
            Image = Item.Image,
            Active = ShopPick == Id,
        })
    end
    View.ShopCards(Cards)
    const Chosen = ShopPick
    const Item = if Chosen then List[Chosen] else nil
    if not Chosen or not Item then
        View.ShopDetail(false)
        return
    end
    const Names: { string } = {}
    for _, PropId in Item.Preview or {} do
        const Info = PropData.get(PropId)
        if Info then
            table.insert(Names, string.lower(Info.Name))
        end
    end
    View.ShopDetail({
        Id = Chosen,
        Name = Item.Name,
        Detail = Item.Description or "",
        Includes = Names,
        Reward = Shop.reward(Item),
        Price = priceOf(Item),
        Model = modelOf(Chosen),
        Image = Item.Image,
        Giftable = Shop.giftable(Item),
        Gifting = Gifting == Chosen,
        Ready = Item.Product > 0,
    })
end

const function loadPrices()
    task.spawn(function()
        for _, Id in Shop.sorted() do
            const Item = Shop.list()[Id]
            if Item.Product > 0 and not Shop.known(Item) then
                Shop.price(Item)
            end
        end
        if Open and ShopOpen then
            refreshShop()
        end
    end)
end

const function owns(Pack: string?): boolean
    const Stats = World.stats()
    return Tools.owns(Pack, if Stats then Stats.Packs else nil, if Stats then Stats.AllPacks else false)
end

const function copyBuild(Given: ToolBuild): ToolBuild
    const Spot = Given.Holster
    return {
        Tool = Given.Tool,
        Parts = table.clone(Given.Parts),
        Holster = if Spot then { On = Spot.On, Attach = Spot.Attach, Offset = table.clone(Spot.Offset), Size = Spot.Size } else nil,
    }
end

const function holsterOf(Build: ToolBuild): ToolHolster
    local Spot = Build.Holster
    if not Spot then
        Spot = { On = false, Attach = "UpperTorso", Offset = Format.packFrame(CFrame.new(0, 0, 0.7) * CFrame.Angles(0, 0, math.rad(40))), Size = 1 }
        Build.Holster = Spot
    end
    return Spot :: ToolHolster
end

const function hiddenHolster(): Bridges.HolsterView
    return { Shown = false, On = false, Attach = "", Size = "", Mode = "None", Looking = "" }
end

const function removePath(Build: ToolBuild, Path: string)
    for Key in Build.Parts do
        if Key == Path or string.sub(Key, 1, #Path + 1) == `{Path}/` then
            Build.Parts[Key] = nil
        end
    end
end

const function toolRows(): { Bridges.ToolPartRow }
    const Build = Draft
    const Rows: { Bridges.ToolPartRow } = {}
    if not Build then
        return Rows
    end
    const Paths: { string } = {}
    for Path in Build.Parts do
        table.insert(Paths, Path)
    end
    table.sort(Paths)
    for _, Path in Paths do
        const Mount = Tools.mountAt(Build.Tool, Build.Parts, Path)
        const Piece = Tools.attachment(Build.Parts[Path])
        if Mount and Piece then
            local Depth = 0
            for _ in string.gmatch(Path, "[^/]+") do
                Depth += 1
            end
            table.insert(Rows, {
                Path = Path,
                Label = Mount.Label or Mount.Id,
                Name = string.lower(Piece.Name),
                Required = Mount.Required == true,
                Depth = Depth,
            })
        end
    end
    return Rows
end

const function detachHandles()
    if Handled then
        Handled = nil
        Gizmo.detach()
    end
end

const function refreshHandles()
    const Build = Draft
    const Spot = if Build then Build.Holster else nil
    const Root, Joint = Bench.holsterParts()
    if not Open or Page ~= "Tools" or ToolMode ~= "Edit" or ShopOpen or HolsterMode == "None" or not Spot or not Spot.On or not Root or not Joint then
        detachHandles()
        return
    end
    if Handled == Root and Gizmo.mode() == HolsterMode then
        return
    end
    Handled = Root
    Gizmo.attach(Root, HolsterMode, {
        moved = function(World: CFrame)
            const Now = Draft
            const Held = if Now then Now.Holster else nil
            const Part = Joint.Part0
            if not Held or not Part then
                return
            end
            local Offset = Part.CFrame:ToObjectSpace(World)
            const Limit = Tools.Config.MaxHolsterOffset
            if Offset.Position.Magnitude > Limit then
                Offset = CFrame.new(Offset.Position.Unit * Limit) * Offset.Rotation
            end
            Joint.C0 = Offset
            Held.Offset = Format.packFrame(Offset)
        end,
        sized = function(_: Vector3, _: CFrame) end,
        finished = function()
            task.defer(function()
                Menu.refresh()
            end)
        end,
    })
end

const function editTool(Build: ToolBuild)
    const Def = Tools.get(Build.Tool)
    Draft = copyBuild(Build)
    ToolMode = "Edit"
    ToolCategory = if Def then Def.Category else ToolCategory
    Mounting = nil
    Equipping = false
    ToolAsk = nil
    HolsterMode = "None"
    ShownHash = ""
    WornHash = ""
    detachHandles()
    Bench.enable(Customize.rig())
    Bench.look(false)
end

const function leaveEdit()
    detachHandles()
    Draft = nil
    Mounting = nil
    Equipping = false
    HolsterMode = "None"
    ShownHash = ""
    WornHash = ""
    Bench.disable()
    ToolMode = if ToolCategory then "Category" else "Categories"
end

const function leaveTools()
    if ToolMode == "Edit" then
        leaveEdit()
    end
    ToolMode = "Categories"
    ToolCategory = nil
    ToolAsk = nil
    View.ToolMountOpen(false)
    View.ToolAsk(false)
    View.ToolSlotBar(false)
    View.SideShown(true)
    View.HolsterState(hiddenHolster())
end

const function slotBar(): Bridges.SlotBarView | false
    if ToolMode == "Edit" and not Equipping then
        return false
    end
    const Saved = ToolsClient.slots()
    const Cards: { Bridges.SlotCard } = {}
    for Slot = 1, Tools.Config.Slots do
        const Key = tostring(Slot)
        const Build = Saved[Key]
        const Def = if Build then Tools.get(Build.Tool) else nil
        const Waiting = ToolAsk
        table.insert(Cards, {
            Slot = Slot,
            Name = if Def then string.lower(Def.Name) else "empty",
            Filled = Def ~= nil,
            Picked = Waiting ~= nil and Waiting.Slot == Slot,
            Clear = not Equipping and Def ~= nil,
            Model = if Def then ToolsClient.preview(`slot{Key}`, Build) else nil,
        })
    end
    return {
        Title = if Equipping then "pick a slot to put it in" else "your hotbar, press a slot to edit it",
        Slots = Cards,
    }
end

const function askText(): string | false
    const Waiting = ToolAsk
    if not Waiting then
        return false
    end
    const Build = ToolsClient.slots()[tostring(Waiting.Slot)]
    const Def = if Build then Tools.get(Build.Tool) else nil
    const Name = if Def then string.lower(Def.Name) else "this tool"
    if Waiting.Kind == "Clear" then
        return `empty slot {Waiting.Slot}? the {Name} in it will be taken out`
    end
    return `edit the {Name} in slot {Waiting.Slot}? it will not change until you press equip`
end

const function refreshTools()
    if ToolMode == "Edit" and (not Draft or not Tools.get((Draft :: ToolBuild).Tool)) then
        leaveEdit()
    end
    const Build = Draft
    const Def = if Build then Tools.get(Build.Tool) else nil
    View.SideShown(ToolMode ~= "Edit")

    const Categories = Tools.categories()
    const Groups: { Bridges.ToolCard } = {}
    local Listed: { string } = {}
    local CategoryName = "tools"
    for _, Category in Categories do
        const Count = #Category.Tools
        table.insert(Groups, {
            Id = Category.Id,
            Name = Category.Name,
            Detail = if Count == 1 then "1 tool" else `{Count} tools`,
            Locked = false,
            Active = Category.Id == ToolCategory,
        })
        if Category.Id == ToolCategory then
            Listed = Category.Tools
            CategoryName = Category.Name
        end
    end
    View.ToolCategoryList(Groups)
    const Cards: { Bridges.ToolCard } = {}
    for _, Id in Listed do
        const Item = Tools.get(Id)
        if Item then
            const Locked = not owns(Item.Pack)
            table.insert(Cards, {
                Id = Id,
                Name = string.lower(Item.Name),
                Detail = if Locked then `needs the {Item.Pack} pack` else Item.Description or "",
                Locked = Locked,
                Active = false,
            })
        end
    end
    View.ToolCards(Cards)
    View.ToolPage({
        Mode = ToolMode,
        Title = if ToolMode == "Edit" then "edit tool" elseif ToolMode == "Category" then CategoryName else "tools",
        Name = if Def then string.lower(Def.Name) else "",
        Detail = if Def then Def.Description or "" else "",
        Equipping = Equipping,
    })
    View.ToolParts(toolRows())
    View.ToolSlotBar(slotBar())
    View.ToolAsk(askText())

    const Path = Mounting
    const Mount = if Build and Path then Tools.mountAt(Build.Tool, Build.Parts, Path) else nil
    if Build and Path and Mount then
        const Choices: { Bridges.MountChoice } = {}
        if not Mount.Required then
            table.insert(Choices, { Id = "none", Name = "nothing", Detail = "leave this spot empty", Locked = false, Active = Build.Parts[Path] == nil })
        end
        for _, Id in Tools.choices(Mount) do
            const Piece = Tools.attachment(Id)
            if Piece then
                const Locked = not owns(Piece.Pack)
                table.insert(Choices, {
                    Id = Id,
                    Name = string.lower(Piece.Name),
                    Detail = if Locked then `needs the {Piece.Pack} pack` else Piece.Description or "",
                    Locked = Locked,
                    Active = Build.Parts[Path] == Id,
                })
            end
        end
        View.ToolMountChoices(Choices)
        View.ToolMountOpen({ Title = `pick a {Mount.Label or Mount.Id}` })
    else
        Mounting = nil
        View.ToolMountOpen(false)
    end

    const Spot = if Build then Build.Holster else nil
    View.HolsterState({
        Shown = ToolMode == "Edit" and Build ~= nil,
        On = Spot ~= nil and Spot.On,
        Attach = if Spot then Spot.Attach else "",
        Size = string.format("%.2fx", if Spot then Spot.Size else 1),
        Mode = HolsterMode,
        Looking = if Bench.looking() then "look at the tool" else "look at my rig",
    })

    const Shown = if Build then HttpService:JSONEncode({ Build.Tool, Build.Parts }) else ""
    if Shown ~= ShownHash then
        ShownHash = Shown
        Bench.show(Build)
    end
    const Worn = if Build then HttpService:JSONEncode({ Build.Tool, Build.Parts, if Spot then { Spot.On, Spot.Attach, Spot.Size } else false }) else ""
    if Worn ~= WornHash then
        WornHash = Worn
        Bench.holster(Build)
    end
    refreshHandles()
end

const function editorView(): Bridges.EditorView?
    const Current = Edit
    if not Current then
        return nil
    end
    if Current.Kind == "Group" then
        const Name = Customize.groupName(Current.Id)
        if not Name then
            return nil
        end
        const Members = membersOf(Current.Id)
        Customize.mark(Members)
        return {
            Kind = "Group",
            Id = Current.Id,
            Name = Name,
            Label = `group of {#Members} {if #Members == 1 then "part" else "parts"}`,
            Texture = "",
            Mode = Customize.getMode(),
            Color = if Members[1] then Customize.colorOf(Members[1]) else nil,
        }
    end
    const Now = Customize.selected()
    if Now and Now ~= Current.Id then
        Current.Id = Now
    end
    const Kind = Customize.kindOf(Current.Id)
    if not Kind or Kind == "Body" then
        return nil
    end
    return {
        Kind = "Part",
        Id = Current.Id,
        Name = Customize.nameOf(Current.Id),
        Label = Menu.Tags[Kind] or "",
        Texture = Customize.textureOf(Current.Id) or "",
        Mode = Customize.getMode(),
        Attach = Customize.attachOf(Current.Id),
        Color = Customize.colorOf(Current.Id),
    }
end

const function closePicker(Keep: boolean)
    const Current = Picker
    if not Current then
        return
    end
    Picker = nil
    View.PickerOpen(false)
    if Keep then
        return
    end
    if Current.Kind == "Skin" then
        Customize.setSkin(Current.Skin)
        return
    end
    for _, Id in Current.Ids do
        const Original = Current.Originals[Id]
        if Original then
            Customize.setColor(Id, Original)
        else
            Customize.clearColor(Id)
        end
    end
end

const function openPicker(Kind: "Skin" | "Part" | "Group", Ids: { string }, Title: string, Start: Color3)
    closePicker(false)
    const Originals: { [string]: Color3 | false } = {}
    for _, Id in Ids do
        Originals[Id] = Customize.customColor(Id) or false
    end
    Picker = {
        Kind = Kind,
        Ids = Ids,
        Originals = Originals,
        Skin = if Kind == "Skin" then Customize.getSkin() else nil,
        Color = Start,
    }
    View.PickerOpen({ Title = Title, Color = Start })
end

const function liveColor(Color: Color3)
    const Current = Picker
    if not Current then
        return
    end
    Current.Color = Color
    if Current.Kind == "Skin" then
        Customize.setSkin(Color)
        return
    end
    for _, Id in Current.Ids do
        Customize.setColor(Id, Color)
    end
end

const function closeEditor()
    if not Edit then
        return
    end
    closePicker(true)
    Edit = nil
    Customize.select(nil)
    Customize.mark({})
    View.Editing(false)
    Menu.refresh()
end

const function refreshEditor()
    if not Edit then
        return
    end
    const Next = editorView()
    if not Next then
        closeEditor()
        return
    end
    View.EditorState(Next)
end

function Menu.refresh()
    if not Open then
        return
    end
    refreshClothes()
    if ShopOpen then
        refreshShop()
        if Page == "Tools" then
            View.HolsterState(hiddenHolster())
            View.ToolSlotBar(false)
            View.ToolAsk(false)
        end
        return
    end
    if Edit then
        refreshEditor()
        return
    end
    View.NavPage(Page)
    if Page == "Body" then
        refreshBody()
    elseif Page == "Parts" then
        refreshRig()
    elseif Page == "Saves" then
        refreshSaves()
    elseif Page == "Info" then
        refreshInfo()
    elseif Page == "Tools" then
        refreshTools()
    end
end

const function queue()
    if Queued then
        return
    end
    Queued = true
    task.defer(function()
        Queued = false
        Menu.refresh()
    end)
end

const function openEditor(Kind: EditKind, Id: string)
    if not Open or ShopOpen then
        return
    end
    closePicker(true)
    Edit = { Kind = Kind, Id = Id }
    Customize.mark({})
    if Kind == "Group" then
        Customize.selectGroup(Id)
    else
        Customize.select(Id)
    end
    if Customize.getMode() == "None" then
        Customize.setMode("Translate")
    end
    View.Editing(true)
    refreshEditor()
    refreshClothes()
end

const function openShop()
    closePicker(true)
    if Edit then
        closeEditor()
    end
    ShopOpen = true
    Gifting = nil
    View.DockShown(false)
    View.ShopShown(true)
    loadPrices()
    Sounds.play("MenuOpen")
    Menu.refresh()
end

const function closeShop()
    if not ShopOpen then
        return
    end
    ShopOpen = false
    Gifting = nil
    View.ShopShown(false)
    View.DockShown(true)
    Sounds.play("MenuClose")
    Menu.refresh()
end

const function setPage(Id: string)
    if Id == "Shop" then
        openShop()
        return
    end
    closePicker(true)
    if Page == "Tools" and Id ~= "Tools" then
        leaveTools()
    end
    Page = Id
    View.Page(Id)
    Menu.refresh()
end

const function run(Action: () -> ())
    task.spawn(function()
        Action()
        queue()
    end)
end

const function onNav(Action: string, Value: any)
    if Action == "Page" and type(Value) == "string" then
        setPage(Value)
    elseif Action == "Reset" then
        if confirmed("Reset") then
            View.NavReset(false)
            closePicker(true)
            Customize.reset()
            Pick = nil
            toast("Back to your normal avatar", true)
        else
            View.NavReset(true)
        end
    elseif Action == "Exit" then
        task.spawn(Menu.close)
    end
end

const function onBody(Action: string, Value: any)
    const Parts = picked()
    if Action == "SkinPick" then
        openPicker("Skin", {}, "skin color", Customize.getSkin() or Color3.fromRGB(234, 184, 146))
    elseif Action == "SkinReset" then
        closePicker(true)
        Customize.setSkin(nil)
    elseif Action == "Size" and type(Value) == "table" and type(Value.Key) == "string" then
        const Step = if type(Value.Step) == "number" then Value.Step else 0
        Customize.setProportion(Value.Key, if Step == 0 then 1 else Customize.getProportion(Value.Key) + Step * Config.HeightStep)
    elseif Action == "ScaleParts" then
        Customize.setScaleParts(not Customize.getScaleParts())
    elseif Action == "Animation" and type(Value) == "string" then
        Customize.setAnimation(Value)
    elseif Action == "Pick" and type(Value) == "string" then
        Pick = if Pick == Value then nil else Value
        Sounds.play("CustomizeSelect")
    elseif Action == "Limb" and type(Value) == "string" then
        const Key = `limb:{Value}`
        Pick = if Pick == Key then nil else Key
        Sounds.play("CustomizeSelect")
    elseif Action == "Hide" then
        const Hide = not hiddenAll(Parts)
        for _, Part in Parts do
            Customize.setHidden(Part, Hide)
        end
    elseif Action == "PartReset" then
        for _, Part in Parts do
            Customize.resetPart(Part)
        end
        const Current = Pick
        const Limb = if Current then string.match(Current, "^limb:(.+)$") else nil
        if Limb then
            Customize.swap(Limb, nil)
        end
    elseif Action == "Swap" and type(Value) == "string" then
        const Current = Pick
        const Key = if Current then (string.match(Current, "^limb:(.+)$") or Current) else nil
        if Key then
            const Ok, Problem = Customize.swap(Key, if Value == "none" then nil else Value)
            if not Ok then
                toast(Problem)
            end
        end
    end
    queue()
end

const function wear(Kind: Catalog.ClothingKind, Raw: string?)
    if not Config.AllowClothingIds then
        toast("Pick one of the clothes from the list")
        return
    end
    const Text = Raw or Typed[Kind] or ""
    if not Format.assetId(Text) then
        toast(`Paste a classic {string.lower(Kind)} id first`)
        return
    end
    run(function()
        const Ok, Problem = Customize.setClothing(Kind, Text)
        if Ok then
            Typed[Kind] = nil
        else
            toast(Problem)
        end
    end)
end

const function onClothes(Action: string, Value: any, Extra: any)
    const Kind: Catalog.ClothingKind? = if Value == "Shirt" or Value == "Pants" then Value else nil
    if Action == "WearShirt" or Action == "WearPants" then
        wear(if Action == "WearShirt" then "Shirt" else "Pants", nil)
        return
    end
    if not Kind then
        return
    end
    const Text = if type(Extra) == "string" then Extra else nil
    if Action == "Search" then
        Searches[Kind] = Text or ""
    elseif Action == "Typed" then
        Typed[Kind] = Text
        return
    elseif Action == "Wear" then
        wear(Kind, Text)
        return
    elseif Action == "Pick" and Text then
        if Text == "custom" then
            return
        end
        if Text == "default" then
            Customize.setClothing(Kind, nil)
        else
            const Preset = Catalog.clothing(Text)
            if Preset then
                run(function()
                    const Ok, Problem = Customize.setClothing(Kind, Preset.Asset)
                    if not Ok then
                        toast(Problem)
                    end
                end)
            end
        end
    end
    queue()
end

const function onDrop(Source: string, Key: string)
    if Key == "list" then
        if Customize.groupOf(Source) then
            Customize.leaveGroup(Source)
            Sounds.play("CustomizeSelect")
        end
        return
    end
    const Kind, Target = string.match(Key, "^(%a+):(.+)$")
    if not Kind or not Target then
        return
    end
    if Kind == "group" then
        if Customize.groupOf(Source) ~= Target and Customize.addToGroup({ Source }, Target) then
            Sounds.play("CustomizeSelect")
        end
    elseif Kind == "part" and Target ~= Source then
        const Into = Customize.groupOf(Target)
        if Into then
            if Customize.groupOf(Source) ~= Into then
                Customize.addToGroup({ Source }, Into)
            end
        else
            const Id, Problem = Customize.group({ Source, Target }, nil)
            if Id then
                toast("Made a group, press move on it to move them together", true)
            else
                toast(Problem)
            end
        end
        Sounds.play("CustomizeSelect")
    end
end

const function onRig(Action: string, Value: any, Extra: any)
    if Action == "InsertTyped" or Action == "ImportTyped" then
        Typed[Action] = if type(Value) == "string" then Value else nil
        return
    elseif Action == "Insert" then
        const Text = if type(Value) == "string" then Value else Typed.InsertTyped or ""
        const AssetId = Format.assetId(Text)
        if not AssetId then
            toast("Paste an accessory id first")
            return
        end
        run(function()
            const Id, Problem = Customize.addAsset(AssetId)
            if Id then
                Typed.InsertTyped = nil
                toast("Added it to your rig", true)
            else
                toast(Problem)
            end
        end)
    elseif Action == "AddMenu" then
        ShapesOpen = not ShapesOpen
        Sounds.play(if ShapesOpen then "MenuOpen" else "MenuClose")
    elseif Action == "Builtin" and type(Value) == "string" then
        const Id, Problem = Customize.addBuiltin(Value)
        if not Id then
            toast(Problem)
        end
    elseif Action == "Edit" and type(Value) == "string" then
        openEditor("Part", Value)
        return
    elseif Action == "Delete" and type(Value) == "string" then
        Customize.remove(Value)
    elseif Action == "Duplicate" and type(Value) == "string" then
        const Id, Problem = Customize.duplicate(Value)
        if Id then
            openEditor("Part", Id)
            return
        end
        toast(Problem)
    elseif Action == "GroupDuplicate" and type(Value) == "string" then
        const Id, Problem = Customize.duplicateGroup(Value)
        if Id then
            openEditor("Group", Id)
            return
        end
        toast(Problem)
    elseif Action == "Drop" and type(Value) == "string" and type(Extra) == "string" then
        onDrop(Value, Extra)
    elseif Action == "GroupMove" and type(Value) == "string" then
        openEditor("Group", Value)
        return
    elseif Action == "Ungroup" and type(Value) == "string" then
        Customize.ungroup(Value)
    elseif Action == "GroupDelete" and type(Value) == "string" then
        if not confirmed(`Group{Value}`) then
            toast("Press delete all again to remove the whole group", true)
            return
        end
        Customize.removeGroup(Value)
    elseif Action == "GroupName" and type(Value) == "string" then
        Customize.renameGroup(Value, if type(Extra) == "string" then Extra else nil)
    elseif Action == "Share" and type(Value) == "string" then
        run(function()
            const Code, Note = Customize.shareGroup(Value)
            if Code then
                View.RigShared(Code)
                toast(if Note then `Share code {Code}. {Note}` else `Share code {Code}`, true)
            else
                toast(Note)
            end
        end)
    elseif Action == "Unshare" and type(Value) == "string" then
        if not confirmed(`Unshare{Value}`) then
            toast("Press unshare again to turn off that code", true)
            return
        end
        run(function()
            const Ok, Problem = Customize.unshareGroup(Value)
            if Ok then
                View.RigShared("")
                toast("That share code no longer works", true)
            else
                toast(Problem)
            end
        end)
    elseif Action == "SharedHide" then
        View.RigShared("")
    elseif Action == "Import" then
        const Code = if type(Value) == "string" then Value else Typed.ImportTyped or ""
        if Code == "" then
            toast("Paste a share code first")
            return
        end
        run(function()
            const Ok, Problem = Customize.importCode(Code)
            if Ok then
                Typed.ImportTyped = nil
                toast("Added the shared group to your rig", true)
            else
                toast(Problem)
            end
        end)
    end
    queue()
end

const function onEditor(Action: string, Value: any)
    const Current = Edit
    if not Current then
        return
    end
    const Id = Current.Id
    const Targets = if Current.Kind == "Group" then membersOf(Id) else { Id }
    if Action == "Done" then
        closeEditor()
        return
    elseif Action == "Mode" and type(Value) == "string" then
        Customize.setMode(Value :: Customize.Mode)
    elseif Action == "Name" and type(Value) == "string" then
        if Current.Kind == "Group" then
            Customize.renameGroup(Id, Value)
        else
            Customize.rename(Id, Value)
        end
    elseif Action == "Reweld" and type(Value) == "string" then
        if Current.Kind == "Part" and Customize.attach(Id, Value, false) then
            Sounds.play("CustomizeSelect")
        end
    elseif Action == "Texture" and type(Value) == "string" then
        if Value == "" then
            Customize.setTexture(Id, "")
        elseif not Format.assetId(Value) then
            toast("Paste an image or decal id")
        else
            run(function()
                const Texture, Problem = Customize.resolveTexture(Value)
                if Texture then
                    for _, Target in Targets do
                        Customize.setTexture(Target, Texture)
                    end
                else
                    toast(Problem)
                end
            end)
            return
        end
    elseif Action == "Restore" then
        Customize.restoreTexture(Id)
    elseif Action == "ColorPick" then
        const Start = if Targets[1] then Customize.colorOf(Targets[1]) else nil
        openPicker(if Current.Kind == "Group" then "Group" else "Part", Targets, if Current.Kind == "Group" then "group color" else "part color", Start or Color3.new(1, 1, 1))
        return
    elseif Action == "ColorReset" then
        closePicker(true)
        for _, Target in Targets do
            Customize.clearColor(Target)
        end
    elseif Action == "Material" and type(Value) == "string" then
        const Material = Format.material(Value)
        if Material then
            for _, Target in Targets do
                Customize.setMaterial(Target, Material, true)
            end
        end
    elseif Action == "Reset" then
        Customize.resetPart(Id)
    elseif Action == "Duplicate" then
        local Made: string?, Problem: string? = nil, nil
        if Current.Kind == "Group" then
            Made, Problem = Customize.duplicateGroup(Id)
        else
            Made, Problem = Customize.duplicate(Id)
        end
        if Made then
            openEditor(Current.Kind, Made)
        else
            toast(Problem)
        end
        return
    elseif Action == "Ungroup" and Current.Kind == "Group" then
        Customize.ungroup(Id)
        closeEditor()
        return
    elseif Action == "Delete" then
        if Current.Kind == "Group" then
            if not confirmed(`Group{Id}`) then
                toast("Press delete all again to remove the whole group", true)
                return
            end
            Customize.removeGroup(Id)
        else
            Customize.remove(Id)
        end
        closeEditor()
        return
    end
    queue()
end

const function onPicker(Action: string, Value: any)
    if Action == "Live" and typeof(Value) == "Color3" then
        liveColor(Value)
    elseif Action == "Use" then
        const Current = Picker
        if Current then
            liveColor(Current.Color)
        end
        closePicker(true)
        Sounds.play("CustomizeApply")
    elseif Action == "Cancel" then
        closePicker(false)
    end
    queue()
end

const function onInfo(Action: string, Value: any)
    if Action == "Tab" and (Value == "Profile" or Value == "Stats") then
        InfoTab = Value
        Sounds.play("CustomizeSelect")
    elseif Action == "NicknameText" and type(Value) == "string" then
        NicknameDraft = Value
        return
    elseif Action == "DescriptionText" and type(Value) == "string" then
        DescriptionDraft = Value
        return
    elseif Action == "Save" then
        const Me = Players.LocalPlayer
        const Changes: { { Field: string, Text: string } } = {}
        const OldName = Me:GetAttribute("Nickname")
        const OldText = Me:GetAttribute("Description")
        if NicknameDraft and NicknameDraft ~= (if type(OldName) == "string" then OldName else "") then
            table.insert(Changes, { Field = "Nickname", Text = NicknameDraft })
        end
        if DescriptionDraft and DescriptionDraft ~= (if type(OldText) == "string" then OldText else "") then
            table.insert(Changes, { Field = "Description", Text = DescriptionDraft })
        end
        if #Changes == 0 then
            toast("Nothing changed", true)
            return
        end
        Sounds.play("SaveSlot")
        run(function()
            for _, Change in Changes do
                const Reply = NetWatch.Bio:Call("@Bio/Text", Change.Field, Change.Text)
                if type(Reply) ~= "table" or not Reply.Ok then
                    toast(if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "Your profile could not be saved")
                    return
                end
            end
            NicknameDraft = nil
            DescriptionDraft = nil
            toast("Profile saved", true)
        end)
        return
    elseif Action == "Stat" and type(Value) == "table" and type(Value.Id) == "string" and type(Value.Step) == "number" then
        const Def = Stats.get(Value.Id)
        if not Def then
            return
        end
        const Next = Stats.clamp(Def, Stats.valueOf(Players.LocalPlayer, Def) + Value.Step)
        Sounds.play("CustomizeSelect")
        run(function()
            const Reply = NetWatch.Bio:Call("@Bio/Stat", Def.Id, Next)
            if type(Reply) ~= "table" or not Reply.Ok then
                toast(if type(Reply) == "table" and type(Reply.Error) == "string" then Reply.Error else "That stat could not be saved")
            end
        end)
        return
    end
    queue()
end

const function onSaves(Action: string, Value: any, Extra: any)
    const Slot = if type(Value) == "number" then Value else nil
    if not Slot then
        return
    end
    const Filled = Customize.saves()[tostring(Slot)] ~= nil
    if Action == "Save" then
        if Filled and not confirmed(`Save{Slot}`) then
            refreshSaves()
            return
        end
        run(function()
            const Ok, Problem = Customize.save(Slot, Drafts[Slot])
            if Ok then
                Drafts[Slot] = nil
                Sounds.play("SaveSlot")
                toast(`Saved look {Slot}`, true)
            else
                toast(Problem)
            end
        end)
    elseif Action == "Load" then
        run(function()
            local Ok, Problem = Customize.loadSave(Slot)
            if Ok then
                Ok, Problem = ToolsClient.loadSave(Slot)
            end
            if Ok then
                Pick = nil
                Sounds.play("LoadSlot")
                toast(`Loaded look {Slot}`, true)
            else
                toast(Problem)
            end
        end)
    elseif Action == "Clear" then
        if not Filled then
            return
        end
        if not confirmed(`Clear{Slot}`) then
            refreshSaves()
            return
        end
        run(function()
            const Ok, Problem = Customize.clearSave(Slot)
            if Ok then
                Sounds.play("ClearSlot")
            else
                toast(Problem)
            end
        end)
    elseif Action == "Name" then
        const Text = if type(Extra) == "string" then string.match(Extra, "^%s*(.-)%s*$") or "" else ""
        if not Filled then
            Drafts[Slot] = if Text ~= "" then Text else nil
        elseif Text ~= "" then
            run(function()
                const Ok, Problem = Customize.renameSave(Slot, Text)
                if not Ok then
                    toast(Problem)
                end
            end)
        end
    end
    queue()
end

const function onShop(Action: string, Value: any, Extra: any)
    if Action == "Close" then
        closeShop()
        return
    elseif Action == "Pick" and type(Value) == "string" then
        ShopPick = Value
        if Gifting ~= Value then
            Gifting = nil
        end
        Sounds.play("CustomizeSelect")
    elseif Action == "Buy" and type(Value) == "string" then
        run(function()
            const Ok, Problem = Shop.buy(Value)
            if not Ok then
                toast(Problem)
            end
        end)
    elseif Action == "GiftOpen" and type(Value) == "string" then
        Gifting = Value
        Typed.Gift = nil
    elseif Action == "GiftClose" then
        Gifting = nil
    elseif Action == "GiftTyped" then
        Typed.Gift = if type(Value) == "string" then Value else nil
        return
    elseif Action == "GiftSend" and type(Value) == "string" then
        const Name = string.match(if type(Extra) == "string" then Extra else Typed.Gift or "", "^%s*(.-)%s*$") or ""
        if Name == "" then
            toast("Type the username of who it is for")
            return
        end
        run(function()
            const Ok, Problem, Real = Shop.gift(Value, Name)
            if Ok then
                Gifting = nil
                toast(`Finish the purchase to send it to {Real or Name}`, true)
            else
                toast(Problem)
            end
        end)
    end
    queue()
end

const function packProblem(Pack: string?): boolean
    if owns(Pack) then
        return false
    end
    toast(`Get the {Pack} pack in the shop to use this`, true)
    return true
end

const function onTools(Action: string, Value: any)
    const Build = Draft
    if Action == "Category" and type(Value) == "string" then
        ToolCategory = Value
        ToolMode = "Category"
        Sounds.play("CustomizeSelect")
    elseif Action == "Back" then
        if ToolMode == "Edit" then
            leaveEdit()
        else
            ToolMode = "Categories"
            ToolCategory = nil
        end
        Sounds.play("CustomizeSelect")
    elseif Action == "Pick" and type(Value) == "string" then
        const Def = Tools.get(Value)
        const Made = if Def then Tools.fresh(Value, owns) else nil
        if not Def or not Made then
            return
        end
        packProblem(Def.Pack)
        editTool(Made)
        Sounds.play("CustomizeSelect")
    elseif Action == "Equip" and Build then
        const Def = Tools.get(Build.Tool)
        if not Equipping and Def and packProblem(Def.Pack) then
            return
        end
        Equipping = not Equipping
        Mounting = nil
        Sounds.play("CustomizeSelect")
    elseif Action == "SlotPress" and type(Value) == "number" then
        if Equipping and Build then
            Equipping = false
            const Sending = copyBuild(Build)
            Sounds.play("CustomizeAdd")
            run(function()
                const Ok, Problem = ToolsClient.setSlot(Value, Sending)
                toast(if Ok then `Put it in slot {Value}` else Problem, Ok)
            end)
            return
        elseif ToolMode ~= "Edit" then
            if ToolsClient.slots()[tostring(Value)] then
                ToolAsk = { Kind = "Load", Slot = Value }
                Sounds.play("Confirm")
            else
                toast("That slot is empty, pick a tool and press equip", true)
            end
        end
    elseif Action == "SlotClear" and type(Value) == "number" and ToolMode ~= "Edit" then
        ToolAsk = { Kind = "Clear", Slot = Value }
        Sounds.play("Confirm")
    elseif Action == "AskNo" then
        ToolAsk = nil
    elseif Action == "AskYes" then
        const Waiting = ToolAsk
        ToolAsk = nil
        if Waiting and Waiting.Kind == "Load" then
            const Saved = ToolsClient.slots()[tostring(Waiting.Slot)]
            const Clean = if Saved then Tools.clean(Saved.Tool, Saved, owns) else nil
            if Clean then
                editTool(Clean)
                Sounds.play("CustomizeSelect")
            else
                toast("That tool could not be loaded")
            end
        elseif Waiting then
            const Slot = Waiting.Slot
            run(function()
                const Ok, Problem = ToolsClient.clearSlot(Slot)
                if not Ok then
                    toast(Problem)
                end
            end)
            return
        end
    elseif Action == "MountClose" then
        Mounting = nil
    elseif Action == "Remove" and type(Value) == "string" and Build then
        removePath(Build, Value)
        Sounds.play("CustomizeSelect")
    elseif Action == "Choose" and type(Value) == "string" and Build and Mounting then
        const Path = Mounting :: string
        if Value == "none" then
            removePath(Build, Path)
        else
            const Piece = Tools.attachment(Value)
            if not Piece then
                return
            end
            if not owns(Piece.Pack) then
                toast(`Get the {Piece.Pack} pack in the shop for that`, true)
                return
            end
            if Build.Parts[Path] ~= Value then
                removePath(Build, Path)
                Build.Parts[Path] = Value
            end
        end
        Mounting = nil
        Sounds.play("CustomizeAdd")
    elseif Action == "View" then
        Bench.look(not Bench.looking())
    elseif Build and string.sub(Action, 1, 7) == "Holster" then
        const Spot = holsterOf(Build)
        if Action == "HolsterToggle" then
            Spot.On = not Spot.On
            if Spot.On then
                Bench.look(true)
            end
        elseif Action == "HolsterAttach" and type(Value) == "string" then
            Spot.Attach = Value
        elseif Action == "HolsterMode" and type(Value) == "string" then
            if Value == "Translate" or Value == "Rotate" then
                HolsterMode = Value
                Bench.look(true)
            else
                HolsterMode = "None"
            end
        elseif Action == "HolsterSize" and type(Value) == "table" then
            const Step = if type(Value.Step) == "number" then Value.Step else 0
            Spot.Size = if Step == 0 then 1 else math.clamp(Spot.Size + Step * Tools.Config.SizeStep, Tools.Config.MinSize, Tools.Config.MaxSize)
        end
    end
    queue()
end

const function onInput(Input: InputObject, Processed: boolean)
    if not Open or Processed or Busy then
        return
    end
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        if ShopOpen or Picker or Page == "Tools" then
            return
        end
        task.defer(function()
            if not Open or Gizmo.busy() then
                return
            end
            const Id = Customize.pickAtMouse()
            if Id and not (Edit and Edit.Id == Id) then
                openEditor("Part", Id)
            end
        end)
        return
    end
    if Input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    if Input.KeyCode == Menu.DoneKey then
        if Picker then
            onPicker("Use", nil)
        elseif Edit then
            closeEditor()
        end
        return
    end
    const Current = Edit
    if not Current then
        return
    end
    const Mode = Menu.Keys[Input.KeyCode]
    if Mode then
        onEditor("Mode", Mode)
    elseif Input.KeyCode == Enum.KeyCode.Delete then
        onEditor("Delete", nil)
    end
end

const function overGui(): boolean
    const Gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not Gui then
        return false
    end
    const Mouse = UserInputService:GetMouseLocation()
    const Inset = GuiService:GetGuiInset()
    for _, Object in Gui:GetGuiObjectsAtPosition(Mouse.X - Inset.X, Mouse.Y - Inset.Y) do
        if Object.Active or Object:IsA("GuiButton") or Object:IsA("TextBox") or Object:IsA("ScrollingFrame") then
            return true
        end
        if Object.BackgroundTransparency < 1 and Object.Name ~= "Customize_Dim" then
            return true
        end
    end
    return false
end

local Waited = 0

const function hoverStep(Delta: number)
    Waited += Delta
    if Waited < Menu.HoverRate then
        return
    end
    Waited = 0
    if not Open or Busy or ShopOpen or Picker or Edit or Page == "Tools" or Gizmo.busy() or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or overGui() then
        Customize.hover(nil)
        return
    end
    Customize.hover(Customize.pickAtMouse())
end

const function closed()
    if Page == "Tools" then
        leaveTools()
    end
    Page = "Body"
    Open = false
    Edit = nil
    Pick = nil
    Picker = nil
    ShopOpen = false
    Gifting = nil
    Confirm = nil
    View.Shown(false)
    View.Editing(false)
    View.ShopShown(false)
    View.DockShown(true)
    View.PickerOpen(false)
    View.ClothesState({ Shown = false, Ids = Config.AllowClothingIds, Shirt = "", Pants = "" })
    View.NavReset(false)
    View.RigShared("")
    View.SideShown(true)
    Menu.Closed:Fire()
end

function Menu.isOpen(): boolean
    return Open
end

function Menu.open()
    Menu.start()
    if Open or Busy then
        return
    end
    Busy = true
    ToolsClient.unequipNow()
    const Ok = Customize.enter()
    Busy = false
    if not Ok then
        toast("You can not customize right now")
        return
    end
    Open = true
    Page = "Body"
    View.Shown(true)
    View.DockShown(true)
    View.Editing(false)
    View.Page(Page)
    Menu.Opened:Fire()
    Menu.refresh()
end

function Menu.close()
    if not Open or Busy then
        return
    end
    Busy = true
    closePicker(true)
    if Page == "Tools" then
        leaveTools()
    end
    View.Shown(false)
    const Ok, Problem = Customize.exit()
    Busy = false
    if Open then
        closed()
    end
    toast(if Ok then "Your look is on" else Problem or "Your look could not be put on", Ok)
end

function Menu.toggle()
    if Open then
        Menu.close()
    else
        Menu.open()
    end
end

function Menu.start()
    if Started then
        return
    end
    Started = true
    Customize.start()
    Shop.start(function(Text: string)
        PropPlacer.toast(Text, "Info")
    end)

    const Gui = vision.create({
        ClassName = "ScreenGui",
        Name = "Customize",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 6,
    }) :: ScreenGui
    Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    View:Open().Parent = Gui

    Bridges.Nav:Bind(onNav)
    Bridges.Body:Bind(onBody)
    Bridges.Clothes:Bind(onClothes)
    Bridges.Rig:Bind(onRig)
    Bridges.Editor:Bind(onEditor)
    Bridges.Picker:Bind(onPicker)
    Bridges.Saves:Bind(onSaves)
    Bridges.Info:Bind(onInfo)
    Players.LocalPlayer.AttributeChanged:Connect(function(Name: string)
        if Open and Page == "Info" and (Name == "Nickname" or Name == "Description" or string.sub(Name, 1, #Stats.AttributePrefix) == Stats.AttributePrefix) then
            queue()
        end
    end)
    Bridges.Shop:Bind(onShop)
    Bridges.Tools:Bind(onTools)
    Bench.MountClicked:Connect(function(Path: string)
        if Open and Page == "Tools" and ToolMode == "Edit" then
            Mounting = Path
            Sounds.play("CustomizeSelect")
            queue()
        end
    end)
    Bench.MountRemoved:Connect(function(Path: string)
        const Build = Draft
        if Open and Page == "Tools" and ToolMode == "Edit" and Build then
            removePath(Build, Path)
            if Mounting == Path then
                Mounting = nil
            end
            Sounds.play("CustomizeSelect")
            queue()
        end
    end)
    ToolsClient.Changed:Connect(queue)
    ToolAssets.Arrived:Connect(function()
        if Open and Page == "Tools" then
            ShownHash = ""
            WornHash = ""
            queue()
        end
    end)

    Customize.Changed:Connect(queue)
    Customize.SelectionChanged:Connect(function()
        if Edit then
            queue()
        end
    end)
    Customize.Exited:Connect(function(Ok: boolean, Problem: string?)
        if Open and not Busy then
            closed()
            if not Ok then
                toast(Problem)
            end
        end
    end)
    UserInputService.InputBegan:Connect(onInput)
    RunService.Heartbeat:Connect(hoverStep)
end

return Menu
