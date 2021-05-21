pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface ISampleProtocol {
  function deposit() external;

  function provideLiquidity(uint256 underlyingAssetamount) external;

  function removeLiquidity(uint256 lpTokenAmount) external;

  function withdraw() external;

  function calculateAccumulateFee(uint256 lpToken) external view returns (uint256);
}
