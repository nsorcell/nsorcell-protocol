// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Lottery6__NotOwner();
error Lottery6__PaymentNotEnough();
error Lottery6__EntryClosed();
error Lottery6__UpkeepUnnecessary(
  uint256 balance,
  uint256 playerCount,
  uint256 lotteryState
);
error Lottery6__NumbersNotDrawn();
error Lottery6__TransferFailed(address forPLayer);
error Lottery6__PlayerAlreadyEntered();

contract Lottery6 is VRFConsumerBaseV2, KeeperCompatibleInterface {
  /* Types */
  enum LotteryState {
    STANDBY,
    OPEN,
    DRAWING,
    CALCULATING
  }

  struct History {
    uint256[6] winningNumbers;
    address[] winners;
  }

  /* Constants */
  uint16 private constant REQUEST_CONFIRMATIONS = 3;

  /* Immutable State Variables */
  address private immutable i_owner;
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
  uint256 private s_totalRandomNumbers;
  address[] private s_players;
  mapping(address => uint256[6]) private s_entries;
  mapping(uint256 => bool) private s_numberDedup;
  History[] private s_history;
  LotteryState private s_state;

  /* Events */
  event Lottery6__Enter(address indexed player);
  event Lottery6__RequestedDraw(uint256 requestId);
  event Lottery6__Draw(uint256[6] indexed winningNumbers);
  event Lottery6__Winners(address[] indexed winners);
  event Lottery6__NoWinners();

  /* Modifiers */
  modifier onylOwner() {
    if (msg.sender != i_owner) {
      revert Lottery6__NotOwner();
    }
    _;
  }

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
    i_owner = msg.sender;

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
    bool hasPlayers = s_players.length > 0;
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
        s_players.length,
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
   @dev - 2. reset the @s_numberDedup variable after the picks
          are finished.
   @dev - 3. Sort the winningNumbers array
   @dev - 4. Iterate over all entries, and compare the sorted
          winningNumbers, with the number the players entered,
          and collect the winners into the winners array.
          (the player numbers must be already sorted)
   @dev - 5. Add the result of the draw to the @param s_history 
          variable.
   @dev - 6.a If the winners array is empty, there are no winners.
   @dev - 6.b If the winners array is not empty, distribute the 
          contract balance equally between them. 
   @dev - 7. Reset the store variables keeping track of everything.
   */
  function fulfillRandomWords(
    uint256, /* requestId */
    uint256[] memory randomWords
  ) internal override {
    uint256[6] memory winningNumbers;

    uint256 rndPicks = 0;
    uint256 nIndex = 0;

    while (rndPicks != 6) {
      uint256 number = randomWords[nIndex] % 45;

      if (s_numberDedup[number] == false) {
        winningNumbers[rndPicks] = number;
        s_numberDedup[number] = true;
        rndPicks++;
      }

      nIndex++;
    }

    winningNumbers = sort(winningNumbers);

    emit Lottery6__Draw(winningNumbers);

    s_state = LotteryState.CALCULATING;
    address[] memory winners;

    for (uint256 i = 0; i < s_totalEntries; i++) {
      address player = s_players[i];
      if (
        keccak256(abi.encode(winningNumbers)) ==
        keccak256(abi.encode(s_entries[player]))
      ) {
        winners[i] = s_players[i];
      }

      delete s_entries[player];
    }

    addHistoryEntry(winningNumbers, winners);

    uint256 winnerCount = winners.length;

    if (winnerCount > 0) {
      uint256 winAmount = address(this).balance / winnerCount;

      for (uint256 i = 0; i < winnerCount; i++) {
        (bool success, ) = payable(winners[i]).call{value: winAmount}("");

        if (!success) {
          revert Lottery6__TransferFailed(winners[i]);
        }
      }

      emit Lottery6__Winners(winners);
    } else {
      emit Lottery6__NoWinners();
    }

    s_totalRandomNumbers = nIndex;
    resetState(nIndex, rndPicks);
  }

  /**
    @notice Enter into the Lottery.
    @dev - The incoming array, which represents the players choices
           should be already sorted.
   */
  function enter(uint256[6] memory numbers) public payable {
    if (s_state != LotteryState.OPEN && s_state != LotteryState.STANDBY) {
      revert Lottery6__EntryClosed();
    }

    if (msg.value > i_entranceFee) {
      revert Lottery6__PaymentNotEnough();
    }

    if (
      keccak256(abi.encode(s_entries[msg.sender])) !=
      keccak256(abi.encode([0, 0, 0, 0, 0, 0]))
    ) {
      revert Lottery6__PlayerAlreadyEntered();
    }

    if (s_totalEntries == 0 && s_state == LotteryState.STANDBY) {
      s_state = LotteryState.OPEN;
    }

    s_entries[msg.sender] = numbers;
    s_players.push(payable(msg.sender));
    s_totalEntries++;

    emit Lottery6__Enter(msg.sender);
  }

  function forceReset() public onylOwner {
    address[] memory players = s_players;
    bool transferSucceeded = true;
    for (uint256 i = 0; i < players.length; i++) {
      (bool success, ) = payable(players[i]).call{value: i_entranceFee}("");

      if (!success) {
        revert Lottery6__TransferFailed(players[i]);
      }
    }

    if (transferSucceeded) {
      resetState(s_totalRandomNumbers, 6);
    }
  }

  function resetState(uint256 totalRandomNumbers, uint256 picksCount) private {
    for (uint256 i = 0; i < totalRandomNumbers - picksCount; i++) {
      delete s_numberDedup[i];
    }

    for (uint256 i = 0; i < s_totalEntries; i++) {
      address player = s_players[i];

      delete s_entries[player];
    }

    delete s_players;
    s_state = LotteryState.STANDBY;
    s_draws++;
    s_lastTimestamp = block.timestamp;
    s_totalEntries = 0;
    s_totalRandomNumbers = 0;
  }

  function addHistoryEntry(
    uint256[6] memory winningNumbers,
    address[] memory winners
  ) private {
    s_history.push(History(winningNumbers, winners));
  }

  /* View Functions */
  function getLastDrawTimestamp() public view returns (uint256) {
    return s_lastTimestamp;
  }

  function getState() public view returns (uint256) {
    return uint256(s_state);
  }

  function getPlayers() public view returns (address[] memory) {
    return s_players;
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
    returns (uint256[6] memory)
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

  function sort(uint256[6] memory data)
    public
    pure
    returns (uint256[6] memory)
  {
    quickSort(data, int256(0), int256(data.length - 1));
    return data;
  }

  function quickSort(
    uint256[6] memory arr,
    int256 left,
    int256 right
  ) private pure {
    int256 i = left;
    int256 j = right;
    if (i == j) return;
    uint256 pivot = arr[uint256(left + (right - left) / 2)];
    while (i <= j) {
      while (arr[uint256(i)] < pivot) i++;
      while (pivot < arr[uint256(j)]) j--;
      if (i <= j) {
        (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
        i++;
        j--;
      }
    }
    if (left < j) quickSort(arr, left, j);
    if (i < right) quickSort(arr, i, right);
  }
}
