// SPDX-License-Identifier: AGPL-3.0
// Feel free to change the license, but this is what we use

// Feel free to change this version of Solidity. We support >=0.6.0 <0.7.0;
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries

import '@yearnvaults/contracts/contracts/BaseStrategy.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import './interfaces/IUniswapRouter.sol';
import './interfaces/ISampleProtocol.sol';

contract Strategy is BaseStrategy {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  ISampleProtocol public sampleProtocol;
  IERC20 public lpToken;
  IUniswapRouter public uniswapRouter;
  address public weth;

  constructor(
    address _vault,
    address _protocol,
    address _lpToken,
    address _uniswapRouter,
    address _weth
  ) public BaseStrategy(_vault) {
    sampleProtocol = ISampleProtocol(_protocol);
    lpToken = IERC20(_lpToken);
    uniswapRouter = IUniswapRouter(_uniswapRouter);
    weth = _weth;

    want.safeApprove(address(sampleProtocol), uint256(-1));
    lpToken.safeApprove(address(this), uint256(-1));
  }

  function name() external view override returns (string memory) {
    return 'StrategySampleProtocolToken';
  }

  function estimatedTotalAssets() public view override returns (uint256) {
    uint256 lpBalance = lpToken.balanceOf(address(this));
    return want.balanceOf(address(this)).add(sampleProtocol.calculateAccumulateFee(lpBalance));
  }

  function balanceOfWant() public view returns (uint256) {
    return IERC20(want).balanceOf(address(this));
  }

  function ethToWant(uint256 _amtInWei) public view returns (uint256) {
    if (_amtInWei == 0) {
      return 0;
    }
    address[] memory path = new address[](2);
    path[0] = address(weth);
    path[1] = address(want);
    uint256[] memory amounts = IUniswapRouter(uniswapRouter).getAmountsOut(_amtInWei, path);

    return amounts[1];
  }

  function prepareReturn(uint256 _debtOutstanding)
    internal
    override
    returns (
      uint256 _profit,
      uint256 _loss,
      uint256 _debtPayment
    )
  {
    _profit = 0;
    _loss = 0;

    uint256 totalDebt = vault.strategies(address(this)).totalDebt;
    uint256 totalAsstes = estimatedTotalAssets();
    uint256 wantBalance = balanceOfWant();

    if (totalAsstes > totalDebt) {
      _profit = totalAsstes.sub(totalDebt);
    } else {
      _loss = totalDebt.sub(totalAsstes);
    }

    //Profit from liquidity mining + _debtOutstanding(the amount that vault needs back from the strategy)
    uint256 toFree = _debtOutstanding.add(_profit);

    if (toFree > wantBalance) {
      //`toFree` is greater than `want` balance, so we need to wihdraw some `want` from protocol
      uint256 withdrawalAmount = toFree.sub(wantBalance);

      //calculate how much LP token should send to protocol to withdraw desired `want`
      uint256 totalLpTokens = lpToken.balanceOf(address(this));
      uint256 desireLpToken = uint256(withdrawalAmount).mul(totalLpTokens).div(totalAsstes) + 1;

      //Send Lp token to protocol and recieve back the want
      sampleProtocol.removeLiquidity(desireLpToken);

      uint256 newWantBalance = balanceOfWant();
      uint256 freedAmountFromProtocol = newWantBalance.sub(wantBalance);

      uint256 withdrawalLoss = toFree.sub(freedAmountFromProtocol);

      if (withdrawalLoss < _profit) {
        _profit = _profit.sub(withdrawalLoss);
      } else {
        _loss = _loss.add(withdrawalLoss.sub(_profit));
        _profit = 0;
      }
    }

    wantBalance = balanceOfWant();

    if (_profit > wantBalance) {
      _debtPayment = 0;
    } else if (_debtOutstanding > 0 && _debtOutstanding.add(_profit) > wantBalance) {
      _debtPayment = wantBalance.sub(_profit);
    } else {
      _debtPayment = _debtOutstanding;
    }
  }

  function adjustPosition(uint256 _debtOutstanding) internal override {
    uint256 wantBalance = balanceOfWant();
    if (wantBalance > _debtOutstanding) {
      uint256 excessWant = wantBalance.sub(_debtOutstanding);

      sampleProtocol.provideLiquidity(excessWant);
    }
  }

  function liquidatePosition(uint256 _amountNeeded)
    internal
    override
    returns (uint256 _liquidatedAmount, uint256 _loss)
  {
    uint256 wantBalance = balanceOfWant();

    if (_amountNeeded > wantBalance) {
      _liquidatedAmount = wantBalance;
      _loss = _amountNeeded.sub(wantBalance);
    } else {
      _liquidatedAmount = wantBalance.sub(_amountNeeded);
      _loss = 0;
    }
  }

  function prepareMigration(address _newStrategy) internal override {}

  function protectedTokens() internal view override returns (address[] memory) {}
}
