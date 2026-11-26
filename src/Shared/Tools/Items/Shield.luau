--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)

const A = Clips.angles

const Rest: Clips.Poses = {
    RightUpperArm = A(0, 0, 0),
    RightLowerArm = A(0, 0, 0),
}

const Hold: Clips.Poses = {
    RightUpperArm = A(-5, 2, 1),
    RightLowerArm = A(40, 0, 0),
    RightHand = A(-20, -3, 0),
}

const Block: Clips.Poses = {
    RightUpperArm = A(43, -20, -63),
    RightLowerArm = A(1, 0, 0),
    RightHand = A(-39, -29, -40),
}

const function setBlock(Context: any, On: boolean)
    if Context.active("Block") ~= On then
        Context.setActive("Block", On)
    end
    if On then
        Context.pushSet("Block")
    else
        Context.popSet("Block")
    end
end

const Items = {
    Shield = {
        Name = "Shield",
        Category = "Melee",
        Order = 5,
        Description = "a sturdy round shield for your off hand. hold click or press F to raise it",
        Hand = "Left",
        Click = false,
        Dual = { Tags = { "Shield" }, With = { "Gun", "Melee" } },
        Clips = {
            Hold = { Name = "Hold", Loop = true, Priority = Enum.AnimationPriority.Idle, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 1, Poses = Hold },
            } },
            Block = { Name = "Block", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
                { Time = 0, Poses = Block },
                { Time = 1, Poses = Block },
            } },
            Equip = { Name = "Equip", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Rest },
                { Time = 0.3, Poses = Hold },
            } },
            PutAway = { Name = "PutAway", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 0.3, Poses = Rest },
            } },
        },
        Sets = {
            Held = { Body = { Idle = "Hold", Walk = "Hold" } },
            Block = { Body = { Idle = "Block", Walk = "Block" } },
        },
        Equip = "Equip",
        Unequip = "PutAway",
        Actions = {
            { Id = "Block", Label = "block", Key = Enum.KeyCode.F, Toggle = true },
        },
        client = {
            onEquip = function(Context: any)
                Context.pushSet("Held")
            end,
            onUnequip = function(Context: any)
                Context.popSet("Block")
                Context.popSet("Held")
            end,
            onActivate = function(Context: any)
                setBlock(Context, true)
            end,
            onRelease = function(Context: any)
                setBlock(Context, false)
            end,
            onAction = function(Context: any, Id: string, On: boolean)
                if Id == "Block" then
                    setBlock(Context, On)
                end
            end,
        },
    },
}

return Items
