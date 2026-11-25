--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const VisionKit = require(ReplicatedStorage.Shared.VisionKit)
const CommonStyle = require(script.Parent.CommonStyle)
const Scope = vision.Scope()
const _MainStyle = Scope:LoadStyle(table.clone(CommonStyle) :: any)

const Common = vision.style("Common")
const Typewriter = Font.fromEnum(Enum.Font.SpecialElite)
const DesignSize = Vector2.new(420, 360)
const Lifetime = 3.5
const MaxShown = 4
const MinimumScale = 0.6

export type Message = {
    Text: string,
    Kind: ("Error" | "Info")?,
}

const Showing: { vision.Vision } = {}
local Order = 0

const function toast(Message: Message, Stack: Instance): { [any]: any }
    Order += 1
    const Info = Message.Kind == "Info"
    return {
        ClassName = "Frame",
        Name = `Toast_{Order}`,
        LayoutOrder = Order,
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = if Info then Common["SuccessColor"] else Common["CloseColor"],
        BorderSizePixel = 0,
        vision.mount(Stack),

        {
            ClassName = "UIStroke",
            Thickness = 2.5,
            Color = Common["InkColor"],
            LineJoinMode = Enum.LineJoinMode.Miter,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        },

        {
            ClassName = "UIPadding",
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 14),
            PaddingRight = UDim.new(0, 14)
        },

        {
            ClassName = "TextLabel",
            Name = "Toast_Text",
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = Message.Text,
            TextWrapped = true,
            TextSize = 20,
            FontFace = Typewriter,
            TextColor3 = if Info then Common["SuccessText"] else Common["CloseText"],
            TextXAlignment = Enum.TextXAlignment.Left,

            {
                ClassName = "UIStroke",
                Color = Color3.new(0, 0, 0),
                Thickness = 1.2,
                LineJoinMode = Enum.LineJoinMode.Round,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            }
        }
    }
end

const function dismiss(Item: vision.Vision)
    const At = table.find(Showing, Item)
    if At then
        table.remove(Showing, At)
        Item:Cleanup()
    end
end

const function push(Stack: Instance, Message: Message)
    const Item = Scope:Capture(toast(Message, Stack))
    Item:Mount()
    table.insert(Showing, Item)
    while #Showing > MaxShown do
        dismiss(Showing[1])
    end
    task.delay(Lifetime, dismiss, Item)
end

const function clear()
    while #Showing > 0 do
        dismiss(Showing[1])
    end
end

return Scope:Capture({
    ClassName = "Frame",
    Name = "Toast_Stack",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.fromOffset(DesignSize.X, DesignSize.Y),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 50,

    {
        ClassName = "UIScale"
    },

    {
        ClassName = "UIListLayout",
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8)
    },

    vision.ready(function(Self: Instance, _, Later: (() -> ()) -> ())
        VisionKit.fit(Self :: GuiObject, Later, MinimumScale)
    end),

    vision.event("Push", false, function(Stack: Instance, _, Value: any)
        if type(Value) == "table" and type(Value.Text) == "string" then
            push(Stack, Value :: Message)
        end
    end),

    vision.cleanup(function()
        clear()
    end)
}::Frame & any)
