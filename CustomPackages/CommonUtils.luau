const ReplicatedStorage = game:GetService("ReplicatedStorage")
const promise = require(ReplicatedStorage.Packages.promise)
const module = {}

module.SharedInfo = {}

-- This is here to launch new scripts while avoiding multi script issues.
function module.DeferLoad(ScriptTarget:ModuleScript)
    return promise.new(function(resolve, Reject)
        const Suc, Err = pcall(function()
            require(ScriptTarget)
        end)

        if Suc then
            resolve("Passed")
        elseif Err == "Module code did not return exactly one value" then
            resolve("Passed")
        else
            Reject(Err)
        end
    end)
end


return module