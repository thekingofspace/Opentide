const ContextActionService = game:GetService("ContextActionService")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const Symbols = require(script.Parent.Symbols)

export type Key = Enum.KeyCode | Enum.UserInputType

export type Options = {
    Keys: { Key }?,
    Activated: ((Input: InputObject?) -> ())?,
    Released: ((Input: InputObject?) -> ())?,
    Priority: number?,
    Sink: boolean?,
    Touch: boolean?,
}

export type ButtonOptions = {
    TouchOnly: boolean?,
}

export type Action = {
    Name: string,
    Values: { Held: string, Key: string, KeyImage: string, Enabled: string },

    Bind: (self: Action) -> (),
    Unbind: (self: Action) -> (),
    IsBound: (self: Action) -> boolean,
    IsHeld: (self: Action) -> boolean,
    Press: (self: Action, Source: any?) -> (),
    Release: (self: Action, Source: any?) -> (),
    SetEnabled: (self: Action, Enabled: boolean) -> (),
    SetKeys: (self: Action, Keys: { Key }) -> (),
    Destroy: (self: Action) -> (),
}

const Action = {}
Action.__index = Action

const Registry: { [string]: any } = {}

const function Device(): "Touch" | "Gamepad" | "Keyboard"
    const Last = UserInputService:GetLastInputType()

    if Last == Enum.UserInputType.Touch then
        return "Touch"
    end

    if string.find(Last.Name, "^Gamepad") then
        return "Gamepad"
    end

    return "Keyboard"
end

const function IsGamepadKey(Key: Key): boolean
    if Key.EnumType ~= Enum.KeyCode then
        return false
    end

    const Name = Key.Name

    return string.find(Name, "^Button") ~= nil or string.find(Name, "^DPad") ~= nil or string.find(Name, "^Thumbstick") ~= nil
end

const function Labels(Keys: { Key }): (string, string)
    const Mode = Device()

    if Mode == "Touch" then
        return "", ""
    end

    for _, Key in Keys do
        if IsGamepadKey(Key) ~= (Mode == "Gamepad") then
            continue
        end

        if Mode == "Gamepad" then
            return (string.gsub(Key.Name, "^Button", "")), UserInputService:GetImageForKeyCode(Key :: Enum.KeyCode)
        end

        if Key.EnumType == Enum.KeyCode then
            const Text = UserInputService:GetStringForKeyCode(Key :: Enum.KeyCode)

            return if Text ~= "" then Text else Key.Name, ""
        end

        return Key.Name, ""
    end

    return "", ""
end

const function Write(self: any, View: any, Field: string, Value: any)
    const Setter = View[self.Values[Field]]

    if type(Setter) == "function" then
        Setter(Value)
    end
end

const function Publish(self: any, Field: string, Value: any)
    for View in self.Views do
        Write(self, View, Field, Value)
    end
end

const function PushAll(self: any, View: any)
    const Text, Image = Labels(self.Keys)

    Write(self, View, "Held", next(self.Pressed) ~= nil)
    Write(self, View, "Key", Text)
    Write(self, View, "KeyImage", Image)
    Write(self, View, "Enabled", self.Enabled)
end

const function PublishKeys(self: any)
    const Text, Image = Labels(self.Keys)

    Publish(self, "Key", Text)
    Publish(self, "KeyImage", Image)
end

const function Handler(self: any)
    return function(_: string, State: Enum.UserInputState, Input: InputObject)
        if State == Enum.UserInputState.Begin then
            self:Press(Input)
        elseif State == Enum.UserInputState.End or State == Enum.UserInputState.Cancel then
            self:Release(Input)
        end

        return if self.Options.Sink == false then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
    end
end

const function Apply(self: any)
    const Want = self.Holds > 0 and self.Enabled

    if Want == self.Bound then
        return
    end

    self.Bound = Want

    if Want then
        const Options = self.Options

        if Options.Priority then
            ContextActionService:BindActionAtPriority(self.Name, Handler(self), Options.Touch == true, Options.Priority, table.unpack(self.Keys))
        else
            ContextActionService:BindAction(self.Name, Handler(self), Options.Touch == true, table.unpack(self.Keys))
        end

        return
    end

    ContextActionService:UnbindAction(self.Name)

    for Source in table.clone(self.Pressed) do
        if typeof(Source) == "Instance" then
            self:Release(Source)
        end
    end
end

function Action.new(Name: string, Options: Options?): Action
    if type(Name) ~= "string" or Name == "" then
        error("an action needs a name", 2)
    end

    if Registry[Name] then
        error(`an action named "{Name}" already exists; get it with Action.get or :Destroy() it first`, 2)
    end

    const Given: Options = Options or {}
    const self = setmetatable({
        Name = Name,
        Values = {
            Held = `{Name}.Held`,
            Key = `{Name}.Key`,
            KeyImage = `{Name}.KeyImage`,
            Enabled = `{Name}.Enabled`,
        },
        Options = Given,
        Keys = table.clone(Given.Keys or {}),
        Holds = 0,
        Bound = false,
        Enabled = true,
        Pressed = {} :: { [any]: boolean },
        Views = setmetatable({}, { __mode = "k" }) :: any,
    }, Action)

    Registry[Name] = self

    return (self :: any) :: Action
