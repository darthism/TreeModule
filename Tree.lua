local EXP_GROWTH = 3
local MIN_FREQUENCY = 0.2
local MAX_FREQUENCY = 4
local HIGH_LIGHT = Instance.new("SelectionBox")
HIGH_LIGHT.Color3 = Color3.fromRGB(0, 0, 0)
HIGH_LIGHT.SurfaceTransparency = 1
HIGH_LIGHT.LineThickness = 0.15
HIGH_LIGHT.Visible = true
local Infinitesimal = 1 / math.huge
local function MapRanges(ToBeMapped, A, B, C, D)
	return (((ToBeMapped - A) / (B - A)) * (D - C)) + C 
end
local function VectorNoY(Vector)
	return Vector3.new(Vector.X, 0, Vector.Z)
end
local function GetAverageOfPoints(Vectors)
	local Sum = Vector3.zero
	for _, Vector in Vectors do
		Sum += Vector
	end
	return Sum / #Vectors
end
local function FlattenGrid2D(Grid)
	local Array = {}
	for I in Grid do
		for J in Grid[I] do
			table.insert(Array, Grid[I][J])
		end
	end
	return Array
end
local function FlattenGrid3D(Grid)
	local Array = {}
	for I in Grid do
		for J in Grid[I] do
			for K in Grid[I][J] do
				table.insert(Array, Grid[I][J][K])
			end
		end
	end
	return Array
end
local BitLibrary = {}
function BitLibrary.Probability(HowRandom, Count)
	local Seed = math.random() * 1000
	local Frequency = MapRanges(
		math.exp(HowRandom * EXP_GROWTH), 
		1, 
		math.exp(EXP_GROWTH), 
		MIN_FREQUENCY, 
		MAX_FREQUENCY
	)
	local Data = {}
	for I = 1, Count do
		table.insert(Data, math.round((math.noise(I * Frequency, Seed) + 1) / 2))	
	end
	return Data
end
function BitLibrary.SwitchDominance(Data, Bit)
	local NewData = {}
	local Majority = 0
	for _, Point in Data do
		Majority += Point
	end
	local DominatingBit = #Data / 2 > Majority and 1 or 0
	local CanSwitch = Bit == DominatingBit
	if CanSwitch then
		for Index, Value in Data do
			NewData[Index] = bit32.bxor(1, Value)
		end
		return NewData
	end
	return Data
end
function BitLibrary.Ones(Count)
	local Points = {}
	for I = 1, Count do
		table.insert(Points, 1)
	end
	return Points
end
local CellLibrary = {}
function CellLibrary.GetCell(Start, Offset, CellSize)
	local I = math.floor((Offset.X - Start.X) / CellSize)
	local J = math.floor((Offset.Y - Start.Y) / CellSize)
	local K = math.floor((Offset.Z - Start.Z) / CellSize)
	return I, J, K
end
function CellLibrary.GetPointOfCell(Start, CellSize, I, J, K)
	return Vector3.new(
		Start.X + (CellSize * I),
		Start.Y + (CellSize * J),
		Start.Z + (CellSize * K)
	)
end
local function GenerateLeaf(TreeObject, Center, YOffset, Size)
	YOffset = YOffset or 0
	local Size = Size or TreeObject.LeafSize
	local Part = Instance.new("Part")
	Part.Anchored = true
	Part.CanCollide = true
	Part.Color = Color3.fromRGB(29, 203, 81)
	Part.Material = Enum.Material.Neon
	Part.Position = Vector3.new(Center.X, Center.Y + YOffset, Center.Z)
	Part.Size = Vector3.new(Size, Size, Size)
	local Highlight = HIGH_LIGHT:Clone()
	Highlight.Adornee = Part
	Highlight.Parent = Part
	Part.Parent = TreeObject._Model
end
local function GenerateBranch(TreeObject, Center, XZAngle, YAngle, Iteration)
	Iteration = Iteration or 1
	if YAngle < 0 then
		return
	end
	local LookVector = (CFrame.fromAxisAngle(Vector3.yAxis, XZAngle) * CFrame.fromAxisAngle(Vector3.zAxis, YAngle)):VectorToWorldSpace(Vector3.new(1, Infinitesimal, 0))
	local RightVector = LookVector:Cross(Vector3.yAxis)
	local UpVector = RightVector:Cross(LookVector)
	local Points = {}
	for I = 1, TreeObject.InitialBranchLength / Iteration do
		for Theta = math.rad(1), 2 * math.pi, math.rad(5) do
			local Offset = Center + (LookVector * I) 
				+ (RightVector * (TreeObject.InitialBranchRadius / Iteration) * math.cos(Theta)) 
				+ (UpVector * (TreeObject.InitialBranchRadius / Iteration) * math.sin(Theta))  
			table.insert(Points, Offset)	
		end
	end
	local Grid = {}
	for _, Point in Points do
		local I, J, K = CellLibrary.GetCell(Center, Point, TreeObject.BlockSize)
		Grid[I] = Grid[I] or {}
		Grid[I][J] = Grid[I][J] or {}
		if Grid[I][J][K] then
			continue
		end
		local CellPoint = CellLibrary.GetPointOfCell(Center, TreeObject.BlockSize, I, J, K)
		local Part = Instance.new("Part")
		Part.Anchored = true
		Part.CanCollide = true
		Part.Color = Color3.fromRGB(93, 58, 34)
		Part.Material = Enum.Material.Wood
		Part.Position = CellPoint
		Part.Size = Vector3.new(TreeObject.BlockSize, TreeObject.BlockSize, TreeObject.BlockSize)
		local Highlight = HIGH_LIGHT:Clone()
		Highlight.Adornee = Part
		Highlight.Parent = Part
		Part.Parent = TreeObject._Model
		Grid[I][J][K] = CellPoint
	end
	GenerateLeaf(TreeObject, Center + (LookVector * (TreeObject.InitialBranchLength / Iteration)))
	local NewCenter = GetAverageOfPoints(FlattenGrid3D(Grid))
	local Sign = math.random() > 0.5 and 1 or -1
	GenerateBranch(TreeObject, NewCenter, XZAngle + ((math.pi / 2) * Sign), YAngle - math.pi / 8, Iteration + 1)
