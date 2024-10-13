local Wizard = {}
local Quadtree = {}

-- caches
local lookupTable = {}
local queryCache = {}

--// constants
local _EPS = 0.0001 -- fuzzyeq tolerance
local _SNAP = 0.2 -- queryCache rounding precision

-- node type
type Node = {
    Position : Vector3, -- x represents the x coordinate of the node
                        -- y represents the data stored within the node
                        -- z represents the z coordinate of the node

    Northwest : Node,
    Northeast : Node,
    Southwest : Node,
    Southeast : Node
}

--// utility functions
-- sets the y component of a vector to 0
local function flatVec(pos : Vector3)
    return pos * Vector3.new(1, 0, 1)
end

-- returns whether the x coordinate of `a` is less than that of `b`
local function XLT(a : Vector3, b : Vector3)
    return a.X < b.X
end

-- returns whether the z coordinate of `a` is less than that of `b`
local function ZLT(a : Vector3, b : Vector3)
    return a.Z < b.Z
end

-- snaps to the specified constant precision
local function snap(pos : Vector3)
    return Vector3.new(
        math.round(pos.X / _SNAP) * _SNAP,
        math.round(pos.Y / _SNAP) * _SNAP,
        math.round(pos.Z / _SNAP) * _SNAP
    )
end

-- fuzzyeq but for numbers
local function fuzzyEqNum(a : number, b : number, eps : number)
    return math.abs(a - b) <= eps
end

--// recursive helpers
-- insert helper
function insert(pos: Vector3, node: Node)
    if not node then
        local leaf : Node = {
            Position = pos,

            Northwest = nil,
            Northeast = nil,
            Southwest = nil,
            Southeast = nil
        }

        lookupTable[flatVec(pos)] = leaf
        queryCache[snap(flatVec(pos))] = leaf
        return leaf
    end

    if XLT(pos, node.Position) then
        if ZLT(pos, node.Position) then
            node.Southwest = insert(pos, node.Southwest)
        else
            node.Northwest = insert(pos, node.Northwest)
        end
    else
        if ZLT(pos, node.Position) then
            node.Southeast = insert(pos, node.Southeast)
        else
            node.Northeast = insert(pos, node.Northeast)
        end
    end

    return node
end

-- query helper
function query(pos : Vector3, node : Node)
    if not node then
        return nil
    elseif pos:FuzzyEq(node.Position, _EPS) then
        queryCache[flatVec(snap(pos))] = node;
        return node
    end

    local nodeDistance = flatVec(pos - node.Position).Magnitude
    local queryNode = (not XLT(pos, node.Position) and not ZLT(pos, node.Position) and "Northeast")
                   or (XLT(pos, node.Position) and not ZLT(pos, node.Position) and "Northwest")
                   or (XLT(pos, node.Position) and ZLT(pos, node.Position) and "Southwest")
                   or (not XLT(pos, node.Position) and ZLT(pos, node.Position) and "Southeast")

    local result = query(pos, node[queryNode])
    return (not result or nodeDistance < flatVec(pos - result.Position).Magnitude) and node or result
end

-- build helper
local function build(positions : {Vector3}, depth : number)
    if #positions == 0 then return nil end

    -- I AM THE HONORED ONE
    -- GLAAAAAAAAAAAAAAAAAZE MEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
    local count = 0
    local average = Vector3.zero

    local closest
    local dist = math.huge

    for i, p in positions do
        average *= count
        count += 1
        average += flatVec(p)
        average /= count

        if count > #positions / 2 then
            if (p - average).Magnitude < dist then
                closest = i
                dist = (p - average).Magnitude
            end
        end
    end

    local node : Node = {
        Position = positions[closest],

        Northwest = nil,
        Northeast = nil,
        Southwest = nil,
        Southeast = nil
    }
    lookupTable[flatVec(positions[closest])] = node
    queryCache[snap(flatVec(positions[closest]))] = node

    local northwest, northeast, southwest, southeast = {}, {}, {}, {}
    
    for i, pos in positions do
        if i ~= closest then
            if XLT(pos, node.Position) then
                if ZLT(pos, node.Position) then
                    table.insert(southwest, pos)
                else
                    table.insert(northwest, pos)
                end
            else
                if ZLT(pos, node.Position) then
                    table.insert(southeast, pos)
                else
                    table.insert(northeast, pos)
                end
            end
        end
    end

    node.Northwest = build(northwest, depth + 1)
    node.Northeast = build(northeast, depth + 1)
    node.Southwest = build(southwest, depth + 1)
    node.Southeast = build(southeast, depth + 1)

    return node
