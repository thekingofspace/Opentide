--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const signal = require(ReplicatedStorage.MainPackages.signal)

export type PressBridge = signal.Bridge<(string), ()>
export type ActionBridge = signal.Bridge<(string, string?), ()>

const Bridges: {
    read SidebarPress: PressBridge,
    read SidebarToggle: PressBridge,
    read Settings: ActionBridge,
} = table.freeze({
    SidebarPress = signal.bridge() :: PressBridge,
    SidebarToggle = signal.bridge() :: PressBridge,
    Settings = signal.bridge() :: ActionBridge,
})

return Bridges
