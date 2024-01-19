--Tic Tac Toe
--Author: Gabriel Max

local Knit = shared.Knit
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Config = {
    MaxCols = 3,
    MaxRows = 3,
}

local GameController = Knit.CreateController {
    Name = "GameController";
}

function GameController:KnitStart()
    local GameService = Knit.GetService("GameService")


    GameService.ChallengeInvite:Connect(function(...)
        self:OnChallengeInvite(...)
    end)

	GameService.ChallengeReject:Connect(function(...)
        self:OnChallengeReject(...)
    end)

	GameService.ChallengeAction:Connect(function(...)
        self:OnChallengeAction(...)
    end)

    -- Mark existing players
    for _, player: Player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        self:MarkPlayer(player)
    end

    -- Mark new players
    Players.PlayerAdded:Connect(function(player)
        self:MarkPlayer(player)
    end)

	self:InitializeUI()
end

function GameController:InitializeUI()
	local GameService = Knit.GetService("GameService")

	local ui : ScreenGui? = self:GetMainUI()

	local acceptBtn : TextButton = ui.Invite.Options.Accept
	acceptBtn.Activated:Connect(function()
		GameService.ChallengeAccept:Fire(self.InvitingPlayer)
		ui.Invite.Visible = false
	end)

	local rejectBtn : TextButton = ui.Invite.Options.Reject
	rejectBtn.Activated:Connect(function()
		GameService.ChallengeReject:Fire(self.InvitingPlayer)
		ui.Invite.Visible = false
		self.InvitingPlayer = nil
	end)

	local player : Player = LocalPlayer
	local gameUI : Frame = ui.Game
	gameUI.LocalPlayer.User.Text = player.DisplayName
	gameUI.LocalPlayer.HeadShot.Image = `rbxthumb://type=AvatarHeadShot&id=3&w=150&h=150&id={player.UserId}`

	for row = 1, Config.MaxRows do
		for col = 1, Config.MaxCols do
			local button : TextButton? = self:GetBoardCell(row, col)
			if not button then
				continue
			end

			button.Text = ""
			button.Activated:Connect(function(inputObject, clickCount)
				self:OnBoardCellClicked(button, row, col)
			end)
		end
	end
end

function GameController:ChallengePlayer(player: Player)
	-- Add your code here
	-- Alternatively, you can change it completely
	local GameService = Knit.GetService("GameService")
    GameService.ChallengeInvite:Fire(player)
end

function GameController:MarkPlayer(player: Player)
	if player.Character then
		self:AddUI(player)
	end

	player.CharacterAdded:Connect(function()
		self:AddUI(player)
	end)
end

function GameController:GetMainUI()
	local player : Player = game.Players.LocalPlayer
    local topGui : ScreenGui? = player.PlayerGui:WaitForChild("Main")
	--
    return topGui
end

function GameController:GetBoardCell(row : number, col : number) : TextButton?
	local ui : ScreenGui? = self:GetMainUI()
	return ui.Game.Board:FindFirstChild(tostring((row - 1) * Config.MaxCols + col))
end

function GameController:AddUI(player : Player)
	local character = player.Character or player.CharacterAdded:Wait()
	-- Create the UI
	local ui = Instance.new("BillboardGui")
	ui.Name = "ChallengePlayer"
	ui.Active = true
	ui.Size = UDim2.fromScale(4, 1)
	ui.StudsOffset = Vector3.new(0, 4, 0)
	ui.LightInfluence = 0
	ui.MaxDistance = 25
	ui.Adornee = character:WaitForChild("Head", 20)

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild("Main") then
		ui.Enabled = not playerGui.Main.Game.Visible
	end

	ui.Parent = playerGui
	
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	button.Size = UDim2.fromScale(1, 1)
	button.TextScaled = true
	button.Text = "Challenge"
	button.Font = Enum.Font.SourceSansSemibold
	button.Parent = ui
	
	Instance.new("UICorner").Parent = button
	
	-- Button click
	button.Activated:Connect(function()
		self:ChallengePlayer(player)
	end)
