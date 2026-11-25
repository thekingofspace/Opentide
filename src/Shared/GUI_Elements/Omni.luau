--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Kit = require(ReplicatedStorage.Shared.GUI_Elements.Customize.Kit)
const Bridges = require(ReplicatedStorage.Shared.Omni.Bridges)
const Shared = require(ReplicatedStorage.Shared.Omni.Shared)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Omni

const Width = 470
const Height = 760
const PopupColor = Color3.fromRGB(51, 51, 221)
const PopupBody = Color3.fromRGB(24, 26, 30)

const Tabs = {
    { Id = "World", Label = "world" },
    { Id = "Ambient", Label = "ambient" },
    { Id = "Messages", Label = "messages" },
    { Id = "Players", Label = "players" },
}

const Sections: { [string]: { string } } = {
    World = { "Omni_WeatherSection", "Omni_TimeSection" },
    Ambient = { "Omni_PresetSection", "Omni_AmbientSection" },
    Messages = { "Omni_PopupSection", "Omni_PinSection" },
    Players = { "Omni_PlayerSection" },
}

const function hint(Name: string, Text: string, Order: number): Kit.Declaration
    return Kit.text(Name, Text, 13, {
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        TextColor3 = Common["OutlineColor"],
        LayoutOrder = Order,
    })
end

const function wide(Name: string, Label: string, Order: number, Fill: Color3, Ink: Color3, Action: string, Value: any?): Kit.Declaration
    return Kit.press(Name, Label, { Size = UDim2.new(1, 0, 0, 46), LayoutOrder = Order }, Fill, Ink, Bridge, Action, Value, false, 17)
end

const function box(Name: string, Placeholder: string, Height2: number, Order: number, Action: string): Kit.Declaration
    return Parts.card(Name, {
        Size = UDim2.new(1, 0, 0, Height2),
        LayoutOrder = Order,
    }, {
        ClassName = "TextBox",
        Text = "",
        PlaceholderText = Placeholder,
        PlaceholderColor3 = Common["MutedColor"],
        TextColor3 = Common["InkColor"],
        FontFace = Parts.Typewriter,
        TextScaled = false,
        TextSize = 16,
        TextWrapped = true,
        MultiLine = Height2 > 50,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = if Height2 > 50 then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
        BackgroundColor3 = Common["CardColor"],
        PropertyChanged = {
            Text = function(_, _, Value: string)
                Bridge:Call(Action, Value)
            end,
        },

        {
            ClassName = "UIPadding",
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, if Height2 > 50 then 8 else 0),
        },
    }, nil, nil, Kit.ItemStroke)
end

