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

        address UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        address UNISWAP_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
        address kaitoAddress = 0x98d0baa52b2D063E780DE12F615f963Fe8537553;
        address usdtAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        uint256 CURRENT_YAP_REQUEST_COUNT = 0;
        address[] memory admins = new address[](2);
        admins[0] = 0x47C14E2dD82B7Cf0E7426c991225417e4C40Cd19;
        admins[1] = 0x47C14E2dD82B7Cf0E7426c991225417e4C40Cd19;

        escrowLogic = new EscrowLogic();

        escrowProxy = new EscrowProxy(
            address(escrowLogic),
            kaitoAddress,
            usdtAddress,
            usdcAddress,
            UNISWAP_V2_FACTORY,
            UNISWAP_V2_ROUTER,
            admins,
            CURRENT_YAP_REQUEST_COUNT
        );

        console.log("EscrowLogic deployed at:", address(escrowLogic));
        console.log("EscrowProxy deployed at:", address(escrowProxy));

        vm.stopBroadcast();

        return escrowProxy;
    }
}
