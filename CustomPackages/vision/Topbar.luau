const Symbols = require(script.Parent.Symbols)

const Topbar = {}

const Icons: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any
const Memory: { [any]: { Folder: Instance, Notices: number, Keys: { any }, Items: { Instance } } } =
    setmetatable({}, { __mode = "k" }) :: any

const States = { Deselected = true, Selected = true, Viewing = true }
const ChildRoles = { Dropdown = true, Menu = true, FixedMenu = true }
const Sides = { Left = true, Right = true }

local IconModule: any = nil

function Topbar.library(): any
    if IconModule then
        return IconModule
    end

    const Packages = (script.Parent :: Instance).Parent
    const Found = Packages and Packages:FindFirstChild("TopbarPlus")

    if not Found or not Found:IsA("ModuleScript") then
        error("Vision.Topbar needs TopbarPlus next to vision (MainPackages.TopbarPlus)", 0)
    end

    IconModule = require(Found :: any)

    return IconModule
end

function Topbar.iconOf(Folder: Instance): any?
    return Icons[Folder]
end

function Topbar.getIcon(NameOrUID: string): any?
    return Topbar.library().getIcon(NameOrUID)
end

function Topbar.getIcons(): { [string]: any }
    return Topbar.library().getIcons()
end

function Topbar.getIconByUID(UID: string): any?
    return Topbar.library().getIconByUID(UID)
end

function Topbar.setTopbarEnabled(Enabled: boolean)
    Topbar.library().setTopbarEnabled(Enabled)
end

function Topbar.modifyBaseTheme(Modifications: any)
    Topbar.library().modifyBaseTheme(Modifications)
end

function Topbar.setDisplayOrder(Order: number)
    Topbar.library().setDisplayOrder(Order)
end

const function IsStateMap(Value: any): boolean
    if type(Value) ~= "table" or next(Value) == nil then
        return false
    end

    for Key in Value do
        if not States[Key] then
            return false
        end
    end

    return true
end

const function List(Value: any): { any }
    return if type(Value) == "table" then Value else { Value }
end

const function Resolve(Folder: Instance, Item: any): Instance?
    if typeof(Item) == "Instance" then
        return Item
    end

    if type(Item) == "string" then
        const Root = Folder.Parent or Folder

        return Root:FindFirstChild(Item, true)
    end

    return nil
end

const function PerState(Method: string)
    return function(Icon: any, Value: any)
        if IsStateMap(Value) then
            for State, Each in Value do
                Icon[Method](Icon, Each, State)
            end
        else
            Icon[Method](Icon, Value)
        end
    end
end

const function Flag(Method: string)
    return function(Icon: any, Value: any)
        Icon[Method](Icon, Value == true)
    end
end

const function SetFont(Icon: any, Font_: any, State: string?)
    if typeof(Font_) == "Font" then
        Icon:modifyTheme({ "IconLabel", "FontFace", Font_, State })
    else
        Icon:setTextFont(Font_, nil, nil, State)
    end
end

const function SetNotices(Icon: any, Value: any, Mem: any)
    const Count = math.max(math.floor(tonumber(Value) or 0), 0)
    local Current = Mem.Notices

    if Count == Current then
        return
    end

    if Count < Current then
        Icon:clearNotices()
        Current = 0
    end

    for _ = Current + 1, Count do
        Icon:notify()
    end

    Mem.Notices = Count
end

const Order = {
    "Name", "Align", "Theme", "Modify", "ModifyChild",
    "Label", "Image", "Order", "Width", "CornerRadius", "ImageScale", "ImageRatio",
    "TextSize", "TextFont", "TextColor",
    "Caption", "CaptionHint", "NoticeLabel", "Indicator",
    "Enabled", "Locked", "OneClick", "AutoDeselect", "CloseOnOutsideClick", "DestroyOnRespawn",
    "DisableOverlay", "Keys", "ToggleItems", "ClipOutside", "Behaviours", "NumberSpinner",
    "Notices", "Selected", "State",
}

