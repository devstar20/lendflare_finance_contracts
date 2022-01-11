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
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract LiquidityTransformer is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public lendflareToken;
    address public uniswapPair;

    IUniswapV2Router02 public constant uniswapRouter =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address payable teamAddress;

    uint256 public constant liquifyTokens = 909090909 * 1e18;
    uint256 public investmentDays;
    uint256 public minInvest;
    uint256 public launchTime;

    struct Globals {
        uint256 totalUsers;
        uint256 transferedUsers;
        uint256 totalWeiContributed;
        bool liquidity;
        uint256 endTimeAt;
    }

    Globals public globals;

    mapping(address => uint256) public investorBalances;
    mapping(address => uint256[2]) investorHistory;

    event UniSwapResult(
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity,
        uint256 endTimeAt
    );

    modifier afterUniswapTransfer() {
        require(globals.liquidity == true, "forward liquidity first");
        _;
    }

    constructor(
        address _lendflareToken,
        address payable _teamAddress,
        uint256 _launchTime
    ) public {
        require(_launchTime > block.timestamp, "!_launchTime");
        launchTime = _launchTime;
        lendflareToken = IERC20(_lendflareToken);
        teamAddress = _teamAddress;

        minInvest = 0.1 ether;
        investmentDays = 7 days;

        
    }

    function createPair() external {
        require(address(uniswapPair) == address(0), "!uniswapPair");

        uniswapPair = address(
            IUniswapV2Factory(factory()).createPair(WETH(), address(this))
        );
    }

    receive() external payable {
        require(
            msg.sender == address(uniswapRouter) || msg.sender == teamAddress,
            "direct deposits disabled"
        );
    }

    function reserve() external payable {
        _reserve(msg.sender, msg.value);
    }

    function reserveWithToken(address _tokenAddress, uint256 _tokenAmount)
        external
    {
        IERC20 token = IERC20(_tokenAddress);

        token.transferFrom(msg.sender, address(this), _tokenAmount);

        token.approve(address(uniswapRouter), _tokenAmount);

        address[] memory _path = preparePath(_tokenAddress);

        uint256[] memory amounts = uniswapRouter.swapExactTokensForETH(
            _tokenAmount,
            0,
            _path,
            address(this),
            block.timestamp
        );

        _reserve(msg.sender, amounts[1]);
    }

    function _reserve(address _senderAddress, uint256 _senderValue) internal {
        require(block.timestamp >= launchTime, "Not started");
        require(
            block.timestamp <= launchTime.add(investmentDays),
            "IDO has ended"
        );
        require(_senderValue >= minInvest, "Investment below minimum");
        require(globals.liquidity == false, "!globals.liquidity");

        investorBalances[_senderAddress] += _senderValue;

        globals.totalWeiContributed += _senderValue;
        globals.totalUsers++;
    }

    function forwardLiquidity() external nonReentrant {
        require(globals.liquidity == false, "!globals.liquidity");
        require(
            block.timestamp > launchTime.add(investmentDays),
            "Not over yet"
        );

        uint256 _etherFee = globals.totalWeiContributed.mul(100).div(1000);
        uint256 _balance = globals.totalWeiContributed.sub(_etherFee);

        teamAddress.transfer(_etherFee);

        uint256 half = liquifyTokens.div(2);
        uint256 _lendflareTokenFee = half.mul(100).div(1000);

        IERC20(lendflareToken).safeTransfer(teamAddress, _lendflareTokenFee);

        lendflareToken.approve(
            address(uniswapRouter),
            half.sub(_lendflareTokenFee)
        );

        (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        ) = uniswapRouter.addLiquidityETH{value: _balance}(
                address(lendflareToken),
                half.sub(_lendflareTokenFee),
                0,
                0,
                address(0x0),
                block.timestamp
            );

        globals.liquidity = true;
        globals.endTimeAt = block.timestamp;

        emit UniSwapResult(
            amountToken,
            amountETH,
            liquidity,
            globals.endTimeAt
        );
    }

    function getMyTokens() external afterUniswapTransfer nonReentrant {
        require(globals.liquidity, "!globals.liquidity");
        require(investorBalances[msg.sender] > 0, "!balance");

        uint256 myTokens = checkMyTokens(msg.sender);

        investorHistory[msg.sender][0] = investorBalances[msg.sender];
        investorHistory[msg.sender][1] = myTokens;
        investorBalances[msg.sender] = 0;

        IERC20(lendflareToken).safeTransfer(msg.sender, myTokens);

        globals.transferedUsers++;

        if (globals.transferedUsers == globals.totalUsers) {
            uint256 surplusBalance = IERC20(lendflareToken).balanceOf(
                address(this)
            );

            if (surplusBalance > 0) {
                IERC20(lendflareToken).safeTransfer(
                    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
                    surplusBalance
                );
            }
        }
    }

    /* view functions */
    function WETH() public pure returns (address) {
        return IUniswapV2Router02(uniswapRouter).WETH();
    }

    function checkMyTokens(address _sender) public view returns (uint256) {
        if (
            globals.totalWeiContributed == 0 || investorBalances[_sender] == 0
        ) {
            return 0;
        }

        uint256 half = liquifyTokens.div(2);
        uint256 otherHalf = liquifyTokens.sub(half);
        uint256 percent = investorBalances[_sender].mul(100e18).div(
            globals.totalWeiContributed
        );
        uint256 myTokens = otherHalf.mul(percent).div(100e18);

        return myTokens;
    }

    function factory() public pure returns (address) {
        return IUniswapV2Router02(uniswapRouter).factory();
    }

    function getInvestorHistory(address _sender)
        public
        view
        returns (uint256[2] memory)
    {
        return investorHistory[_sender];
    }

    function preparePath(address _tokenAddress)
        internal
        pure
        returns (address[] memory _path)
    {
        _path = new address[](2);
        _path[0] = _tokenAddress;
        _path[1] = WETH();
    }
}
