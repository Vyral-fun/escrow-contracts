// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title EscrowProxy
 * @dev This contract works as a proxy that delegates calls to an implementation contract.
 * Only the implementation address and proxy owner are stored here.
 */
contract EscrowProxy {
    // keccak256("eip1967.proxy.implementation") - 1 = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // keccak256("eip1967.proxy.admin") - 1 = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
    bytes32 internal constant PROXY_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    uint256[100] private __gap;

    event Upgraded(address indexed implementation);

    error ImplementationRequired();
    error InitializationFailed();

    constructor(
        address _logicImplementation,
        address _kaitoAddress,
        address[] memory _admins,
        uint256 _currentYapRequestCount
    ) {
        if (_logicImplementation == address(0)) {
            revert ImplementationRequired();
        }

        assembly {
            sstore(IMPLEMENTATION_SLOT, _logicImplementation)
        }
        assembly {
            sstore(PROXY_ADMIN_SLOT, caller())
        }

        (bool success,) = _logicImplementation.delegatecall(
            abi.encodeWithSignature(
                "initialize(address,address[],uint256,address)",
                _kaitoAddress,
                _admins,
                _currentYapRequestCount,
                msg.sender
            )
        );

        if (!success) {
            revert InitializationFailed();
        }
    }

    function upgradeTo(address _newImplementation) external onlyProxyAdmin {
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

    modifier onlyProxyAdmin() {
        require(msg.sender == _proxyAdmin(), "Not proxy admin");
        _;
    }

    function _proxyAdmin() public view returns (address admin_) {
        assembly {
            admin_ := sload(PROXY_ADMIN_SLOT)
        }
    }
}
