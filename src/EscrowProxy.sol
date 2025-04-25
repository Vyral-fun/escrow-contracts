// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EscrowProxy
 * @dev This contract works as a proxy that delegates calls to an implementation contract.
 * Only the implementation address and proxy owner are stored here.
 */
contract EscrowProxy is Ownable {
    // keccak256("eip1967.proxy.implementation") - 1 = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    uint256[100] private __gap;

    event Upgraded(address indexed implementation);

    error ImplementationRequired();
    error InitializationFailed();
    error NotOwner();

    constructor(
        address _logicImplementation,
        address _kaitoAddress,
        address _usdtAddress,
        address _usdcAddress,
        address _uniswapFactory,
        address _uniswapRouter,
        address[] memory _admins,
        uint256 _currentYapRequestCount
    ) Ownable(msg.sender) {
        if (_logicImplementation == address(0)) {
            revert ImplementationRequired();
        }
        assembly {
            sstore(IMPLEMENTATION_SLOT, _logicImplementation)
        }

        (bool success,) = _logicImplementation.delegatecall(
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address[],uint256)",
                _usdcAddress,
                _usdtAddress,
                _kaitoAddress,
                _uniswapFactory,
                _uniswapRouter,
                _admins,
                _currentYapRequestCount
            )
        );

        if (!success) {
            revert InitializationFailed();
        }
    }

    function upgradeTo(address _newImplementation) external {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
        if (_newImplementation == address(0)) {
            revert ImplementationRequired();
        }
        assembly {
            sstore(IMPLEMENTATION_SLOT, _newImplementation)
        }
        emit Upgraded(_newImplementation);
    }

    function _implementation() internal view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }

    function get_implementation() external view returns (address) {
        return _implementation();
    }

    fallback() external payable {
        _delegate(_implementation());
    }

    function _delegate(address impl) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {
        _delegate(_implementation());
    }
}
