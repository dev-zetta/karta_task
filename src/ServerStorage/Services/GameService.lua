--Tic Tac Toe
--Author: Gabriel Max

local Knit = shared.Knit

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local ASSETS_IN_WORKSPACE = false
if ASSETS_IN_WORKSPACE then
    workspace.Assets.Parent = ServerStorage
end

local Config = {
    --TODO: Move constants from code to this struct
    MaxCols = 3,
    MaxRows = 3,
}

local GameService = Knit.CreateService {
    Name = "GameService";
    Client = {
        ChallengeInvite = Knit.CreateSignal(),
        ChallengeAccept = Knit.CreateSignal(),
        ChallengeReject = Knit.CreateSignal(),
        ChallengeAction = Knit.CreateSignal(),
    };
}

function GameService:KnitStart()
    self.playerData = {}

    Players.PlayerAdded:Connect(function(...)
        self:OnPlayerAdded(...)
    end)

    Players.PlayerRemoving:Connect(function(...)
        self:OnPlayerRemoved(...)
    end)

    self.Client.ChallengeInvite:Connect(function(...)
        self:OnChallengeInvite(...)
    end)

    self.Client.ChallengeAccept:Connect(function(...)
        self:OnChallengeAccept(...)
    end)

    self.Client.ChallengeReject:Connect(function(...)
        self:OnChallengeReject(...)
    end)

    self.Client.ChallengeAction:Connect(function(...)
        self:OnChallengeAction(...)
    end)
end

function GameService:OnPlayerAdded(player: Player)
    -- Add player's leaderstats
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    -- Add wins value
    local wins = Instance.new("IntValue")
    wins.Name = "Wins"
    wins.Value = 0
    wins.Parent = leaderstats

    self.playerData[player] = {
        Player = player,
    }

    self:UpdateLeaderstats()
end

function GameService:OnPlayerRemoved(player: Player)
    local data = self.playerData[player]
    if data then
        if data.Challenge then
            --Make sure the other player wins the game
            local challenge = data.Challenge
            local otherPlayer : Player = (player == challenge.Player1) and challenge.Player2 or challenge.Player1
            self:MakePlayerWin(otherPlayer)
        end

        self.playerData[player] = nil
    end
end

-- Function to update the board on the client
function GameService:UpdateChallenge(player : Player)
    local challenge = self.playerData[player].Challenge
    self.Client.ChallengeAction:Fire(player, {
        Id = "UpdateBoard",
        Board = challenge.Board,
        NextPlayer = (challenge.CurrentPlayer == "X") and "O" or "X"
    })
end

-- Function to check for a win
function GameService:CheckForWin(board : {}, currentPlayer : string)
    --TODO: Use Config instead of inline constants
    -- Check rows and columns
    for i = 1, 3 do
        if board[i][1] == currentPlayer and board[i][2] == currentPlayer and board[i][3] == currentPlayer then
            return true
        end
        if board[1][i] == currentPlayer and board[2][i] == currentPlayer and board[3][i] == currentPlayer then
            return true
        end
    end

    -- Check diagonals
    if board[1][1] == currentPlayer and board[2][2] == currentPlayer and board[3][3] == currentPlayer then
        return true
    end

    if board[1][3] == currentPlayer and board[2][2] == currentPlayer and board[3][1] == currentPlayer then
        return true
    end

    return false
end

function GameService:CheckForDraw(board : {})
    local values = {["X"] = 0, ["O"] = 0, [""] = 0}

    for i, row in board do
        for j, value in row do
            values[value] += 1
        end
    end

    return values[""] == 0
end

-- Function to initialize the board
function GameService:InitializeBoard()
    local board = {}
    for i = 1, Config.MaxRows do
        board[i] = {}
        for j = 1, Config.MaxCols do
            board[i][j] = ""
        end
    end
    return board
end