const function playerRow(View: Bridges.PlayerRow, Order: number): Kit.Declaration
    return Parts.card(`OmniPlayer_{View.Id}`, {
        Size = UDim2.new(1, 0, 0, 60),
        LayoutOrder = Order,
    }, {
        BackgroundColor3 = Style.CardColor,

        Kit.text("Name", View.Name, 17, {
            Position = UDim2.fromOffset(12, 8),
            Size = UDim2.new(1, -200, 0, 22),
            FontFace = Parts.Heading,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        Kit.text("Detail", View.Detail, 13, {
            Position = UDim2.fromOffset(12, 32),
            Size = UDim2.new(1, -200, 0, 16),
            TextColor3 = Style.PackColor,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        Kit.press(`OmniPlayer_{View.Id}_GoTo`, "go to", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -96, 0.5, 0),
            Size = UDim2.fromOffset(84, 38),
        }, Style.ButtonColor, Style.InkColor, Bridge, "GoTo", View.Id, false, 15),

        Kit.press(`OmniPlayer_{View.Id}_Bring`, "bring", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(84, 38),
        }, Style.WidgetColor, Style.InkColor, Bridge, "Bring", View.Id, false, 15),
    }, nil, nil, Kit.ItemStroke)
end

const function steppers(): { Kit.Declaration }
    const Made: { Kit.Declaration } = {}
    for Order, Key in Shared.sortedAmbient() do
        table.insert(Made, Kit.stepper(`OmniAmbient_{Key}`, Shared.Ambient[Key].Name, Bridge, "AmbientStep", Key, Order + 1))
    end
    return Made
end

const function panel(): Kit.Declaration
    const TabButtons: { Kit.Declaration } = {}
    for Order, Tab in Tabs do
        table.insert(TabButtons, Kit.press(`Omni_Tab_{Tab.Id}`, Tab.Label, { Size = UDim2.new(0.25, -6, 0, 42), LayoutOrder = Order }, Style.ButtonColor, Style.InkColor, Bridge, "Tab", Tab.Id, false, 15))
    end
    const Hours: { Kit.Declaration } = {}
    for Index, Hour in { 0, 3, 6, 9, 12, 15, 18, 21 } do
        table.insert(Hours, Kit.press(`Omni_Hour_{Hour}`, string.format("%02d:00", Hour), { LayoutOrder = Index }, Style.ButtonColor, Style.InkColor, Bridge, "Hour", Hour, false, 15))
    end
    const AmbientChildren: { Kit.Declaration } = steppers()
    table.insert(AmbientChildren, 1, hint("Omni_AmbientHint", "change these then press apply. everyone sees it", 1))
    table.insert(AmbientChildren, Kit.text("Omni_TintLabel", "tint", 16, { FontFace = Parts.Heading, LayoutOrder = 20 }))
    table.insert(AmbientChildren, Kit.chips("Omni_Tints", "OmniTints", Vector2.new(124, 38), Bridge, "Tint", 21))
    table.insert(AmbientChildren, wide("Omni_ApplyAmbient", "apply for everyone", 22, Style.SuccessColor, Style.SuccessText, "ApplyAmbient"))
    table.insert(AmbientChildren, wide("Omni_ClearAmbient", "clear ambient", 23, Style.PlateColor, Style.InkColor, "ClearAmbient"))

    return Kit.panel("Omni", "omni tool", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(Width, Height),
        Visible = false,

        { ClassName = "UIScale" },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.55)
            const Header = Self:FindFirstChild("Omni_Header")
            if Header and Header:IsA("GuiObject") then
                Header.Active = true
                Parts.draggable(Self :: GuiObject, Header, Later)
            end
        end),

        vision.event("OmniShown", false, function(Self: Instance, _, Value: boolean)
            (Self :: GuiObject).Visible = Value == true
        end),

        vision.event("OmniTab", "World", function(Self: Instance, _, Value: string)
            for _, Tab in Tabs do
                const On = Tab.Id == Value
                Kit.setButton(Self, `Omni_Tab_{Tab.Id}`, nil, if On then Style.AccentColor else Style.ButtonColor, if On then Style.AccentText else Style.InkColor)
                for _, Name in Sections[Tab.Id] do
                    Kit.show(Self, Name, On)
                end
            end
        end),

        vision.event("OmniWorld", { Weather = "", WeatherFrozen = false, Hour = "", TimeFrozen = false }, function(Self: Instance, _, View: Bridges.WorldView)
            Kit.label(Self, "Omni_WeatherNow", `now: {View.Weather}`)
            Kit.label(Self, "Omni_TimeNow", `now: {View.Hour}`)
            Kit.setButton(Self, "Omni_FreezeWeather", if View.WeatherFrozen then "weather flow: off" else "weather flow: on", if View.WeatherFrozen then Style.CloseColor else Style.SuccessColor, Style.SuccessText)
            Kit.setButton(Self, "Omni_FreezeTime", if View.TimeFrozen then "time flow: off" else "time flow: on", if View.TimeFrozen then Style.CloseColor else Style.SuccessColor, Style.SuccessText)
        end),

        vision.event("OmniAmbient", {}, function(Self: Instance, _, Values: { [string]: string })
            for Key, Text in Values do
                Kit.label(Self, `OmniAmbient_{Key}_Value`, Text)
            end
        end),
    }, {
        Kit.close("Omni_Close", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -(Kit.Margin + 10), 0, Kit.Margin + Kit.HeaderHeight / 2),
            ZIndex = 5,
        }, Bridge, "Close", nil, 36),

        Parts.merge(Kit.body("Omni_List"), {
            Kit.row("Omni_Tabs", 44, 0, TabButtons),

            Kit.section("Omni_WeatherSection", "weather", 1, {
                Kit.text("Omni_WeatherNow", "now:", 15, { FontFace = Parts.Heading, LayoutOrder = 1 }),
                Kit.chips("Omni_Weathers", "OmniWeathers", Vector2.new(124, 40), Bridge, "Weather", 2),
                wide("Omni_FreezeWeather", "weather flow: on", 3, Style.SuccessColor, Style.SuccessText, "FreezeWeather"),
                hint("Omni_WeatherHint", "turn weather flow off to keep the weather from changing on its own", 4),
            }),

            Kit.section("Omni_TimeSection", "time", 2, {
                Kit.text("Omni_TimeNow", "now:", 15, { FontFace = Parts.Heading, LayoutOrder = 1 }),
                Parts.merge(Kit.grid("Omni_Hours", Vector2.new(92, 40), 2), Hours),
                Kit.input("Omni_HourInput", "set an hour, like 14.5", {
                    Size = UDim2.new(1, 0, 0, 44),
                    LayoutOrder = 3,
                }, function(Text: string, Box: TextBox)
                    Bridge:Call("HourText", Text)
                    Box.Text = ""
                end),
                wide("Omni_FreezeTime", "time flow: on", 4, Style.SuccessColor, Style.SuccessText, "FreezeTime"),
            }),

            Parts.merge(Kit.section("Omni_PresetSection", "presets", 3, {
                Kit.chips("Omni_Presets", "OmniPresets", Vector2.new(190, 40), Bridge, "Preset", 1),
            }), { Visible = false }),

            Parts.merge(Kit.section("Omni_AmbientSection", "ambient", 4, AmbientChildren), { Visible = false }),

            Parts.merge(Kit.section("Omni_PopupSection", "popup", 5, {
                box("Omni_PopupTitle", "title", 44, 1, "PopupTitle"),
                box("Omni_PopupText", "message for everyone", 120, 2, "PopupText"),
                wide("Omni_SendPopup", "send popup to everyone", 3, Style.SuccessColor, Style.SuccessText, "SendPopup"),
            }), { Visible = false }),

            Parts.merge(Kit.section("Omni_PinSection", "pin to top of screen", 6, {
                box("Omni_PinText", "text to pin", 44, 1, "PinText"),
                wide("Omni_Pin", "pin it", 2, Style.SuccessColor, Style.SuccessText, "Pin"),
                wide("Omni_Unpin", "unpin", 3, Style.PlateColor, Style.InkColor, "Unpin"),
            }), { Visible = false }),

            Parts.merge(Kit.section("Omni_PlayerSection", "players", 7, {
                wide("Omni_BringAll", "bring everyone to me", 1, Style.WidgetColor, Style.InkColor, "BringAll"),
                {
                    ClassName = "Frame",
                    Name = "Omni_Players",
                    Size = UDim2.fromScale(1, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    Destroying = function(Self: Instance)
                        Kit.clear(Self)
                    end,

                    {
                        ClassName = "UIListLayout",
                        FillDirection = Enum.FillDirection.Vertical,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 8),
                    },

                    vision.event("OmniPlayers", {}, function(Self: Instance, _, Rows: { Bridges.PlayerRow })
                        const Items: { Kit.Item } = {}
                        for Index, Row in Rows do
                            table.insert(Items, {
                                Key = tostring(Row.Id),
                                Hash = `{Row.Name}|{Row.Detail}`,
                                Build = function(): Kit.Declaration
                                    return playerRow(Row, Index)
                                end,
                            })
                        end
                        Kit.sync(Self, Items)
                    end),

                    vision.cleanup(function(Self: Instance, _)
                        Kit.clear(Self)
                    end),
                },
            }), { Visible = false }),
        }),
    })
