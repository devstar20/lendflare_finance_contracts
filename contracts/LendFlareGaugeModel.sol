// SPDX-License-Identifier: UNLICENSED
/* 

  _                          _   _____   _                       
 | |       ___   _ __     __| | |  ___| | |   __ _   _ __    ___ 
 | |      / _ \ | '_ \   / _` | | |_    | |  / _` | | '__|  / _ \
 | |___  |  __/ | | | | | (_| | |  _|   | | | (_| | | |    |  __/
 |_____|  \___| |_| |_|  \__,_| |_|     |_|  \__,_| |_|     \___|
                                                                 
LendFlare.finance
*/

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract LendFlareGaugeModel {
    using SafeMath for uint256;

    struct GagueModel {
        address gauge;
        uint256 weight;
        bool shutdown;
    }

    address[] gauges;
    address public owner;
    address public supplyExtraReward;

    mapping(address => GagueModel) public gaugeWeights;

    event AddGaguge(address indexed gauge, uint256 weight);
    event ToggleGague(address indexed gauge, bool enabled);
    event UpdateGagueWeight(address indexed gauge, uint256 weight);
    event SetOwner(address owner);

    modifier onlyOwner() {
        require(
            owner == msg.sender,
            "LendFlareGaugeModel: caller is not the owner"
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

    function setSupplyExtraReward(address _v) public onlyOwner {
        require(_v != address(0), "!_v");

        supplyExtraReward = _v;
    }

    // default = 100000000000000000000 weight(%) = 100000000000000000000 * 1e18/ total * 100
    function addGague(address _gauge, uint256 _weight) public {
        require(
            msg.sender == supplyExtraReward,
            "LendFlareGaugeModel: !authorized addGague"
        );

        gauges.push(_gauge);

        gaugeWeights[_gauge] = GagueModel({
            gauge: _gauge,
            weight: _weight,
            shutdown: false
        });
    }

    function updateGagueWeight(address _gauge, uint256 _newWeight)
        public
        onlyOwner
    {
        require(_gauge != address(0), "LendFlareGaugeModel:: !_gague");

        bool found;

        for (uint256 i = 0; i < gauges.length; i++) {
            if (gauges[i] == _gauge) {
                found = true;
            }
        }

        require(found, "LendFlareGaugeModel: !found");

        gaugeWeights[_gauge].weight = _newWeight;

        emit UpdateGagueWeight(_gauge, gaugeWeights[_gauge].weight);
    }

    function toggleGague(address _gauge, bool _state) public onlyOwner {
        gaugeWeights[_gauge].shutdown = _state;

        emit ToggleGague(_gauge, _state);
    }

    function getGagueWeight(address _gague) public view returns (uint256) {
        uint256 totalWeight;

        for (uint256 i = 0; i < gauges.length; i++) {
            if (!gaugeWeights[gauges[i]].shutdown) {
                totalWeight = totalWeight.add(gaugeWeights[gauges[i]].weight);
            }
        }

        return gaugeWeights[_gague].weight.mul(1e18).div(totalWeight);
    }

    function gaugesLength() public view returns (uint256) {
        return gauges.length;
    }
}
