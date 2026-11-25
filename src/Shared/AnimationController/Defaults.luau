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
        Point = { Name = "Point", Part = "Body", Crouch = "CrouchPoint" },
    } :: { [string]: EmoteRef },
}

return Defaults
