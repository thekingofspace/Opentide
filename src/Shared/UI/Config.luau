--!strict
const GUI = script.Parent.Parent.GUI_Elements

return {
    Customize = GUI.Customize,
    Tools = GUI.Tools,
    Radio = GUI.Radio,
    Dice = GUI.Dice,
    ActionLog = GUI.ActionLog,
    Omni = GUI.Omni,
    Emotes = GUI.Emotes,
    Sidebar = GUI.Sidebar,
    Settings = GUI.SettingsPanel,
    BuildPanel = GUI.BuildPanel,
    Toast = GUI.Toast,
    SaveMenu = GUI.SaveMenu,
    PropWidget = GUI.PropWidget,
} :: { [string]: Instance }
