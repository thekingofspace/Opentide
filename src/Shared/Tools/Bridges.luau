--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type ActBridge = signal.Bridge<(string, any?, any?), ()>

export type SlotView = {
    Slot: number,
    Name: string,
    Tool: string?,
    Model: Instance?,
    Active: boolean,
    Linked: number?,
    Linking: boolean?,
    Linkable: boolean?,
}

export type ActionView = {
    Id: string,
    Label: string,
    Key: string?,
    On: boolean,
}

export type BarView = {
    Actions: { ActionView },
}

const Bridges: {
    read Hud: ActBridge,
} = table.freeze({
    Hud = signal.bridge() :: ActBridge,
})

return Bridges
