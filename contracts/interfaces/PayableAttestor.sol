// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

abstract contract PayableAttestor {
    error InsufficientFee();
    error WithdrawAddressNotSet();

    /// @notice Emitted when a fee is set.
    /// @param id The id of the attestation.
    /// @param fee The fee to be set.
    event FeeSet(uint256 id, uint256 fee);

    address public _withdrawAddress;

    mapping(uint256 => uint256) public _fees;

    /// @notice Modifier to check if the fee is sufficient.
    /// @param id The id of the attestation.
    modifier feeCheck(uint256 id) {
        if (msg.value < _fees[id]) revert InsufficientFee();
        _;
    }

    ///@notice Constructor sets the withdraw address.
    constructor(address withdrawAddress) {
        _withdrawAddress = withdrawAddress;
    }

    ///@notice Sets the withdraw address.
    ///@param withdrawAddress The address to withdraw to.
    function setWithdrawAddress(address withdrawAddress) external virtual;

    ///@notice Sets the fee for a attestation.
    ///@param id The id of the attestation.
    ///@param fee The fee to be set.
    function setFee(uint256 id, uint256 fee) external virtual;

    ///@notice Withdraws the funds to the withdraw address.
    function withdraw() external virtual;
}
