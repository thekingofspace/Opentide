--!strict
export type Value = boolean | number | string | Vector2 | Vector3 | Color3 | CFrame

const Codec = {}

const function finite(Number: number): boolean
    return Number == Number and Number ~= math.huge and Number ~= -math.huge
end

const function allFinite(List: { number }): boolean
    for _, Number in List do
        if not finite(Number) then
            return false
        end
    end
    return true
end

const function frame(Found: { number }): CFrame
    return CFrame.new(
        Found[1], Found[2], Found[3],
        Found[4], Found[5], Found[6],
        Found[7], Found[8], Found[9],
        Found[10], Found[11], Found[12]
    )
end

const function numbers(Data: { any }, From: number, Count: number): { number }?
    const Found: { number } = {}
    for Index = From, From + Count - 1 do
        const Number = Data[Index]
        if type(Number) ~= "number" or not finite(Number) then
            return nil
        end
        table.insert(Found, Number)
    end
    return Found
end

function Codec.finite(Value: any): boolean
    const Kind = typeof(Value)
    if Kind == "number" then
        return finite(Value)
    elseif Kind == "boolean" or Kind == "string" then
        return true
    elseif Kind == "Vector2" then
        return finite(Value.X) and finite(Value.Y)
    elseif Kind == "Vector3" then
        return finite(Value.X) and finite(Value.Y) and finite(Value.Z)
    elseif Kind == "Color3" then
        return finite(Value.R) and finite(Value.G) and finite(Value.B)
    elseif Kind == "CFrame" then
        return allFinite({ (Value :: CFrame):GetComponents() })
    end
    return false
end

function Codec.same(A: any, B: any): boolean
    return typeof(A) == typeof(B)
end

function Codec.encode(Value: any): any
    if not Codec.finite(Value) then
        return nil
    end
    const Kind = typeof(Value)
    if Kind == "boolean" or Kind == "number" or Kind == "string" then
        return Value
    elseif Kind == "Vector2" then
        return { "V2", Value.X, Value.Y }
    elseif Kind == "Vector3" then
        return { "V3", Value.X, Value.Y, Value.Z }
    elseif Kind == "Color3" then
        return { "C3", Value.R, Value.G, Value.B }
    elseif Kind == "CFrame" then
        const Encoded: { any } = { "CF" }
        for _, Number in { (Value :: CFrame):GetComponents() } do
            table.insert(Encoded, Number)
        end
        return Encoded
    end
    return nil
end

function Codec.decode(Data: any): Value?
    const Kind = type(Data)
    if Kind == "boolean" or Kind == "string" then
        return Data
    elseif Kind == "number" then
        return if finite(Data) then Data else nil
    elseif Kind ~= "table" then
        return nil
    end
    const Tag = Data[1]
    if Tag == "V2" then
        const Found = numbers(Data, 2, 2)
        return if Found then Vector2.new(Found[1], Found[2]) else nil
    elseif Tag == "V3" then
        const Found = numbers(Data, 2, 3)
        return if Found then Vector3.new(Found[1], Found[2], Found[3]) else nil
    elseif Tag == "C3" then
        const Found = numbers(Data, 2, 3)
        return if Found then Color3.new(Found[1], Found[2], Found[3]) else nil
    elseif Tag == "CF" then
        const Found = numbers(Data, 2, 12)
        return if Found then frame(Found) else nil
    end
    return nil
end

function Codec.encodeMap(Map: { [string]: any }): { [string]: any }
    const Encoded: { [string]: any } = {}
    for Name, Value in Map do
        if type(Name) == "string" then
            Encoded[Name] = Codec.encode(Value)
        end
    end
    return Encoded
end

function Codec.decodeMap(Map: any): { [string]: Value }
    const Decoded: { [string]: Value } = {}
    if type(Map) ~= "table" then
        return Decoded
    end
    for Name, Data in Map do
        if type(Name) == "string" then
            const Value = Codec.decode(Data)
            if Value ~= nil then
                Decoded[Name] = Value
            end
        end
    end
    return Decoded
end

function Codec.packFrame(Frame: CFrame): { number }
    return { Frame:GetComponents() }
end

function Codec.unpackFrame(Data: any): CFrame?
    if type(Data) ~= "table" then
        return nil
    end
    const Found = numbers(Data, 1, 12)
    return if Found then frame(Found) else nil
end

return Codec
