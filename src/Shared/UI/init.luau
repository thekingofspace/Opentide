--!strict
const Config = require(script.Config)

export type View = { [string]: (...any) -> any }

export type Source = Instance | { [string]: any }

const UI = {
    Config = Config,
}

const Overrides: { [string]: Source } = {}
const Loaded: { [string]: any } = {}
const Views: { [string]: View } = {}

function UI.use(Name: string, Given: Source)
    if Loaded[Name] ~= nil then
        warn(`[UI] "{Name}" was already loaded, call UI.use before the system that shows it starts`)
    end
    Overrides[Name] = Given
    Loaded[Name] = nil
end

function UI.load(Name: string): any
    const Known = Loaded[Name]
    if Known ~= nil then
        return if Known then Known else nil
    end
    const Source = Overrides[Name] or Config[Name]
    local Made: any = nil
    if typeof(Source) == "Instance" and Source:IsA("ModuleScript") then
        const Ok, Result = pcall((require :: any), Source)
        if Ok then
            Made = Result
        else
            warn(`[UI] "{Name}" failed to load: {Result}`)
        end
    elseif type(Source) == "table" then
        Made = Source
    else
        warn(`[UI] there is no UI set for "{Name}" in UI/Config`)
    end
    Loaded[Name] = Made or false
    return Made
end

function UI.view(Name: string): View
    const Known = Views[Name]
    if Known then
        return Known
    end
    const Made = setmetatable({}, {
        __index = function(_, Key: string): (...any) -> any
            return function(...: any): any
                const Impl = UI.load(Name)
                const Handler = if type(Impl) == "table" then Impl[Key] else nil
                if type(Handler) == "function" then
                    return Handler(...)
                end
                return nil
            end
        end,
    }) :: any
    Views[Name] = Made
    return Made
end

const function invoke(Callback: any, ...: any): any
    return Callback(...)
end

function UI.mount(Name: string, Parent: Instance): Instance?
    const Impl = UI.load(Name)
    if type(Impl) ~= "table" then
        return nil
    end
    const Open: any = Impl.Open
    if type(Open) == "function" then
        const Made = invoke(Open, Impl)
        Made.Parent = Parent
        return Made
    end
    const Mount: any = Impl.mount
    if type(Mount) == "function" then
        return invoke(Mount, Parent)
    end
    warn(`[UI] "{Name}" has no Open or mount function`)
    return nil
end

function UI.unmount(Name: string)
    const Impl = UI.load(Name)
    if type(Impl) ~= "table" then
        return
    end
    const Cleanup: any = Impl.Cleanup
    const Unmount: any = Impl.unmount
    if type(Cleanup) == "function" then
        invoke(Cleanup, Impl)
    elseif type(Unmount) == "function" then
        invoke(Unmount)
    end
end

return UI
