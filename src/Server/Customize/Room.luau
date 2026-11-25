--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const Config = require(ReplicatedStorage.Shared.Customize.Config)

const Room = {
    Name = "CustomizeRoom",
    SpotName = "RigSpot",
    FloorColor = Color3.fromRGB(214, 206, 194),
    WallColor = Color3.fromRGB(176, 168, 160),
}

local Built: Model? = nil

const function slab(Name: string, Size: Vector3, At: CFrame, Color: Color3, Parent: Instance): Part
    const Made = Instance.new("Part")
    Made.Name = Name
    Made.Size = Size
    Made.CFrame = At
    Made.Color = Color
    Made.Material = Enum.Material.SmoothPlastic
    Made.Anchored = true
    Made.TopSurface = Enum.SurfaceType.Smooth
    Made.BottomSurface = Enum.SurfaceType.Smooth
    Made.Parent = Parent
    return Made
end

const function build(): Model
    const Model = Instance.new("Model")
    Model.Name = Room.Name
    const Base = Config.RoomPosition
    const Size = Config.RoomSize
    const Height = Config.RoomHeight
    const Half = Size / 2

    slab("Floor", Vector3.new(Size, 1, Size), CFrame.new(Base - Vector3.new(0, 0.5, 0)), Room.FloorColor, Model)
    slab("Ceiling", Vector3.new(Size, 1, Size), CFrame.new(Base + Vector3.new(0, Height + 0.5, 0)), Room.WallColor, Model)
    slab("Back", Vector3.new(Size, Height, 1), CFrame.new(Base + Vector3.new(0, Height / 2, Half + 0.5)), Room.WallColor, Model)
    slab("Front", Vector3.new(Size, Height, 1), CFrame.new(Base + Vector3.new(0, Height / 2, -Half - 0.5)), Room.WallColor, Model)
    slab("Left", Vector3.new(1, Height, Size), CFrame.new(Base + Vector3.new(-Half - 0.5, Height / 2, 0)), Room.WallColor, Model)
    slab("Right", Vector3.new(1, Height, Size), CFrame.new(Base + Vector3.new(Half + 0.5, Height / 2, 0)), Room.WallColor, Model)

    const Lamp = slab("Lamp", Vector3.new(4, 0.4, 4), CFrame.new(Base + Vector3.new(0, Height - 0.2, 0)), Color3.new(1, 1, 1), Model)
    Lamp.Material = Enum.Material.Neon
    const Light = Instance.new("PointLight")
    Light.Range = Size
    Light.Brightness = 1.6
    Light.Shadows = true
    Light.Parent = Lamp

    const Spot = slab("RigSpot", Vector3.new(1, 1, 1), CFrame.new(Base + Vector3.new(0, 3, 0)), Color3.new(1, 1, 1), Model)
    Spot.Transparency = 1
    Spot.CanCollide = false
    Spot.CanQuery = false
    Spot.CanTouch = false

    Model.Parent = Workspace
    return Model
end

function Room.get(): Model
    const Existing = Built
    if Existing and Existing.Parent then
        return Existing
    end
    const Found = Workspace:FindFirstChild(Room.Name)
    const Made = if Found and Found:IsA("Model") then Found else build()
    Built = Made
    return Made
end

function Room.spot(): CFrame
    const Spot = Room.get():FindFirstChild(Room.SpotName)
    if Spot and Spot:IsA("BasePart") then
        return Spot.CFrame
    end
    return CFrame.new(Config.RoomPosition + Vector3.new(0, 3, 0))
end

function Room.hold(): CFrame
    return Room.spot() * CFrame.new(0, -Config.HoldDepth, 0)
end

return Room
