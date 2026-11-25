--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const vision = require(ReplicatedStorage.MainPackages.vision)
const Bridges = require(script.Parent.Bridges)
const Sounds = require(ReplicatedStorage.Shared.Sounds)

export type Spec = {
    Id: string,
    Text: string,
    Color: Color3?,
    Ink: Color3?,
    Icon: string?,
    Key: string?,
    Order: number?,
    Toggle: boolean?,
    Active: boolean?,
    pressed: ((Button: Button) -> ())?,
}

export type Button = {
    Id: string,
    setActive: (Self: Button, Active: boolean) -> (),
    isActive: (Self: Button) -> boolean,
    setVisible: (Self: Button, Visible: boolean) -> (),
    setText: (Self: Button, Text: string) -> (),
    setColor: (Self: Button, Color: Color3, Ink: Color3?) -> (),
    remove: (Self: Button) -> (),
}

type Entry = {
    Spec: Spec,
    Button: Button,
    Active: boolean,
    Visible: boolean,
    Index: number,
}

const Sidebar = {
    DefaultColor = Color3.fromRGB(120, 124, 134),
    DefaultInk = Color3.new(1, 1, 1),
    OnColor = Color3.fromRGB(78, 160, 96),
    OffColor = Color3.fromRGB(214, 84, 72),
}

const Entries: { [string]: Entry } = {}
local View: vision.Vision? = nil
local Open = true
local Count = 0

const function refresh()
    const Shown = View
    if not Shown then
        return
    end
    const List: { Entry } = {}
    for _, Entry in Entries do
        if Entry.Visible then
            table.insert(List, Entry)
        end
    end
    table.sort(List, function(A: Entry, B: Entry): boolean
        const OrderA = A.Spec.Order or 0
        const OrderB = B.Spec.Order or 0
        if OrderA == OrderB then
            return A.Index < B.Index
        end
        return OrderA < OrderB
    end)
    const Views = {}
    for Position, Entry in List do
        table.insert(Views, {
            Id = Entry.Spec.Id,
            Text = Entry.Spec.Text,
            Color = if Entry.Spec.Toggle
                then (if Entry.Active then Sidebar.OnColor else Sidebar.OffColor)
                else Entry.Spec.Color or Sidebar.DefaultColor,
            Ink = Entry.Spec.Ink or Sidebar.DefaultInk,
            Icon = Entry.Spec.Icon,
            Key = Entry.Spec.Key,
            Active = Entry.Active,
            Toggle = Entry.Spec.Toggle == true,
            Order = Position,
        })
    end
    Shown.Buttons(Views)
end

function Sidebar.attach(Given: vision.Vision)
    View = Given
    Given.Expanded(Open)
    refresh()
end

function Sidebar.addButton(Spec: Spec): Button
    const Old = Entries[Spec.Id]
    if Old then
        Old.Button:remove()
    end
    Count += 1
    local Made: Button
    Made = {
        Id = Spec.Id,
        setActive = function(_: Button, Active: boolean)
            const Entry = Entries[Spec.Id]
            if Entry and Entry.Button == Made and Entry.Active ~= Active then
                Entry.Active = Active
                refresh()
            end
        end,
        isActive = function(_: Button): boolean
            const Entry = Entries[Spec.Id]
            return Entry ~= nil and Entry.Active
        end,
        setVisible = function(_: Button, Visible: boolean)
            const Entry = Entries[Spec.Id]
            if Entry and Entry.Button == Made and Entry.Visible ~= Visible then
                Entry.Visible = Visible
                refresh()
            end
        end,
        setText = function(_: Button, Text: string)
            Spec.Text = Text
            refresh()
        end,
        setColor = function(_: Button, Color: Color3, Ink: Color3?)
            Spec.Color = Color
            Spec.Ink = Ink or Spec.Ink
            refresh()
        end,
        remove = function(_: Button)
            const Entry = Entries[Spec.Id]
            if Entry and Entry.Button == Made then
                Entries[Spec.Id] = nil
                refresh()
            end
        end,
    }
    Entries[Spec.Id] = {
        Spec = Spec,
        Button = Made,
        Active = Spec.Active == true,
        Visible = true,
        Index = Count,
    }
    refresh()
    return Made
end

function Sidebar.get(Id: string): Button?
    const Entry = Entries[Id]
    return if Entry then Entry.Button else nil
end

function Sidebar.setOpen(Value: boolean)
    if Open ~= Value then
        Sounds.play(if Value then "SidebarOpen" else "SidebarClose")
    end
    Open = Value
    const Shown = View
    if Shown then
        Shown.Expanded(Value)
    end
end

function Sidebar.isOpen(): boolean
    return Open
end

function Sidebar.toggle()
    Sidebar.setOpen(not Open)
end

Bridges.SidebarPress:Bind(function(Id: string)
    const Entry = Entries[Id]
    const Pressed = if Entry then Entry.Spec.pressed else nil
    if Entry and Pressed then
        task.spawn(Pressed, Entry.Button)
    end
end)

Bridges.SidebarToggle:Bind(function()
    Sidebar.toggle()
end)

return Sidebar
