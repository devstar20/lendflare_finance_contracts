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
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ILendingMarketPoolChecker {
    function checker(
        uint256 _convexBoosterPid,
        uint256[] memory _supplyBoosterPids,
        int128[] memory _curveCoinIds
    ) external view returns (bool);
}

interface IConvexBooster {
    function liquidate(
        uint256 _convexPid,
        int128 _curveCoinId,
        address _user,
        uint256 _amount
    ) external returns (address, uint256);

    function depositFor(
        uint256 _convexPid,
        uint256 _amount,
        address _user
    ) external returns (bool);

    function withdrawFor(
        uint256 _convexPid,
        uint256 _amount,
        address _user,
        bool _isFrozenTokens
    ) external returns (bool);

    function poolInfo(uint256 _convexPid)
        external
        view
        returns (
            uint256 originConvexPid,
            address curveSwapAddress,
            address lpToken,
            address originCrvRewards,
            address originStash,
            address virtualBalance,
            address rewardCrvPool,
            address rewardCvxPool,
            bool shutdown
        );
}

interface ISupplyBooster {
    function liquidate(
        bytes32 _lendingId,
        uint256 _lendingAmount,
        uint256 _lendingInterest
    ) external payable returns (address);

    function getLendingInfos(bytes32 _lendingId)
        external
        view
        returns (address);

    function borrow(
        uint256 _pid,
        bytes32 _lendingId,
        address _user,
        uint256 _lendingAmount,
        uint256 _lendingInterest,
        uint256 _borrowNumbers
    ) external;

    // ether
    function repayBorrow(
        bytes32 _lendingId,
        address _user,
        uint256 _lendingInterest
    ) external payable;

    // erc20
    function repayBorrow(
        bytes32 _lendingId,
        address _user,
        uint256 _lendingAmount,
        uint256 _lendingInterest
    ) external;

    function getBorrowRatePerBlock(uint256 _pid)
        external
        view
        returns (uint256);

    function getUtilizationRate(uint256 _pid) external view returns (uint256);
}

interface ICurveSwap {
    // function get_virtual_price() external view returns (uint256);

    // lp to token 68900637075889600000000, 2
    function calc_withdraw_one_coin(uint256 _tokenAmount, int128 _tokenId)
        external
        view
        returns (uint256);

    // token to lp params: [0,0,70173920000], false
    /* function calc_token_amount(uint256[] memory amounts, bool deposit)
        external
        view
        returns (uint256); */
}

interface ILendingSponsor {
    function addSponsor(bytes32 _lendingId, address _user) external payable;

    function payFee(bytes32 _lendingId, address payable _user) external;
}

