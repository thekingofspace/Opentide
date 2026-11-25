--!strict
const Config = require(script.Config)

const Images = {
    Config = Config,
}

function Images.get(Name: string): string?
    const Value = Config[Name]
    if type(Value) ~= "string" or Value == "" then
        return nil
    end
    return if string.match(Value, "^%d+$") then `rbxassetid://{Value}` else Value
end

function Images.set(Name: string, Value: string)
    Config[Name] = Value
end

return Images
