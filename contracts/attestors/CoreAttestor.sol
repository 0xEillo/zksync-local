// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CliqueAttestationsRegistry, Attestation} from "../AttestationsRegistry.sol";
import {PayableAttestor} from "./../interfaces/PayableAttestor.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "solmate/src/utils/MerkleProofLib.sol";

struct AirdropData {
    address receiver;
    uint64 expirationDate;
    string schema;
    string attestationURL;
    bytes32[] proof;
}

error InvalidSignature();
error IdHasNoRoot(uint256 id);
error InvalidSigner(address signer, address receiver);
error ReceiverNotOwner();
error InvalidData(
    address receiver,
    uint256 id,
    uint64 expirationDate,
    string attestationURL,
    bytes32[] proof
);

// _________                           _____   __    __                   __
// \_   ___ \  ___________   ____     /  _  \_/  |__/  |_  ____   _______/  |_  ___________
// /    \  \/ /  _ \_  __ \_/ __ \   /  /_\  \   __\   __\/ __ \ /  ___/\   __\/  _ \_  __ \
// \     \___(  <_> )  | \/\  ___/  /    |    \  |  |  | \  ___/ \___ \  |  | (  <_> )  | \/
//  \______  /\____/|__|    \___  > \____|__  /__|  |__|  \___  >____  > |__|  \____/|__|
//         \/                   \/          \/                \/     \/

contract CoreAttestor is AccessControl, Pausable, PayableAttestor {
    using ECDSA for bytes32;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    CliqueAttestationsRegistry public _attestationsRegistry;
    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");
    address public _relayer;

    mapping(uint256 => bytes32) public _roots;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when a merkle-root is set.
    /// @param id The id mapped to the root.
    /// @param root The new updated root.
    event RootSet(uint256 id, bytes32 root);

    ///@notice Emitted when a merkle-root is added.
    ///@param id The id mapped to the root.
    ///@param root The new added root.
    event RootAdded(uint256 id, bytes32 root);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Constructor sets the attestation address, id, and Access Roles.
    /// @param attestationsRegistry The address of the attestation.
    /// @param relayer The address of the relayer.
    /// @param withdrawAddress The address to withdraw fees to.
    constructor(
        address attestationsRegistry,
        address relayer,
        address withdrawAddress
    ) PayableAttestor(withdrawAddress) {
        _attestationsRegistry = CliqueAttestationsRegistry(
            attestationsRegistry
        );
        _relayer = relayer;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ATTESTOR_ROLE, msg.sender);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EXTERNAL FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Updates a merkle-root.
    /// @param id The id of the root to be updated.
    /// @param root The new root.
    function setRoot(
        uint256 id,
        bytes32 root
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _roots[id] = root;
        emit RootSet(id, root);
    }

    /// @notice Issues an attestation to a receiver.
    /// @param receiver The receiver of the attestation.
    /// @param id The id of the attestation.
    /// @param expirationDate The expiration date of the attestation.
    /// @param attestationURL The URL of the attestation.
    /// @param signature Message signed by the relayer off chain.
    function attestAttestation(
        address receiver,
        uint256 id,
        uint64 expirationDate,
        string calldata schema,
        string calldata attestationURL,
        bytes memory signature
    ) external payable whenNotPaused feeCheck(id) {
        if (msg.sender != receiver) revert InvalidSigner(msg.sender, receiver);

        bytes32 messageHash = keccak256(
            abi.encode(receiver, id, expirationDate, attestationURL)
        );
        if (messageHash.toEthSignedMessageHash().recover(signature) != _relayer)
            revert InvalidSignature();

        Attestation memory attestation = Attestation(
            schema,
            attestationURL,
            address(this),
            uint64(block.timestamp),
            expirationDate,
            false
        );

        _attestationsRegistry.attest(receiver, id, attestation);
    }

    /// @notice Updates the attestation URL of the provided receiver's attestation.
    /// @param receiver The address to receive the attestation.
    /// @param id The id of the attestation.
    /// @param expirationDate The expiration date of the attestation.
    /// @param attestationURL URL of the caller's updated credentials.
    /// @param signature Message signed by the relayer off chain.
    function updateAttestation(
        address receiver,
        uint256 id,
        uint64 expirationDate,
        string calldata attestationURL,
        bytes memory signature
    ) external payable whenNotPaused feeCheck(id) {
        if (!_attestationsRegistry.ownerOf(receiver, id))
            revert ReceiverNotOwner();
        if (msg.sender != receiver) revert InvalidSigner(msg.sender, receiver);

        bytes32 messageHash = keccak256(
            abi.encode(receiver, id, expirationDate, attestationURL)
        );
        if (messageHash.toEthSignedMessageHash().recover(signature) != _relayer)
            revert InvalidSignature();

        _attestationsRegistry.update(
            receiver,
            id,
            expirationDate,
            attestationURL
        );
    }

    /// @notice Aidrops SBTs to a list of receivers in the merkle-tree.
    /// @param leaves The list of attestation-data to be issued.
    function airdropAttestations(
        uint256 id,
        AirdropData[] calldata leaves
    ) external onlyRole(ATTESTOR_ROLE) whenNotPaused {
        if (_roots[id] == bytes32(0)) revert IdHasNoRoot(id);

        uint256 airdropLength = leaves.length;

        for (uint256 i = 0; i < airdropLength; ) {
            address receiver = leaves[i].receiver;
            uint64 expirationDate = leaves[i].expirationDate;
            string calldata attestationURL = leaves[i].attestationURL;

            Attestation memory attestation = Attestation(
                leaves[i].schema,
                attestationURL,
                address(this),
                uint64(block.timestamp),
                expirationDate,
                false
            );

            if (
                !_verify(
                    id,
                    _leaf(receiver, id, expirationDate, attestationURL),
                    leaves[i].proof
                )
            )
                revert InvalidData(
                    receiver,
                    id,
                    expirationDate,
                    attestationURL,
                    leaves[i].proof
                );

            _attestationsRegistry.attest(receiver, id, attestation);

            unchecked {
                ++i;
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PUBLIC FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // The owner can call this function to pause functions with "whenNotPaused" modifier.
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Sets the relayer address.
    /// @param relayer The address of the relayer.
    function setRelayer(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _relayer = relayer;
    }

    // The owner can call this function to unpause functions with "whenNotPaused" modifier.
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Constructs a merkle-tree leaf.
    /// @param receiver The receiver of the attestation.
    /// @param id The id of the attestation.
    /// @param attestationURL The attestationURL of the attestation.
    function _leaf(
        address receiver,
        uint256 id,
        uint64 expirationDate,
        string calldata attestationURL
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(receiver, id, expirationDate, attestationURL)
            );
    }

    /// @notice Verifies a given leaf is in the merkle-tree with the given root.
    function _verify(
        uint256 id,
        bytes32 leaf,
        bytes32[] calldata proof
    ) internal view returns (bool) {
        bytes32 root = _roots[id];
        return MerkleProofLib.verify(proof, root, leaf);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       PAYABLE ISSUER                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc PayableAttestor
    function setWithdrawAddress(
        address withdrawAddress
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _withdrawAddress = withdrawAddress;
    }

    /// @inheritdoc PayableAttestor
    function setFee(
        uint256 id,
        uint256 fee
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _fees[id] = fee;
    }

    /// @inheritdoc PayableAttestor
    function withdraw() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_withdrawAddress == address(0)) revert WithdrawAddressNotSet();
        (bool success, ) = payable(_withdrawAddress).call{
            value: address(this).balance
        }("");
        require(success, "Withdrawal failed");
    }
}
