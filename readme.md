### Contracts description

***

* [SupplyBooster.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/SupplyBooster.sol)

​		Users can deposit stable tokens.

* [ConvexBooster.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/ConvexBooster.sol)

​		Users can deposit curve LP and get  convex interest.

* [GenerateLendingPools.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/GenerateLendingPools.sol)

​		Allows LendFlare deployer to add convex pools.

* [LendingSponsor.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/LendingSponsor.sol)

​		When the user borrows asset, 0.1ETH will be transferred to the LendingSponsor contract for liquidation. If user repays before borrowing time, 0.1ETH will be returned.

* [LendingMarket.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/LendingMarket.sol)

​		Users can borrow, liquidate and repay in this contract.

* [LiquidityTransformer.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/LiquidityTransformer.sol)

​		Allow users to stake ETH or stable tokens. The contract will automatically add liquidity to Uniswap using this fund along with LFT. LFT can be withdrawn instantly after this process.

* [LendFlareGaugeModel.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/LendFlareGaugeModel.sol)

​		Gauge weight of the CompoundBooster's pool.

* [LendFlareToken.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/LendFlareToken.sol)

​		LFT token model.

* [LendFlareVotingEscrow.sol](https://github.com/LendFlare/lendflare_finance_contracts/blob/main/contracts/LendFlareVotingEscrow.sol)

​		Users can deposit their LFT tokens and get VeLFT tokens.



### Convex pools

> Query from [0xF403C135812408BFbE8713b5A23a04b3D48AAE31](https://etherscan.io/address/0xF403C135812408BFbE8713b5A23a04b3D48AAE31#code)

| INDEX | CURVE LP TOKEN                             | NAME                                                      | SYMBOL                 |
| ----- | ------------------------------------------ | --------------------------------------------------------- | ---------------------- |
| 0     | 0x845838DF265Dcd2c412A1Dc9e959c7d08537f8a2 | Curve.fi cDAI/cUSDC                                       | cDAI+cUSDC             |
| 1     | 0x9fC689CCaDa600B6DF723D9E47D84d76664a1F23 | Curve.fi cDAI/cUSDC/USDT                                  | cDAI+cUSDC+USDT        |
| 2     | 0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8 | Curve.fi yDAI/yUSDC/yUSDT/yTUSD                           | yDAI+yUSDC+yUSDT+yTUSD |
| 3     | 0x3B3Ac5386837Dc563660FB6a0937DFAa5924333B | Curve.fi yDAI/yUSDC/yUSDT/yBUSD                           | yDAI+yUSDC+yUSDT+yBUSD |
| 4     | 0xC25a3A3b969415c80451098fa907EC722572917F | Curve.fi DAI/USDC/USDT/sUSD                               | crvPlain3andSUSD       |
| 5     | 0xD905e2eaeBe188fc92179b6350807D8bd91Db0D8 | Curve.fi DAI/USDC/USDT/PAX                                | ypaxCrv                |
| 6     | 0x49849C98ae39Fff122806C06791Fa73784FB3675 | Curve.fi renBTC/wBTC                                      | crvRenWBTC             |
| 7     | 0x075b1bb99792c9E1041bA13afEf80C91a1e70fB3 | Curve.fi renBTC/wBTC/sBTC                                 | crvRenWSBTC            |
| 8     | 0xb19059ebb43466C323583928285a49f558E572Fd | Curve.fi hBTC/wBTC                                        | hCRV                   |
| 9     | 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490 | Curve.fi DAI/USDC/USDT                                    | 3Crv                   |
| 10    | 0xD2967f45c4f384DEEa880F807Be904762a3DeA07 | Curve.fi GUSD/3Crv                                        | gusd3CRV               |
| 11    | 0x5B5CFE992AdAC0C9D48E05854B2d91C73a003858 | Curve.fi HUSD/3Crv                                        | husd3CRV               |
| 12    | 0x97E2768e8E73511cA874545DC5Ff8067eB19B787 | Curve.fi USDK/3Crv                                        | usdk3CRV               |
| 13    | 0x4f3E8F405CF5aFC05D68142F3783bDfE13811522 | Curve.fi USDN/3Crv                                        | usdn3CRV               |
| 14    | 0x1AEf73d49Dedc4b1778d0706583995958Dc862e6 | Curve.fi MUSD/3Crv                                        | musd3CRV               |
| 15    | 0xC2Ee6b0334C261ED60C72f6054450b61B8f18E35 | Curve.fi RSV/3Crv                                         | rsv3CRV                |
| 16    | 0x64eda51d3Ad40D56b9dFc5554E06F94e1Dd786Fd | Curve.fi tBTC/sbtcCrv                                     | tbtc/sbtcCrv           |
| 17    | 0x3a664Ab939FD8482048609f652f9a0B0677337B9 | Curve.fi DUSD/3Crv                                        | dusd3CRV               |
| 18    | 0xDE5331AC4B3630f94853Ff322B66407e0D6331E8 | Curve.fi pBTC/sbtcCRV                                     | pBTC/sbtcCRV           |
| 19    | 0x410e3E86ef427e30B9235497143881f717d93c2A | Curve.fi bBTC/sbtcCRV                                     | bBTC/sbtcCRV           |
| 20    | 0x2fE94ea3d5d4a175184081439753DE15AeF9d614 | Curve.fi oBTC/sbtcCRV                                     | oBTC/sbtcCRV           |
| 21    | 0x94e131324b6054c0D789b190b2dAC504e4361b53 | Curve.fi UST/3Crv                                         | ust3CRV                |
| 22    | 0x194eBd173F6cDacE046C53eACcE9B953F28411d1 | Curve.fi EURS/sEUR                                        | eursCRV                |
| 23    | 0xA3D87FffcE63B53E0d54fAa1cc983B7eB0b74A9c | Curve.fi ETH/sETH                                         | eCRV                   |
| 24    | 0xFd2a8fA60Abd58Efe3EeE34dd494cD491dC14900 | Curve.fi aDAI/aUSDC/aUSDT                                 | a3CRV                  |
| 25    | 0x06325440D014e39736583c165C2963BA99fAf14E | Curve.fi ETH/stETH                                        | steCRV                 |
| 26    | 0x02d341CcB60fAaf662bC0554d13778015d1b285C | Curve.fi aDAI/aSUSD                                       | saCRV                  |
| 27    | 0xaA17A236F2bAdc98DDc0Cf999AbB47D47Fc0A6Cf | Curve.fi ETH/aETH                                         | ankrCRV                |
| 28    | 0x7Eb40E450b9655f4B3cC4259BCC731c63ff55ae6 | Curve.fi USDP/3Crv                                        | usdp3CRV               |
| 29    | 0x5282a4eF67D9C33135340fB3289cc1711c13638C | Curve.fi cyDAI/cyUSDC/cyUSDT                              | ib3CRV                 |
| 30    | 0xcee60cFa923170e4f8204AE08B4fA6A3F5656F3a | Curve.fi LINK/sLINK                                       | linkCRV                |
| 31    | 0xEcd5e75AFb02eFa118AF914515D6521aaBd189F1 | Curve.fi Factory USD Metapool: TrueUSD                    | TUSD3CRV-f             |
| 32    | 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B | Curve.fi Factory USD Metapool: Frax                       | FRAX3CRV-f             |
| 33    | 0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA | Curve.fi Factory USD Metapool: Liquity                    | LUSD3CRV-f             |
| 34    | 0x4807862AA8b2bF68830e4C8dc86D0e9A998e085a | Curve.fi Factory USD Metapool: Binance USD                | BUSD3CRV-f             |
| 35    | 0x53a901d48795C58f485cBB38df08FA96a24669D5 | Curve.fi ETH/rETH                                         | rCRV                   |
| 36    | 0x43b4FdFD4Ff969587185cDB6f0BD875c5Fc83f8c | Curve.fi Factory USD Metapool: Alchemix USD               | alUSD3CRV-f            |
| 37    | 0xcA3d75aC011BF5aD07a98d02f18225F9bD9A6BDF | Curve.fi USD-BTC-ETH                                      | crvTricrypto           |
| 38    | 0xc4AD29ba4B3c580e6D59105FFf484999997675Ff | Curve.fi USD-BTC-ETH                                      | crv3crypto             |
| 39    | 0xFD5dB7463a3aB53fD211b4af195c5BCCC1A03890 | Curve.fi Factory Plain Pool: Euro Tether                  | EURT-f                 |
| 40    | 0x5a6A4D54456819380173272A5E8E9B9904BdF41B | Curve.fi Factory USD Metapool: Magic Internet Money 3Pool | MIM-3LP3CRV-f          |
| 41    | 0x9D0464996170c6B9e75eED71c68B99dDEDf279e8 | Curve.fi Factory Plain Pool: cvxCRV                       | cvxcrv-f               |
| 42    | 0x8818a9bb44Fbf33502bE7c15c500d0C783B73067 | Curve.fi Factory Plain Pool: ibJPY/sJPY                   | ibJPY+sJPY-f           |
| 43    | 0xD6Ac1CB9019137a896343Da59dDE6d097F710538 | Curve.fi Factory Plain Pool: ibGBP/sGBP                   | ibGBP+sGBP-f           |
| 44    | 0x3F1B0278A9ee595635B61817630cC19DE792f506 | Curve.fi Factory Plain Pool: ibAUD/sAUD                   | ibAUD+sAUD-f           |
| 45    | 0x19b080FE1ffA0553469D20Ca36219F17Fcf03859 | Curve.fi Factory Plain Pool: ibEUR/sEUR                   | ibEUR+sEUR-f           |
| 46    | 0x9c2C8910F113181783c249d8F6Aa41b51Cde0f0c | Curve.fi Factory Plain Pool: ibCHF/sCHF                   | ibCHF+sCHF-f           |
| 47    | 0x8461A004b50d321CB22B7d034969cE6803911899 | Curve.fi Factory Plain Pool: ibKRW/sKRW                   | ibKRW+sKRW-f           |
| 48    | 0xB15fFb543211b558D40160811e5DcBcd7d5aaac9 | Recue Token                                               | cvxRT                  |
| 49    | 0xC4C319E2D4d66CcA4464C0c2B32c9Bd23ebe784e | Curve.fi Factory Pool: alETH                              | alETH+ETH-f            |
| 50    | 0x3Fb78e61784C9c637D560eDE23Ad57CA1294c14a | Curve.fi Factory Plain Pool: Neutrino EUR                 | EURN/EURT-f            |
| 51    | 0x5B3b5DF2BF2B6543f78e053bD91C4Bdd820929f1 | Curve.fi Factory USD Metapool: USDM                       | USDM3CRV-f             |
| 52    | 0x55A8a39bc9694714E2874c1ce77aa1E599461E18 | Curve.fi Factory Plain Pool: MIM-UST                      | MIM-UST-f              |
| 53    | 0xFbdCA68601f835b27790D98bbb8eC7f05FDEaA9B | Curve.fi Factory BTC Metapool: ibBTC                      | ibbtc/sbtcCRV-f        |
| 54    | 0x3D229E1B4faab62F621eF2F6A610961f7BD7b23B | Curve EURS-USDC                                           | crvEURSUSDC            |
| 55    | 0x3b6831c0077a1e44ED0a21841C3bC4dC11bCE833 | Curve EURT-3Crv                                           | crvEURTUSD             |
| 56    | 0x87650D7bbfC3A9F10587d7778206671719d9910D | Curve.fi Factory USD Metapool: Origin Dollar              | OUSD3CRV-f             |
| 57    | 0xc270b3B858c335B6BA5D5b10e2Da8a09976005ad | Curve.fi Factory USD Metapool: Paxos Dollar (USDP)        | pax-usdp3CRV-f         |
| 58    | 0xBaaa1F5DbA42C3389bDbc2c9D2dE134F5cD0Dc89 | Curve.fi Factory Plain Pool: d3pool                       | D3-f                   |
| 59    | 0xCEAF7747579696A2F0bb206a14210e3c9e6fB269 | Curve.fi Factory USD Metapool: wormhole v2 UST-3Pool      | UST_whv23CRV-f         |
| 60    | 0xb9446c4Ef5EBE66268dA6700D26f96273DE3d571 | Curve.fi Factory Plain Pool: 3EURpool                     | 3EURpool-f             |
| 61    | 0xEd4064f376cB8d68F770FB1Ff088a3d0F3FF5c4d | Curve CRV-ETH                                             | crvCRVETH              |
| 62    | 0xAA5A67c256e27A5d80712c51971408db3370927D | Curve.fi Factory USD Metapool: DOLA-3pool Curve LP        | DOLA3POOL3CRV-f        |