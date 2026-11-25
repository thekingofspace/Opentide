--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type ActBridge = signal.Bridge<(string, any?, any?), ()>

export type ChannelCard = {
    Id: string,
    Name: string,
    Detail: string,
    Active: boolean,
}

export type NowView = {
    On: boolean,
    Channel: string,
    Track: string,
    Volume: string,
    Level: number,
}

const Bridges: {
    read Radio: ActBridge,
} = table.freeze({
    Radio = signal.bridge() :: ActBridge,
})

return Bridges
