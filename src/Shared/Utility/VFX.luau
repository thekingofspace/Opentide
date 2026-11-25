--!strict
const Lighting = game:GetService("Lighting")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

const signal = require(ReplicatedStorage.MainPackages.signal)

const VFX = {
    Attribute = "UtilityVFX",
    Owned = "UtilityOwned",
    Changed = signal.new(),
    Classes = {
        ParticleEmitter = true,
        Beam = true,
        Trail = true,
        Fire = true,
        Smoke = true,
        Sparkles = true,
        BloomEffect = true,
        SunRaysEffect = true,
        DepthOfFieldEffect = true,
        BlurEffect = true,
    } :: { [string]: boolean },
}

local Enabled = true
local Started = false

const function affect(Item: Instance)
    if not VFX.Classes[Item.ClassName] or Item:GetAttribute(VFX.Owned) then
        return
    end
    const Loose: any = Item
    if not Enabled then
        if Item:GetAttribute(VFX.Attribute) == nil then
            Item:SetAttribute(VFX.Attribute, Loose.Enabled == true)
        end
        Loose.Enabled = false
    else
        const Was = Item:GetAttribute(VFX.Attribute)
        if type(Was) == "boolean" then
            Loose.Enabled = Was
            Item:SetAttribute(VFX.Attribute, nil)
        end
    end
end

const function everything()
    for _, Root in { Workspace, Lighting } :: { Instance } do
        for _, Item in Root:GetDescendants() do
            affect(Item)
        end
    end
end

function VFX.enabled(): boolean
    return Enabled
end

function VFX.setEnabled(Value: boolean)
    if Enabled == Value then
        return
    end
    Enabled = Value
    everything()
    VFX.Changed:Fire(Value)
end

function VFX.start()
    if Started then
        return
    end
    Started = true
    for _, Root in { Workspace, Lighting } :: { Instance } do
        Root.DescendantAdded:Connect(function(Item: Instance)
            if not Enabled then
                task.defer(affect, Item)
            end
        end)
    end
end

return VFX
