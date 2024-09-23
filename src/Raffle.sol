// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
// pragma solidity 0.8.26; // Custom errors in `require()`

import { VRFConsumerBaseV2Plus } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import { VRFV2PlusClient } from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import { Utils } from "./Utils.sol";

/**
 * @title A sample Raffle contract
 * @author abraj
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
  /* Errors */
  error Raffle__NotEnoughEthSent();
  error Raffle__TransferFailed();
  error Raffle__RaffleNotOpen();
  error Raffle__NoBalance();
  error Raffle__NoPlayers();
  error Raffle__UpkeepNotNeeded(string tag, uint256 raffleState, uint256 balance, uint256 playersLength);

  /* Type declarations */
  enum RaffleState {
    OPEN, // 0
    CALCULATING // 1

  }

  /* State variables */
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_WORDS = 1;
  bool private constant ENABLE_NATIVE_PAYMENT = false;

  uint256 private immutable i_entranceFee;
  // @dev The duration of the lottery in seconds
  uint256 private immutable i_interval;
  // @dev see https://docs.chain.link/docs/vrf/v2-5/supported-networks
  bytes32 private immutable i_keyHash;
  uint256 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;

  address payable[] private s_players;
  uint256 private s_lastTimestamp;
  uint256 private s_recentRequestId;
  address private s_recentWinner;
  RaffleState private s_raffleState;

  /* Events */
  event RaffleEntered(address indexed player);
  event RequestedRaffleWinner(uint256 indexed requestId);
  event WinnerPicked(address indexed recentWinner);

  // gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae
  // callbackGasLimit = 100000
  constructor(
    uint256 entranceFee,
    uint256 interval,
    address vrfCoordinator,
    bytes32 gasLane,
    uint32 callbackGasLimit,
    uint256 subscriptionId
  ) VRFConsumerBaseV2Plus(vrfCoordinator) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    i_keyHash = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;

    s_lastTimestamp = block.timestamp;
    s_raffleState = RaffleState.OPEN;
  }

  function enterRaffle() external payable {
    // Checks
    // require(msg.value >= i_entranceFee, "Not enough ETH sent!");
    // require(msg.value >= i_entranceFee, Raffle__NotEnoughEthSent());
    if (msg.value < i_entranceFee) {
      revert Raffle__NotEnoughEthSent();
    }
    if (s_raffleState != RaffleState.OPEN) {
      revert Raffle__RaffleNotOpen();
    }

    // Effects
    s_players.push(payable(msg.sender));
    emit RaffleEntered(msg.sender);
  }

  function pickWinner() internal {
    // Checks
    // Already performed in performUpkeep()

    // Effects
    s_raffleState = RaffleState.CALCULATING;

    // Interactions
    // Get a random number
    // Will revert if subscription is not set and funded.
    uint256 requestId = s_vrfCoordinator.requestRandomWords(
      VRFV2PlusClient.RandomWordsRequest({
        keyHash: i_keyHash,
        subId: i_subscriptionId,
        requestConfirmations: REQUEST_CONFIRMATIONS,
        callbackGasLimit: i_callbackGasLimit,
        numWords: NUM_WORDS,
        extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: ENABLE_NATIVE_PAYMENT }))
      })
    );

    s_recentRequestId = requestId;
    // Redundant, since `VRFCoordinatorV2_5Mock` anyways emits `RandomWordsRequested` event
    emit RequestedRaffleWinner(requestId);
  }

  function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
    // Checks
    // NOTE: `assert` consumes all remaining gas if it fails
    assert(s_recentRequestId == requestId);
    assert(block.timestamp - s_lastTimestamp >= i_interval);
    assert(s_raffleState == RaffleState.OPEN);
    assert(address(this).balance > 0);
    assert(s_players.length > 0);

    // Effects
    uint256 randomNumber = randomWords[0];
    uint256 winnerIndex = randomNumber % s_players.length;
    address payable recentWinner = s_players[winnerIndex];
    s_recentWinner = recentWinner;
    s_players = new address payable[](0);
    s_lastTimestamp = block.timestamp;
    s_raffleState = RaffleState.OPEN;
    emit WinnerPicked(recentWinner);

    // Interactions
    (bool success,) = recentWinner.call{ value: address(this).balance }("");
    if (!success) {
      revert Raffle__TransferFailed();
    }
  }

  /**
   * @dev This is the function that chainlink will call to see if the
   * lottery is ready to have a winner picked.
   * The following should be true in order for upkeepNeeded to be true:
   * 1. The time interval has passed before raffle runs
   * 2. The lottery is open
   * 3. The contract has ETH (has players)
   * 4. Implicitly, your subscription has LINK
   * @param - ignored
   * @return upkeepNeeded - true if it's time to restart the lottery
   * @return - (upkeepNeeded,)
   */
  function checkUpkeep(bytes memory /* checkData */ )
    public
    view
    returns (bool upkeepNeeded, bytes memory /* performData */ )
  {
    bool timeHasPassed = (block.timestamp - s_lastTimestamp) >= i_interval;
    bool isOpen = s_raffleState == RaffleState.OPEN;
    bool hasBalance = address(this).balance > 0;
    bool hasPlayers = s_players.length > 0;
    upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
    return (upkeepNeeded, "");
  }

  function performUpkeep(bytes calldata /* performData */ ) external {
    // Checks
    (bool upkeepNeeded,) = checkUpkeep("");
    if (!upkeepNeeded) {
      bool timeHasPassed = (block.timestamp - s_lastTimestamp) >= i_interval;
      bool isOpen = s_raffleState == RaffleState.OPEN;
      bool hasBalance = address(this).balance > 0;
      bool hasPlayers = s_players.length > 0;
      Utils utils = new Utils();
      string[] memory args = new string[](4);
      args[0] = utils.boolToString(timeHasPassed);
      args[1] = utils.boolToString(isOpen);
      args[2] = utils.boolToString(hasBalance);
      args[3] = utils.boolToString(hasPlayers);
      string memory tag = utils.concatenateStrings(args);

      revert Raffle__UpkeepNotNeeded(tag, uint256(s_raffleState), address(this).balance, s_players.length);
    }

    // Effects
    pickWinner();
  }

  /**
   * Getter functions
   */
  function getEntranceFee() external view returns (uint256) {
    return i_entranceFee;
  }

  function getRaffleState() external view returns (RaffleState) {
    return s_raffleState;
  }

  function getPlayer(uint256 index) external view returns (address) {
    return s_players[index];
  }

  function getRecentRequestId() external view returns (uint256) {
    return s_recentRequestId;
  }
}