const Setters: { [string]: (Icon: any, Value: any, Mem: any) -> () } = {
    Name = function(Icon, Value)
        Icon:setName(Value)
    end,
    Align = function(Icon, Value)
        Icon:align(Value)
    end,
    Theme = function(Icon, Value)
        Icon:setTheme(Value)
    end,
    Modify = function(Icon, Value)
        Icon:removeModification("VisionModify")
        Icon:modifyTheme(Value, "VisionModify")
    end,
    ModifyChild = function(Icon, Value)
        Icon:modifyChildTheme(Value, "VisionModifyChild")
    end,

    Label = PerState("setLabel"),
    Image = PerState("setImage"),
    Order = PerState("setOrder"),
    Width = PerState("setWidth"),
    CornerRadius = PerState("setCornerRadius"),
    ImageScale = PerState("setImageScale"),
    ImageRatio = PerState("setImageRatio"),
    TextSize = PerState("setTextSize"),
    TextColor = PerState("setTextColor"),
    TextFont = function(Icon, Value)
        if IsStateMap(Value) then
            for State, Each in Value do
                SetFont(Icon, Each, State)
            end
        else
            SetFont(Icon, Value)
        end
    end,

    Caption = function(Icon, Value)
        Icon:setCaption(Value)
    end,
    CaptionHint = function(Icon, Value)
        Icon:setCaptionHint(Value)
    end,
    NoticeLabel = function(Icon, Value)
        Icon:setNoticeLabel(Value)
    end,
    Indicator = function(Icon, Value)
        Icon:setIndicator(Value)
    end,

    Enabled = function(Icon, Value)
        Icon:setEnabled(Value ~= false)
    end,
    Locked = function(Icon, Value)
        if Value == true then
            Icon:lock()
        else
            Icon:unlock()
        end
    end,
    OneClick = Flag("oneClick"),
    AutoDeselect = Flag("autoDeselect"),
    CloseOnOutsideClick = Flag("setCloseOnOutsideClick"),
    DestroyOnRespawn = Flag("setDestroyOnRespawn"),
    DisableOverlay = Flag("disableOverlay"),

    Keys = function(Icon, Value, Mem)
        for _, Key in Mem.Keys do
            Icon:unbindToggleKey(Key)
        end

        Mem.Keys = table.clone(List(Value))

        for _, Key in Mem.Keys do
            Icon:bindToggleKey(Key)
        end
    end,
    ToggleItems = function(Icon, Value, Mem)
        for _, Item in Mem.Items do
            Icon:unbindToggleItem(Item)
        end

        table.clear(Mem.Items)

        for _, Each in List(Value) do
            const Item = Resolve(Mem.Folder, Each)

            if Item then
                Icon:bindToggleItem(Item)
                table.insert(Mem.Items, Item)
            else
                warn(`[Vision.Topbar] toggle item "{tostring(Each)}" was not found`)
            end
        end
    end,
    ClipOutside = function(Icon, Value, Mem)
        for _, Each in List(Value) do
            const Item = Resolve(Mem.Folder, Each)

            if Item then
                Icon:clipOutside(Item)
            end
        end
    end,
    Behaviours = function(Icon, Value)
        for _, Each in Value do
            Icon:setBehaviour(
                Each[1] or Each.Collective,
                Each[2] or Each.Property,
                Each[3] or Each.Callback,
                Each[4] or Each.Refresh
            )
        end
    end,
    NumberSpinner = function(Icon, Value)
        if type(Value) == "table" and Value.Spinner then
            Icon:convertLabelToNumberSpinner(Value.Spinner, Value.Callback)
        else
            Icon:convertLabelToNumberSpinner(Value)
        end
    end,

    Notices = SetNotices,
    Selected = function(Icon, Value)
        if Value == true and not Icon.isSelected then
            Icon:select()
        elseif Value ~= true and Icon.isSelected then
            Icon:deselect()
        end
    end,
    State = function(Icon, Value)
        if type(Value) == "string" and Icon.activeState ~= Value then
            Icon:setState(Value)
        end
    end,
}

const function Read(View: any, Token: any): any
    const Getter = View[Token.Name]
    const Value = if type(Getter) == "function" then Getter() else nil

    return if Value == nil then Token.Initial else Value
end

const function WriteBack(View: any, Token: any, Value: any)
    if Symbols.Bound(Token) then
        const Setter = View[Token.Name]

        if type(Setter) == "function" then
            Setter(Value)
        end
    end
end

const function Tag(Child: { [any]: any }, Role: string, Index: number)
    const Copy = table.clone(Child)
    const Attributes = table.clone(Copy.attributes or Copy.Attributes or {})

    Attributes.TopbarRole = Role
    Attributes.TopbarIndex = Index
    Copy.attributes = Attributes
    Copy.Attributes = nil

    return Copy
end