end

const function popup(): Kit.Declaration
    return {
        ClassName = "Frame",
        Name = "OmniPopup",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromOffset(460, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = PopupBody,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 40,

        { ClassName = "UIStroke", Color = PopupColor, Thickness = 5 },
        { ClassName = "UIScale" },

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            VisionKit.fit(Self :: GuiObject, Later, 0.6)
        end),

        vision.event("OmniPopup", false, function(Self: Instance, _, View: Bridges.PopupView | false)
            (Self :: GuiObject).Visible = View ~= false
            if View then
                Kit.label(Self, "OmniPopup_Title", View.Title)
                Kit.label(Self, "OmniPopup_Text", View.Text)
                Kit.label(Self, "OmniPopup_From", `from {View.From}`)
            end
        end),

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
        },

        {
            ClassName = "Frame",
            Name = "OmniPopup_Bar",
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = PopupColor,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = 41,

            Kit.text("OmniPopup_Title", "", 19, {
                Position = UDim2.fromOffset(12, 0),
                Size = UDim2.new(1, -60, 1, 0),
                FontFace = Parts.Heading,
                TextColor3 = Color3.new(1, 1, 1),
                TextYAlignment = Enum.TextYAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 42,
            }),

            {
                ClassName = "TextButton",
                Name = "OmniPopup_Close",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.fromOffset(30, 30),
                BackgroundColor3 = Style.CloseColor,
                BorderSizePixel = 0,
                Text = "X",
                FontFace = Parts.Heading,
                TextSize = 17,
                TextColor3 = Color3.new(1, 1, 1),
                ZIndex = 43,
                Activated = function()
                    Bridge:Call("ClosePopup")
                end,
            },
        },

        {
            ClassName = "Frame",
            Name = "OmniPopup_Body",
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            ZIndex = 41,

            {
                ClassName = "UIListLayout",
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 8),
            },

            {
                ClassName = "UIPadding",
                PaddingTop = UDim.new(0, 14),
                PaddingBottom = UDim.new(0, 16),
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
            },

            Kit.text("OmniPopup_Text", "", 18, {
                Size = UDim2.fromScale(1, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                TextWrapped = true,
                TextColor3 = Color3.fromRGB(235, 236, 240),
                LayoutOrder = 1,
                ZIndex = 42,
            }),

            Kit.text("OmniPopup_From", "", 13, {
                TextColor3 = Color3.fromRGB(150, 154, 170),
                LayoutOrder = 2,
                ZIndex = 42,
            }),
        },
    }
end

const function pin(): Kit.Declaration
    return {
        ClassName = "TextLabel",
        Name = "OmniPin",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 4),
        Size = UDim2.new(0.8, 0, 0, 48),
        BackgroundTransparency = 1,
        Text = "",
        FontFace = Parts.Heading,
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        TextStrokeTransparency = 0.2,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        Visible = false,
        ZIndex = 35,

        { ClassName = "UITextSizeConstraint", MaxTextSize = 40 },

        vision.event("OmniPin", false, function(Self: Instance, _, Text: string | false)
            const Label = Self :: TextLabel
            Label.Visible = Text ~= false
            if Text then
                Label.Text = Text
            end
        end),
    }
end

return Kit.Scope:Capture({
    ClassName = "Frame",
    Name = "Omni_Root",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,

    panel(),
    popup(),
    pin(),
} :: Frame & any)
