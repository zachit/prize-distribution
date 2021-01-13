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
    bool prizesPaid;
    uint256 commissionRate;
    uint256 stakeToPrizeRatio;
    address[] players;
    uint256[] prizeDistribution;
    address[] playerRanks;
    mapping (address => uint256) deposits;
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
    updateCommissionRate(_commissionRate);
  }

  /**
  * @dev Updates the commission rate used for competitions.
  */
  function updateCommissionRate(uint256 _commissionRate) public onlyOwner {
    require(_commissionRate <= 1000, "Commission rate must be <= 1000.");
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
    uint256 _endBlock
  ) public {
    require(_startBlock > block.number,
      "The start block must be after the current block.");
    require(_endBlock > _startBlock,
      "The end block must be after the start block.");
    require(_entryFee > 0,
      "There must be a fee to enter the competition.");
    address[] memory _players;
    address[] memory _playerRanks;
    uint256[] memory _distribution;
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
      prizesPaid: false,
      commissionRate: commissionRate,
      players: _players,
      prizeDistribution: _distribution,
      playerRanks: _playerRanks,
      stakeToPrizeRatio: 50
    });
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

  function buildDistribution(
    uint256 _playerCount,
    uint256 _entryFee,
    uint256 _stakeToPrizeRatio
  ) internal returns (uint256[] memory) {
    uint256[] memory prizeModel = buildFibPrizeModel(_playerCount);
    uint256[] memory distributions = new uint[](_playerCount);
    for (uint256 i=0; i<prizeModel.length; i++) {
      uint256 prize = (1 - _stakeToPrizeRatio) * prizeModel[i];
      uint256 distribution = (_stakeToPrizeRatio + prize) * _entryFee;
      distributions[i] = distribution;
    }
    return distributions;
  }

  function buildFibPrizeModel(
    uint256 _playerCount
  ) internal returns (uint256[] memory) {
    uint256[] memory fib = new uint[](_playerCount);
    for (uint256 i=0; i<_playerCount; i++) {
      if (fib.length == 0) {
        fib[i] = 1 - 1 / _playerCount;
      } else if (fib.length == 1) {
        fib[i] = 1;
      } else {
        // as "5" increases, more winnings go towards the top quartile
        uint256 nextFib = fib[i-1] * 5 / _playerCount + fib[i-2];
        fib[i] = nextFib;
      }
    }
    uint256 fibSum = getArraySum(fib);
    for (uint256 i=0; i<fib.length; i++) {
      fib[i] = fib[i].div(fibSum).div(fib.length);
    }
    return fib;
  }

  function getArraySum(
    uint256[] memory _array
  ) internal returns (uint256) {
    uint256 sum = 0;
    for (uint256 i=0; i<_array.length; i++) {
      sum = sum.add(_array[i]);
    }
    return sum;
  }

  /**
   * @dev The owner of the smart contract can call this function to submit
   * the rank of each player once the competition has finished.
   *
   * Note: the owner does not need to necessarily be a sigle actor. The owner
   * of the contract could be a Multisig wallet with multiple signatories
   * required, resulting in this function performing the role of an oracle.
   */
  function submitPlayersByRank(
    uint256 _competitionId,
    address[] memory _players
  ) public competitionExists(_competitionId) onlyOwner {
    Competition storage competition = competitions[_competitionId];
    require(_players.length == competition.players.length,
      "You must submit ranks for every player in the competition.");
    require(competition.endBlock < block.number,
      "The competition has not finished yet.");
    competitions[_competitionId].playerRanks.length = 0;
    competition.prizeDistribution = buildDistribution(
      competition.players.length,
      competition.entryFee,
      competition.stakeToPrizeRatio
    );
    for(uint i=0; i<_players.length; i++) {
      require(competition.deposits[_players[i]] > 0,
        "You submitted a player that has not entered the competition.");
      competitions[_competitionId].playerRanks.push(_players[i]);
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
      "This competition was canceled. There are no prizes to withdraw.");
    require(!competition.prizesPaid, "The prizes have already been paid.");
    require(competition.playerRanks.length > 0,
      "The player ranks have not been set yet.");
    uint256 totalPrizePool = (competition.players.length
                              .mul(competition.entryFee))
                              .sub(calculateCommission(competition));
    for(uint256 i=0; i<competition.players.length; i++) {
      uint256 playerPrize = competition.prizeDistribution[i]
                              .mul(totalPrizePool)
                              .div(100);
      address(uint160(competition.playerRanks[i])).transfer(playerPrize);
    }
    competition.prizesPaid = true;
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
    address(uint160(owner())).transfer(calculateCommission(competition));
    competition.commissionPaid = true;
  }

  /**
  * @dev Calculates the commission charged on a competition prize pool.
  */
  function calculateCommission(
    Competition memory competition
  ) internal returns(uint256) {
    return competition.players.length
            .mul(competition.entryFee)
            .mul(competition.commissionRate)
            .div(1000);
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
