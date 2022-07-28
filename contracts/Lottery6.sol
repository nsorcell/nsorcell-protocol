// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./ArrayUtils.sol";

import "hardhat/console.sol";

error Lottery6__NotOwner();
error Lottery6__PaymentNotEnough();
error Lottery6__EntryClosed();
error Lottery6__UpkeepUnnecessary(
  uint256 balance,
  uint256 playerCount,
  uint256 lotteryState
);
error Lottery6__NumbersNotDrawn();
error Lottery6__AlreadyInGame();
error Lottery6__TransferFailed(address forPLayer);

contract Lottery6 is VRFConsumerBaseV2, KeeperCompatibleInterface {
  using Uint256ArrayUtils for uint256[];
  using AddressArrayUtils for address[];
  using EnumerableSet for EnumerableSet.AddressSet;

  /* Types */
  enum LotteryState {
    STANDBY,
    OPEN,
    DRAWING,
    CALCULATING
  }

  struct History {
    uint256[] winningNumbers;
    address[][] results;
  }

  /* Constants */
  uint16 private constant REQUEST_CONFIRMATIONS = 3;

  /* Immutable State Variables */
  bytes32 private immutable i_keyHash;
  uint32 private immutable i_callbackGasLimit;
  uint32 private immutable i_numberCount;
  uint64 private immutable i_subscriptionId;
  uint256 private immutable i_interval;
  uint256 private immutable i_entranceFee;
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

  /* State Variables */
  uint256 private s_totalEntries;
  uint256 private s_lastTimestamp;
  uint256 private s_draws;
  mapping(uint256 => address[]) private s_hitMap;
  mapping(address => uint256[]) private s_entries;
  EnumerableSet.AddressSet private s_players;
  History[] private s_history;
  LotteryState private s_state;

  /* Events */
  event Lottery6__Enter(address indexed player);
  event Lottery6__RequestedDraw(uint256 requestId);
  event Lottery6__Draw(uint256[] winningNumbers);
  event Lottery6__Results(address[][] results);

  /* Functions */

  /**
   * @param vrfCoordinator - ChainLink VRFCoordinatorV2 contract address.
   * @param keyHash - Chainlink keyHash for Oracle gas.
   * @param numberCount - Count of requested random numbers.
   * @param subscriptionId - Chainlink VRF Subscription identifier.
   * @param interval - interval of randomNumber draws after the first player entered.
   * @param entranceFee - Payment to enter the lottery
   */
  constructor(
    address vrfCoordinator,
    bytes32 keyHash,
    uint32 callbackGasLimit,
    uint32 numberCount,
    uint64 subscriptionId,
    uint256 interval,
    uint256 entranceFee
  ) VRFConsumerBaseV2(vrfCoordinator) {
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
    i_keyHash = keyHash;
    i_callbackGasLimit = callbackGasLimit;
    i_numberCount = numberCount;
    i_subscriptionId = subscriptionId;
    i_interval = interval;
    i_entranceFee = entranceFee;

    s_state = LotteryState.STANDBY;
    s_totalEntries = 0;
    s_lastTimestamp = block.timestamp;
    s_draws = 0;
  }

  /**
    @notice - KeeperCompatible checkUpkeep override
   */
  function checkUpkeep(bytes memory)
    public
    view
    override
    returns (
      bool upkeepNeeded,
      bytes memory /* performData */
    )
  {
    bool isOpen = (s_state == LotteryState.OPEN);
    bool timePassed = ((block.timestamp - s_lastTimestamp) > i_interval);
    bool hasPlayers = s_players.length() > 0;
    bool hasBalance = address(this).balance > 0;

    upkeepNeeded = isOpen && timePassed && hasPlayers && hasBalance;

    return (upkeepNeeded, "");
  }

  /**
    @notice - KeeperCompatible performUpkeep override
   */
  function performUpkeep(
    bytes calldata /* performData */
  ) external override {
    (bool upkeepNeeded, ) = checkUpkeep("");

    if (!upkeepNeeded) {
      revert Lottery6__UpkeepUnnecessary(
        address(this).balance,
        s_players.length(),
        uint256(s_state)
      );
    }

    s_state = LotteryState.DRAWING;

    uint256 requestId = i_vrfCoordinator.requestRandomWords(
      i_keyHash,
      i_subscriptionId,
      REQUEST_CONFIRMATIONS,
      i_callbackGasLimit,
      i_numberCount
    );

    emit Lottery6__RequestedDraw(requestId);
  }

  /**
   @dev - 1. pick random words from the incoming array, until
          there are 6 unique numbers.
          are finished.
   @dev - 2. Sort the winningNumbers array
   @dev - 3. Iterate over all entries, and compare the sorted
          winningNumbers, with the number the players entered,
          and collect the winners into the winners array.
          (the player numbers must be already sorted)
   @dev - 4. Add the result of the draw to the @param s_history 
          variable.
   @dev - 5.a If the winners array is empty, there are no winners.
   @dev - 5.b If the winners array is not empty, distribute the 
          contract balance equally between them. 
   @dev - 6. Reset the store variables keeping track of everything.
   @notice - @param s_players, and @param s_entries is not emptied,
             entry is kept for future draws.
   */
  function fulfillRandomWords(
    uint256, /* requestId */
    uint256[] memory randomWords
  ) internal override {
    uint256[] memory winningNumbers = new uint256[](6);

    uint256 nIndex = 0;
    uint256 rndPicks = 0;

    while (rndPicks != 6) {
      uint256 number = randomWords[nIndex] % 45;

      if (!winningNumbers.contains(number) && number != 0) {
        winningNumbers[rndPicks] = number;
        rndPicks++;
      }

      nIndex++;
    }

    winningNumbers.sort();

    emit Lottery6__Draw(winningNumbers);

    s_state = LotteryState.CALCULATING;

    distributePrizePool(winningNumbers);

    address[][] memory results = new address[][](7);

    for (uint256 i = 0; i < results.length; i++) {
      results[i] = s_hitMap[i];
    }

    addHistoryEntry(winningNumbers, results);

    emit Lottery6__Results(results);

    resetState();
  }

  /**
    @notice Enter into the Lottery.
    @dev - The incoming array, which represents the players choices
           should be already sorted.
   */
  function enter(uint256[6] memory numbers, bool updateNumbers) public payable {
    if (s_state != LotteryState.OPEN && s_state != LotteryState.STANDBY) {
      revert Lottery6__EntryClosed();
    }

    if (msg.value < i_entranceFee) {
      revert Lottery6__PaymentNotEnough();
    }

    if (s_players.contains(msg.sender) && !updateNumbers) {
      revert Lottery6__AlreadyInGame();
    }

    if (s_totalEntries == 0 && s_state == LotteryState.STANDBY) {
      s_state = LotteryState.OPEN;
      s_lastTimestamp = block.timestamp;
    }

    s_entries[msg.sender] = numbers;
    s_players.add(msg.sender);
    s_totalEntries++;

    emit Lottery6__Enter(msg.sender);
  }

  function exit() public returns (bool) {
    if (s_players.contains(msg.sender)) {
      delete s_entries[msg.sender];
      s_players.remove(msg.sender);

      s_totalEntries--;

      if (s_totalEntries == 0) {
        s_state = LotteryState.STANDBY;
      }

      return true;
    }

    return false;
  }

  function determineHitMap(uint256[] memory winningNumbers) private {
    for (uint256 i = 0; i < s_totalEntries; i++) {
      uint256 hits = 0;
      address player = s_players.at(i);
      uint256[] memory playerNumbers = s_entries[player];

      for (uint256 j = 0; j < winningNumbers.length; j++) {
        if (playerNumbers.contains(winningNumbers[j])) {
          hits++;
        }
      }

      s_hitMap[hits].push(player);
    }
  }

  function distributePrizePool(uint256[] memory winningNumbers) private {
    determineHitMap(winningNumbers);

    // Sum should be the whole balance
    // 5% + 10% + 20% + 65%
    uint256 unitReward = address(this).balance / 20;
    uint256 fourHitsReward = unitReward * 2;
    uint256 fiveHitsReward = unitReward * 4;
    uint256 sixHitsReward = unitReward * 13;

    payPlayers(s_hitMap[6], sixHitsReward);
    payPlayers(s_hitMap[5], fiveHitsReward);
    payPlayers(s_hitMap[4], fourHitsReward);
    payPlayers(s_hitMap[3], fourHitsReward);
  }

  function payPlayers(address[] memory players, uint256 amount) private {
    uint256 winAmount;

    if (players.length > 0) {
      winAmount = players.length / amount;

      for (uint256 i = 0; i < players.length; i++) {
        (bool success, ) = payable(players[i]).call{value: winAmount}("");

        if (!success) {
          revert Lottery6__TransferFailed(players[i]);
        }
      }
    }
  }

  function resetState() private {
    if (s_totalEntries > 0) {
      s_state = LotteryState.OPEN;
    } else {
      s_state = LotteryState.STANDBY;
    }
    s_draws++;
    s_lastTimestamp = block.timestamp;

    if (s_hitMap[6].length > 0) {
      resetPlayers();
    }

    for (uint256 i = 0; i < 7; i++) {
      delete s_hitMap[i];
    }
  }

  function resetPlayers() private {
    address[] memory players = s_players.values();

    for (uint256 i = 0; i < players.length; i++) {
      address player = players[i];

      s_players.remove(player);
      delete s_entries[player];
    }
  }

  function addHistoryEntry(
    uint256[] memory winningNumbers,
    address[][] memory results
  ) private {
    s_history.push(History(winningNumbers, results));
  }

  /* View Functions */
  function getLastDrawTimestamp() public view returns (uint256) {
    return s_lastTimestamp;
  }

  function getState() public view returns (uint256) {
    return uint256(s_state);
  }

  function getPlayers() public view returns (address[] memory) {
    return s_players.values();
  }

  function getHistory() public view returns (History[] memory) {
    History[] memory history = new History[](s_draws);

    for (uint256 i = 0; i < history.length; i++) {
      History storage item = s_history[i];
      history[i] = item;
    }

    return history;
  }

  function getPlayerNumbers(address player)
    public
    view
    returns (uint256[] memory)
  {
    return s_entries[player];
  }

  function getNumberCount() public view returns (uint256) {
    return i_numberCount;
  }

  function getNumberOfDraws() public view returns (uint256) {
    return s_draws;
  }

  function getDrawInterval() public view returns (uint256) {
    return i_interval;
  }
}
