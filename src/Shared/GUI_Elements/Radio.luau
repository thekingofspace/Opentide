--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Kit = require(ReplicatedStorage.Shared.GUI_Elements.Customize.Kit)
const Bridges = require(ReplicatedStorage.Shared.Radio.Bridges)

const Style = Kit.Style
const Common = Kit.Common
const Bridge = Bridges.Radio

const Width = 420
const Height = 640
const BarHeight = 14
const SliderHeight = 30

const function channelCard(View: Bridges.ChannelCard, Order: number): Kit.Declaration
    const Fill = if View.Active then Kit.Picked else Style.CardColor
    return Parts.card(`Channel_{View.Id}`, {
        Size = UDim2.new(1, 0, 0, 60),
        LayoutOrder = Order,
    }, {
        ClassName = "TextButton",
        Text = "",
        AutoButtonColor = true,
        BackgroundColor3 = Fill,
        Activated = function()
            Bridge:Call("Tune", View.Id)
        end,
        Parts.bevel(`Channel_{View.Id}_Shine`, 3, Kit.light(Fill), Kit.dark(Fill)),

        Kit.text("Name", View.Name, 18, {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -90, 0, 22),
            FontFace = Parts.Heading,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        Kit.text("Detail", View.Detail, 13, {
            Position = UDim2.fromOffset(14, 33),
            Size = UDim2.new(1, -90, 0, 16),
            TextColor3 = Style.PackColor,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }),

        Kit.text("Live", if View.Active then "on air" else "", 14, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(70, 20),
            FontFace = Parts.Heading,
            TextColor3 = Style.CloseColor,
            TextXAlignment = Enum.TextXAlignment.Right,
        }),
    }, 3, nil, Kit.ItemStroke)
end

const function bar(Name: string, Order: number, Fill: Color3, Height2: number, Extra: Kit.Declaration?): Kit.Declaration
    return Parts.merge({
        ClassName = "Frame",
        Name = Name,
        Size = UDim2.new(1, 0, 0, Height2),
        BackgroundColor3 = Style.WellColor,
        BorderSizePixel = 0,
        LayoutOrder = Order,
        Parts.outline(Kit.ItemStroke),

        {
            ClassName = "Frame",
            Name = "Fill",
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = Fill,
            BorderSizePixel = 0,
        },
    }, Extra or {})
end

const function slider(): Kit.Declaration
    return bar("Radio_Slider", 1, Style.AccentColor, SliderHeight, {
        Size = UDim2.new(1, -112, 0, SliderHeight),
        Active = true,

        vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
            const Track = Self :: GuiObject
            local Dragging = false
            const function set(X: number)
                const Width2 = Track.AbsoluteSize.X
                if Width2 <= 0 then
                    return
                end
                Bridge:Call("Volume", math.clamp((X - Track.AbsolutePosition.X) / Width2, 0, 1))
            end
            const Began = Track.InputBegan:Connect(function(Input: InputObject)
                const Kind = Input.UserInputType
                if Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch then
                    Dragging = true
                    set(Input.Position.X)
                end
            end)
            const Changed = UserInputService.InputChanged:Connect(function(Input: InputObject)
                const Kind = Input.UserInputType
                if Dragging and (Kind == Enum.UserInputType.MouseMovement or Kind == Enum.UserInputType.Touch) then
                    set(Input.Position.X)
                end
            end)
            const Ended = UserInputService.InputEnded:Connect(function(Input: InputObject)
                const Kind = Input.UserInputType
                if Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch then
                    Dragging = false
                end
            end)
            Later(function()
                Began:Disconnect()
                Changed:Disconnect()
                Ended:Disconnect()
            end)
        end),
    })
end

const function fill(Root: Instance, Name: string, Value: number)
    const Holder = Root:FindFirstChild(Name, true)
    const Found = if Holder then Holder:FindFirstChild("Fill") else nil
    if Found and Found:IsA("GuiObject") then
        Found.Size = UDim2.fromScale(math.clamp(Value, 0, 1), 1)
    end
end

