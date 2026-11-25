--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type ActBridge = signal.Bridge<(string, any?, any?), ()>

export type PlayerChip = {
    Id: number,
    Name: string,
}

export type EntryRow = {
    Id: number,
    Time: string,
    Text: string,
    Kind: string,
}

export type LogView = {
    Picking: boolean,
    Count: number,
}

const Bridges: {
    read Log: ActBridge,
} = table.freeze({
    Log = signal.bridge() :: ActBridge,
})

return Bridges
