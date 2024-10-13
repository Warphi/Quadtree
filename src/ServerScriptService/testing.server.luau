local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules
local Shared = Modules.Shared

local Quadtree = require(Shared.Quadtree)

--// begin testing quadtree ////////////////////////

local qt = Quadtree.new()
-- qt:Build({
--     Vector3.new(0, 0, 0),
--     Vector3.new(10, 0, 10),
--     Vector3.new(-10, 0, 10),
--     Vector3.new(-10, 0, -10),
--     Vector3.new(10, 0, -10),
--     Vector3.new(15, 0, 15)
-- })

local t = 0
RunService.Stepped:Connect(function(dt)
    t += dt

    local positions = {}
    for i = -40, 40, 5 do
        for j = -40, 40, 5 do
            positions[#positions + 1] = (Vector3.new(
                i,
                math.sin(dt + i) * 5,
                j
            ))
        end
    end

    qt:Build(positions)
    qt:Draw(qt.Root)
end)

print(qt:Search(Vector3.new(-10, 20, 10)))
print(qt:Search(Vector3.new(15, 0, 15)))
print(qt:Query(Vector3.new(-7, 0, -8)))
print(qt:Query(Vector3.new(6, 0, 6)))

--//////////////////////////////////////////////////