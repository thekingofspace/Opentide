--!strict
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const vision = require(ReplicatedStorage.MainPackages.vision)
const CommonStyle = require(ReplicatedStorage.Shared.GUI_Elements.CommonStyle)
const Parts = require(ReplicatedStorage.Shared.GUI_Elements.Parts)
const Widgets = require(ReplicatedStorage.Shared.PropPlacer.Widgets)
const NetWatch = require(ReplicatedStorage.Shared.NetWatch)
const Settings = require(script.Parent.Settings)

const MetaVision = {
    Interval = 0.3,
    Lift = 2.6,
}

const Scope = vision.Scope()
const _MainStyle = Scope:LoadStyle(table.clone(CommonStyle) :: any)

const Tags: { [Player]: vision.Vision } = {}
local Active = false
local Folder: Folder? = nil
local Started = false

const function folder(): Folder
    const Existing = Folder
    if Existing and Existing.Parent then
        return Existing
    end
    const Made = Instance.new("Folder")
    Made.Name = "MetaVisionTags"
    Made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    Folder = Made
    return Made
end

const function tag(Player: Player, Head: BasePart): { [any]: any }
    return {
        ClassName = "BillboardGui",
        Name = Player.Name,
        Adornee = Head,
        Size = UDim2.fromOffset(220, 52),
        StudsOffset = Vector3.new(0, MetaVision.Lift, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        ResetOnSpawn = false,
        vision.mount(folder()),

        Parts.text("Display", Player.DisplayName, {
            Size = UDim2.new(1, 0, 0, 26),
            TextScaled = false,
            TextSize = 22,
            FontFace = Parts.Heading,
            TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            Parts.textOutline()
        }),

        Parts.text("Detail", `@{Player.Name}`, {
            Position = UDim2.fromOffset(0, 26),
            Size = UDim2.new(1, 0, 0, 20),
            TextScaled = false,
            TextSize = 15,
            TextColor3 = Color3.fromRGB(220, 220, 230),
            TextXAlignment = Enum.TextXAlignment.Center,
            Parts.textOutline(),

            vision.event("Distance", 0, function(Label: Instance, _, Value: number)
                (Label :: TextLabel).Text = `@{Player.Name}  {math.floor(Value)} st`
            end)
        })
    }
end

const function drop(Player: Player)
    const Existing = Tags[Player]
    if Existing then
        Tags[Player] = nil
        Existing:Cleanup()
    end
end

const function clear()
    for Player in Tags do
        drop(Player)
    end
end

const function headOf(Player: Player): BasePart?
    const Character = Player.Character
    const Head = if Character then Character:FindFirstChild("Head") else nil
    return if Head and Head:IsA("BasePart") then Head else nil
end

const function refresh()
    if not Active then
        return
    end
    const Mine = headOf(Players.LocalPlayer)
    const Range = Settings.get("MetaRange")
    const Limit = if type(Range) == "number" then Range else 120
    for _, Player in Players:GetPlayers() do
        if Player == Players.LocalPlayer then
            continue
        end
        const Head = headOf(Player)
        const Distance = if Head and Mine then (Head.Position - Mine.Position).Magnitude else math.huge
        if not Head or Distance > Limit then
            drop(Player)
            continue
        end
        const Known = Tags[Player]
        if Known and (Known:Open() :: BillboardGui).Adornee ~= Head then
            drop(Player)
        end
        local Shown = Tags[Player]
        if not Shown then
            const Made = Scope:Capture(tag(Player, Head))
            Made:Mount()
            Tags[Player] = Made
            Shown = Made
        end
        (Shown :: vision.Vision).Distance(Distance)
    end
    for Player in Tags do
        if Player.Parent ~= Players then
            drop(Player)
        end
    end
end

function MetaVision.active(): boolean
    return Active
end

function MetaVision.setActive(Value: boolean)
    if Started then
        NetWatch.DataNet:Emit("@Stats/MetaVision", Value)
    end
    Active = Value
    Widgets.setRevealed(Value)
    if Value then
        refresh()
    else
        clear()
    end
end

function MetaVision.start()
    if Started then
        return
    end
    Started = true
    Players.PlayerRemoving:Connect(drop)
    task.spawn(function()
        while true do
            task.wait(MetaVision.Interval)
            refresh()
        end
    end)
end

return MetaVision
