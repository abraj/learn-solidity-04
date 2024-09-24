// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig, CodeConstants } from "./HelperConfig.s.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { LinkToken } from "test/mocks/LinkToken.sol";
import { DevOpsTools } from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
  function run() external {
    createSubscriptionUsingConfig();
  }

  function createSubscriptionUsingConfig() public returns (uint256) {
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
    address vrfCoordinator = networkConfig.vrfCoordinator;
    return createSubscription(vrfCoordinator, networkConfig.account);
  }

  function createSubscription(address vrfCoordinator, address account) public returns (uint256) {
    console.log("====> [createSubscription] chainId:", block.chainid);

    vm.startBroadcast(account);
    uint256 subsId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
    vm.stopBroadcast();

    console.log("====> subscriptionId:", subsId);
    return subsId;
  }
}

contract FundSubscription is Script, CodeConstants {
  uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

  function run() external {
    fundSubscriptionUsingConfig();
  }

  function fundSubscriptionUsingConfig() public {
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
    address vrfCoordinator = networkConfig.vrfCoordinator;
    uint256 subscriptionId = networkConfig.subscriptionId;
    address linkToken = networkConfig.link;
    return fundSubscription(vrfCoordinator, subscriptionId, linkToken, networkConfig.account);
  }

  function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
    console.log("====> [fundSubscription] chainId:", block.chainid);
    console.log("====> subscriptionId:", subscriptionId);
    console.log("====> vrfCoordinator:", vrfCoordinator);

    if (block.chainid == LOCAL_CHAIN_ID) {
      vm.startBroadcast();
      VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 100);
      vm.stopBroadcast();
    } else {
      vm.startBroadcast(account);
      LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
      vm.stopBroadcast();
    }
  }
}

contract AddConsumer is Script {
  function run() external {
    address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
    addConsumerUsingConfig(mostRecentlyDeployed);
  }

  function addConsumerUsingConfig(address mostRecentlyDeployed) public {
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
    uint256 subsId = networkConfig.subscriptionId;
    address vrfCoordinator = networkConfig.vrfCoordinator;
    addConsumer(mostRecentlyDeployed, vrfCoordinator, subsId, networkConfig.account);
  }

  function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subsId, address account) public {
    console.log("====> [addConsumer] chainId:", block.chainid);
    console.log("====> consumer:", contractToAddToVrf);
    console.log("====> subscriptionId:", subsId);
    console.log("====> vrfCoordinator:", vrfCoordinator);

    vm.startBroadcast(account);
    VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subsId, contractToAddToVrf);
    vm.stopBroadcast();
  }
}
