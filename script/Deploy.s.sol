// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {EscrowLogic} from "../src/EscrowLogic.sol";
import {EscrowProxy} from "../src/EscrowProxy.sol";

contract DeployScript is Script {
    EscrowLogic public escrowLogic;
    EscrowProxy public escrowProxy;

    function setUp() public {}

    function run() public returns (EscrowProxy) {
        vm.startBroadcast();

        uint256 CURRENT_YAP_REQUEST_COUNT = 0;
        address[] memory admins = new address[](2);
        admins[0] = 0x47C14E2dD82B7Cf0E7426c991225417e4C40Cd19;
        admins[1] = 0x47C14E2dD82B7Cf0E7426c991225417e4C40Cd19;

        escrowLogic = new EscrowLogic();

        escrowProxy = new EscrowProxy(address(escrowLogic), admins, CURRENT_YAP_REQUEST_COUNT);

        console.log("EscrowLogic deployed at:", address(escrowLogic));
        console.log("EscrowProxy deployed at:", address(escrowProxy));

        vm.stopBroadcast();

        return escrowProxy;
    }
}
