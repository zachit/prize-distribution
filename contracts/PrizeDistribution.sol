pragma solidity >=0.4.22 <0.9.0;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";

contract PrizeDistribution is Ownable {

  using SafeMath for uint256;

  /**
   * @dev Throws if competition does not exist.
   */
  modifier competitionExists(uint256 _competitionId) {
    require(competitions[_competitionId].valid,
      "The competition does not exist.");
    _;
  }

  struct Competition {
    string title;
    address owner;
    string externalReference;
    uint256 entryFee;
    uint256 startBlock;
    uint256 endBlock;
    bool valid;
    bool canceled;
    bool commissionPaid;
    uint256 commissionRate;
    address[] players;
    mapping (address => uint256) deposits;
    mapping (uint256 => uint256) prizeDistribution;
    mapping (uint256 => address) playerRanks;
  }

  mapping (uint => Competition) public competitions;
  uint256 public competitionCount = 0;
  uint256 public commissionRate;
  uint256 public maxPlayers;

  /**
  * @dev Sets the commission rate charged on competitions and max players
  * permitted in a single competition on creation of the contract.
  */
  constructor(
    uint256 _commissionRate,
    uint256 _maxPlayers
  ) public {
    maxPlayers = _maxPlayers;
    require(_commissionRate <= 1000, "Commission rate must be <= 1000.");
    updateCommissionRate(_commissionRate);
  }

  /**
  * @dev Updates the commission rate used for competitions.
  */
  function updateCommissionRate(uint256 _commissionRate) public onlyOwner {
    commissionRate = _commissionRate;
  }

  /**
  * @dev Returns the commission that is charged by the smart contract on
  * prize pools. A number between 0 and 1000, where 1000 = 100%.
  *
  * The commission is redeemable by the owner of the contract.
  */
  function getCommissionRate() public view returns (uint256) {
    return commissionRate;
  }

  /**
  * @dev Returns the number of created competitions.
  */
  function getCompetitionCount() public view returns (uint256) {
    return competitionCount;
  }

  /**
  * @dev Returns a competition by ID.
  */
  function getCompetition(
    uint _competitionId
  ) public competitionExists(_competitionId) view returns (
    string memory,
    address,
    string memory,
    uint256,
    uint256,
    uint256,
    bool,
    uint256
  ) {
    Competition storage competition = competitions[_competitionId];
    return (
      competition.title,
      competition.owner,
      competition.externalReference,
      competition.entryFee,
      competition.startBlock,
      competition.endBlock,
      competition.canceled,
      competition.players.length
    );
  }

  /**
  * @dev Anybody can create new competitions, and they will be deemed to be
  * the owner of the competition.
  */
  function createCompetition(
    string memory _title,
    string memory _externalReference,
    uint256 _entryFee,
    uint256 _startBlock,
    uint256 _endBlock,
    uint256[] memory _distribution
  ) public {
    uint256 sumDistribution = 0;
    require(_distribution.length <= 10,
      "The prize distribution cannot have more than 10 categories.");
    for(uint256 i=0; i<_distribution.length; i++) {
      sumDistribution = sumDistribution.add(_distribution[i]);
    }
    require(_startBlock > block.number,
      "The start block must be after the current block.");
    require(_endBlock > _startBlock,
      "The end block must be after the start block.");
    require(sumDistribution == 100,
      "The prize distribution must total 100%.");
    address[] memory _players;
    competitions[competitionCount] = Competition({
      title: _title,
      owner: msg.sender,
      externalReference: _externalReference,
      entryFee: _entryFee,
      startBlock: _startBlock,
      endBlock: _endBlock,
      valid: true,
      canceled: false,
      commissionPaid: false,
      commissionRate: commissionRate,
      players: _players
    });
    for(uint256 i=0; i<_distribution.length; i++) {
      competitions[competitionCount].prizeDistribution[i] = _distribution[i];
    }
    competitionCount += 1;
  }

  /**
   * @dev Anyone can enter a competition provided it is not full, has not
   * already started, has not been canceled, and they pay the required
   * entrance fee.
   */
  function enterCompetition(
    uint256 _competitionId
  ) public competitionExists(_competitionId) payable {
    Competition storage competition = competitions[_competitionId];
    require(msg.value == competition.entryFee,
      "You must deposit the exact entry fee in Ether.");
    require(competition.deposits[msg.sender] == 0x0,
      "You have already entered this competition.");
    require(!competition.canceled,
      "This competition has been canceled.");
    require(block.number < competition.startBlock,
      "This competition has already started.");
    require(competition.players.length < maxPlayers,
      "This competition is already full.");
    competition.deposits[msg.sender] = msg.value;
    competition.players.push(msg.sender);
  }

  /**
   * @dev The owner of a competition can cancel it if it has not started.
   */
  function cancelCompetition(
    uint256 _competitionId
  ) public competitionExists(_competitionId) {
    Competition storage competition = competitions[_competitionId];
    require(competition.owner == msg.sender,
      "Only the owner of a competition can cancel it.");
    require(!competition.canceled,
      "The competition has already been canceled.");
    require(competition.startBlock > block.number,
      "You cannot cancel the competition because it has already started.");
    competitions[_competitionId].canceled = true;
    for(uint256 i=0; i<competition.players.length; i++) {
      returnEntryFee(_competitionId, address(uint160(competition.players[i])));
    }
  }

  /**
   * @dev Returns a player's entrance fee (called internally on cancel).
   */
  function returnEntryFee(
    uint256 _competitionId,
    address payable _player
  ) internal {
    Competition storage competition = competitions[_competitionId];
    uint256 playerDeposit = competition.deposits[_player];
    _player.transfer(playerDeposit);
    competitions[_competitionId].deposits[_player] = 0;
  }

  /**
   * @dev The owner of the smart contract can call this function to submit
   * the rank of each player once the competition has finished.
   *
   * Note: the owner does not need to necessarily be a sigle actor. The owner
   * of the contract could be a Multisig wallet with multiple signatories
   * required, resulting in this function performing the role of an oracle.
   */
  function submitPlayerRanks(
    uint256 _competitionId,
    uint256[] memory _ranks,
    address[] memory _players
  ) public competitionExists(_competitionId) onlyOwner {
    Competition storage competition = competitions[_competitionId];
    require(_ranks.length == competition.players.length,
      "You must submit ranks for every player in the competition.");
    require(competition.endBlock < block.number,
      "The competition has not finished yet.");
    require(_ranks.length == _players.length,
      "You must submit a rank for every player.");
    for(uint i=0; i<_players.length; i++) {
      require(competition.deposits[_players[i]] > 0,
        "You submitted a player that has not entered the competition.");
      competitions[_competitionId].playerRanks[_ranks[i]] = _players[i];
    }
  }

  /**
   * @dev If the the player ranks have been set by the owner, then
   * anybody can call this function and the prizes will be distributed to
   * the original depositors according the prize distribution and player ranks.
   */
  function withdrawPrizes(
    uint256 _competitionId
  ) public competitionExists(_competitionId) {
    Competition storage competition = competitions[_competitionId];
    require(!competition.canceled,
      "This competition was canceled. You can only withdraw the original entrance fee.");
    // TODO - send the prize to the sender if they entered the competition and have not already claime their prize
  }

  /**
  * @dev Anybody can withdraw unpaid commission to the contract owner.
  */
  function withdrawCommission(
    uint256 _competitionId
  ) public competitionExists(_competitionId) {
    Competition storage competition = competitions[_competitionId];
    require(!competition.commissionPaid,
      "The commission has already been paid out.");
    require(competition.startBlock < block.number,
      "The competition has not started yet.");
    uint256 commission = competition.players.length
                          .mul(competition.entryFee)
                          .mul(competition.commissionRate)
                          .div(1000);
    address(uint160(owner())).transfer(commission);
    competition.commissionPaid = true;
  }

  /**
   * @dev Ensures that it is not possible for Ether to enter the contract
   * unless through the context of entering a competition and paying then
   * correct entrance fee.
   */
  function() external payable {
    revert("You must not send Ether directly to this contract.");
  }
}
