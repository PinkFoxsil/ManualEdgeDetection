local RunService = game:GetService("RunService")

local Vertex = require(script.Vertices)
local Face = require(script.Faces)

local Class = {}
Class.__index = Class

function CreateOutlineTwoPoints(point1, point2, lineThickness, place, name)
	local edge = Instance.new("Part")

	local dist = (point1 - point2).magnitude
	edge.CFrame = CFrame.new(point1, point2)*CFrame.new(0, 0, -dist/2)*CFrame.Angles(0, math.rad(90), 0)
	edge.Size = Vector3.new(dist, lineThickness, lineThickness)

	edge.Name = name or "Outline"

	edge.Color = Color3.new(1, 1, 1)
	edge.Material = Enum.Material.Neon
	edge.Anchored = true
	edge.CanCollide = false

	edge.Parent = place
end

function IsPositionInPart(pos: Vector3, part, onset: boolean)
	onset = onset or false
	
	local rayPerms = RaycastParams.new()
	rayPerms.FilterType = Enum.RaycastFilterType.Whitelist
	rayPerms.FilterDescendantsInstances = {part.Part}
	
	for _, v in pairs(part.Faces) do
		if v:CheckPointOnFace(pos) then
			return onset
		end
	end
	
	local ray = workspace:Raycast(pos, part.CenterOfMass - pos, rayPerms)
	
	return not ray
end

function PiercingRay(startPt, endPt, findParts)
	local rayPerms = RaycastParams.new()
	rayPerms.FilterType = Enum.RaycastFilterType.Whitelist
	rayPerms.FilterDescendantsInstances = {findParts}
	
	local intersections = {}
	local start = startPt
	while true do
		RunService.Heartbeat:Wait()
		local ray = workspace:Raycast(start, endPt - start, rayPerms)
		if not ray or (ray.Position - endPt).Magnitude <= .001 then break end
		start = ray.Position
		table.insert(intersections, ray.Position)
	end
	
	start = endPt
	while true do
		RunService.Heartbeat:Wait()
		local ray = workspace:Raycast(start, startPt - start, rayPerms)
		if not ray or (ray.Position - startPt).Magnitude <= .001 then break end
		start = ray.Position
		table.insert(intersections, ray.Position)
	end
	
	table.sort(intersections, function(a, b)
		return (a - startPt).Magnitude < (b - startPt).Magnitude
	end)
	
	return intersections
end

