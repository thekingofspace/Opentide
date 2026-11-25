--!strict
const ServerStorage = game:GetService("ServerStorage")
const Workspace = game:GetService("Workspace")

const Avatar = {
    Enabled = true,
    RigName = "Rig",
    AbsoluteScale = "CustomizeAbsoluteScale",
    Parts = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" },
    Scales = { "BodyTypeScale", "ProportionScale", "HeightScale", "WidthScale", "DepthScale", "HeadScale" },
    Looks = {
        HeightScale = "Height",
        WidthScale = "Width",
        DepthScale = "Depth",
        HeadScale = "Head",
    } :: { [string]: string },
}

local Template: HumanoidDescription? = nil

const function rigOf(): Model?
    for _, Place in { Workspace, ServerStorage } :: { Instance } do
        const Found = Place:FindFirstChild(Avatar.RigName)
        if Found and Found:IsA("Model") and Found:FindFirstChildOfClass("Humanoid") then
            return Found
        end
    end
    return nil
end

function Avatar.template(): HumanoidDescription?
    const Known = Template
    if Known then
        return Known
    end
    const Rig = rigOf()
    const Humanoid = if Rig then Rig:FindFirstChildOfClass("Humanoid") else nil
    if not Humanoid then
        warn(`[Avatar] there is no rig named {Avatar.RigName} to copy the body from`)
        return nil
    end
    const Found = Humanoid:FindFirstChildOfClass("HumanoidDescription")
    local Made: HumanoidDescription? = if Found then Found:Clone() else nil
    if not Made then
        const Ok, Applied = pcall(function()
            return Humanoid:GetAppliedDescription()
        end)
        Made = if Ok then Applied else nil
    end
    Template = Made
    return Made
end

function Avatar.force(Character: Model, Given: Look?): boolean
    if not Avatar.Enabled then
        return false
    end
    const Humanoid = Character:FindFirstChildOfClass("Humanoid")
    const Base = Avatar.template()
    if not Humanoid or not Base or Humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        return false
    end
    const Ok, Description = pcall(function()
        return Humanoid:GetAppliedDescription()
    end)
    if not Ok or not Description then
        return false
    end
    local Different = false
    for _, Field in Avatar.Parts do
        if (Description :: any)[Field] ~= (Base :: any)[Field] then
            Different = true
            (Description :: any)[Field] = (Base :: any)[Field]
        end
    end
    for _, Field in Avatar.Scales do
        const Key = Avatar.Looks[Field]
        const Factor = if Given and Key then (Given :: any)[Key] else nil
        const Wanted = (Base :: any)[Field] * (if type(Factor) == "number" then Factor else 1)
        if math.abs((Description :: any)[Field] - Wanted) > 1e-4 then
            Different = true
            (Description :: any)[Field] = Wanted
        end
    end
    Humanoid:SetAttribute(Avatar.AbsoluteScale, true)
    if not Different then
        return true
    end
    const Applied, Problem = pcall(function()
        Humanoid:ApplyDescriptionAsync(Description)
    end)
    if not Applied then
        warn(`[Avatar] could not set the blocky body: {Problem}`)
    end
    return Applied
end

return Avatar
