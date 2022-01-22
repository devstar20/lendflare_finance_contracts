// SPDX-License-Identifier: UNLICENSED
/* 

  _                          _   _____   _                       
 | |       ___   _ __     __| | |  ___| | |   __ _   _ __    ___ 
 | |      / _ \ | '_ \   / _` | | |_    | |  / _` | | '__|  / _ \
 | |___  |  __/ | | | | | (_| | |  _|   | | | (_| | | |    |  __/
 |_____|  \___| |_| |_|  \__,_| |_|     |_|  \__,_| |_|     \___|
                                                                 
LendFlare.finance
*/

pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

interface ILiquidityGauge {
    function updateReward(address _for) external;

    function totalAccrued(address _for) external view returns (uint256);
}

interface ILendFlareToken {
    function mint(address _for, uint256 amount) external;
}

contract LendFlareTokenMinter {
    using SafeMath for uint256;

    address public token;
    uint256 public launchTime;

    mapping(address => mapping(address => uint256)) public minted; // user -> gauge -> value

    event Minted(address user, address gauge, uint256 amount);

    constructor(address _token, uint256 _launchTime) public {
        require(_launchTime > block.timestamp, "!_launchTime");
        launchTime = _launchTime;
        token = _token;
    }

    function _mint_for(address gauge_addr, address _for) internal {
        if (block.timestamp >= launchTime) {
            ILiquidityGauge(gauge_addr).updateReward(_for);

            uint256 total_mint = ILiquidityGauge(gauge_addr).totalAccrued(_for);
            uint256 to_mint = total_mint - minted[_for][gauge_addr];

            if (to_mint != 0) {
                ILendFlareToken(token).mint(_for, to_mint);
                minted[_for][gauge_addr] = total_mint;

                emit Minted(_for, gauge_addr, total_mint);
            }
        }
    }

    function mint(address gauge_addr) public {
        _mint_for(gauge_addr, msg.sender);
    }

    function mint_many(address[8] memory gauge_addrs) public {
        for (uint256 i = 0; i < gauge_addrs.length; i++) {
            _mint_for(gauge_addrs[i], msg.sender);
        }
    }

    function mint_for(address gauge_addr, address _for) public {
        _mint_for(gauge_addr, _for);
    }
}
