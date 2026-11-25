export type function StringValues(value: type)
    assert(value:is("table"), "Expected a table type")

    local properties = value:properties()
    local result = {}

    for _, property in properties do
        if property.read then
            table.insert(result, property.read)
        end
    end

    assert(#result > 0, "Expected at least one property")

    return types.unionof(table.unpack(result))
end

return true