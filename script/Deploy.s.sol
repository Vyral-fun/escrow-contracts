// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Escrow} from "../src/Escrow.sol";

contract DeployScript is Script {
    Escrow public escrow;
    address[] public admins = [0x47C14E2dD82B7Cf0E7426c991225417e4C40Cd19, 0x47C14E2dD82B7Cf0E7426c991225417e4C40Cd19];

    function setUp() public {}

    function run() public returns (Escrow) {
        vm.startBroadcast();
        address kaitoAddress = 0x47C14E2dD82B7Cf0E7426c991225417e4C40Cd19; // Change this
        escrow = new Escrow(kaitoAddress, admins);

        vm.stopBroadcast();

        return escrow;
    }
}
