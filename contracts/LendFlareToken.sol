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
import "@openzeppelin/contracts/proxy/Initializable.sol";

contract LendFlareToken is Initializable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint256 private _decimals;

    uint256 public constant ONE_DAY = 86400;
    uint256 public constant YEAR = ONE_DAY * 365;
    uint256 public constant INITIAL_RATE = (274815283 * 10**18) / YEAR; // leading to 43% premine
    uint256 public constant RATE_REDUCTION_TIME = YEAR;
    uint256 public constant RATE_REDUCTION_COEFFICIENT = 1189207115002721024; // 2 ** (1/4) * 1e18
    uint256 public constant RATE_DENOMINATOR = 10**18;

    int128 public mining_epoch;
    uint256 public start_epoch_time;
    uint256 public rate;
    uint256 public start_epoch_supply;
    uint256 public version;

    address public owner;
    address public minter;

    event UpdateMiningParameters(uint256 time, uint256 rate, uint256 supply);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
    event SetMinter(address minter);
    event SetOwner(address owner);

    function initialize(address _owner, address _multiSigUser)
        public
        initializer
    {
        _name = "LendFlare DAO Token";
        _symbol = "LFT";
        _decimals = 18;
        version = 1;

        owner = _owner;

        // total = 1303030301 * 10**_decimals
        uint256 liquidity_transformer = 909090909 * 10**_decimals;
        uint256 official_team = 90909090 * 10**_decimals;
        uint256 merkle_airdrop = 30303030 * 10**_decimals;
        uint256 early_liquidity_reward = 151515151 * 10**_decimals;
        uint256 community = 121212121 * 10**_decimals;

        uint256 init_supply = liquidity_transformer
            .add(official_team)
            .add(merkle_airdrop)
            .add(early_liquidity_reward)
            .add(community);

        _balances[_multiSigUser] = init_supply;
        _totalSupply = init_supply;

        emit Transfer(address(0), _multiSigUser, liquidity_transformer);
        emit Transfer(address(0), _multiSigUser, official_team);
        emit Transfer(address(0), _multiSigUser, merkle_airdrop);
        emit Transfer(address(0), _multiSigUser, early_liquidity_reward);
        emit Transfer(address(0), _multiSigUser, community);

        start_epoch_time = block.timestamp + ONE_DAY - RATE_REDUCTION_TIME;

        

        mining_epoch = -1;
        rate = 0;
        start_epoch_supply = init_supply;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "LendFlareToken: caller is not the owner");
        _;
    }

    function set_owner(address _owner) public onlyOwner {
        owner = _owner;

        emit SetOwner(_owner);
    }

    function _update_mining_parameters() internal {
        uint256 _rate = rate;
        uint256 _start_epoch_supply = start_epoch_supply;

        start_epoch_time += RATE_REDUCTION_TIME;
        mining_epoch += 1;

        if (_rate == 0) {
            _rate = INITIAL_RATE;
        } else {
            _start_epoch_supply += _rate * RATE_REDUCTION_TIME;
            start_epoch_supply = _start_epoch_supply;
            _rate = (_rate * RATE_DENOMINATOR) / RATE_REDUCTION_COEFFICIENT;
        }

        rate = _rate;

        emit UpdateMiningParameters(
            block.timestamp,
            _rate,
            _start_epoch_supply
        );
    }

    function update_mining_parameters() external {
        require(
            block.timestamp >= start_epoch_time + RATE_REDUCTION_TIME,
            "too soon!"
        );

        _update_mining_parameters();
    }

    function start_epoch_time_write() external returns (uint256) {
        uint256 _start_epoch_time = start_epoch_time;

        if (block.timestamp >= _start_epoch_time + RATE_REDUCTION_TIME) {
            _update_mining_parameters();

            return start_epoch_time;
        }

        return _start_epoch_time;
    }

    function future_epoch_time_write() external returns (uint256) {
        uint256 _start_epoch_time = start_epoch_time;

        if (block.timestamp >= _start_epoch_time + RATE_REDUCTION_TIME) {
            _update_mining_parameters();

            return start_epoch_time + RATE_REDUCTION_TIME;
        }

        return _start_epoch_time + RATE_REDUCTION_TIME;
    }

    function _available_supply() internal view returns (uint256) {
        return start_epoch_supply + (block.timestamp - start_epoch_time) * rate;
    }

    function available_supply() public view returns (uint256) {
        return _available_supply();
    }

    function mintable_in_timeframe(uint256 start, uint256 end)
        external
        view
        returns (uint256)
    {
        require(start <= end, "start > end");

        uint256 to_mint = 0;
        uint256 current_epoch_time = start_epoch_time;
        uint256 current_rate = rate;

        if (end > current_epoch_time + RATE_REDUCTION_TIME) {
            current_epoch_time += RATE_REDUCTION_TIME;
            current_rate =
                (current_rate * RATE_DENOMINATOR) /
                RATE_REDUCTION_COEFFICIENT;
        }

        require(
            end <= current_epoch_time + RATE_REDUCTION_TIME,
            "too far in future"
        );

        // LendFlareToken will not work in 1000 years. Darn!
        for (uint256 i = 0; i < 999; i++) {
            if (end >= current_epoch_time) {
                uint256 current_end = end;

                if (current_end > current_epoch_time + RATE_REDUCTION_TIME) {
                    current_end = current_epoch_time + RATE_REDUCTION_TIME;
                }

                uint256 current_start = start;

                if (current_start >= current_epoch_time + RATE_REDUCTION_TIME) {
                    break;
                } else if (current_start < current_epoch_time) {
                    current_start = current_epoch_time;
                }

                to_mint += current_rate * (current_end - current_start);

                if (start >= current_epoch_time) break;

                current_epoch_time -= RATE_REDUCTION_TIME;
                current_rate =
                    (current_rate * RATE_REDUCTION_COEFFICIENT) /
                    RATE_DENOMINATOR;

                require(
                    current_rate <= INITIAL_RATE,
                    "this should never happen"
                );
            }
        }

        return to_mint;
    }

    function set_minter(address _minter) public onlyOwner {
        minter = _minter;

        emit SetMinter(_minter);
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address user, address spender)
        public
        view
        virtual
        returns (uint256)
    {
        return _allowances[user][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(
                amount,
                "transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].sub(
                subtractedValue,
                "decreased allowance below zero"
            )
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");

        _balances[sender] = _balances[sender].sub(
            amount,
            "transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function mint(address account, uint256 amount) public returns (bool) {
        require(msg.sender == minter);
        require(account != address(0), "mint to the zero address");

        if (block.timestamp >= start_epoch_time + RATE_REDUCTION_TIME) {
            _update_mining_parameters();
        }

        _totalSupply = _totalSupply.add(amount);

        require(
            _totalSupply <= _available_supply(),
            "exceeds allowable mint amount"
        );

        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function burn(uint256 amount) public returns (bool) {
        _balances[msg.sender] = _balances[msg.sender].sub(
            amount,
            "burn amount exceeds balance"
        );

        _totalSupply = _totalSupply.sub(amount);

        emit Transfer(msg.sender, address(0), amount);
    }

    function _approve(
        address user,
        address spender,
        uint256 amount
    ) internal virtual {
        require(user != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");

        _allowances[user][spender] = amount;
        emit Approval(user, spender, amount);
    }
}
