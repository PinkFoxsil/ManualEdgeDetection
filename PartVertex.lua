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

function IsPositionInPart(pos: Vector3, part, onset: boolean) -- Working as intended
	onset = onset or false
	
	local rayPerms = RaycastParams.new()
	rayPerms.FilterType = Enum.RaycastFilterType.Whitelist
	rayPerms.FilterDescendantsInstances = {part.Part}
	
	for _, v in pairs(part.Faces) do
		if v:CheckPointOnFace(pos) then
			return onset
		end
	end
	
	part.Anchored = true
	part.Position = pos
	part.Material = Enum.Material.Neon
	part.Size = Vector3.new(.1, .1, .1)
	part.Color = Color3.new(0.968627, 0, 1)
	part.Parent = workspace
	
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
		table.insert(intersections, {["Instance"] = ray.Instance, ["Position"] = ray.Position})
	end
	
	start = endPt
	while true do
		RunService.Heartbeat:Wait()
		local ray = workspace:Raycast(start, startPt - start, rayPerms)
		if not ray or (ray.Position - startPt).Magnitude <= .001 then break end
		start = ray.Position
		table.insert(intersections, {["Instance"] = ray.Instance, ["Position"] = ray.Position})
	end
	
	table.sort(intersections, function(a, b)
		return (a.Position - startPt).Magnitude < (b.Position - startPt).Magnitude
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
	self.CenterOfMass = Vector3.new(0, 0, 0)
	self.Faces = {}

	if part:IsA("WedgePart") then
		self.Vertices, self.CenterOfMass, self.Faces = GetInfoWedge(part)
	elseif part:IsA("Part") and part.Shape == Enum.PartType.Block then
		self.Vertices, self.CenterOfMass, self.Faces = GetInfoBlock(part)
	else
		warn("Part isn't wedge or block!")
	end
	
	self.LongestDistance = 0
	
	for _, v in pairs(self.Vertices) do
		self.LongestDistance = math.max(self.LongestDistance, (self.CenterOfMass - v.Pos).Magnitude)
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
	v.v1:AddNext({v.v2.Pos, v.v3.Pos, v.v5.Pos})
	v.v2:AddNext({v.v1.Pos, v.v4.Pos, v.v6.Pos})
	v.v3:AddNext({v.v1.Pos, v.v4.Pos, v.v5.Pos})
	v.v4:AddNext({v.v2.Pos, v.v3.Pos, v.v6.Pos})
	v.v5:AddNext({v.v1.Pos, v.v3.Pos, v.v6.Pos})
	v.v6:AddNext({v.v2.Pos, v.v4.Pos, v.v5.Pos})
	
	local mass = GetCenter(v)
	
	local f = {}
	
	f["f1"] = Face.new(mass, {v.v1, v.v2, v.v4, v.v3})
	f["f2"] = Face.new(mass, {v.v1, v.v2, v.v6, v.v5})
	f["f3"] = Face.new(mass, {v.v1, v.v3, v.v5})
	f["f4"] = Face.new(mass, {v.v2, v.v4, v.v6})
	f["f5"] = Face.new(mass, {v.v3, v.v4, v.v6, v.v5})

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
	v.v1:AddNext({v.v2.Pos, v.v3.Pos, v.v5.Pos})
	v.v2:AddNext({v.v1.Pos, v.v4.Pos, v.v6.Pos})
	v.v3:AddNext({v.v1.Pos, v.v4.Pos, v.v7.Pos})
	v.v4:AddNext({v.v2.Pos, v.v3.Pos, v.v8.Pos})
	v.v5:AddNext({v.v1.Pos, v.v6.Pos, v.v7.Pos})
	v.v6:AddNext({v.v2.Pos, v.v5.Pos, v.v8.Pos})
	v.v7:AddNext({v.v3.Pos, v.v5.Pos, v.v8.Pos})
	v.v8:AddNext({v.v4.Pos, v.v6.Pos, v.v7.Pos})
	
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

--[[ Unused Code
function Class:GetIntersectionVertices()
	local interParts = {}
	for _, v in pairs(self.IntersectingParts) do
		table.insert(interParts, v.Part)
	end
	
	local newVerts = {}
	
	-- Cycles through every vert and every vert next to it : 100%
	local vertsChecked = {}
	for _, a in pairs(self.Vertices) do
		table.insert(vertsChecked, a)
		
		-- Checks if begining vert is in other part
		local beginningVert = false
		for _, k in ipairs(self.IntersectingParts) do
			if IsPositionInPart(a.Pos, k, true) then
				beginningVert = true
				break
			end
		end
		
		for _, b in ipairs(a.Next) do
			local edgeVerts = {}
			if not beginningVert then
				edgeVerts = {Vertex.new(a.Pos)}
			end
			
			-- Checks if the vertex had already been checked : 100%
			if table.find(vertsChecked, b) then continue end
			local hit = PiercingRay(a.Pos, b, interParts)
			
			-- Adds verts : 100%
			for _, v in ipairs(hit) do
				local positionTaken = false
				for _, k in ipairs(self.IntersectingParts) do
					if IsPositionInPart(v.Position, k, false) then
						positionTaken = true
						break
					end
				end
				if not positionTaken then
					for _, k in ipairs(self.IntersectingParts) do
						if v.Instance == k.Part then
							table.insert(edgeVerts, Vertex.new(v.Position, k))
							break
						end
					end
				end
			end
			
			-- Checks if ending vert is in other part
			local endingVert = false
			for _, k in ipairs(self.IntersectingParts) do
				if IsPositionInPart(b, k, true) then
					endingVert = true
					break
				end
			end
			if not endingVert then
				table.insert(edgeVerts, Vertex.new(b))
			end
			
			-- Connects vertices
			for i = 1, #edgeVerts-1, 2 do
				local j = i + 1
				edgeVerts[i]:AddNext({edgeVerts[j]})
				edgeVerts[j]:AddNext({edgeVerts[i]})
			end
			
			-- Combine same vertices and add to final outcome
			for i = 1, #edgeVerts do
				local sameVerts = false
				for _, v in ipairs(newVerts) do
					if v:Combine(edgeVerts[i]) then
						sameVerts = true
						break
					end
				end
				if not sameVerts then
					table.insert(newVerts, edgeVerts[i])
				end
			end
		end
	end
	
	self.Vertices = newVerts
end
]]

function Class.Compare(obj1, obj2)
	local newVertsObj1 = {}
	local newVertsObj2 = {}
	
	-- These tables will always be the same length
	local sharingVerticesA = {}
	local sharingVerticesB = {}
	
	-- Objects are too far to be adjacent or intersecting (for optomization purposes)
	if (obj1.CenterOfMass - obj2.CenterOfMass).Magnitude > (obj1.LongestDistance + obj2.LongestDistance) then return end
	
	-- Checks if objects are adjacent by comparring vertices
	for _, a in pairs(obj1.Vertices) do
		for _, b in pairs(obj2.Vertices) do
			if a.Pos == b.Pos then
				
				-- is sharing vertices
				table.insert(sharingVerticesA, a)
				table.insert(sharingVerticesB, b)
			end
		end	
	end
	
	-- Destroys connections between vertices depending on the side the faces are on
	for i = 1, #sharingVerticesA do -- TODO: Fix this, it doesn't fully work and still leaves edges despite not implementing the other TO_DO
		for _, aN in ipairs(sharingVerticesA[i].Next) do
			for _, bN in ipairs(sharingVerticesB[i].Next) do
				if (aN - sharingVerticesA[i].Pos).Unit == (bN - sharingVerticesB[i].Pos).Unit then
					-- TODO: Code if faces are on same side or opposite; if same then don't get rid of connection
					--[[ 
						Don't check if the faces are on the same side; just check 
						if the normals are the same, the centers lies on the plane
						of the other, and if the vector (face1.Center - face2.Center) 
						touches vector (a-aN)*math.huge.
					]]
					sharingVerticesA[i]:RemoveNext(aN)
					sharingVerticesB[i]:RemoveNext(bN)
				end
			end
		end
	end
	
	-- 1st Object
	for _, a in pairs(obj1.Vertices) do
		
		-- Checks if objects are intersecting by seeing if vertices are in the other part (skips vertice if true)
		if IsPositionInPart(a.Pos, obj2, true) and not table.find(sharingVerticesA, a) then continue end
		
		local newVertex = Vertex.new(a.Pos)
		
		for _, n in ipairs(a.Next) do
			local rayPerms = RaycastParams.new()
			rayPerms.FilterType = Enum.RaycastFilterType.Whitelist
			rayPerms.FilterDescendantsInstances = {obj2.Part}

			local ray = workspace:Raycast(a.Pos, (n - a.Pos), rayPerms)
			
			if ray then
				
				local endVertex = Vertex.new(ray.Position, ray.Instance)
				endVertex:AddNext({a.Pos})
				table.insert(newVertsObj1, endVertex)
				
				newVertex:AddNext({ray.Position})
				
			else
				
				local endVertex = Vertex.new(n)
				endVertex:AddNext({a.Pos})
				table.insert(newVertsObj1, endVertex)
				
				newVertex:AddNext({n})
				
			end
		end
		
		table.insert(newVertsObj1, newVertex)
	end
	
	-- 2nd Object
	for _, b in pairs(obj2.Vertices) do

		-- Checks if objects are intersecting by seeing if vertices are in the other part (skips vertice if true)
		if IsPositionInPart(b.Pos, obj1, true) and not table.find(sharingVerticesB, b) then continue end
		
		local newVertex = Vertex.new(b.Pos)
		
		for _, n in ipairs(b.Next) do
			local rayPerms = RaycastParams.new()
			rayPerms.FilterType = Enum.RaycastFilterType.Whitelist
			rayPerms.FilterDescendantsInstances = {obj1.Part}

			local ray = workspace:Raycast(b.Pos, (n - b.Pos), rayPerms)

			if ray then

				local endVertex = Vertex.new(ray.Position, ray.Instance)
				endVertex:AddNext({b.Pos})
				table.insert(newVertsObj2, endVertex)

				newVertex:AddNext({ray.Position})
				
			else
				
				local endVertex = Vertex.new(n)
				endVertex:AddNext({b.Pos})
				table.insert(newVertsObj2, endVertex)

				newVertex:AddNext({n})
				
			end
		end

		table.insert(newVertsObj2, newVertex)
	end
	
	-- Combine Same vertices
	local CombinedObj1 = {}
	for i = 1, #newVertsObj1 do
		local sameVerts = false
		for _, v in ipairs(CombinedObj1) do
			if v:Combine(newVertsObj1[i]) then
				sameVerts = true
				break
			end
		end
		if not sameVerts then
			table.insert(CombinedObj1, newVertsObj1[i])
		end
	end
	
	local CombinedObj2 = {}
	for i = 1, #newVertsObj2 do
		local sameVerts = false
		for _, v in ipairs(CombinedObj2) do
			if v:Combine(newVertsObj2[i]) then
				sameVerts = true
				break
			end
		end
		if not sameVerts then
			table.insert(CombinedObj2, newVertsObj2[i])
		end
	end
	
	obj1.Vertices = CombinedObj1
	obj2.Vertices = CombinedObj2
end

function Class:GetAdjacentVertices()
	for _, v in ipairs(self.AdjacentParts) do
		
	end
end

function Class:OutlineEdges(place, lineThickness)
	local vertsChecked = {}
	for _, a in pairs(self.Vertices) do
		table.insert(vertsChecked, a.Pos)

		for _, n in ipairs(a.Next) do
			-- Checks if the vertex had already been checked
			if table.find(vertsChecked, n) then continue end
			CreateOutlineTwoPoints(a.Pos, n, lineThickness, place)
		end
	end
end

function Class:AddIntersecting(VertexPart)
	table.insert(self.IntersectingParts, VertexPart)
end

function Class:AddAdjacent(VertexPart)
	table.insert(self.AdjacentParts, VertexPart)
end

--[[
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

