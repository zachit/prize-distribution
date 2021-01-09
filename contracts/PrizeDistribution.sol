pragma solidity >=0.4.22 <0.9.0;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";

contract PrizeDistribution is Ownable {

  using SafeMath for uint256;

  struct Competition {
    string title;
    address owner;
    string externalReference;
    uint256 depositCount;
    uint256 distributionApprovalRate;
    uint256 entryFee;
    uint256 startBlock;
    uint256 endBlock;
    bool valid;
    bool playerRanksLocked;
    bool canceled;
    mapping (address => uint256) deposits;
    mapping (uint256 => uint256) prizeDistribution;
    mapping (address => bool) prizeDistributionApproved;
    mapping (uint256 => address) playerRanks;
  }

  mapping (uint => Competition) public competitions;
  uint256 public competitionCount = 0;
  uint256 public commissionRate;
  uint256 public commissionRateLastUpdated;
  uint256 public maxPlayers;

  constructor(
    uint256 _commissionRate,
    uint256 _maxPlayers
  ) public {
    maxPlayers = _maxPlayers;
    updateCommissionRate(_commissionRate);
  }

  /**
  * @dev Updates the commission rate used for competitions.
  */
  function updateCommissionRate(uint256 _commissionRate) public {
    commissionRate = _commissionRate;
    commissionRateLastUpdated = block.number;
  }

  /**
  * @dev Returns the commission that is charged by the smart contract on
  * competition prize pools. A number between 0 and 1000, where 1000 = 100%.
  *
  * The commission is redeemable by the owner of the contract.
  */
  function getCommissionRate() public view returns (uint256) {
    return commissionRate;
  }

  /**
  * @dev Returns the count of competitions.
  */
  function getCompetitionCount() public view returns (uint256) {
    return competitionCount;
  }

  /**
  * @dev Returns a competition by ID.
  */
  function getCompetition(
    uint _competitionId
  ) public view returns (
    string memory,
    address,
    string memory,
    uint256,
    uint256,
    uint256,
    uint256,
    uint256,
    bool,
    bool
  ) {
    Competition storage competition = competitions[_competitionId];
    require(competition.valid, "The competition does not exist.");
    return (
      competition.title,
      competition.owner,
      competition.externalReference,
      competition.depositCount,
      competition.distributionApprovalRate,
      competition.entryFee,
      competition.startBlock,
      competition.endBlock,
      competition.playerRanksLocked,
      competition.canceled
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
    uint256 _distributionApprovalRate,
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
    require(_distributionApprovalRate > 0,
      "The distribution approval rate must be greater than zero.");
    require(_distributionApprovalRate <= 100,
      "The distribution approval rate must be less than or equal to 100.");
    require(_startBlock > block.number,
      "The start block must be after the current block.");
    require(_endBlock > _startBlock,
      "The end block must be after the start block.");
    require(sumDistribution == 100,
      "The prize distribution must total 100%.");
    competitions[competitionCount] = Competition({
      title: _title,
      owner: msg.sender,
      depositCount: 0,
      externalReference: _externalReference,
      entryFee: _entryFee,
      distributionApprovalRate: _distributionApprovalRate,
      startBlock: _startBlock,
      endBlock: _endBlock,
      valid: true,
      canceled: false,
      playerRanksLocked: false
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
  ) public payable {
    Competition storage competition = competitions[_competitionId];
    require(competition.valid,
      "The competition does not exist.");
    require(msg.value == competition.entryFee,
      "You must deposit the exact entry fee in Ether.");
    require(competition.deposits[msg.sender] == 0x0,
      "You have already entered this competition.");
    require(!competition.canceled,
      "This competition has been canceled.");
    require(block.number < competition.startBlock,
      "This competition has already started.");
    require(competition.depositCount < maxPlayers,
      "This competition is already full.");
    competition.deposits[msg.sender] = msg.value;
    competition.depositCount += 1;
  }

  /**
   * @dev The owner of a competition can cancel it
   * if it has not already started.
   */
  function cancelCompetition(
    uint256 _competitionId
  ) public {
    Competition storage competition = competitions[_competitionId];
    require(competition.valid, "The competition does not exist.");
    require(competition.owner == msg.sender,
      "Only the owner of a competition can cancel it.");
    require(competition.startBlock > block.number,
      "You cannot cancel the competition because it has already started.");
    require(!competition.canceled,
      "The competition has already been canceled.");
    competition.canceled = true;
  }

  /**
   * @dev If a competition has been canceled anybody can call this
   * function to return the entrace fee to the original depositor.
   */
  function returnEntryFee(
    uint256 _competitionId,
    address payable _player
  ) public {
    Competition storage competition = competitions[_competitionId];
    require(competition.valid, "The competition does not exist.");
    require(competition.canceled, "The competition has not been canceled.");
    uint256 playerDeposit = competition.deposits[_player];
    require(playerDeposit > 0, "There is nothing to return to this player.");
    _player.transfer(playerDeposit);
    competitions[_competitionId].deposits[_player] = 0;
  }

  /**
   * @dev The owner of the smart contract can call this function to submit
   * the rank of each player once the competition has finished.
   *
   * Note: the owner does not need to necessarily be a sigle actor. The owner
   * of the contract could be a Multisig wallet, resulting in this function
   * performing the role of a decentralised oracle.
   */
  function submitPlayerRanks(
    uint256 _competitionId,
    uint256[] memory _ranks,
    address[] memory _players
  ) public onlyOwner {
    Competition storage competition = competitions[_competitionId];
    require(competition.valid, "The competition does not exist.");
    require(!competition.playerRanksLocked, "The player ranks are already locked.");
    require(_ranks.length < competition.depositCount, "The rank submitted is not valid for the competition.");
    require(competition.endBlock < block.number, "The competition has not finished yet.");
    require(_ranks.length == _players.length, "You must submit a rank for every player.");
    for(uint i=0; i<_players.length; i++) {
      require(competition.deposits[_players[i]] > 0, "You submitted a player that has not entered the competition.");
      competitions[_competitionId].playerRanks[_ranks[i]] = _players[i];
    }
    competition.playerRanksLocked = true;
  }

  /**
   * @dev If the prizes of a competition have been locked by the owner, then
   * anybody can call this function and the prizes will be distributed to
   * the original depositors according the prize distribution and player ranks.
   */
  function withdrawPrizes(
    uint256 _competitionId
  ) public {
    Competition storage competition = competitions[_competitionId];
    require(competition.valid, "The competition does not exist.");
    // TODO - send the prize to the sender if they entered the competition and have not already claime their prize
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
