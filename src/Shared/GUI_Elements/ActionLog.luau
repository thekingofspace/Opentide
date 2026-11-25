--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Kit = require(ReplicatedStorage.Shared.GUI_Elements.Customize.Kit)
const Bridges = require(ReplicatedStorage.Shared.ActionLog.Bridges)

const Style = Kit.Style
const Bridge = Bridges.Log

const Width = 440
const Height = 660
const Top = Kit.Margin + Kit.HeaderHeight + 10
const ChipHeight = 40
const Footer = 116

const Tags: { [string]: { Label: string, Fill: Color3, Ink: Color3 } } = {
    Roll = { Label = "roll", Fill = Style.AccentColor, Ink = Style.AccentText },
    Note = { Label = "note", Fill = Style.WidgetColor, Ink = Style.InkColor },
    System = { Label = "info", Fill = Style.PlateColor, Ink = Style.InkColor },
}

const function chip(View: Bridges.PlayerChip, Order: number): Kit.Declaration
    return Parts.card(`Tracked_{View.Id}`, {
        Size = UDim2.fromOffset(0, ChipHeight - 6),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = Order,
    }, {
        BackgroundColor3 = Style.CardColor,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        },

        { ClassName = "UIPadding", PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 4) },

        Kit.text("Name", View.Name, 15, {
            Size = UDim2.fromOffset(0, 22),
            AutomaticSize = Enum.AutomaticSize.X,
            FontFace = Parts.Heading,
            LayoutOrder = 1,
        }),

        Kit.close(`Tracked_{View.Id}_Remove`, { LayoutOrder = 2 }, Bridge, "Remove", View.Id, 26),
    }, nil, nil, Kit.ItemStroke)
end

const function row(View: Bridges.EntryRow): Kit.Declaration
    const Tag = Tags[View.Kind] or Tags.System
    return {
        ClassName = "Frame",
        Name = `Entry_{View.Id}`,
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Style.CardColor,
        BorderSizePixel = 0,
        LayoutOrder = View.Id,
        Parts.outline(Kit.ItemStroke),

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
        },

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, 7),
            PaddingBottom = UDim.new(0, 9),
            PaddingLeft = UDim.new(0, 9),
            PaddingRight = UDim.new(0, 9),
        },

        {
            ClassName = "Frame",
            Name = "Top",
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            LayoutOrder = 1,

            {
                ClassName = "TextLabel",
                Name = "Tag",
                Size = UDim2.fromOffset(52, 22),
                BackgroundColor3 = Tag.Fill,
                BorderSizePixel = 0,
                Text = Tag.Label,
                FontFace = Parts.Heading,
                TextSize = 14,
                TextColor3 = Tag.Ink,
                Parts.outline(1.2),
            },

            Kit.text("Time", View.Time, 14, {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.fromOffset(70, 22),
                FontFace = Parts.Heading,
                TextColor3 = Style.OutlineColor,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextYAlignment = Enum.TextYAlignment.Center,
            }),
        },

        Kit.text("Text", View.Text, 17, {
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextColor3 = Style.InkColor,
            FontFace = if View.Kind == "Roll" then Parts.Heading else Parts.Typewriter,
            LayoutOrder = 2,
        }),
    }
end

