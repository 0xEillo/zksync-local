// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interfaces/IAttestations.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// _________ .__  .__                                    _____ __________
// \_   ___ \|  | |__| ________ __   ____               /  _  \\______   \
// /    \  \/|  | |  |/ ____/  |  \_/ __ \    ______   /  /_\  \|       _/
// \     \___|  |_|  < <_|  |  |  /\  ___/   /_____/  /    |    \    |   \
//  \______  /____/__|\__   |____/  \___  >           \____|__  /____|_  /
//         \/            |__|           \/                    \/       \/

/// @title CliqueAttestationsRegistry
/// @author Clique
/// @custom:coauthor Ollie (eillo.eth)
contract CliqueAttestationsRegistry is IAttestations, ERC1155, AccessControl {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ROLE CONSTANTS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    mapping(address => mapping(uint256 => Attestation)) public _attestations;
    mapping(uint256 => string) public _schemas;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Restricts function callers to attestation holder or admin.
    /// @param account The account of the function caller.
    /// @param id The id of the attestation.
    modifier onlyHolderOrOwner(address account, uint256 id) {
        // function caller must be the account and an attestation owner, or admin.
        if (
            (msg.sender != account || ownerOf(msg.sender, id) == false) &&
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) == false
        ) {
            revert AccessRestricted(msg.sender);
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 CONSTRUCTOR & INITIALIZER                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor() ERC1155("") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ATTESTOR_ROLE, msg.sender);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EXTERNAL FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Sets the URI, following ERC1155 standard.
    /// @param uri The URI to be set.
    function setURI(string memory uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(uri);
    }

    /// @inheritdoc IAttestations
    function attest(
        address account,
        uint256 id,
        Attestation memory attestation
    ) external override onlyRole(ATTESTOR_ROLE) {
        if (ownerOf(account, id)) revert AlreadyAttested(account, id);
        if (!eq(attestation.schema, _schemas[id])) revert InvalidSchema();

        _attestations[account][id] = attestation;
        _mint(account, id, 1, "");
        emit UpdateAttestation(account, id, attestation);
    }

    /// @inheritdoc IAttestations
    function update(
        address account,
        uint256 id,
        uint64 expirationDate,
        string memory attestationURL
    ) external override onlyRole(ATTESTOR_ROLE) {
        if (!ownerOf(account, id)) revert NotAttestationOwner();

        Attestation memory attestation = _attestations[account][id];
        attestation.expirationDate = expirationDate;
        attestation.attestationURL = attestationURL;
        emit UpdateAttestation(account, id, attestation);
    }

    /// @inheritdoc IAttestations
    function revoke(
        address account,
        uint256 id
    ) external override onlyHolderOrOwner(account, id) {
        if (!ownerOf(account, id)) revert NotAttestationOwner();

        _attestations[account][id].revoked = true;
        _burn(account, id, 1);
        emit UpdateAttestation(account, id, _attestations[account][id]);
    }

    /// @inheritdoc IAttestations
    function setSchema(
        uint256 id,
        string memory schema
    ) external onlyRole(ATTESTOR_ROLE) {
        _schemas[id] = schema;
        emit UpdateSchema(id, schema);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PUBLIC FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IAttestations
    function ownerOf(
        address account,
        uint256 tokenId
    ) public view override returns (bool) {
        return balanceOf(account, tokenId) != 0;
    }

    /// @notice checks if an attestation is expired.
    /// @param account The account of the attestation owner.
    /// @param id The id of the attestation.
    function isExpired(address account, uint256 id) public view returns (bool) {
        uint256 expirationDate = _attestations[account][id].expirationDate;
        if (expirationDate == 0) return false;
        return block.timestamp > expirationDate;
    }

    /// @notice checks if an attestation with the given account and id is revoked.
    /// @param account The account of the attestation owner.
    /// @param id The id of the attestation.
    function isRevoked(address account, uint256 id) public view returns (bool) {
        return _attestations[account][id].revoked;
    }

    // @notice attetation is non-transferable
    function setApprovalForAll(
        address operator,
        bool approved
    ) public view virtual override {
        revert Soulbound();
    }

    // @notice attestation is non-transferable
    function isApprovedForAll(
        address account,
        address operator
    ) public view virtual override returns (bool) {
        revert Soulbound();
    }

    /// @inheritdoc ERC1155
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns whether `a` equals `b`.
    function eq(
        string memory a,
        string memory b
    ) internal pure returns (bool result) {
        assembly {
            result := eq(
                keccak256(add(a, 0x20), mload(a)),
                keccak256(add(b, 0x20), mload(b))
            )
        }
    }

    // @notice attestation is non-transferable
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        if (!(from == address(0) || to == address(0))) revert Soulbound();
    }

    /// @notice Emits Attest event when a attestation is minted and Revoke when it
    ///         is burned.
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        if (from == address(0)) {
            emit Attest(to, ids[0]);
        }
        if (to == address(0)) {
            emit Revoke(address(0), ids[0]);
        }
    }
}
