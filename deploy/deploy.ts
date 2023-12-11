import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const safeVault = await deploy("SafeVault", {
    from: deployer,
    args: [
      process.env.USDC_ADDRESS,
      process.env.BUY_TAX_BPS,
      process.env.SELL_TAX_BPS,
      process.env.MANAGEMENT_ADDRESS,
      process.env.AI_FUND_ADDRESS,
    ],
    log: true,
  });

  console.log(`SafeVault contract: `, safeVault.address);
};
export default func;
func.id = "deploy_safe_vault"; // id required to prevent reexecution
func.tags = ["SafeVault"];