end

function GameController:TogglePlayersUI(visible : boolean)
	local ui : PlayerGui? = LocalPlayer:WaitForChild("PlayerGui")
	for _, item in ui:GetChildren() do
		if item:IsA("BillboardGui") and item.Name == "ChallengePlayer" then
			item.Enabled = visible
		end
	end
end

-- Called when we get an invitation for a game
function GameController:OnChallengeInvite(player: Player)
	local ui : ScreenGui? = self:GetMainUI()
	if not ui or self.InvitingPlayer then
		return
	end

	self.InvitingPlayer = player
	ui.Invite.Visible = true
	ui.Invite.Body.Text = `<font color="#BB86FC">{player.DisplayName}</font> has sent you an invite to play Tic-Tac-Toe!`

	-- Reject automatically
	task.delay(8, function()
		if ui.Invite.Visible then
			ui.Invite.Visible = false

			local GameService = Knit.GetService("GameService")
			GameService.ChallengeReject:Fire(self.InvitingPlayer)
			self.InvitingPlayer = nil
		end
	end)
end

-- Called when out invitation got rejected
function GameController:OnChallengeReject()
	local ui : ScreenGui? = self:GetMainUI()
	ui.Rejected.Visible = true
	task.delay(5, function()
		ui.Rejected.Visible = false
	end)
end

--This is called when server requires some action from the controller
function GameController:OnChallengeAction(action : {})
	local ui : ScreenGui? = self:GetMainUI()

	--warn("action received", action)
	if action.Id == "UpdateBoard" then
		for row = 1, Config.MaxRows do
			for col = 1, Config.MaxCols do
				local button : TextButton? = self:GetBoardCell(row, col)
				if not button then
					continue
				end
				button.Text = action.Board[row][col]
			end
		end

		local player : Player = LocalPlayer
		local gameUI : Frame = ui.Game

		if player:GetAttribute("BoardMark") == action.NextPlayer then
			gameUI.LocalPlayer.Warning.Visible = true
			gameUI.Opponent.Warning.Visible = false
		else
			gameUI.LocalPlayer.Warning.Visible = false
			gameUI.Opponent.Warning.Visible = true
		end
	elseif action.Id == "Start" then
		local opponent : Player = action.Opponent
	
		local gameUI : Frame = ui.Game
		gameUI.Opponent.User.Text = opponent.DisplayName
		gameUI.Opponent.HeadShot.Image = `rbxthumb://type=AvatarHeadShot&id=3&w=150&h=150&id={opponent.UserId}`

		for row = 1, Config.MaxRows do
			for col = 1, Config.MaxCols do
				local button : TextButton? = self:GetBoardCell(row, col)
				if not button then
					continue
				end
				button.Text = ""
			end
		end

		gameUI.LocalPlayer.Warning.Visible = self.InvitingPlayer ~= nil
		gameUI.Visible = true
		self:TogglePlayersUI(false)
	elseif action.Id == "Finish" or action.Id == "Draw" then
		local winUI : Frame = action.Id == "Draw" and ui.Draw or (action.Wins and ui.Win or ui.Lose)
		winUI.Visible = true

		self.InvitingPlayer = false
		self:TogglePlayersUI(true)

		task.delay(5, function()
			winUI.Visible = false
			ui.Game.Visible = false
		end)
	end
end

--This is called when player clicks on a cell on the board
function GameController:OnBoardCellClicked(button: TextButton, row: number, col: number)
	local player : Player = LocalPlayer

	if button.Text == "" and player:GetAttribute("BoardMark") then
		local GameService = Knit.GetService("GameService")
		GameService.ChallengeAction:Fire({
			Id = "TakeTurn",
			row = row,
			col = col
		})
	end
end

return GameController