return Kit.Scope:Capture(Kit.panel("ActionLog", "action log", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(Width, Height),
    Visible = false,

    { ClassName = "UIScale" },

    vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
        VisionKit.fit(Self :: GuiObject, Later, 0.55)
        const Header = Self:FindFirstChild("ActionLog_Header")
        if Header and Header:IsA("GuiObject") then
            Header.Active = true
            Parts.draggable(Self :: GuiObject, Header, Later)
        end
    end),

    vision.event("LogShown", false, function(Self: Instance, _, Value: boolean)
        (Self :: GuiObject).Visible = Value == true
    end),

    vision.event("LogState", { Picking = false, Count = 0 }, function(Self: Instance, _, View: Bridges.LogView)
        Kit.setButton(Self, "ActionLog_Add", if View.Picking then "click a player... (press to cancel)" else "+ add player", if View.Picking then Kit.Picked else Style.ButtonColor, Style.InkColor)
        Kit.show(Self, "ActionLog_NoPlayers", View.Count == 0)
    end),
}, {
    Kit.close("ActionLog_Close", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(Kit.Margin + 10), 0, Kit.Margin + Kit.HeaderHeight / 2),
        ZIndex = 5,
    }, Bridge, "Close", nil, 36),

    Kit.press("ActionLog_Add", "+ add player", {
        Position = UDim2.fromOffset(Kit.Margin, Top),
        Size = UDim2.new(1, -Kit.Margin * 2, 0, 44),
    }, Style.ButtonColor, Style.InkColor, Bridge, "Pick", nil, false, 17),

    {
        ClassName = "ScrollingFrame",
        Name = "ActionLog_Players",
        Position = UDim2.fromOffset(Kit.Margin, Top + 52),
        Size = UDim2.new(1, -Kit.Margin * 2, 0, ChipHeight + 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 4,
        Destroying = function(Self: Instance)
            Kit.clear(Self)
        end,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        },

        Kit.text("ActionLog_NoPlayers", "no players added yet, your own rolls are always logged", 15, {
            Size = UDim2.fromOffset(Width - Kit.Margin * 2, 22),
            TextColor3 = Style.OutlineColor,
            FontFace = Parts.Heading,
            LayoutOrder = 0,
        }),

        vision.event("LogPlayers", {}, function(Self: Instance, _, Chips: { Bridges.PlayerChip })
            const Items: { Kit.Item } = {}
            for Index, View in Chips do
                table.insert(Items, {
                    Key = tostring(View.Id),
                    Hash = View.Name,
                    Build = function(): Kit.Declaration
                        return chip(View, Index)
                    end,
                })
            end
            Kit.sync(Self, Items)
        end),

        vision.cleanup(function(Self: Instance, _)
            Kit.clear(Self)
        end),
    },

    Kit.scroller("ActionLog_Entries", {
        Position = UDim2.fromOffset(Kit.Margin, Top + 60 + ChipHeight),
        Size = UDim2.new(1, -Kit.Margin * 2, 1, -(Top + 60 + ChipHeight + Footer)),
        Destroying = function(Self: Instance)
            Kit.clear(Self)
        end,

        vision.event("LogEntries", {}, function(Self: Instance, _, Rows: { Bridges.EntryRow })
            const Items: { Kit.Item } = {}
            for _, View in Rows do
                table.insert(Items, {
                    Key = tostring(View.Id),
                    Hash = View.Text,
                    Build = function(): Kit.Declaration
                        return row(View)
                    end,
                })
            end
            Kit.sync(Self, Items)
            const Frame = Self :: ScrollingFrame
            task.defer(function()
                Frame.CanvasPosition = Vector2.new(0, math.max(Frame.AbsoluteCanvasSize.Y - Frame.AbsoluteWindowSize.Y, 0))
            end)
        end),

        vision.cleanup(function(Self: Instance, _)
            Kit.clear(Self)
        end),
    }, 10),

    Kit.input("ActionLog_Note", "write a note and press enter", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, Kit.Margin, 1, -(Kit.Margin + 54)),
        Size = UDim2.new(1, -Kit.Margin * 2, 0, 44),
    }, function(Text: string, Box: TextBox)
        Bridge:Call("Note", Text)
        Box.Text = ""
    end),

    Kit.press("ActionLog_Clear", "clear log", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, Kit.Margin, 1, -Kit.Margin),
        Size = UDim2.new(1, -Kit.Margin * 2, 0, 44),
    }, Style.PlateColor, Style.InkColor, Bridge, "Clear", nil, false, 16),
}) :: Frame & any)
