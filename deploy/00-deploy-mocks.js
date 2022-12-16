const { developmentChains } = require("../helper-hardhat-config")

/**
 * @dev https://docs.chain.link/vrf/v2/subscription/supported-networks
 * use this link to get VRF  address. Base fee is given as the premium
 * fee (0.25 Link) as of 12/12/2022
 */

const BASE_FEE = ethers.utils.parseEther("0.25") // It costs 0.25 LINK per request
const GAS_PRICE_LINK = 1e9 // LINK per gas. Calculated value based on the gas price of the chain.

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const args = [BASE_FEE, GAS_PRICE_LINK]

    if (developmentChains.includes(network.name)) {
        log("Local network detected! Deploying mocks...")
        // Deploy a mock vrf coordinator
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mocks deployed!")
        log("----------------------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