end

--// class methods
-- constructs a new quadtree
function Wizard.new()
    local tree = setmetatable({
        Root = nil
    }, {__index = Quadtree})
    return tree;
end

-- inserts a new position into the quadtree, using x and z as position and y as the value
function Quadtree:Insert(pos : Vector3)
    self.Root = insert(pos, self.Root)
end

-- builds a new quadtree from the provided list of positions
function Quadtree:Build(positions : {Vector3})
    self:Clear()
    self.Root = build(positions, 0)
end

-- searches for a position, returning whether it exists or not
function Quadtree:Search(pos : Vector3)
    if (not lookupTable[flatVec(pos)]) then return false end
    return true
end

-- returns the closest node to a point
function Quadtree:Query(pos : Vector3)
    local snapped = snap(flatVec(pos))
    if self:Search(pos) then return lookupTable[pos] end -- if the position is on the grid
    if (queryCache[snapped]) then return queryCache[snapped] end -- if the position or one close to it has been cached

    return query(pos, self.Root)
end

-- clears the quadtree and associated data structures
function Quadtree:Clear()
    lookupTable = {}
    queryCache = {}
    self.Root = nil -- gc does the rest
end

--// DEBUG METHODS ///////////////////////////////////////////////////
-- draws a part at a node
function drawNode(node : Node, root : boolean)
    local nodePart = Instance.new("Part")
    nodePart.Position = (node.Position)
    nodePart.Anchored = true
    if root then
        nodePart.Size = Vector3.new(2, 2, 2)
        nodePart.Color = Color3.new(1.000000, 0.741176, 0.027451)
    else
        nodePart.Size = Vector3.new(0.6, 0.6, 0.6)
        nodePart.Color = Color3.new(0.917647, 0.027451, 1)
    end
    nodePart.Material = Enum.Material.Neon
    nodePart.CanCollide = false
    nodePart.Parent = workspace.Drawing
end

-- draws a connection between two nodes
function drawConnection(a : Node, b : Node, root : boolean)
    local length = (a.Position - b.Position).Magnitude
    local position = b.Position + (a.Position - b.Position).Unit * length / 2
    local connectionPart = Instance.new("Part")
    connectionPart.CFrame = CFrame.lookAt(position, a.Position)
    connectionPart.Anchored = true
    if root then
        connectionPart.Size = Vector3.new(0.3, 0.3, length)
        connectionPart.Color = Color3.new(1.000000, 0.027451, 0.027451)
    else
        connectionPart.Size = Vector3.new(0.1, 0.1, length)
        connectionPart.Color = Color3.new(0.062745, 0.749020, 1)
    end
    connectionPart.Material = Enum.Material.Neon
    connectionPart.CanCollide = false
    connectionPart.Parent = workspace.Drawing
end

-- draws the tree
function Quadtree:Draw(node : Node)
    if not (workspace:FindFirstChild("Drawing")) then
        local folder = Instance.new("Folder")
        folder.Name = "Drawing"
        folder.Parent = workspace
    end

    if node == self.Root then workspace.Drawing:ClearAllChildren() end

    drawNode(node, node == self.Root)
    
    if node.Southeast then
        drawConnection(node, node.Southeast, node == self.Root)
        self:Draw(node.Southeast)
    end
    
    if node.Southwest then
        drawConnection(node, node.Southwest, node == self.Root)
        self:Draw(node.Southwest)
    end
    
    if node.Northeast then
        drawConnection(node, node.Northeast, node == self.Root)
        self:Draw(node.Northeast)
    end
    
    if node.Northwest then
        drawConnection(node, node.Northwest, node == self.Root)
        self:Draw(node.Northwest)
    end
end

return Wizard