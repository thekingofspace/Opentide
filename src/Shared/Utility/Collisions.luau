--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const PropObject = require(ReplicatedStorage.Shared.PropPlacer.PropObject)
const World = require(ReplicatedStorage.Shared.PropPlacer.World)

const Collisions = {
    Attribute = "UtilityCollide",
    BoxFolder = "ServerBoxes",
}

local Enabled = true
local Started = false

const function affect(Root: Instance)
    const Parts: { BasePart } = {}
    if Root:IsA("BasePart") then
        table.insert(Parts, Root)
    end
    for _, Item in Root:GetDescendants() do
        if Item:IsA("BasePart") then
            table.insert(Parts, Item)
        end
    end
    for _, Part in Parts do
        if not Enabled then
            if Part:GetAttribute(Collisions.Attribute) == nil then
                Part:SetAttribute(Collisions.Attribute, Part.CanCollide)
            end
            Part.CanCollide = false
        else
            const Was = Part:GetAttribute(Collisions.Attribute)
            if type(Was) == "boolean" then
                Part.CanCollide = Was
                Part:SetAttribute(Collisions.Attribute, nil)
            end
        end
    end
end

const function everything()
    affect(World.folder())
    const Boxes = Workspace:FindFirstChild(Collisions.BoxFolder)
    if Boxes then
        affect(Boxes)
    end
    const Selection = Workspace:FindFirstChild("PropSelection")
    if Selection then
        affect(Selection)
    end
end

function Collisions.enabled(): boolean
    return Enabled
end

function Collisions.setEnabled(Value: boolean)
    if Enabled == Value then
        return
    end
    Enabled = Value
    everything()
end

function Collisions.start()
    if Started then
        return
    end
    Started = true
    PropObject.Mounted:Connect(function(Prop: PropObject.Prop)
        const Model = Prop.Model
        if not Enabled and Model then
            affect(Model)
        end
    end)
    Workspace.DescendantAdded:Connect(function(Item: Instance)
        if Enabled or not Item:IsA("BasePart") then
            return
        end
        const Boxes = Workspace:FindFirstChild(Collisions.BoxFolder)
        if Boxes and Item:IsDescendantOf(Boxes) then
            affect(Item)
        end
    end)
end

return Collisions
