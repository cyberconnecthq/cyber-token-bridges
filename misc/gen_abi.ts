import * as fs from "fs/promises";
import * as path from "path";

const writeAbi = async () => {
  const folders = [
    "CyberVault.sol/CyberVault.json",
    "CyberStakingPool.sol/CyberStakingPool.json",
    "CyberTokenAdapter.sol/CyberTokenAdapter.json",
    "CyberTokenController.sol/CyberTokenController.json",
    "LaunchTokenWithdrawer.sol/LaunchTokenWithdrawer.json",
    "RewardTokenWithdrawer.sol/RewardTokenWithdrawer.json",
    "CyberTokenDistributor.sol/CyberTokenDistributor.json",
  ];
  const ps = folders.map(async (file) => {
    const f = await fs.readFile(path.join("./out", file), "utf8");
    const json = JSON.parse(f);
    const fileName = path.parse(file).name;
    return fs.writeFile(
      path.join("docs/abi", `${fileName}.json`),
      JSON.stringify(json.abi)
    );
  });
  await Promise.all(ps);
};

const main = async () => {
  await writeAbi();
};

main()
  .then(() => {})
  .catch((err) => {
    console.error(err);
  });
