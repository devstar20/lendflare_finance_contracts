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

contract LendingSponsor {
    using SafeMath for uint256;

    enum LendingInfoState {
        NONE,
        CLOSED
    }

    struct LendingInfo {
        address user;
        uint256 amount;
        LendingInfoState state;
    }

    address public lendingMarket;
    uint256 public totalSupply;
    address public owner;

    mapping(bytes32 => LendingInfo) public lendingInfos;

    event AddSponsor(bytes32 sponsor, uint256 amount);
    event RequestFee(bytes32 sponsor, uint256 amount);
    event PayFee(bytes32 sponsor, address user, uint256 sponsorAmount);
    event SetOwner(address owner);

    modifier onlyLendingMarket() {
        require(
            lendingMarket == msg.sender,
            "LendingSponsor: caller is not the lendingMarket"
        );

        _;
    }

    modifier onlyOwner() {
        require(
            owner == msg.sender,
            "LendingSponsor: caller is not the owner"
        );
        _;
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;

        emit SetOwner(_owner);
    }

    constructor() public {
        owner = msg.sender;
    }

    function setLendingMarket(address _v) external onlyOwner {
        lendingMarket = _v;
    }

    function payFee(bytes32 _lendingId, address payable _user)
        public
        onlyLendingMarket
    {
        LendingInfo storage lendingInfo = lendingInfos[_lendingId];

        if (lendingInfo.state == LendingInfoState.NONE) {
            lendingInfo.state = LendingInfoState.CLOSED;

            _user.transfer(lendingInfo.amount);

            emit PayFee(_lendingId, _user, lendingInfo.amount);
        }
    }

    function addSponsor(bytes32 _lendingId, address _user)
        public
        payable
        onlyLendingMarket
    {
        lendingInfos[_lendingId] = LendingInfo({
            user: _user,
            amount: msg.value,
            state: LendingInfoState.NONE
        });

        totalSupply = totalSupply.add(msg.value);

        emit AddSponsor(_lendingId, msg.value);
    }
}