function findAllPartsOnRay(startPt, endPt, findParts)
	local rayPerms = RaycastParams.new()
	rayPerms.FilterType = Enum.RaycastFilterType.Whitelist
	rayPerms.FilterDescendantsInstances = {findParts}

	local intersections = {}
	while true do
		local ray = workspace:Raycast(startPt, endPt, rayPerms)
		if not ray then return intersections end
		startPt = ray.Position
		intersections[#intersections+1] = ray.Position
	end
end

function Class.new(part)
	local self = setmetatable({}, {__index = Class})

	self.Part = part
	
	self.IntersectingParts = {}
	self.AdjacentParts = {}

	self.Vertices = {}
	self.Faces = {}

	if part:IsA("WedgePart") then
		self.Vertices, self.CenterOfMass, self.Faces = GetInfoWedge(part)
	elseif part:IsA("Part") and part.Shape == Enum.PartType.Block then
		self.Vertices, self.CenterOfMass, self.Faces = GetInfoBlock(part)
	else
		warn("Part isn't wedge or block!")
	end
	
	return self
end

function GetCenter(verts)
	local center = Vector3.new(0,0,0)
	local i = 0
	for _, v in pairs(verts) do
		center += v.Pos
		i += 1
	end
	return center / math.max(i, 1)
end

function GetInfoWedge(part)
	local v = {}

	local size = part.Size
	local cFrame = part.CFrame
	-- Create Vertices
	v["v1"] = Vertex.new(cFrame * CFrame.new(size/2))
	v["v2"] = Vertex.new(cFrame * CFrame.new(-size.X/2, size.Y/2, size.Z/2))
	v["v3"] = Vertex.new(cFrame * CFrame.new(size.X/2 , -size.Y/2 , size.Z/2))
	v["v4"] = Vertex.new(cFrame * CFrame.new(-size.X/2 , -size.Y/2 , size.Z/2))
	v["v5"] = Vertex.new(cFrame * CFrame.new(size.X/2 , -size.Y/2 , -size.Z/2))
	v["v6"] = Vertex.new(cFrame * CFrame.new(-size/2))

	-- Connect Vertices
	v.v1:AddNext({v.v2, v.v3, v.v5})
	v.v2:AddNext({v.v1, v.v4, v.v6})
	v.v3:AddNext({v.v1, v.v4, v.v5})
	v.v4:AddNext({v.v2, v.v3, v.v6})
	v.v5:AddNext({v.v1, v.v3, v.v6})
	v.v6:AddNext({v.v2, v.v4, v.v5})
	
	local mass = GetCenter(v)
	
	local f = {}
	
	f["f1"] = Face.new(mass, {v.v1, v.v2, v.v3, v.v4})
	f["f2"] = Face.new(mass, {v.v1, v.v2, v.v5, v.v6})
	f["f3"] = Face.new(mass, {v.v1, v.v3, v.v5})
	f["f4"] = Face.new(mass, {v.v2, v.v4, v.v6})
	f["f5"] = Face.new(mass, {v.v3, v.v4, v.v5, v.v6})

	return v, mass, f
end

function GetInfoBlock(part)
	local v = {}

	local size = part.Size
	local cFrame = part.CFrame
	-- Create Vertices
	v["v1"] = Vertex.new(cFrame * CFrame.new(size/2))
	v["v2"] = Vertex.new(cFrame * CFrame.new(-size.X/2, size.Y/2, size.Z/2))
	v["v3"] = Vertex.new(cFrame * CFrame.new(size.X/2 , size.Y/2 , -size.Z/2))
	v["v4"] = Vertex.new(cFrame * CFrame.new(-size.X/2 , size.Y/2 , -size.Z/2))
	v["v5"] = Vertex.new(cFrame * CFrame.new(size.X/2 , -size.Y/2 , size.Z/2))
	v["v6"] = Vertex.new(cFrame * CFrame.new(-size.X/2 , -size.Y/2 , size.Z/2))
	v["v7"] = Vertex.new(cFrame * CFrame.new(size.X/2 , -size.Y/2 , -size.Z/2))
	v["v8"] = Vertex.new(cFrame * CFrame.new(-size/2))

	-- Connect Vertices
	v.v1:AddNext({v.v2, v.v3, v.v5})
	v.v2:AddNext({v.v1, v.v4, v.v6})
	v.v3:AddNext({v.v1, v.v4, v.v7})
	v.v4:AddNext({v.v2, v.v3, v.v8})
	v.v5:AddNext({v.v1, v.v6, v.v7})
	v.v6:AddNext({v.v2, v.v5, v.v8})
	v.v7:AddNext({v.v3, v.v5, v.v8})
	v.v8:AddNext({v.v4, v.v6, v.v7})
	
	local mass = GetCenter(v)

	local f = {}

	f["f1"] = Face.new(mass, {v.v1, v.v2, v.v4, v.v3})
	f["f2"] = Face.new(mass, {v.v1, v.v2, v.v6, v.v5})
	f["f3"] = Face.new(mass, {v.v1, v.v3, v.v7, v.v5})
	f["f4"] = Face.new(mass, {v.v2, v.v4, v.v8, v.v6})
	f["f5"] = Face.new(mass, {v.v3, v.v4, v.v8, v.v7})
	f["f6"] = Face.new(mass, {v.v5, v.v6, v.v8, v.v7})

	return v, mass, f
end

function Class:GetIntersectionVertices()
	local interParts = {}
	for _, v in pairs(self.IntersectingParts) do
		table.insert(interParts, v.Part)
	end
	
	local newVerts = {}
	
	-- Cycles through every vert and every vert next to it
	local vertsChecked = {}
	for _, a in pairs(self.Vertices) do
		table.insert(vertsChecked, a)
		
		-- Checks if begining vert is in other part
		local positionTaken = false
		for _, k in ipairs(self.IntersectingParts) do
			if IsPositionInPart(a.Pos, k, true) then
				positionTaken = true
				break
			end
		end
		
		for _, b in ipairs(a.Next) do
			local edgeVerts = {}
			if not positionTaken then
				edgeVerts = {Vertex.new(a.Pos)}
			end
			
			-- Checks if the vertex had already been checked
			if table.find(vertsChecked, b) then continue end
			local hit = PiercingRay(a.Pos, b.Pos, interParts)
			
			-- Adds verts
			for _, v in ipairs(hit) do
				positionTaken = false
				for _, k in ipairs(self.IntersectingParts) do
					if IsPositionInPart(v, k, false) then
						positionTaken = true
						break
					end
				end
				if not positionTaken then
					table.insert(edgeVerts, Vertex.new(v))
				end
			end
			
			-- Checks if ending vert is in other part
			positionTaken = false
			for _, k in ipairs(self.IntersectingParts) do
				if IsPositionInPart(b.Pos, k, true) then
					positionTaken = true
					break
				end
			end
			if not positionTaken then
				table.insert(edgeVerts, Vertex.new(b.Pos))
			end
			
			-- Connects vertices
			if #edgeVerts == 0 then
				CreateOutlineTwoPoints(a.Pos, b.Pos, .02, workspace)
			end
			for i = 1, #edgeVerts-1, 2 do
				local j = i + 1
				edgeVerts[i]:AddNext({edgeVerts[j]})
				edgeVerts[j]:AddNext({edgeVerts[i]})
				--CreateOutlineTwoPoints(edgeVerts[i].Pos, edgeVerts[j].Pos, .02, workspace)
			end
			
			-- Combine same vertices and add to final outcome
			for i = 1, #edgeVerts do
				positionTaken = false
				for _, v in ipairs(newVerts) do
					if v:Combine(edgeVerts[i]) then
						positionTaken = true
						break
					end
				end
				if not positionTaken then
					table.insert(newVerts, edgeVerts[i])
				end
			end
		end
	end
	
	self.Vertices = newVerts
end

function Class:GetAdjacentVertices()
	for _, v in ipairs(self.AdjacentParts) do
		
	end
end

function Class:OutlineEdges(place, lineThickness)
	local vertsChecked = {}
	for _, a in pairs(self.Vertices) do
		table.insert(vertsChecked, a)

		for _, b in ipairs(a.Next) do
			-- Checks if the vertex had already been checked
			if table.find(vertsChecked, b) then continue end
			CreateOutlineTwoPoints(a.Pos, b.Pos, lineThickness, place)
		end
	end
end

function Class:AddIntersecting(VertexPart)
	table.insert(self.IntersectingParts, VertexPart)
end

function Class:AddAdjacent(VertexPart)
	table.insert(self.AdjacentParts, VertexPart)
end

--[[ Unused code
function Class:AddVertex(v)
	self.Vertices[#self.Vertices+1] = v
end

function Class:RemoveVertex(v)
	local t = {}

	for i = 1, #self.Vertices do
		if self.Vertices[i] ~= v then
			t[#t+1] = i
		end
	end

	self.Vertices = t
end
]]


return Class
