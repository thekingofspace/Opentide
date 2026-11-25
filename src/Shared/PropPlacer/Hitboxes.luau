--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

const PropData = require(ReplicatedStorage.Shared.PropData)
const PropObject = require(script.Parent.PropObject)
const World = require(script.Parent.World)

type Prop = PropObject.Prop

type Bound = {
    Prop: Prop,
    Part: BasePart?,
}

const Hitboxes = {
    FolderName = "ServerBoxes",
}

const Bindings: { [string]: Bound } = {}
local Folder: Instance? = nil
local Started = false

const function partFor(Key: string): BasePart?
    const Holder = Folder
    const Found = if Holder then Holder:FindFirstChild(Key) else nil
    return if Found and Found:IsA("BasePart") then Found else nil
end

const function bind(Prop: Prop)
    if Prop.Destroyed then
        return
    end
    const Found = PropData.definition(Prop.Id)
    if not Found or not Found.ServerBox then
        return
    end
    Bindings[Prop.Key] = {
        Prop = Prop,
        Part = partFor(Prop.Key),
    }
end

const function watch(Holder: Instance)
    Folder = Holder
    for Key, Binding in Bindings do
        Binding.Part = partFor(Key)
    end
    Holder.ChildAdded:Connect(function(Child: Instance)
        const Binding = Bindings[Child.Name]
        if Binding and Child:IsA("BasePart") then
            Binding.Part = Child
        end
    end)
    Holder.ChildRemoved:Connect(function(Child: Instance)
        const Binding = Bindings[Child.Name]
        if Binding and Binding.Part == Child then
            Binding.Part = nil
        end
    end)
end

const function follow()
    for _, Binding in Bindings do
        const Part = Binding.Part
        const Model = Binding.Prop.Model
        if not Part or not Model then
            continue
        end
        const Offset = Part:GetAttribute("PropOffset")
        if typeof(Offset) == "CFrame" then
            Model:PivotTo(Part.CFrame * Offset)
        end
    end
end

function Hitboxes.of(Prop: Prop): BasePart?
    const Binding = Bindings[Prop.Key]
    return if Binding then Binding.Part else nil
end

function Hitboxes.start()
    if Started then
        return
    end
    Started = true

    PropObject.Mounted:Connect(bind)
    World.Removed:Connect(function(Prop: Prop)
        Bindings[Prop.Key] = nil
    end)

    const Existing = Workspace:FindFirstChild(Hitboxes.FolderName)
    if Existing then
        watch(Existing)
    else
        local Waiting: RBXScriptConnection? = nil
        Waiting = Workspace.ChildAdded:Connect(function(Child: Instance)
            if Child.Name == Hitboxes.FolderName and not Folder then
                const Link = Waiting
                if Link then
                    Link:Disconnect()
                end
                watch(Child)
            end
        end)
    end

    RunService.PreRender:Connect(follow)
end

return Hitboxes
