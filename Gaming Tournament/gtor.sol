// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GamingTournament
 * @dev Gaming tournament contract with OpenZeppelin security features
 */
contract GamingTournament is ReentrancyGuard, Ownable {
    
    enum TournamentState { Open, Active, Completed }
    
    struct Tournament {
        string name;
        uint256 entryFee;
        uint256 maxPlayers;
        uint256 prizePool;
        address[] players;
        address winner;
        TournamentState state;
        mapping(address => bool) registered;
    }
    
    mapping(uint256 => Tournament) public tournaments;
    mapping(address => uint256) public playerWinnings;
    
    uint256 public tournamentCounter;
    
    event TournamentCreated(uint256 tournamentId, string name, uint256 entryFee);
    event PlayerRegistered(uint256 tournamentId, address player);
    event TournamentStarted(uint256 tournamentId);
    event WinnerAnnounced(uint256 tournamentId, address winner, uint256 prize);
    event PrizeWithdrawn(address player, uint256 amount);
    
    // FIX: Pass initialOwner to Ownable constructor
    constructor(address initialOwner) Ownable(initialOwner) {
        // Constructor body can be empty or contain additional initialization
    }
    
    /**
     * @dev Create a new tournament
     * @param _name Tournament name
     * @param _entryFee Entry fee in wei
     * @param _maxPlayers Maximum number of players (must be power of 2)
     */
    function createTournament(
        string memory _name,
        uint256 _entryFee,
        uint256 _maxPlayers
    ) external onlyOwner {
        require(_maxPlayers >= 2 && (_maxPlayers & (_maxPlayers - 1)) == 0, 
                "Max players must be power of 2");
        
        Tournament storage newTournament = tournaments[tournamentCounter];
        newTournament.name = _name;
        newTournament.entryFee = _entryFee;
        newTournament.maxPlayers = _maxPlayers;
        newTournament.state = TournamentState.Open;
        
        emit TournamentCreated(tournamentCounter, _name, _entryFee);
        tournamentCounter++;
    }
    
    /**
     * @dev Register for a tournament by paying entry fee
     * @param _tournamentId Tournament ID to register for
     */
    function registerPlayer(uint256 _tournamentId) external payable nonReentrant {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(tournament.state == TournamentState.Open, "Tournament not open");
        require(msg.value == tournament.entryFee, "Incorrect entry fee");
        require(!tournament.registered[msg.sender], "Already registered");
        require(tournament.players.length < tournament.maxPlayers, "Tournament full");
        
        tournament.registered[msg.sender] = true;
        tournament.players.push(msg.sender);
        tournament.prizePool += msg.value;
        
        emit PlayerRegistered(_tournamentId, msg.sender);
    }
    
    /**
     * @dev Start tournament when enough players registered
     * @param _tournamentId Tournament ID to start
     */
    function startTournament(uint256 _tournamentId) external onlyOwner {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(tournament.state == TournamentState.Open, "Tournament already started");
        require(tournament.players.length == tournament.maxPlayers, "Not enough players");
        
        tournament.state = TournamentState.Active;
        
        emit TournamentStarted(_tournamentId);
    }
    
    /**
     * @dev Declare tournament winner and distribute prize
     * @param _tournamentId Tournament ID
     * @param _winner Address of the winning player
     */
    function declareWinner(uint256 _tournamentId, address _winner) external onlyOwner nonReentrant {
        Tournament storage tournament = tournaments[_tournamentId];
        
        require(tournament.state == TournamentState.Active, "Tournament not active");
        require(tournament.registered[_winner], "Winner not registered");
        
        tournament.winner = _winner;
        tournament.state = TournamentState.Completed;
        
        // Calculate prize (90% to winner, 10% platform fee)
        uint256 platformFee = tournament.prizePool * 10 / 100;
        uint256 winnerPrize = tournament.prizePool - platformFee;
        
        // Add to player winnings
        playerWinnings[_winner] += winnerPrize;
        
        // Send platform fee to owner
        payable(owner()).transfer(platformFee);
        
        emit WinnerAnnounced(_tournamentId, _winner, winnerPrize);
    }
    
    /**
     * @dev Withdraw accumulated winnings
     */
    function withdrawWinnings() external nonReentrant {
        uint256 amount = playerWinnings[msg.sender];
        require(amount > 0, "No winnings to withdraw");
        
        playerWinnings[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        
        emit PrizeWithdrawn(msg.sender, amount);
    }
    
    // View functions
    function getTournamentInfo(uint256 _tournamentId) external view returns (
        string memory name,
        uint256 entryFee,
        uint256 maxPlayers,
        uint256 currentPlayers,
        uint256 prizePool,
        TournamentState state,
        address winner
    ) {
        Tournament storage tournament = tournaments[_tournamentId];
        return (
            tournament.name,
            tournament.entryFee,
            tournament.maxPlayers,
            tournament.players.length,
            tournament.prizePool,
            tournament.state,
            tournament.winner
        );
    }
    
    function getTournamentPlayers(uint256 _tournamentId) external view returns (address[] memory) {
        return tournaments[_tournamentId].players;
    }
    
    function getPlayerWinnings(address _player) external view returns (uint256) {
        return playerWinnings[_player];
    }
}
