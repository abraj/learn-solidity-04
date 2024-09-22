// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Script } from "forge-std/Script.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
  uint96 public MOCK_BASE_FEE = 0.25 ether;
  uint96 public MOCK_GAS_PRICE_LINK = 1e9;
  int256 public MOCK_WEI_PER_UINT_LINK = 4e15; // LINK / ETH price

  uint256 public constant LOCAL_CHAIN_ID = 31337;
  uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
}

contract HelperConfig is Script, CodeConstants {
  error HelperConfig__InvalidChainId();

  struct NetworkConfig {
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;
  }

  NetworkConfig public localNetworkConfig;
  mapping(uint256 chainId => NetworkConfig) public networkConfigs;

  constructor() {
    networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    // networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
  }

  function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
    if (networkConfigs[chainId].vrfCoordinator != address(0)) {
      return networkConfigs[chainId];
    } else if (chainId == LOCAL_CHAIN_ID) {
      return getOrCreateAnvilConfig();
    } else {
      revert HelperConfig__InvalidChainId();
    }
  }

  function getConfig() public returns (NetworkConfig memory) {
    return getConfigByChainId(block.chainid);
  }

  function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
    return NetworkConfig({
      entranceFee: 0.01 ether, // 1e16
      interval: 30, // 30 sec
      vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
      gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
      callbackGasLimit: 500000, // 500,000 gas
      subscriptionId: 0
    });
  }

  function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
    if (localNetworkConfig.vrfCoordinator != address(0)) {
      return localNetworkConfig;
    }

    // Deploy mock vrfCoordinator
    vm.startBroadcast();
    VRFCoordinatorV2_5Mock vrfCoordinatorMock =
      new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
    vm.stopBroadcast();

    localNetworkConfig = NetworkConfig({
      entranceFee: 0.01 ether, // 1e16
      interval: 30, // 30 sec
      vrfCoordinator: address(vrfCoordinatorMock),
      gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // doesn't matter
      callbackGasLimit: 500000, // 500,000 gas
      subscriptionId: 0
    });
    return localNetworkConfig;
  }
}
