--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)

const A = Clips.angles

const Rest: Clips.Poses = {
    RightUpperArm = A(0, 0, 0),
    RightLowerArm = A(0, 0, 0),
}

const Hold: Clips.Poses = {
    RightUpperArm = A(-21, 26, 2),
    RightLowerArm = A(100, 0, 0),
    RightHand = A(-61, 9, 21),
}

const Mouth: Clips.Poses = {
    Head = A(-8, 0, 0),
    RightUpperArm = A(-32, 64, 92),
    RightLowerArm = A(120, 0, 0),
    RightHand = A(-77, 5, 103),
}

const Chew: Clips.Poses = {
    Head = A(-3, 0, 0),
    RightUpperArm = A(-38, 57, 91),
    RightLowerArm = A(119, 0, 0),
    RightHand = A(-70, 8, 110),
}

const Items = {
    Bread = {
        Name = "Bread",
        Category = "Food",
        Order = 1,
        Description = "a fresh loaf. click to take a bite, it never runs out",
        Clips = {
            Hold = { Name = "Hold", Loop = true, Priority = Enum.AnimationPriority.Idle, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 1, Poses = Hold },
            } },
            Eat = { Name = "Eat", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 0.3, Poses = Mouth },
                { Time = 0.5, Poses = Chew },
                { Time = 0.7, Poses = Mouth },
                { Time = 0.9, Poses = Chew },
                { Time = 1.25, Poses = Hold },
            } },
            Equip = { Name = "Equip", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Rest },
                { Time = 0.25, Poses = Hold },
            } },
            PutAway = { Name = "PutAway", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 0.25, Poses = Rest },
            } },
        },
        Sets = {
            Held = { Body = { Idle = "Hold", Walk = "Hold" } },
        },
        Equip = "Equip",
        Unequip = "PutAway",
        Actions = {
            { Id = "Eat", Label = "eat (click)" },
        },
        client = {
            onEquip = function(Context: any)
                Context.pushSet("Held")
            end,
            onUnequip = function(Context: any)
                Context.popSet("Held")
            end,
            onActivate = function(Context: any)
                if Context.Data.Eating then
                    return
                end
                Context.Data.Eating = true
                Context.play("Eat")
                task.delay(1.3, function()
                    Context.Data.Eating = false
                end)
            end,
            onAction = function(Context: any, Id: string)
                if Id == "Eat" then
                    const Hooks = Context.Def.client
                    Hooks.onActivate(Context)
                end
            end,
        },
    },
}

return Items
