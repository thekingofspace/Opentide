--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const vision = require(ReplicatedStorage.MainPackages.vision)
const Bridges = require(ReplicatedStorage.Shared.Customize.Bridges)
const Kit = require(script.Parent.Kit)

type Page = {
    Id: string,
    Label: string,
    Fill: Color3,
    Ink: Color3,
}

const Style = Kit.Style

const Nav = {
    Width = 240,
    Height = 640,
    ButtonHeight = 58,
    Pages = {
        { Id = "Info", Label = "info", Fill = Style.ButtonColor, Ink = Style.InkColor },
        { Id = "Body", Label = "body", Fill = Style.ButtonColor, Ink = Style.InkColor },
        { Id = "Parts", Label = "rig parts", Fill = Style.ButtonColor, Ink = Style.InkColor },
        { Id = "Saves", Label = "saves", Fill = Style.ButtonColor, Ink = Style.InkColor },
        { Id = "Tools", Label = "tools", Fill = Style.ButtonColor, Ink = Style.InkColor },
        { Id = "Shop", Label = "shop", Fill = Style.WidgetColor, Ink = Style.InkColor },
    } :: { Page },
}

function Nav.paint(Root: Instance, Current: string)
    for _, Page in Nav.Pages do
        const On = Page.Id == Current
        Kit.setButton(Root, `Nav_{Page.Id}`, nil, if On then Style.AccentColor else Page.Fill, if On then Style.AccentText else Page.Ink)
    end
end

const function pageButton(Page: Page, Order: number): Kit.Declaration
    return Kit.press(`Nav_{Page.Id}`, Page.Label, {
        Size = UDim2.new(1, 0, 0, Nav.ButtonHeight),
        LayoutOrder = Order,
    }, Page.Fill, Page.Ink, Bridges.Nav, "Page", Page.Id, false, 20)
end

function Nav.build(): Kit.Declaration
    const Buttons: Kit.Declaration = {
        ClassName = "Frame",
        Name = "Nav_Pages",
        Position = UDim2.fromOffset(Kit.Margin, Kit.Margin + Kit.HeaderHeight + 14),
        Size = UDim2.new(1, -Kit.Margin * 2, 0, #Nav.Pages * (Nav.ButtonHeight + 10)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,

        {
            ClassName = "UIListLayout",
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
        },
    }
    for Order, Page in Nav.Pages do
        table.insert(Buttons, pageButton(Page, Order))
    end

    return Kit.panel("Nav", "customize", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(Nav.Width, Nav.Height),

        vision.event("NavPage", "Body", function(Self: Instance, _, Value: string)
            Nav.paint(Self, Value)
        end),

        vision.event("NavReset", false, function(Self: Instance, _, Value: boolean)
            Kit.setButton(Self, "Nav_Reset", if Value then "sure? press again" else "reset avatar", if Value then Style.CloseColor else Style.PlateColor, if Value then Style.CloseText else Style.InkColor)
        end),
    }, {
        Buttons,

        {
            ClassName = "Frame",
            Name = "Nav_Divider",
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, Kit.Margin, 1, -(Kit.Margin + 124)),
            Size = UDim2.new(1, -Kit.Margin * 2, 0, 3),
            BackgroundColor3 = Style.BevelDark,
            BorderSizePixel = 0,
        },

        Kit.press("Nav_Reset", "reset avatar", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, Kit.Margin, 1, -(Kit.Margin + 60)),
            Size = UDim2.new(1, -Kit.Margin * 2, 0, 50),
        }, Style.PlateColor, Style.InkColor, Bridges.Nav, "Reset", nil, false, 18),

        Kit.press("Nav_Exit", "exit", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, Kit.Margin, 1, -Kit.Margin),
            Size = UDim2.new(1, -Kit.Margin * 2, 0, 52),
        }, Style.CloseColor, Style.CloseText, Bridges.Nav, "Exit", nil, true, 21),
    })
end

return Nav
