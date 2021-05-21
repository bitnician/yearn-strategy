pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface ISampleProtocol {

  //This function allows us to provice Liquidity to the protocol
  function provideLiquidity(uint256 underlyingAsset) external;

  //This function allows us to get back the underlying asset + profits
  function removeLiquidity(uint256 lpToken) external;

  //This function will return the rewards that has been accumulated. (same as MasterChef contract of sushiswap)
  function calculateAccumulateFee(uint256 lpToken) external view returns (uint256);
}
