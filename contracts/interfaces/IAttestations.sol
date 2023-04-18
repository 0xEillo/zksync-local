// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                            TYPES                           */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
struct Attestation {
    string schema;
    string attestationURL;
    address attestor;
    uint64 attestedDate;
    uint64 expirationDate;
    bool revoked;
}

/// @title IAttestations
/// @author Clique
/// @custom:coauthor Ollie (eillo.eth)
interface IAttestations {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error Soulbound();
    error AlreadyAttested(address account, uint256 id);
    error AccessRestricted(address account);
    error NotAttestationOwner();
    error InvalidSchema();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev This emits when a new attestation is attested.
    event Attest(address indexed to, uint256 indexed id);

    /// @dev This emits when an existing attestation is revoked from an account and
    /// burnt.
    event Revoke(address indexed to, uint256 indexed id);

    /// @dev This emits when updating the attestation URL of an attestation.
    /// @param account The account that owns the attestation.
    /// @param id The id of the SBT.
    /// @param attestation The new attestation attestation.
    event UpdateAttestation(
        address indexed account,
        uint256 indexed id,
        Attestation attestation
    );

    /// @dev This emits when updating the schema of attestations.
    /// @param id The id of the attestations.
    /// @param schema The new schema.
    event UpdateSchema(uint256 indexed id, string schema);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EXTERNAL FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Attests an attestation with the given id to the given account.
    /// @param account The account to issue the attestation to.
    /// @param id The id of the SBT being issued.
    /// @param attestation The attestation being attested.
    function attest(
        address account,
        uint256 id,
        Attestation memory attestation
    ) external;

    /// @notice Updates the attestation URL of an attestation.
    /// @param account The account that owns the attestation.
    /// @param id The id of the attestation to be updated.
    /// @param expirationDate The new expiration date of the attestation.
    /// @param attestationURL The new attestation URL.
    function update(
        address account,
        uint256 id,
        uint64 expirationDate,
        string memory attestationURL
    ) external;

    /// @notice Burns SBT with given id. At any time, an attestation.
    /// receiver must be able to disassociate themselves from an attestation.
    /// publicly through calling this function.
    /// @param account The address of the owner of the attestation.
    /// @param id The SBT id.
    function revoke(address account, uint256 id) external;

    /// @notice Sets a schema for attestations of id {id}. This allows for
    ///         standardized attestation values.
    /// @param id The id of the attestations.
    /// @param schema The schema of the attestations.
    function setSchema(uint256 id, string memory schema) external;

    /// @notice Checks if an account is an owner of a SBT.
    /// @param account The address of the owner.
    /// @param id The identifier for an attestation.
    /// @return The SBT id.
    function ownerOf(address account, uint256 id) external view returns (bool);
}
