// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract EscrowProxy is Ownable {
    uint256 private s_yapRequestCount;
    uint256 private s_rewardBufferTime;
    uint256 private s_feeBalance;
    address private kaitoTokenAddress;
    mapping(uint256 => YapRequest) private s_yapRequests;
    mapping(uint256 => address[]) private s_yap_winners;
    mapping(address => bool) private s_is_admin;
    mapping(uint256 => mapping(address => ApprovedWinner)) private s_yapWinnersApprovals;
    address private s_implementation;
    address private s_owner;

    struct YapRequest {
        uint256 yapId;
        address creator;
        uint256 budget;
        bool isActive;
    }

    struct ApprovedWinner {
        address winner;
        uint256 amount;
        uint256 approvalTime;
    }

    event Upgraded(address indexed implementation);

    error ImplementationRequired();
    error NotOwner();
    error InitializationFailed();

    constructor(
        address _implementation,
        address _kaitoAddress,
        address[] memory _admins,
        uint256 _bufferTime,
        uint256 _currentYapRequestCount
    ) Ownable(msg.sender) {
        if (_implementation == address(0)) {
            revert ImplementationRequired();
        }
        s_implementation = _implementation;
        s_owner = msg.sender;

        (bool success,) = _implementation.delegatecall(
            abi.encodeWithSignature(
                "initialize(address,address[],uint256,uint256)",
                _kaitoAddress,
                _admins,
                _bufferTime,
                _currentYapRequestCount
            )
        );

        if (!success) {
            revert InitializationFailed();
        }
    }

    function upgradeTo(address _newImplementation) external {
        if (msg.sender != s_owner) {
            revert NotOwner();
        }
        if (_newImplementation == address(0)) {
            revert ImplementationRequired();
        }
        s_implementation = _newImplementation;
        emit Upgraded(_newImplementation);
    }

    function get_implementation() external view returns (address) {
        return s_implementation;
    }

    fallback() external payable {
        address implementation = s_implementation;

        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
