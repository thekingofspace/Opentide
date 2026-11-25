--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)

const A = Clips.angles

const Hold: Clips.Poses = {
    UpperTorso = A(0, -15, 0),
    RightUpperArm = A(35, 0, -60),
    RightLowerArm = A(50, 0, 0),
    LeftUpperArm = A(70, 10, 60),
    LeftLowerArm = A(5, 0, 0),
}

const Rest: Clips.Poses = {
    UpperTorso = A(0, -5, 0),
    RightUpperArm = A(0, 20, -45),
    RightLowerArm = A(145, 0, 0),
    RightHand = A(10, 35, -10),
    LeftUpperArm = A(0, 0, 3),
    LeftLowerArm = A(10, 0, 0),
}

const Bobbed: Clips.Poses = Clips.merge(Hold, {
    UpperTorso = A(3, -15, 0),
    RightUpperArm = A(38, 0, -60),
    LeftUpperArm = A(73, 10, 60),
})

const Items = {
    BaseballBat = {
        Name = "Baseball Bat",
        Category = "Melee",
        Order = 1,
        Description = "a sturdy bat. pick a barrel and add parts to it",
        Mounts = {
            { Id = "Handle", Label = "handle", Accepts = { "BatHandle" }, Offset = CFrame.identity, Required = true },
            { Id = "Head", Label = "barrel", Accepts = { "BatBarrel" }, Offset = CFrame.new(0, 1.2, 0) },
        },
        Defaults = {
            Handle = "WoodHandle",
            Head = "WoodBarrel",
        },
        Clips = {
            Hold = { Name = "Hold", Loop = true, Priority = Enum.AnimationPriority.Idle, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 1, Poses = Hold },
            } },
            HoldWalk = { Name = "HoldWalk", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 0.45, Poses = Bobbed },
                { Time = 0.9, Poses = Hold },
            } },
            Rest = { Name = "Rest", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
                { Time = 0, Poses = Rest },
                { Time = 1, Poses = Rest },
            } },
            Swing = { Name = "Swing", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 0.14, Poses = {
                    UpperTorso = A(0, -45, 0),
                    RightUpperArm = A(70, 0, -40),
                    RightLowerArm = A(95, 0, 0),
                    LeftUpperArm = A(60, 0, 0),
                    LeftLowerArm = A(70, 0, 0),
                } },
                { Time = 0.3, Style = Enum.PoseEasingStyle.Linear, Poses = {
                    UpperTorso = A(0, 25, 0),
                    RightUpperArm = A(85, 0, -5),
                    RightLowerArm = A(15, 0, 0),
                    LeftUpperArm = A(80, 0, 0),
                    LeftLowerArm = A(20, 0, 0),
                } },
                { Time = 0.44, Poses = {
                    UpperTorso = A(0, 55, 0),
                    RightUpperArm = A(75, 0, 25),
                    RightLowerArm = A(45, 0, 0),
                    LeftUpperArm = A(70, 0, 0),
                    LeftLowerArm = A(50, 0, 0),
                } },
                { Time = 0.66, Poses = Hold },
            } },
            Equip = { Name = "Equip", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = { RightUpperArm = A(0, 0, 0) } },
                { Time = 0.16, Poses = { RightUpperArm = A(-25, 0, -10), RightLowerArm = A(20, 0, 0) } },
                { Time = 0.36, Poses = Hold },
            } },
            PutAway = { Name = "PutAway", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 0.2, Poses = { RightUpperArm = A(-25, 0, -15), RightLowerArm = A(30, 0, 0) } },
                { Time = 0.36, Poses = { RightUpperArm = A(0, 0, 0), RightLowerArm = A(0, 0, 0) } },
            } },
        },
        Sets = {
            Held = { Body = { Idle = "Hold", Walk = "HoldWalk" } },
            Rest = { Body = { Idle = "Rest", Walk = "Rest" } },
        },
        Equip = "Equip",
        Unequip = "PutAway",
        Actions = {
            { Id = "Rest", Label = "rest on shoulder", Key = Enum.KeyCode.Q, Toggle = true },
        },
        client = {
            onEquip = function(Context: any)
                Context.pushSet("Held")
            end,
            onUnequip = function(Context: any)
                Context.popSet("Rest")
                Context.popSet("Held")
            end,
            onActivate = function(Context: any)
                if Context.active("Rest") or Context.Data.Swinging then
                    return
                end
                Context.Data.Swinging = true
                Context.play("Swing")
                Context.send("Swing")
                task.delay(0.6, function()
                    Context.Data.Swinging = false
                end)
            end,
            onAction = function(Context: any, Id: string, On: boolean)
                if Id ~= "Rest" then
                    return
                end
                if On then
                    Context.stop("Swing")
                    Context.pushSet("Rest")
                else
                    Context.popSet("Rest")
                end
            end,
        },
    },
}

return Items
