import hre from "hardhat";
import { Wallet } from "zksync-web3";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

const main = async () => {
  const wallet = new Wallet(
    process.env.PRIVATE_KEYS || "" // env
  );
  const deployer = new Deployer(hre, wallet);

  console.log(deployer.zkWallet.address);

  console.log("<---------- Deploying AttestationsRegistry ---------->");

  const CliqueAttestationsRegistry = await deployer.loadArtifact(
    "CliqueAttestationsRegistry"
  );
  const attestationsRegistry = await deployer.deploy(
    CliqueAttestationsRegistry
  );

  console.log("AttestationsRegistry address", attestationsRegistry.address);

  console.log("<---------- Deploying CoreAttestor ---------->");
  const artifact = await deployer.loadArtifact("CoreAttestor");
  const coreAttestor = await deployer.deploy(artifact, [
    attestationsRegistry,
    "0x4401A1667dAFb63Cff06218A69cE11537de9A101",
    "0x4401A1667dAFb63Cff06218A69cE11537de9A101",
  ]);
  console.log("CoreAttestor address:", coreAttestor.address);
  console.log(
    "CoreAttestor relayer:",
    "0x4401A1667dAFb63Cff06218A69cE11537de9A101"
  );
  console.log(
    "CoreAttestor withdrawAddress:",
    "0x4401A1667dAFb63Cff06218A69cE11537de9A101"
  );
};
main();
