import keccak256 from "keccak256";
import { expect } from "chai";
import { Wallet, Provider, Contract } from "zksync-web3";
import * as hre from "hardhat";
import { ethers } from "ethers";

import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

const RICH_WALLET_PK =
  "0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110";

async function deployAR(deployer: Deployer): Promise<Contract> {
  const CliqueAttestationsRegistry = await deployer.loadArtifact(
    "CliqueAttestationsRegistry"
  );
  return await deployer.deploy(CliqueAttestationsRegistry);
}
async function deployCA(
  deployer: Deployer,
  attestationsRegistry: string
): Promise<Contract> {
  const artifact = await deployer.loadArtifact("CoreAttestor");
  return await deployer.deploy(artifact, [
    attestationsRegistry,
    "0x4401a1667dafb63cff06218a69ce11537de9a101",
    "0x4401a1667dafb63cff06218a69ce11537de9a101",
  ]);
}

describe("Contract-Testing", function () {
  // Test case to ensure proper deployment of contracts and issuance of attestations to a receiver
  it("Should deploy contracts and issue attestations to a receiver", async function () {
    // Set up Ethereum provider
    const provider = Provider.getDefaultProvider();

    // Create wallet with a predefined private key
    const wallet = new Wallet(RICH_WALLET_PK, provider);
    const deployer = new Deployer(hre, wallet);

    // Deploy Attestation Registry (AR) and Core Attestor (CA) contracts
    const ar = await deployAR(deployer);
    const ca = await deployCA(deployer, ar.address);

    // Get the ATTESTOR_ROLE identifier
    const attestor_role = await ar.ATTESTOR_ROLE();

    // Set the relayer address for the Core Attestor contract
    const relayer = await ca.setRelayer(deployer.zkWallet.address);
    await relayer.wait();

    // Set the fee for the attestation
    const fee = await ca.setFee(1, ethers.utils.parseEther("1"));
    await fee.wait();

    // Grant the ATTESTOR_ROLE to the Core Attestor contract
    const tx1 = await ar.grantRole(attestor_role, ca.address);
    await tx1.wait();

    // Set the schema for the attestation
    const tx2 = await ar.setSchema(1, "test");
    await tx2.wait();

    // Generate a signature for the attestation
    const signature = await getSignature(
      deployer.zkWallet,
      deployer.zkWallet.address,
      1,
      0,
      "test"
    );

    // Issue the attestation using the Core Attestor contract
    const tx3 = await ca.attestAttestation(
      deployer.zkWallet.address,
      1,
      0,
      "test",
      "test",
      signature,
      { value: ethers.utils.parseEther("1") }
    );
    await tx3.wait();

    // Retrieve the attestation from the Attestation Registry contract
    const attestation = await ar._attestations(deployer.zkWallet.address, 1);

    // Check if the attestation URL matches the expected value
    expect(attestation.attestationURL).to.equal("test");
  });
});

async function getSignature(
  signer: Wallet,
  receiver: string,
  id: number,
  expirationDate: number,
  url: string
) {
  let messageHash = keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["address", "uint256", "uint64", "string"],
      [receiver, id, expirationDate, url]
    )
  );
  const signature = await signer.signMessage(messageHash);
  return signature;
}
