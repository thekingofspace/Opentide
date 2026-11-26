--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type ActBridge = signal.Bridge<(string, any?, any?), ()>

export type EmoteCard = {
    Id: string,
    Name: string,
    Active: boolean,
}

const Bridges: {
    read Emotes: ActBridge,
} = table.freeze({
    Emotes = signal.bridge() :: ActBridge,
})

return Bridges