function Topbar.icon(Props: { [string]: any })
    const Declaration: { [any]: any } = {
        ClassName = "Folder",
        Name = if type(Props.Name) == "string" then Props.Name else "TopbarIcon",
    }

    for _, Key in Order do
        const Value = Props[Key]

        if Symbols.Bound(Value) then
            table.insert(Declaration, Symbols.merge(Value.Name, function(Folder: Instance, _, New: any)
                const Icon = Icons[Folder]

                if Icon and New ~= nil then
                    Setters[Key](Icon, New, Memory[Icon])
                end
            end))
        end
    end

    for Role in ChildRoles do
        for Index, Child in Props[Role] or {} do
            table.insert(Declaration, Tag(Child, Role, Index))
        end
    end

    for Side in Sides do
        for Index, Child in Props[Side] or {} do
            table.insert(Declaration, Tag(Child, Side, Index))
        end
    end

    table.insert(Declaration, Symbols.ready(function(Folder: Instance, View: any, OnCleanup: any)
        const Icon = Topbar.library().new()
        const Mem = { Folder = Folder, Notices = 0, Keys = {}, Items = {} }

        Icons[Folder] = Icon
        Memory[Icon] = Mem

        for _, Key in Order do
            const Value = Props[Key]
            const Now = if Symbols.Bound(Value) then Read(View, Value) else Value

            if Now ~= nil then
                Setters[Key](Icon, Now, Mem)
            end
        end

        if Props.Action and Props.OneClick == nil then
            Icon:oneClick(true)
        end

        Icon.toggled:Connect(function(IsSelected: boolean)
            WriteBack(View, Props.Selected, IsSelected)
        end)

        Icon.stateChanged:Connect(function(StateName: string)
            WriteBack(View, Props.State, StateName)
        end)

        Icon.selected:Connect(function()
            if Props.Action then
                Props.Action:Press(Icon)
                Props.Action:Release(Icon)
            end

            if Props.OnClick then
                task.spawn(Props.OnClick, Icon, View)
            end
        end)

        for Key, Callback in Props do
            if type(Key) ~= "string" or type(Callback) ~= "function" or Key == "OnClick" then
                continue
            end

            if string.sub(Key, 1, 2) ~= "On" then
                continue
            end

            const EventName = string.lower(string.sub(Key, 3, 3)) .. string.sub(Key, 4)
            const Signal = Icon[EventName]

            if type(Signal) == "table" and Signal.Connect then
                Signal:Connect(function(...)
                    Callback(Icon, View, ...)
                end)
            else
                warn(`[Vision.Topbar] {Key}: TopbarPlus icons have no "{EventName}" event`)
            end
        end

        for EventName, Callback in Props.Events or {} do
            Icon:bindEvent(EventName, Callback)
        end

        const Roles: { [string]: { { Index: number, Item: any } } } = {}

        for _, Child in Folder:GetChildren() do
            const Role = Child:GetAttribute("TopbarRole")
            const Index = Child:GetAttribute("TopbarIndex") or 0

            if ChildRoles[Role] and Icons[Child] then
                Roles[Role] = Roles[Role] or {}
                table.insert(Roles[Role], { Index = Index, Item = Icons[Child] })
            elseif Sides[Role] and Child:IsA("GuiObject") then
                Roles[Role] = Roles[Role] or {}
                table.insert(Roles[Role], { Index = Index, Item = Child })
            end
        end

        for Role, Entries in Roles do
            table.sort(Entries, function(A, B)
                return A.Index < B.Index
            end)

            const Items = {}

            for _, Entry in Entries do
                table.insert(Items, Entry.Item)
            end

            if Role == "Dropdown" then
                Icon:setDropdown(Items)
            elseif Role == "Menu" then
                Icon:setMenu(Items)
            elseif Role == "FixedMenu" then
                Icon:setFixedMenu(Items)
            else
                for _, Item in Items do
                    Icon:addInstance(Item, Role)
                end
            end
        end

        if type(Props.Handle) == "string" then
            const Setter = View[Props.Handle]

            if type(Setter) == "function" then
                Setter(Icon)
            end
        end

        if Props.Setup then
            Props.Setup(Icon, View)
        end

        OnCleanup(function()
            Icons[Folder] = nil
            Memory[Icon] = nil
            Icon:destroy()
        end)
    end))

    return Declaration
end

const Globals: { [string]: (Value: any) -> () } = {
    Enabled = function(Value)
        Topbar.setTopbarEnabled(Value ~= false)
    end,
    DisplayOrder = function(Value)
        Topbar.setDisplayOrder(Value)
    end,
    BaseTheme = function(Value)
        Topbar.modifyBaseTheme(Value)
    end,
}

function Topbar.settings(Props: { [string]: any })
    const Declaration: { [any]: any } = { ClassName = "Folder", Name = "TopbarSettings" }

    for Key, Apply in Globals do
        const Value = Props[Key]

        if Symbols.Bound(Value) then
            table.insert(Declaration, Symbols.merge(Value.Name, function(Folder: Instance, _, New: any)
                if New ~= nil and Folder:GetAttribute("Ready") then
                    Apply(New)
                end
            end))
        end
    end

    table.insert(Declaration, Symbols.ready(function(Folder: Instance, View: any, OnCleanup: any)
        for Key, Apply in Globals do
            const Value = Props[Key]
            const Now = if Symbols.Bound(Value) then Read(View, Value) else Value

            if Now ~= nil then
                Apply(Now)
            end
        end

        Folder:SetAttribute("Ready", true)

        OnCleanup(function()
            if Props.Enabled ~= nil then
                Topbar.setTopbarEnabled(true)
            end
        end)
    end))

    return Declaration
end

return table.freeze(Topbar)