end
local function AddWoodLayerToWorld(TreeObject, Width, Height, MakeRandom)
	local BottomCenter = TreeObject.BottomCenter
	local BlockSize = TreeObject.BlockSize
	local LayerWidth = Width * BlockSize
	local LayerHeight = Height * BlockSize
	local Corners = {
		Vector3.new(-(LayerWidth / 2), LayerHeight, -(LayerWidth / 2)),
		Vector3.new((LayerWidth / 2), LayerHeight,  -(LayerWidth / 2)),
		Vector3.new((LayerWidth / 2), LayerHeight, (LayerWidth / 2)),
		Vector3.new(-(LayerWidth / 2), LayerHeight, (LayerWidth / 2)),
	}
	local Grid = {}
	for I = 1, 4 do
		local Corner = Corners[I]
		local Difference = (Corners[math.max((I + 1) % 5, 1)] - Corner).Unit
		local Points
		if MakeRandom then
			Points = BitLibrary.Probability(0.8, Width)
			Points = BitLibrary.SwitchDominance(Points, 1)
		else
			Points = BitLibrary.Ones(Width)
		end
		Grid[I] = {}
		for J = 1, Width do
			local PotentialPosition = BottomCenter + Corner + (Difference * BlockSize * (J - 1))
			Grid[I][J] = PotentialPosition
			if Points[J] == 0 then
				continue
			end
			local Part = Instance.new("Part")
			Part.Anchored = true
			Part.CanCollide = true
			Part.Color = Color3.fromRGB(93, 58, 34)
			Part.Material = Enum.Material.Wood
			Part.Position = PotentialPosition
			Part.Size = Vector3.new(BlockSize, BlockSize, BlockSize)
			local Highlight = HIGH_LIGHT:Clone()
			Highlight.Adornee = Part
			Highlight.Parent = Part
			Part.Parent = TreeObject._Model
		end
		
	end
	return Grid
end
local function GenerateWoodLayer(TreeObject, Width, Height)
	local Grid = AddWoodLayerToWorld(TreeObject, Width, Height, true)
	AddWoodLayerToWorld(TreeObject, Width - 2, Height, false)
	return Grid
end
local function GenerateTree(TreeObject)
	TreeObject._Model = Instance.new("Model")
	TreeObject._Model.Name = "Tree: "..tostring(TreeObject._Model)
	local Iteration = 0
	for I = 1, 0.4 * TreeObject.Width do
		GenerateWoodLayer(TreeObject, TreeObject.Width - (2 * (I - 1)), (I - 1))
		Iteration += 1
	end
	local Layers = {}
	for I = 1, TreeObject.Height do
		local MakeRandom = I ~= TreeObject.Height
		table.insert(Layers, GenerateWoodLayer(TreeObject, TreeObject.Width - (2 * (Iteration - 1)), (Iteration - 1) + I, MakeRandom))
	end
	local BlackList = {}
	for I = 1, TreeObject.RootBranches do
		if I == #Layers then
			table.clear(BlackList)
		end
		local Angle = ((2 * math.pi) / TreeObject.RootBranches) * I
		local RandomIndex
		while true do
			RandomIndex = math.random(1, #Layers)
			if #BlackList ~= #Layers then
				table.clear(BlackList)
				break
			elseif not table.find(BlackList, RandomIndex) then
				break
			end
		end
		local Layer = Layers[RandomIndex]
		table.insert(BlackList, RandomIndex)
		GenerateBranch(TreeObject, GetAverageOfPoints(FlattenGrid2D(Layer)), Angle, math.pi / 8)
	end
	GenerateLeaf(TreeObject, GetAverageOfPoints(FlattenGrid2D(Layers[#Layers])), 12.5, 25)
	TreeObject._Model.Parent = workspace
end
GenerateTree({
	BottomCenter = Vector3.new(0, 2, 0),
	Width = 15,
	Height = 6,
	RootBranches = 5,
	InitialBranchLength = 30,
	InitialBranchRadius = 3,
	LeafSize = 15,
	BlockSize = 3,
})