end

function Action.get(Name: string): Action?
    return Registry[Name]
end

function Action.Bind(self: any)
    self.Holds += 1
    Apply(self)
end

function Action.Unbind(self: any)
    self.Holds = math.max(self.Holds - 1, 0)
    Apply(self)
end

function Action.IsBound(self: any): boolean
    return self.Bound
end

function Action.IsHeld(self: any): boolean
    return next(self.Pressed) ~= nil
end

function Action.Press(self: any, Source: any?)
    const From = if Source == nil then "Manual" else Source

    if not self.Enabled or self.Pressed[From] then
        return
    end

    const Was = next(self.Pressed) ~= nil

    self.Pressed[From] = true

    if not Was then
        Publish(self, "Held", true)

        if self.Options.Activated then
            task.spawn(self.Options.Activated, if typeof(From) == "Instance" then From else nil)
        end
    end
end

function Action.Release(self: any, Source: any?)
    const From = if Source == nil then "Manual" else Source

    if not self.Pressed[From] then
        return
    end

    self.Pressed[From] = nil

    if next(self.Pressed) == nil then
        Publish(self, "Held", false)

        if self.Options.Released then
            task.spawn(self.Options.Released, if typeof(From) == "Instance" then From else nil)
        end
    end
end

function Action.SetEnabled(self: any, Enabled: boolean)
    if self.Enabled == Enabled then
        return
    end

    self.Enabled = Enabled

    if not Enabled then
        for Source in table.clone(self.Pressed) do
            self:Release(Source)
        end
    end

    Apply(self)
    Publish(self, "Enabled", Enabled)
end

function Action.SetKeys(self: any, Keys: { Key })
    self.Keys = table.clone(Keys)

    if self.Bound then
        self.Bound = false
        ContextActionService:UnbindAction(self.Name)
        Apply(self)
    end

    PublishKeys(self)
end

function Action.Destroy(self: any)
    if self.Bound then
        ContextActionService:UnbindAction(self.Name)
        self.Bound = false
    end

    table.clear(self.Pressed)
    table.clear(self.Views)

    if Registry[self.Name] == self then
        Registry[self.Name] = nil
    end
end

const function IsPointer(Input: InputObject): boolean
    return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

function Action.button(Target: Action | string, Options: ButtonOptions?)
    const Settings: ButtonOptions = Options or {}

    return Symbols.ready(function(Button: Instance, View: any, OnCleanup: any)
        const self: any = if type(Target) == "string" then Registry[Target] else Target

        if not self then
            error(`no action named "{tostring(Target)}"; make it with Action.new first`, 0)
        end

        if not Button:IsA("GuiButton") then
            error(`Action.button("{self.Name}") belongs on a TextButton or ImageButton, not a {Button.ClassName}`, 0)
        end

        self.Views[View] = (self.Views[View] or 0) + 1
        self.Holds += 1
        Apply(self)
        PushAll(self, View)

        const Mine: { [InputObject]: boolean } = {}
        const Connections: { RBXScriptConnection } = {}

        const function Finish(Input: InputObject)
            if Mine[Input] then
                Mine[Input] = nil
                self:Release(Input)
            end
        end

        table.insert(Connections, Button.InputBegan:Connect(function(Input: InputObject)
            if not IsPointer(Input) or Mine[Input] then
                return
            end

            Mine[Input] = true
            self:Press(Input)

            local Watch: RBXScriptConnection

            Watch = Input:GetPropertyChangedSignal("UserInputState"):Connect(function()
                if Input.UserInputState == Enum.UserInputState.End or Input.UserInputState == Enum.UserInputState.Cancel then
                    Watch:Disconnect()
                    Finish(Input)
                end
            end)

            table.insert(Connections, Watch)
        end))

        table.insert(Connections, (Button :: GuiButton).Activated:Connect(function(Input: InputObject?)
            if Input and string.find(Input.UserInputType.Name, "^Gamepad") then
                self:Press(Input)
                self:Release(Input)
            end
        end))

        if Settings.TouchOnly then
            const function Show()
                (Button :: GuiButton).Visible = Device() == "Touch"
            end

            table.insert(Connections, UserInputService.LastInputTypeChanged:Connect(Show))
            Show()
        end

        OnCleanup(function()
            for _, Connection in Connections do
                Connection:Disconnect()
            end

            for Input in table.clone(Mine) do
                Finish(Input)
            end

            const Count = (self.Views[View] or 1) - 1

            self.Views[View] = if Count > 0 then Count else nil
            self.Holds = math.max(self.Holds - 1, 0)
            Apply(self)
        end)
    end)
end

if RunService:IsClient() then
    UserInputService.LastInputTypeChanged:Connect(function()
        for _, Each in Registry do
            if next(Each.Views) ~= nil then
                PublishKeys(Each)
            end
        end
    end)
end

return table.freeze({
    new = Action.new,
    get = Action.get,
    button = Action.button,
})
