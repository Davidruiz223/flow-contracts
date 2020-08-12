pragma solidity ^0.6.2;

import "./math/ABDKMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/GSN/Context.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/utils/Address.sol";

contract FLOW is Context, IERC20 {
    using SafeMath for uint256;
    using ABDKMath64x64 for int128;
    using Address for address;

    mapping (address => uint256) private _partsOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private constant INITIAL_SUPPLY = 10 * 10**6 * 10**9;
    uint256 private constant MAX_UINT = ~uint256(0);
    uint256 private constant TOTAL_PARTS = MAX_UINT - (MAX_UINT % INITIAL_SUPPLY);

    uint256 private constant CYCLE_SECONDS = 86400;
    uint256 private constant FINAL_CYCLE = 3711;

    struct Era {
        uint256 startCycle;
        uint256 endCycle;
        int128 cycleInflation;
        uint256 finalSupply;
    }

    Era[11] private _eras;
    uint256 private _startTime;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor () public {
        _name = 'Flow Protocol';
        _symbol = 'FLOW';
        _decimals = 9;

        _partsOwned[_msgSender()] = TOTAL_PARTS;
        _initEras();
        _startTime = now;
    }

    function _initEras() private {
        _eras[0] = Era(1, 60, 184467440737095516, 18166966985640902);
        _eras[1] = Era(61, 425, 92233720368547758, 112174713264391144);
        _eras[2] = Era(426, 790, 46116860184273879, 279057783081840914);
        _eras[3] = Era(791, 1155, 23058430092136939, 440268139544969912);
        _eras[4] = Era(1156, 1520, 11529215046068469, 553044069474490613);
        _eras[5] = Era(1521, 1885, 5764607523034234, 619853011328525904);
        _eras[6] = Era(1886, 2250, 2882303761517117, 656228575376038043);
        _eras[7] = Era(2251, 2615, 1441151880758558, 675209948612919169);
        _eras[8] = Era(2616, 2980, 720575940379279, 684905732173838476);
        _eras[9] = Era(2981, 3345, 360287970189639, 689805758238227141);
        _eras[10] = Era(3346, 3710, 180143985094819, 692268913795056564);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function startTime() external view returns(uint256) {
        return _startTime;
    }

    function sendAirdrop(address[] calldata recipients, uint256 airdropAmt) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            transfer(recipients[i], airdropAmt);
        }
    }

    function totalSupply() public view override returns (uint256) {
        return _getSupply(INITIAL_SUPPLY, getCurrentCycle());
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _partsOwned[account].div(_getRate(TOTAL_PARTS, totalSupply()));
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function getCurrentCycle() public view returns (uint256) {
        return _getCycle(_startTime, now);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 currentRate = _getRate(TOTAL_PARTS, totalSupply());
        uint256 partsToTransfer = amount.mul(currentRate);
        _partsOwned[sender] = _partsOwned[sender].sub(partsToTransfer);
        _partsOwned[recipient] = _partsOwned[recipient].add(partsToTransfer);
        emit Transfer(sender, recipient, amount);
    }

    function _getCycle(uint256 startTime, uint256 currentTime) private pure returns(uint256) {
        uint256 secondsElapsed = _getElapsedSeconds(startTime, currentTime);
        uint256 cycle = (secondsElapsed - (secondsElapsed % CYCLE_SECONDS)) / CYCLE_SECONDS + 1;
        if (cycle >= FINAL_CYCLE) return FINAL_CYCLE;
        return cycle;
    }

    function _getElapsedSeconds(uint256 startTime, uint256 currentTime) private pure returns(uint256) {
        return currentTime.sub(startTime);
    }

    function _getSupply(uint256 initialSupply, uint256 currentCycle) private view returns(uint256) {
        uint256 currentSupply = initialSupply;
        for (uint256 i = 0; i < _eras.length; i++) {
            Era memory era = _eras[i];
            if (currentCycle > era.endCycle) {
                currentSupply = era.finalSupply;
            } else {
                currentSupply = _compound(currentSupply, era.cycleInflation, currentCycle.sub(era.startCycle));
                break;
            }
        }
        return currentSupply;
    }

    function _compound(uint256 principle, int128 rate, uint256 periods) private pure returns(uint256){
        uint256 result = ABDKMath64x64.mulu(
                            ABDKMath64x64.pow (
                                ABDKMath64x64.add (
                                0x10000000000000000,
                                rate),
                                periods), principle);
        return result;
    }

    function _getRate(uint256 totalParts, uint256 supply) private pure returns(uint256) {
        return totalParts.div(supply);
    }
}