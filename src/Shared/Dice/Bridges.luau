--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type ActBridge = signal.Bridge<(string, any?, any?), ()>

export type DieCard = {
    Id: string,
    Name: string,
    Active: boolean,
}

const Bridges: {
    read Dice: ActBridge,
} = table.freeze({
    Dice = signal.bridge() :: ActBridge,
})

return Bridges
