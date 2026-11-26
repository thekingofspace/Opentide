--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Clips = require(ReplicatedStorage.Shared.AnimationController.Clips)

const A = Clips.angles

const Hold: Clips.Poses = {
    UpperTorso = A(0, -30, 0),
    RightUpperArm = A(38, 32, -52),
    RightLowerArm = A(65, 0, 0),
    RightHand = A(16, 23, -37),
    LeftUpperArm = A(22, -31, 49),
    LeftLowerArm = A(64, 0, 0),
    LeftHand = A(-4, -57, -34),
}

const Bobbed: Clips.Poses = {
    UpperTorso = A(4, -30, 0),
    RightUpperArm = A(43, 23, -52),
    RightLowerArm = A(42, 0, 0),
    RightHand = A(25, 21, -38),
    LeftUpperArm = A(24, -24, 46),
    LeftLowerArm = A(50, 0, 0),
    LeftHand = A(9, -51, -26),
}

const Windup: Clips.Poses = {
    UpperTorso = A(0, -50, 0),
    RightUpperArm = A(34, 30, -52),
    RightLowerArm = A(83, 0, 0),
    RightHand = A(28, -2, -58),
    LeftUpperArm = A(52, -4, 54),
    LeftLowerArm = A(2, 0, 0),
    LeftHand = A(-46, -66, -134),
}

const Contact: Clips.Poses = {
    UpperTorso = A(0, 15, 0),
    RightUpperArm = A(-105, 41, 121),
    RightLowerArm = A(115, 0, 0),
    RightHand = A(135, -83, 45),
    LeftUpperArm = A(11, 11, 76),
    LeftLowerArm = A(1, 0, 0),
    LeftHand = A(4, 9, 54),
}

const Follow: Clips.Poses = {
    UpperTorso = A(0, 50, 0),
    RightUpperArm = A(-50, 86, 58),
    RightLowerArm = A(107, 0, 0),
    RightHand = A(-72, 6, 108),
    LeftUpperArm = A(46, 4, 71),
    LeftLowerArm = A(1, 0, 0),
    LeftHand = A(69, -10, 58),
}

const Rest: Clips.Poses = {
    UpperTorso = A(0, -8, 0),
    RightUpperArm = A(-9, 21, -13),
    RightLowerArm = A(111, 0, 0),
    RightHand = A(39, 13, -26),
    LeftUpperArm = A(0, 0, 3),
    LeftLowerArm = A(12, 0, 0),
}

const OneHold: Clips.Poses = {
    RightUpperArm = A(-17, -6, -10),
    RightLowerArm = A(62, 0, 0),
    RightHand = A(58, 3, -15),
}

const OneBob: Clips.Poses = {
    RightUpperArm = A(-11, -6, -9),
    RightLowerArm = A(53, 0, 0),
    RightHand = A(62, 2, -14),
}

const Down: Clips.Poses = {
    RightUpperArm = A(0, 0, 0),
    RightLowerArm = A(0, 0, 0),
    LeftUpperArm = A(0, 0, 0),
    LeftLowerArm = A(0, 0, 0),
}

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
            Hold_OneHand = { Name = "Hold_OneHand", Loop = true, Priority = Enum.AnimationPriority.Idle, Frames = {
                { Time = 0, Poses = OneHold },
                { Time = 1, Poses = OneHold },
            } },
            HoldWalk_OneHand = { Name = "HoldWalk_OneHand", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
                { Time = 0, Poses = OneHold },
                { Time = 0.45, Poses = OneBob },
                { Time = 0.9, Poses = OneHold },
            } },
            Rest = { Name = "Rest", Loop = true, Priority = Enum.AnimationPriority.Movement, Frames = {
                { Time = 0, Poses = Rest },
                { Time = 1, Poses = Rest },
            } },
            Swing = { Name = "Swing", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 0.16, Poses = Windup, Style = Enum.PoseEasingStyle.Cubic, Direction = Enum.PoseEasingDirection.Out },
                { Time = 0.24, Poses = Windup },
                { Time = 0.34, Poses = Contact, Style = Enum.PoseEasingStyle.Linear },
                { Time = 0.46, Poses = Follow, Style = Enum.PoseEasingStyle.Cubic, Direction = Enum.PoseEasingDirection.Out },
                { Time = 0.58, Poses = Follow },
                { Time = 0.85, Poses = Hold },
            } },
            Equip = { Name = "Equip", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Down },
                { Time = 0.18, Poses = OneHold },
                { Time = 0.38, Poses = Hold },
            } },
            PutAway = { Name = "PutAway", Priority = Enum.AnimationPriority.Action, Frames = {
                { Time = 0, Poses = Hold },
                { Time = 0.18, Poses = OneHold },
                { Time = 0.36, Poses = Down },
            } },
        },
        Sets = {
            Held = { Body = { Idle = "Hold", Walk = "HoldWalk" } },
            Rest = { Body = { Idle = "Rest", Walk = "Rest" } },
        },
        Equip = "Equip",
        Unequip = "PutAway",
        Dual = { Tags = { "Melee" }, With = { "Shield" } },
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
                task.delay(0.8, function()
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