return Kit.Scope:Capture(Kit.panel("Radio", "radio", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(Width, Height),
    Visible = false,

    { ClassName = "UIScale" },

    vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
        VisionKit.fit(Self :: GuiObject, Later, 0.55)
        const Header = Self:FindFirstChild("Radio_Header")
        if Header and Header:IsA("GuiObject") then
            Header.Active = true
            Parts.draggable(Self :: GuiObject, Header, Later)
        end
    end),

    vision.event("RadioShown", false, function(Self: Instance, _, Value: boolean)
        (Self :: GuiObject).Visible = Value == true
    end),

    vision.event("RadioNow", { On = false, Channel = "off", Track = "", Volume = "50%", Level = 0.5 }, function(Self: Instance, _, View: Bridges.NowView)
        Kit.label(Self, "Radio_Channel", View.Channel)
        Kit.label(Self, "Radio_Track", View.Track)
        Kit.label(Self, "Radio_VolumeValue", View.Volume)
        Kit.setButton(Self, "Radio_Power", if View.On then "on" else "off", if View.On then Style.SuccessColor else Style.ButtonColor, if View.On then Style.SuccessText else Style.InkColor)
        fill(Self, "Radio_Slider", View.Level)
    end),

    vision.event("RadioProgress", 0, function(Self: Instance, _, Value: number)
        fill(Self, "Radio_Progress", Value)
    end),
}, {
    Kit.close("Radio_Close", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(Kit.Margin + 10), 0, Kit.Margin + Kit.HeaderHeight / 2),
        ZIndex = 5,
    }, Bridge, "Close", nil, 36),

    Parts.merge(Kit.body("Radio_List"), {
        Kit.section("Radio_NowSection", "now playing", 1, {
            Kit.text("Radio_Channel", "off", 22, {
                FontFace = Parts.Heading,
                LayoutOrder = 1,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
            Kit.text("Radio_Track", "", 15, {
                TextColor3 = Common["PackColor"],
                LayoutOrder = 2,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
            bar("Radio_Progress", 3, Style.WidgetColor, BarHeight),
            Kit.row("Radio_Controls", 48, 4, {
                Kit.press("Radio_Back", "<", { Size = UDim2.fromOffset(70, 46) }, Style.ButtonColor, Style.InkColor, Bridge, "Step", -1, false, 24),
                Kit.press("Radio_Power", "off", { Size = UDim2.fromOffset(150, 46) }, Style.ButtonColor, Style.InkColor, Bridge, "Power", nil, false, 22),
                Kit.press("Radio_Next", ">", { Size = UDim2.fromOffset(70, 46) }, Style.ButtonColor, Style.InkColor, Bridge, "Step", 1, false, 24),
            }),
        }),

        Kit.section("Radio_VolumeSection", "volume", 2, {
            Kit.row("Radio_VolumeRow", SliderHeight + 4, 1, {
                Kit.press("Radio_Quieter", "-", { Size = UDim2.fromOffset(34, SliderHeight + 2) }, Style.ButtonColor, Style.InkColor, Bridge, "Nudge", -1, false, 20),
                slider(),
                Kit.press("Radio_Louder", "+", { Size = UDim2.fromOffset(34, SliderHeight + 2) }, Style.ButtonColor, Style.InkColor, Bridge, "Nudge", 1, false, 20),
            }),
            Kit.text("Radio_VolumeValue", "50%", 15, {
                FontFace = Parts.Heading,
                TextXAlignment = Enum.TextXAlignment.Center,
                LayoutOrder = 2,
            }),
        }),

        Kit.section("Radio_ChannelSection", "channels", 3, {
            {
                ClassName = "Frame",
                Name = "Radio_Channels",
                Size = UDim2.fromScale(1, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 1,
                Destroying = function(Self: Instance)
                    Kit.clear(Self)
                end,

                {
                    ClassName = "UIListLayout",
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 8),
                },

                vision.event("RadioChannels", {}, function(Self: Instance, _, Cards: { Bridges.ChannelCard })
                    const Items: { Kit.Item } = {}
                    for Index, View in Cards do
                        table.insert(Items, {
                            Key = View.Id,
                            Hash = `{View.Name}|{View.Detail}|{View.Active}`,
                            Build = function(): Kit.Declaration
                                return channelCard(View, Index)
                            end,
                        })
                    end
                    Kit.sync(Self, Items)
                end),

                vision.cleanup(function(Self: Instance, _)
                    Kit.clear(Self)
                end),
            },
        }),
    }),
}) :: Frame & any)