contract LendingMarket is Initializable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public convexBooster;
    address public supplyBooster;
    address public lendingSponsor;

    uint256 public launchTime;
    address public lendingMarketPoolChecker;
    uint256 public liquidateThresholdBlockNumbers;
    uint256 public version;

    address public owner;

    enum UserLendingState {
        LENDING,
        EXPIRED,
        LIQUIDATED
    }

    struct PoolInfo {
        uint256 convexPid;
        uint256[] supportPids;
        int128[] curveCoinIds;
        uint256 lendingThreshold;
        uint256 liquidateThreshold;
        uint256 borrowIndex;
    }

    struct UserLending {
        bytes32 lendingId;
        uint256 token0;
        uint256 token0Price;
        uint256 lendingAmount;
        uint256 lendingInterest;
        uint256 supportPid;
        int128 curveCoinId;
        uint256 borrowNumbers;
    }

    struct LendingInfo {
        address user;
        uint256 pid;
        uint256 userLendingIndex;
        uint256 borrowIndex;
        uint256 startedBlock;
        uint256 utilizationRate;
        uint256 supplyRatePerBlock;
        UserLendingState state;
    }

    struct BorrowInfo {
        uint256 borrowAmount;
        uint256 supplyAmount;
    }

    struct Statistic {
        uint256 totalCollateral;
        uint256 totalBorrow;
        uint256 recentRepayAt;
    }

    struct LendingParams {
        uint256 lendingAmount;
        uint256 lendingInterest;
        uint256 lendingRate;
        uint256 utilizationRate;
        uint256 supplyRatePerBlock;
        address lpToken;
        uint256 token0Price;
    }

    PoolInfo[] public poolInfo;

    // user address => container
    mapping(address => UserLending[]) public userLendings;
    // lending id => user address
    mapping(bytes32 => LendingInfo) public lendings;
    // pool id => (borrowIndex => user lendingId)
    mapping(uint256 => mapping(uint256 => bytes32)) public poolLending;
    mapping(bytes32 => BorrowInfo) public borrowInfos;
    mapping(bytes32 => Statistic) public myStatistics;
    // number => block numbers
    mapping(uint256 => uint256) public borrowNumberLimit;

    event LendingBase(
        bytes32 indexed lendingId,
        uint256 marketPid,
        uint256 supplyPid,
        int128 curveCoinId,
        uint256 borrowBlocks
    );

    event Borrow(
        bytes32 indexed lendingId,
        address indexed user,
        uint256 pid,
        uint256 token0,
        uint256 token0Price,
        uint256 lendingAmount,
        uint256 borrowNumber
    );
    event Initialized(address indexed thisAddress);
    event RepayBorrow(
        bytes32 indexed lendingId,
        address user,
        UserLendingState state
    );

    event Liquidate(
        bytes32 indexed lendingId,
        address user,
        uint256 liquidateAmount,
        uint256 gasSpent,
        UserLendingState state
    );

    event SetOwner(address owner);

    modifier onlyOwner() {
        require(owner == msg.sender, "LendingMarket: caller is not the owner");
        _;
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;

        emit SetOwner(_owner);
    }

    function initialize(
        address _owner,
        address _lendingSponsor,
        address _convexBooster,
        address _supplyBooster
    ) public initializer {
        launchTime = block.timestamp;
        owner = _owner;
        lendingSponsor = _lendingSponsor;
        convexBooster = _convexBooster;
        supplyBooster = _supplyBooster;

        

        borrowNumberLimit[19] = 524288;
        borrowNumberLimit[20] = 1048576;
        borrowNumberLimit[21] = 2097152;

        liquidateThresholdBlockNumbers = 50;
        version = 1;

        emit Initialized(address(this));
    }

    function borrow(
        uint256 _pid,
        uint256 _token0,
        uint256 _borrowNumber,
        uint256 _supportPid
    ) public payable nonReentrant {
        require(block.timestamp >= launchTime, "!launchTime");
        require(borrowNumberLimit[_borrowNumber] != 0, "!borrowNumberLimit");
        require(msg.value == 0.1 ether, "!lendingSponsor");

        _borrow(_pid, _supportPid, _borrowNumber, _token0);
    }

    function _getCurveInfo(
        uint256 _convexPid,
        int128 _curveCoinId,
        uint256 _token0
    ) internal view returns (address lpToken, uint256 token0Price) {
        address curveSwapAddress;

        (, curveSwapAddress, lpToken, , , , , , ) = IConvexBooster(
            convexBooster
        ).poolInfo(_convexPid);

        token0Price = ICurveSwap(curveSwapAddress).calc_withdraw_one_coin(
            _token0,
            _curveCoinId
        );
    }

    function _borrow(
        uint256 _pid,
        uint256 _supportPid,
        uint256 _borrowNumber,
        uint256 _token0
    ) internal returns (LendingParams memory) {
        PoolInfo storage pool = poolInfo[_pid];

        pool.borrowIndex++;

        bytes32 lendingId = generateId(
            msg.sender,
            _pid,
            pool.borrowIndex + block.number
        );

        LendingParams memory lendingParams = getLendingInfo(
            _token0,
            pool.convexPid,
            pool.curveCoinIds[_supportPid],
            pool.supportPids[_supportPid],
            pool.lendingThreshold,
            pool.liquidateThreshold,
            _borrowNumber
        );

        IERC20(lendingParams.lpToken).safeTransferFrom(
            msg.sender,
            address(this),
            _token0
        );

        IERC20(lendingParams.lpToken).safeApprove(convexBooster, 0);
        IERC20(lendingParams.lpToken).safeApprove(convexBooster, _token0);

        ISupplyBooster(supplyBooster).borrow(
            pool.supportPids[_supportPid],
            lendingId,
            msg.sender,
            lendingParams.lendingAmount,
            lendingParams.lendingInterest,
            _borrowNumber
        );

        IConvexBooster(convexBooster).depositFor(
            pool.convexPid,
            _token0,
            msg.sender
        );

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(_pid, pool.supportPids[_supportPid], address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.add(
            lendingParams.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.add(
            lendingParams.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(_pid, pool.supportPids[_supportPid], msg.sender)
        ];

        statistic.totalCollateral = statistic.totalCollateral.add(_token0);
        statistic.totalBorrow = statistic.totalBorrow.add(
            lendingParams.lendingAmount
        );

        userLendings[msg.sender].push(
            UserLending({
                lendingId: lendingId,
                token0: _token0,
                token0Price: lendingParams.token0Price,
                lendingAmount: lendingParams.lendingAmount,
                lendingInterest: lendingParams.lendingInterest,
                supportPid: pool.supportPids[_supportPid],
                curveCoinId: pool.curveCoinIds[_supportPid],
                borrowNumbers: borrowNumberLimit[_borrowNumber]
            })
        );

        lendings[lendingId] = LendingInfo({
            user: msg.sender,
            pid: _pid,
            borrowIndex: pool.borrowIndex,
            userLendingIndex: userLendings[msg.sender].length - 1,
            startedBlock: block.number,
            utilizationRate: lendingParams.utilizationRate,
            supplyRatePerBlock: lendingParams.supplyRatePerBlock,
            state: UserLendingState.LENDING
        });

        poolLending[_pid][pool.borrowIndex] = lendingId;

        ILendingSponsor(lendingSponsor).addSponsor{value: msg.value}(
            lendingId,
            msg.sender
        );

        emit LendingBase(
            lendingId,
            _pid,
            pool.supportPids[_supportPid],
            pool.curveCoinIds[_supportPid],
            borrowNumberLimit[_borrowNumber]
        );

        emit Borrow(
            lendingId,
            msg.sender,
            _pid,
            _token0,
            lendingParams.token0Price,
            lendingParams.lendingAmount,
            _borrowNumber
        );
    }

    function _repayBorrow(
        bytes32 _lendingId,
        uint256 _amount,
        bool isErc20,
        bool isFrozenTokens
    ) internal {
        LendingInfo storage lendingInfo = lendings[_lendingId];

        require(lendingInfo.startedBlock > 0, "!invalid lendingId");

        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingIndex
        ];
        PoolInfo memory pool = poolInfo[lendingInfo.pid];

        require(
            lendingInfo.state == UserLendingState.LENDING,
            "!UserLendingState"
        );

        require(
            block.number <=
                lendingInfo.startedBlock.add(userLending.borrowNumbers),
            "Expired"
        );

        require(_amount == userLending.lendingAmount, "!_amount");

        lendingInfo.state = UserLendingState.EXPIRED;

        IConvexBooster(convexBooster).withdrawFor(
            pool.convexPid,
            userLending.token0,
            lendingInfo.user,
            isFrozenTokens
        );

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(lendingInfo.pid, userLending.supportPid, address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.sub(
            userLending.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.sub(
            userLending.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(
                lendingInfo.pid,
                userLending.supportPid,
                lendingInfo.user
            )
        ];

        statistic.totalCollateral = statistic.totalCollateral.sub(
            userLending.token0
        );
        statistic.totalBorrow = statistic.totalBorrow.sub(
            userLending.lendingAmount
        );
        statistic.recentRepayAt = block.timestamp;

        if (isErc20) {
            address underlyToken = ISupplyBooster(supplyBooster)
                .getLendingInfos(userLending.lendingId);

            IERC20(underlyToken).safeTransferFrom(
                msg.sender,
                supplyBooster,
                userLending.lendingAmount
            );

            ISupplyBooster(supplyBooster).repayBorrow(
                userLending.lendingId,
                lendingInfo.user,
                userLending.lendingAmount,
                userLending.lendingInterest
            );
        } else {
            ISupplyBooster(supplyBooster).repayBorrow{
                value: userLending.lendingAmount
            }(
                userLending.lendingId,
                lendingInfo.user,
                userLending.lendingInterest
            );
        }

        ILendingSponsor(lendingSponsor).payFee(
            userLending.lendingId,
            payable(lendingInfo.user)
        );

        emit RepayBorrow(
            userLending.lendingId,
            lendingInfo.user,
            lendingInfo.state
        );
    }

    function repayBorrow(bytes32 _lendingId) public payable {
        _repayBorrow(_lendingId, msg.value, false, false);
    }

    function repayBorrowERC20(bytes32 _lendingId, uint256 _amount) public {
        _repayBorrow(_lendingId, _amount, true, false);
    }

    function repayBorrowAndFrozenTokens(bytes32 _lendingId) public payable {
        _repayBorrow(_lendingId, msg.value, false, true);
    }

    function repayBorrowERC20AndFrozenTokens(
        bytes32 _lendingId,
        uint256 _amount
    ) public {
        _repayBorrow(_lendingId, _amount, true, true);
    }

    function liquidate(bytes32 _lendingId, uint256 _extraErc20Amount)
        public
        payable
        nonReentrant
    {
        uint256 gasStart = gasleft();
        LendingInfo storage lendingInfo = lendings[_lendingId];

        require(lendingInfo.startedBlock > 0, "!invalid lendingId");

        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingIndex
        ];

        require(
            lendingInfo.state == UserLendingState.LENDING,
            "!UserLendingState"
        );

        require(
            lendingInfo.startedBlock.add(userLending.borrowNumbers).sub(
                liquidateThresholdBlockNumbers
            ) < block.number,
            "!borrowNumbers"
        );

        PoolInfo memory pool = poolInfo[lendingInfo.pid];

        lendingInfo.state = UserLendingState.LIQUIDATED;

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(lendingInfo.pid, userLending.supportPid, address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.sub(
            userLending.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.sub(
            userLending.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(
                lendingInfo.pid,
                userLending.supportPid,
                lendingInfo.user
            )
        ];

        statistic.totalCollateral = statistic.totalCollateral.sub(
            userLending.token0
        );
        statistic.totalBorrow = statistic.totalBorrow.sub(
            userLending.lendingAmount
        );

        (address underlyToken, uint256 liquidateAmount) = IConvexBooster(
            convexBooster
        ).liquidate(
                pool.convexPid,
                userLending.curveCoinId,
                lendingInfo.user,
                userLending.token0
            );

        if (underlyToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            liquidateAmount = liquidateAmount.add(msg.value);

            ISupplyBooster(supplyBooster).liquidate{value: liquidateAmount}(
                userLending.lendingId,
                userLending.lendingAmount,
                userLending.lendingInterest
            );
        } else {
            IERC20(underlyToken).safeTransfer(supplyBooster, liquidateAmount);

            if (_extraErc20Amount > 0) {
                // Failure without authorization
                IERC20(underlyToken).safeTransferFrom(
                    msg.sender,
                    supplyBooster,
                    _extraErc20Amount
                );
            }

            ISupplyBooster(supplyBooster).liquidate(
                userLending.lendingId,
                userLending.lendingAmount,
                userLending.lendingInterest
            );
        }

        ILendingSponsor(lendingSponsor).payFee(
            userLending.lendingId,
            msg.sender
        );

        uint256 gasSpent = (21000 + gasStart - gasleft()).mul(tx.gasprice);

        emit Liquidate(
            userLending.lendingId,
            lendingInfo.user,
            liquidateAmount,
            gasSpent,
            lendingInfo.state
        );
    }

    function setLiquidateThresholdBlockNumbers(uint256 _v) public onlyOwner {
        require(_v >= 50 && _v <= 100, "!_v");

        liquidateThresholdBlockNumbers = _v;
    }

    function setLendingMarketPoolChecker(address _v) public onlyOwner {
        require(_v != address(0), "!_v");

        lendingMarketPoolChecker = _v;
    }

    function setBorrowNumberLimit(uint256 _number, uint256 _v)
        public
        onlyOwner
    {
        require(_number > 6 && _v > 64, "!_number or !_v");

        borrowNumberLimit[_number] = _v;
    }

    function setLendingThreshold(uint256 _pid, uint256 _v) public onlyOwner {
        require(_v >= 100 && _v <= 300, "!_v");

        PoolInfo storage pool = poolInfo[_pid];

        pool.lendingThreshold = _v;
    }

    function setLiquidateThreshold(uint256 _pid, uint256 _v) public onlyOwner {
        require(_v >= 50 && _v <= 300, "!_v");

        PoolInfo storage pool = poolInfo[_pid];

        pool.liquidateThreshold = _v;
    }

    receive() external payable {}

    /* 
    @param _convexBoosterPid convexBooster contract
    @param _supplyBoosterPids supply contract
    @param _curveCoinIds curve coin id of curve COINS
     */
    function addMarketPool(
        uint256 _convexBoosterPid,
        uint256[] memory _supplyBoosterPids,
        int128[] memory _curveCoinIds,
        uint256 _lendingThreshold,
        uint256 _liquidateThreshold
    ) public onlyOwner {
        if (lendingMarketPoolChecker != address(0)) {
            bool checkerState = ILendingMarketPoolChecker(
                lendingMarketPoolChecker
            ).checker(_convexBoosterPid, _supplyBoosterPids, _curveCoinIds);
            require(checkerState, "!checkerState");
        }

        require(
            _lendingThreshold >= 100 && _lendingThreshold <= 300,
            "!_lendingThreshold"
        );
        require(
            _liquidateThreshold >= 50 && _liquidateThreshold <= 300,
            "!_liquidateThreshold"
        );
        require(
            _supplyBoosterPids.length == _curveCoinIds.length,
            "!_supportPids && _curveCoinIds"
        );

        poolInfo.push(
            PoolInfo({
                convexPid: _convexBoosterPid,
                supportPids: _supplyBoosterPids,
                curveCoinIds: _curveCoinIds,
                lendingThreshold: _lendingThreshold,
                liquidateThreshold: _liquidateThreshold,
                borrowIndex: 0
            })
        );
    }

    /* function toBytes16(uint256 x) internal pure returns (bytes16 b) {
        return bytes16(bytes32(x));
    } */

    function generateId(
        address x,
        uint256 y,
        uint256 z
    ) public pure returns (bytes32) {
        /* return toBytes16(uint256(keccak256(abi.encodePacked(x, y, z)))); */
        return keccak256(abi.encodePacked(x, y, z));
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function cursor(
        uint256 _pid,
        uint256 _offset,
        uint256 _size
    ) public view returns (bytes32[] memory, uint256) {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 size = _offset + _size > pool.borrowIndex
            ? pool.borrowIndex - _offset
            : _size;
        uint256 index;

        bytes32[] memory userLendingIds = new bytes32[](size);

        for (uint256 i = 0; i < size; i++) {
            bytes32 userLendingId = poolLending[_pid][_offset + i];

            userLendingIds[index] = userLendingId;
            index++;
        }

        return (userLendingIds, pool.borrowIndex);
    }

    function calculateRepayAmount(bytes32 _lendingId)
        public
        view
        returns (uint256)
    {
        LendingInfo memory lendingInfo = lendings[_lendingId];
        UserLending memory userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingIndex
        ];

        if (lendingInfo.state == UserLendingState.LIQUIDATED) return 0;

        return userLending.lendingAmount;
    }

    function getPoolSupportPids(uint256 _pid)
        public
        view
        returns (uint256[] memory)
    {
        PoolInfo memory pool = poolInfo[_pid];

        return pool.supportPids;
    }

    function getCurveCoinId(uint256 _pid, uint256 _supportPid)
        public
        view
        returns (int128)
    {
        PoolInfo memory pool = poolInfo[_pid];

        return pool.curveCoinIds[_supportPid];
    }

    function getUserLendingState(bytes32 _lendingId)
        public
        view
        returns (UserLendingState)
    {
        LendingInfo memory lendingInfo = lendings[_lendingId];

        return lendingInfo.state;
    }

    function getLendingInfo(
        uint256 _token0,
        uint256 _convexPid,
        int128 _curveCoinId,
        uint256 _supplyPid,
        uint256 _lendingThreshold,
        uint256 _liquidateThreshold,
        uint256 _borrowBlocks
    ) public view returns (LendingParams memory) {
        (address lpToken, uint256 token0Price) = _getCurveInfo(
            _convexPid,
            _curveCoinId,
            _token0
        );

        uint256 utilizationRate = ISupplyBooster(supplyBooster)
            .getUtilizationRate(_supplyPid);
        uint256 supplyRatePerBlock = ISupplyBooster(supplyBooster)
            .getBorrowRatePerBlock(_supplyPid);
        uint256 supplyRate = getSupplyRate(supplyRatePerBlock, _borrowBlocks);
        uint256 lendflareTotalRate;

        if (utilizationRate > 0) {
            lendflareTotalRate = getLendingRate(
                supplyRate,
                getAmplificationFactor(utilizationRate)
            );
        } else {
            lendflareTotalRate = supplyRate.sub(1e18);
        }

        uint256 lendingAmount = (token0Price *
            1e18 *
            (1000 - _lendingThreshold - _liquidateThreshold)) /
            (1e18 + lendflareTotalRate) /
            1000;

        // lendingInterest
        uint256 lendlareInterest = lendingAmount.mul(lendflareTotalRate).div(
            1e18
        );
        // uint256 borrowAmount = lendingAmount.sub(lendlareInterest);
        // uint256 repayBorrowAmount = lendingAmount;

        return
            LendingParams({
                lendingAmount: lendingAmount,
                lendingInterest: lendlareInterest,
                lendingRate: lendflareTotalRate,
                utilizationRate: utilizationRate,
                supplyRatePerBlock: supplyRatePerBlock,
                lpToken: lpToken,
                token0Price: token0Price
            });
    }

    function getUserLendingsLength(address _user)
        public
        view
        returns (uint256)
    {
        return userLendings[_user].length;
    }

    function getSupplyRate(uint256 _supplyBlockRate, uint256 n)
        public
        pure
        returns (uint256)
    {
        _supplyBlockRate = _supplyBlockRate + (10**18);

        for (uint256 i = 1; i <= n; i++) {
            _supplyBlockRate = (_supplyBlockRate**2) / (10**18);
        }

        return _supplyBlockRate;
    }

    function getAmplificationFactor(uint256 _utilizationRate)
        public
        pure
        returns (uint256)
    {
        if (_utilizationRate <= 0.9 * 1e18) {
            return uint256(10).mul(_utilizationRate).div(9).add(1e18);
        }

        return uint256(20).mul(_utilizationRate).sub(16 * 1e18);
    }

    // lendflare total rate
    function getLendingRate(uint256 _supplyRate, uint256 _amplificationFactor)
        public
        pure
        returns (uint256)
    {
        return _supplyRate.sub(1e18).mul(_amplificationFactor).div(1e18);
    }

    function getEncodePacked(
        uint256 _pid,
        uint256 _supportPid,
        address _sender
    ) public pure returns (bytes32) {
        if (_sender == address(0)) {
            return generateId(_sender, _pid, _supportPid);
        }

        return generateId(_sender, _pid, _supportPid);
    }
}
