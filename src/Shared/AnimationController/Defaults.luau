--!strict
export type Target = "Full" | "Legs" | "Body"

export type SlotRef = {
    Name: string,
    ReferenceSpeed: number?,
}

export type SetRef = {
    Full: { [string]: SlotRef }?,
    Legs: { [string]: SlotRef }?,
    Body: { [string]: SlotRef }?,
}

export type ActionRef = {
    Name: string,
    Part: Target?,
}

export type EmoteRef = {
    Name: string,
    Label: string?,
    Order: number?,
    Part: Target?,
    Looped: boolean?,
    Crouch: string?,
}

const Defaults = {
    UseRobloxAnimations = false,

    Slots = {
        Legs = {
            Walk = { Name = "Walk_Legs", ReferenceSpeed = 10 },
        },
        Body = {
            Walk = { Name = "Walk_Body", ReferenceSpeed = 10 },
        },
    } :: SetRef,

    Sets = {
        Crouch = {
            Legs = {
                Idle = { Name = "CrouchIdle_Legs" },
                Walk = { Name = "CrouchWalk_Legs", ReferenceSpeed = 6 },
            },
            Body = {
                Idle = { Name = "CrouchIdle_Body" },
                Walk = { Name = "CrouchWalk_Body", ReferenceSpeed = 6 },
            },
        },
    } :: { [string]: SetRef },

    Actions = {} :: { [string]: ActionRef },

    Emotes = {
        Point = { Name = "Point", Label = "point", Order = 1, Part = "Body", Crouch = "CrouchPoint" },
        Wave = { Name = "Wave", Label = "wave", Order = 2, Part = "Full" },
        Cheer = { Name = "Cheer", Label = "cheer", Order = 3, Part = "Full" },
        Laugh = { Name = "Laugh", Label = "laugh", Order = 4, Part = "Full" },
        Dance = { Name = "Dance", Label = "dance", Order = 5, Part = "Full", Looped = true },
    } :: { [string]: EmoteRef },
}

return Defaults