-- Function to handle player moves
function GameService:OnChallengeAction(player : Player, action: {})
    if not action or action.Id ~= "TakeTurn" then
        return
    end

    local data1 = self.playerData[player]
    if not data1 then
        return
    end

    local challenge = data1.Challenge
    if challenge.CurrentPlayer ~= player:GetAttribute("BoardMark") then
        return -- cheating?
    end

    if challenge.Board[action.row][action.col] == "" then
        --It's empty cell, proceed
        challenge.Board[action.row][action.col] = challenge.CurrentPlayer
        self:UpdateChallenge(challenge.Player1)
        self:UpdateChallenge(challenge.Player2)

        local otherPlayer : Player = (player == challenge.Player1) and challenge.Player2 or challenge.Player1
        local data2 = self.playerData[otherPlayer]

        if self:CheckForWin(challenge.Board, challenge.CurrentPlayer) then
            self:MakePlayerWin(player, otherPlayer)

            data1.Challenge = nil
            data2.Challenge = nil
        elseif self:CheckForDraw(challenge.Board) then
            --Check for draw... this can be done better
            self.Client.ChallengeAction:Fire(challenge.Player1, {
                Id = "Draw",
            })

            self.Client.ChallengeAction:Fire(challenge.Player2, {
                Id = "Draw",
            })

            data1.Challenge = nil
            data2.Challenge = nil
        else
            --No one wins yet
            challenge.CurrentPlayer = (challenge.CurrentPlayer == "X") and "O" or "X"
        end
    end
end

function GameService:MakePlayerWin(player : Player, otherPlayer: Player?)
    local winStats : IntValue = player.leaderstats.Wins
    winStats.Value +=1
    self:UpdateLeaderstats()

    self.Client.ChallengeAction:Fire(player, {
        Id = "Finish",
        Wins = true
    })

    if otherPlayer then
        self.Client.ChallengeAction:Fire(otherPlayer, {
            Id = "Finish",
            Wins = false
        })
    end
end

function GameService:OnChallengeInvite(player1: Player, player2: Player)
    local data1 = self.playerData[player1]
    local data2 = self.playerData[player2]
    if not data1 or not data2 then
        return
    end

    if data1.Challenge or data2.Challenge then
        return
    end

    self.Client.ChallengeInvite:Fire(player2, player1)
end

function GameService:OnChallengeAccept(player1: Player, player2: Player)
    local data1 = self.playerData[player1]
    local data2 = self.playerData[player2]
    if not data1 or not data2 then
        return
    end

    if data1.Challenge or data2.Challenge then
        return
    end

    -- Initialize the board
    local board = self:InitializeBoard()
    local challenge = {
        Board = board,
        Player1 = player1, --X
        Player2 = player2, --O
        CurrentPlayer = "X",
    }

    -- Assign to every player the board mark they have, so we know at client side at any time
    player1:SetAttribute("BoardMark", "X")
    player2:SetAttribute("BoardMark", "O")

    data1.Challenge = challenge
    data2.Challenge = challenge

    self.Client.ChallengeAction:Fire(player1, {
        Id = "Start",
        Opponent = player2,
    })

    self.Client.ChallengeAction:Fire(player2, {
        Id = "Start",
        Opponent = player1
    })
end

function GameService:OnChallengeReject(player1: Player, player2: Player)
    self.Client.ChallengeReject:Fire(player2)
end

function GameService:UpdateLeaderstats()
    -- This updates the physical leaderstats in the workspace
    local leaderboard = {}
    for _, player in Players:GetPlayers() do
        table.insert(leaderboard, {
            Player = player,
            Wins = player.leaderstats.Wins.Value
        })
    end

    table.sort(leaderboard, function(a, b)
        return a.Wins > b.Wins
    end)

    local list : ScrollingFrame? = workspace.Leaderboard.Leaderboard.List
    for _, item : Instance in list:GetChildren() do
        if item:IsA("Frame") and item.Visible then
            item:Destroy()
        end
    end

    for i, stats in leaderboard do
        local player : Player = stats.Player
        local item : Frame = list.Template:Clone()
        item.User.Text = `{player.DisplayName} (@{player.Name})`
        item.Score.Text = string.format("%0.2i", stats.Wins)
        item.HeadShot.Image = `rbxthumb://type=AvatarHeadShot&id=3&w=150&h=150&id={player.UserId}`
        item.Visible = true
        item.LayoutOrder = i
        item.Parent = list

        if i >= 14 then
            break
        end
    end
end

return GameService
