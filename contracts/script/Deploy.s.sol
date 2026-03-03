// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DiceFate} from "../src/DiceFate.sol";
import {MockVRFCoordinatorV2} from "../src/MockVRFCoordinatorV2.sol";

contract Deploy is Script {
    bytes32 public constant KEY_HASH = keccak256(abi.encode("key"));
    uint64 public constant SUB_ID = 1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock VRF coordinator
        MockVRFCoordinatorV2 mockVRF = new MockVRFCoordinatorV2();

        // Deploy DiceFate
        DiceFate diceFate = new DiceFate(address(mockVRF), KEY_HASH, SUB_ID);

        // Fund the house with 100 ETH
        diceFate.depositHouse{value: 100 ether}();

        vm.stopBroadcast();

        // Log deployed addresses
        vm.serializeAddress(
            "contracts",
            "MockVRFCoordinatorV2",
            address(mockVRF)
        );
        vm.serializeAddress("contracts", "DiceFate", address(diceFate));
    }
}
