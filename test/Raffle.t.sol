// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Raffle } from "src/Raffle.sol";
import { DeployRaffle } from "script/Raffle.s.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
  Raffle private raffle;
  HelperConfig private helperConfig;

  uint256 private entranceFee;
  uint256 private interval;
  address private vrfCoordinator;
  bytes32 private gasLane;
  uint32 private callbackGasLimit;
  uint256 private subscriptionId;

  address public PLAYER = makeAddr("player");
  uint256 public constant PLAYER_STARTING_BALANCE = 10 ether;

  // NOTE: Duplicated from Raffle.sol (so, keep in sync)
  event RaffleEntered(address indexed player);
  event RequestedRaffleWinner(uint256 indexed requestId);
  event WinnerPicked(address indexed recentWinner);

  function setUp() external {
    DeployRaffle deployRaffle = new DeployRaffle();
    (raffle, helperConfig) = deployRaffle.run();

    HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
    entranceFee = config.entranceFee;
    interval = config.interval;
    vrfCoordinator = config.vrfCoordinator;
    gasLane = config.gasLane;
    callbackGasLimit = config.callbackGasLimit;
    subscriptionId = config.subscriptionId;

    vm.deal(PLAYER, PLAYER_STARTING_BALANCE);
  }

  function test_InitializesInOpenState() public view {
    assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
  }

  function test_InsufficientEntranceFee() public {
    // Arrange
    vm.prank(PLAYER);

    // Act/Assert
    vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
    raffle.enterRaffle();
  }

  function test_RecordsPlayersWhenTheyEnter() public {
    // Arrange
    vm.prank(PLAYER);

    // Act
    raffle.enterRaffle{ value: entranceFee }();

    // Assert
    address playerRecorded = raffle.getPlayer(0);
    assert(playerRecorded == PLAYER);
  }

  function test_EnteringRaffleEmitsEvent() public {
    // Arrange
    vm.prank(PLAYER);

    // Act/Assert
    vm.expectEmit(true, false, false, false, address(raffle));
    emit RaffleEntered(PLAYER);
    raffle.enterRaffle{ value: entranceFee }();
  }

  modifier raffleEntered() {
    vm.prank(PLAYER);
    raffle.enterRaffle{ value: entranceFee }();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    _;
  }

  function test_DontAllowEntranceDuringCalculatingState() public raffleEntered {
    // Arrange
    // [modifier] raffleEntered
    // vm.prank(PLAYER);  // not required
    raffle.performUpkeep("");

    // Act/Assert
    vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
    vm.prank(PLAYER);
    raffle.enterRaffle{ value: entranceFee }();
  }

  function test_CheckUpkeepReturnsFalseIfRaffleHasNoBalance() public {
    // Arrange
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);

    // Act
    (bool upkeepNeeded,) = raffle.checkUpkeep("");

    // Assert
    assert(!upkeepNeeded);
  }

  function test_CheckUpkeepReturnsFalseIfRaffleIsntOpen() public raffleEntered {
    // Arrange
    // [modifier] raffleEntered
    // vm.prank(PLAYER);  // not required
    raffle.performUpkeep("");

    // Act
    (bool upkeepNeeded,) = raffle.checkUpkeep("");

    // Assert
    assert(!upkeepNeeded);
  }

  function test_CheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{ value: entranceFee }();

    // Act
    (bool upkeepNeeded,) = raffle.checkUpkeep("");

    // Assert
    assert(!upkeepNeeded);
  }

  function test_CheckUpkeepReturnsTrueWhenParametersAreGood() public raffleEntered {
    // Arrange
    // [modifier] raffleEntered

    // Act
    (bool upkeepNeeded,) = raffle.checkUpkeep("");

    // Assert
    assert(upkeepNeeded);
  }

  function test_PerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {
    // Arrange
    // [modifier] raffleEntered

    // [Optional]
    (bool upkeepNeeded,) = raffle.checkUpkeep("");
    assert(upkeepNeeded);

    // Act / Assert
    raffle.performUpkeep("");
  }

  function test_PerformUpkeepRevertsIfCheckUpkeepIsFalse1() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{ value: entranceFee }();

    string memory tag = "0111";
    uint256 raffleState = 0;
    uint256 balance = 0.01 ether;
    uint256 playersLength = 1;

    // Act / Assert
    vm.expectRevert(
      abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, tag, raffleState, balance, playersLength)
    );
    raffle.performUpkeep("");
  }

  function test_PerformUpkeepRevertsIfCheckUpkeepIsFalse2() public {
    // Arrange
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);

    string memory tag = "1100";
    uint256 raffleState = 0;
    uint256 balance = 0;
    uint256 playersLength = 0;

    // Act / Assert
    vm.expectRevert(
      abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, tag, raffleState, balance, playersLength)
    );
    raffle.performUpkeep("");
  }

  function test_PerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
    // Arrange
    // [modifier] raffleEntered

    // Act
    vm.recordLogs();
    raffle.performUpkeep("");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory logEntry;
    for (uint256 i = 0; i < entries.length; i++) {
      if (entries[i].emitter == address(raffle)) {
        logEntry = entries[i];
        break;
      }
    }
    bytes32 requestId = logEntry.topics[1];

    // Assert
    assert(uint256(requestId) > 0);
    assert(raffle.getRecentRequestId() == uint256(requestId));
    assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
  }

  // Stateless fuzz test
  function test_FulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
    // Arrange
    // [modifier] raffleEntered

    // Act / Assert
    vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle) /*consumer*/ );
  }

  function test_FulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered {
    // Arrange
    // [modifier] raffleEntered
    uint256 additionalEntrants = 3; // 4 total
    uint256 startingIndex = 1; // starts with 1 to avoid address(0)
    address expectedWinner = address(1); // (pre-computed) based on <mock_random_number> and 4 entrants

    for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
      address newPlayer = address(uint160(i));
      hoax(newPlayer, 1 ether); // vm.prank() + vm.deal()
      raffle.enterRaffle{ value: entranceFee }();
    }
    uint256 startingTimestamp = raffle.getLastTimestamp();
    uint256 winnerStartingBalance = expectedWinner.balance;

    // Act
    vm.recordLogs();
    raffle.performUpkeep("");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory logEntry;
    for (uint256 i = 0; i < entries.length; i++) {
      if (entries[i].emitter == address(raffle)) {
        logEntry = entries[i];
        break;
      }
    }
    bytes32 requestId = logEntry.topics[1];

    // Alternatively:
    // uint256 requestId = raffle.getRecentRequestId();

    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle) /*consumer*/ );

    // Assert
    uint256 recentRandomNumber = raffle.getRecentRandomNumber();
    address recentWinner = raffle.getRecentWinner();
    uint256 endingTimestamp = raffle.getLastTimestamp();

    // NOTE: prize may be greater, in case someone pays more than entry price
    uint256 prize = entranceFee * (additionalEntrants + 1);

    assert(recentRandomNumber > 0);
    assert(recentWinner == expectedWinner);
    assert(recentWinner.balance >= winnerStartingBalance + prize);
    assert(endingTimestamp > startingTimestamp);

    assert(raffle.getPlayersLength() == 0);
    assert(raffle.getRecentRequestId() == 0);
    assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
  }
}
