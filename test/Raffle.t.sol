// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";
import { Raffle } from "src/Raffle.sol";
import { DeployRaffle } from "script/Raffle.s.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";

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

  function test_DontAllowEntranceDuringCalculatingState() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{ value: entranceFee }();

    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    vm.prank(PLAYER);
    raffle.performUpkeep("");

    // Act/Assert
    vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
    vm.prank(PLAYER);
    raffle.enterRaffle{ value: entranceFee }();
  }
}
