const fs = require("fs")
const path = require("path")
require("@nomiclabs/hardhat-etherscan")
require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("solidity-coverage")
require('hardhat-abi-exporter')


const low = require("lowdb")
const FileSync = require("lowdb/adapters/FileSync")

const secret = JSON.parse(fs.readFileSync(path.resolve("secret-release.json"), "utf8"))

extendEnvironment(hre => {
    const adapter = new FileSync(path.resolve(`deployed-${hre.network.name}.json`))
    const db = low(adapter)

    hre.capitalize = string => {
        return string.charAt(0).toLowerCase() + string.slice(1)
    }

    hre.wait = async ms => {
        return new Promise(resolve => setTimeout(() => resolve(), ms))
    }

    hre.saving = (key, address, args) => {
        db.set(key, {
            address: address,
            arguments: args || []
        }).write()
    }

    hre.get = key => {
        return db.get(key).value()
    }

    hre.insert = (key, value) => {
        db.set(`${key}`, value).write()
    }

    hre.verified = key => {
        db.set(`${key}.verify`, true).write()
    }

    hre.deployNetworks = {
        mainnet: { enabled: hre.network.name == `mainnet` ? true : false, chainId: 1 },
        ropsten: { enabled: hre.network.name == `ropsten` ? true : false, chainId: 3 },
        rinkeby: { enabled: hre.network.name == `rinkeby` ? true : false, chainId: 4 }
    }

    hre.currentNetwork = hre.deployNetworks[hre.network.name]
    hre.now = Math.floor((new Date()).getTime() / 1000)


    hre.deployer = async () => {
        const [owner] = await hre.ethers.getSigners()

        return owner.address
    }

    hre.multiSigOwner = secret.multiSigOwner
    hre.teamAddress = secret.teamAddress
    hre.proxyAdmin = secret.proxyAdmin

    hre.deploy = async (contractName, saveName, args) => {

        const contract = await hre.ethers.getContractFactory(contractName)

        let instance

        if (args != undefined)
            instance = await contract.deploy(...args).catch(why => console.log(why))
        else
            instance = await contract.deploy().catch(why => console.log(why))

        console.log(`👉 Processing ${contractName} - ${saveName} - ${instance.deployTransaction.hash}`)

        await instance.deployed().then(receipt => {
            hre.saving(saveName, instance.address, args || [])
        }).catch(why => console.log(why))

        return instance
    }

    hre.simpleDeploy = async (contractName, args) => {
        return hre.deploy(contractName, hre.capitalize(contractName), args)
    }

    hre.deployProxy = async (contractName, initializeParams, contractAddress) => {
        let interface = new hre.ethers.utils.Interface(hre.getABI(contractName))
        const initializeABI = interface.encodeFunctionData("initialize", initializeParams)

        const LendFlareProxy = await hre.ethers.getContractFactory("LendFlareProxy")
        const lendFlareProxy = await LendFlareProxy.deploy(contractAddress, hre.proxyAdmin, initializeABI)

        await lendFlareProxy.deployed()

        const Contract = await hre.ethers.getContractFactory(contractName)
        const instance = await Contract.attach(lendFlareProxy.address)

        return {
            proxy: lendFlareProxy,
            instance: instance,
            contractAddress: contractAddress,
            proxyAdmin: hre.proxyAdmin,
            initializeABI: initializeABI
        }
    }

    hre.upgradeProxy = async (contractName, contractAddress, proxyAddress) => {
        const LendFlareProxy = await hre.ethers.getContractFactory("LendFlareProxy")
        const lendFlareProxy = await LendFlareProxy.attach(proxyAddress)

        const lendFlareProxyTx = await lendFlareProxy.upgradeTo(contractAddress)

        await lendFlareProxyTx.wait()

        const Contract = await hre.ethers.getContractFactory(contractName)
        const instance = await Contract.attach(lendFlareProxy.address)

        return {
            proxy: lendFlareProxy,
            instance: instance,
            contractAddress: contractAddress
        }
    }

    hre.attach = async (contractName, saveName) => {
        const contract = await hre.ethers.getContractFactory(contractName)
        const instance = await contract.attach(hre.get(saveName).address)

        return instance
    }

    hre.simpleAttach = async (contractName) => {
        return attach(contractName, hre.capitalize(contractName))
    }

    hre.attachByProxy = async (contractName, saveName) => {
        const contract = await hre.ethers.getContractFactory(contractName)
        const instance = await contract.attach(hre.get(saveName).upgradeableProxy.address)

        return instance
    }

    hre.simpleAttachByProxy = async (contractName) => {
        return attachByProxy(contractName, hre.capitalize(contractName))
    }

    hre.getABI = contractName => {
        const buildPath = path.join(__dirname, 'abis')
        const filename = `${buildPath}/${contractName}.json`
        const ABIJson = require(filename)

        return ABIJson
    }

    hre.waitTx = async (f, waitTime) => {
        if (Array.isArray(f)) {
            for (let i = 0; i < f.length; i++) {
                const receipt = f[i]
                console.log(`👉 Waiting ${receipt.hash}`)

                await receipt.wait()

                waitTime = waitTime || 0

                if (waitTime > 0) {
                    await hre.wait(waitTime)
                }
            }
        }
    }

    hre.waitCallbackTx = async (f, waitTime) => {
        if (Array.isArray(f)) {
            for (let i = 0; i < f.length; i++) {
                const receipt = await f[i]()
                console.log(`👉 Waiting ${receipt.hash}`)

                await receipt.wait()

                waitTime = waitTime || 0

                if (waitTime > 0) {
                    await hre.wait(waitTime)
                }
            }
        }
    }
})

task("envtest", (args, hre) => {
    console.log(hre.hi)
})


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address)
    }
})

task("contracts", "Prints the list of contracts")
    .addParam("deployFile")
    .setAction(async (taskArgs, hre) => {
        const contracts = JSON.parse(fs.readFileSync(path.resolve(taskArgs[`deployFile`])))

        Object.keys(contracts).map((k, _) => {
            console.log(`> ${k} ${contracts[k].address}`)
        })
    })

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

module.exports = {
    networks: {
        mainnet: {
            url: secret.networks.mainnet.url,
            accounts:
                secret.mnemonic,
            // gas: 2e6
        }
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
    },
    etherscan: {
        apiKey: secret.apiKeys[0],
    },
    abiExporter: {
        path: './abis',
        clear: true,
        flat: true,
        only: [],
        spacing: 2,
        pretty: true,
    },
    solidity: {
        compilers: [
            {
                version: "0.6.12",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            }
        ],
        // overrides: {
        //   "contracts/xxx.sol": {
        //     version: "0.6.12",
        //     settings: {
        //       optimizer: {
        //         enabled: false
        //       },
        //     },
        //   }
        // }
    }
}
