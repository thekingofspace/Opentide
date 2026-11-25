--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type ActBridge = signal.Bridge<(string, any?, any?), ()>

export type WorldView = {
    Weather: string,
    WeatherFrozen: boolean,
    Hour: string,
    TimeFrozen: boolean,
}

export type PlayerRow = {
    Id: number,
    Name: string,
    Detail: string,
}

export type PopupView = {
    Title: string,
    Text: string,
    From: string,
}

const Bridges: {
    read Omni: ActBridge,
} = table.freeze({
    Omni = signal.bridge() :: ActBridge,
})

return Bridges
