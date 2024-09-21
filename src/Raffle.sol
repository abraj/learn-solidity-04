// SPDX-License-Identifier: MIT
// pragma solidity 0.8.19;
pragma solidity 0.8.26; // Custom errors in `require()`

/**
 * @title A sample Raffle contract
 * @author abraj
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle {
  /* Errors */
  error Raffle__NotEnoughEthSent();

  uint256 private immutable i_entranceFee;

  constructor(uint256 entranceFee) {
    i_entranceFee = entranceFee;
  }

  function enterRaffle() public payable {
    // require(msg.value >= i_entranceFee, "Not enough ETH sent!");
    // if (msg.value < i_entranceFee) {
    //   revert Raffle__NotEnoughEthSent();
    // }
    require(msg.value >= i_entranceFee, Raffle__NotEnoughEthSent());
  }

  function pickWinner() public { }

  /**
   * Getter functions
   */
  function getEntranceFee() external view returns (uint256) {
    return i_entranceFee;
  }
}
