// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract PooledDerivative {
    mapping(address => uint256) private bookLongSide;
    mapping(address => uint256) private bookShortSide;
    address[] private investorsLongSide;
    address[] private investorsShortSide;

    uint256 public totalBalanceLongSide;
    uint256 public totalBalanceShortSide;

    string description;
    uint256 lastPrice;
    uint256 minUsd = 50 * 10**18;
    uint256 eqTolerance = 5;

    AggregatorV3Interface public underlyingPriceFeed;
    AggregatorV3Interface public ethUsdPriceFeed;

    constructor(
        address _underlyingPriceFeed,
        address _ethUsdPriceFeed,
        string memory _description
    ) public {
        underlyingPriceFeed = AggregatorV3Interface(_underlyingPriceFeed);
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        description = _description;
    }

    function getContractDescription() public view returns (string memory) {
        // print a description of the derivative
        return description;
    }

    function getStatus() public view returns (string memory) {
        if (
            totalBalanceShortSide >
            ((100 + eqTolerance) / 100) * totalBalanceLongSide
        ) {
            return "Short side is underexposed";
        } else if (
            totalBalanceLongSide >
            ((100 + eqTolerance) / 100) * totalBalanceShortSide
        ) return "Long side is underexposed";
        else {
            return "Contract is hedged";
        }
    }

    function enterLongSide() public payable {
        requireMinimum(msg.value);
        investorsLongSide.push(msg.sender);
        bookLongSide[msg.sender] += msg.value;
        totalBalanceLongSide += msg.value;
    }

    function enterShortSide() public payable {
        requireMinimum(msg.value);
        investorsLongSide.push(msg.sender);
        bookLongSide[msg.sender] += msg.value;
        totalBalanceShortSide += msg.value;
    }

    function requireMinimum(uint256 amountEth) internal {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 amountUsd = amountEth / (uint256(price) * 10**10);
        require(amountUsd > minUsd);
    }

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    function settlementFunction() public {}

    function callSettlement() public {}

    function withdrawFunds() public {}

    function terminateContract() public {}

    function computeFees() public {}

    function transferFees() public {}

    function computeAmoutNeededForHedge() public view {}
}
