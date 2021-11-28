// SPDX-License-Identifier: MIT
// Author: Lukas Schreiner
// Chainlink Hackaton 2021

pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract PooledDerivative {
    // address -> (balance, partition of total balance)
    mapping(address => uint256[2]) public bookLongSide;
    mapping(address => uint256[2]) public bookShortSide;
    // address -> (balance,
    //              partition of total hedgeContract balance,
    //              balance used for hegding,
    //              partition of total balance used for hegding)
    mapping(address => uint256[4]) public bookHedgeProviders;

    address payable[] public investorsLongSide;
    address payable[] public investorsShortSide;
    address payable[] hedgeProviders;

    uint80 previousRoundId;
    uint256 previousPrice;
    uint256 previousTimeStamp;

    uint256 public totalBalanceLongSide;
    uint256 public totalBalanceShortSide;
    uint256 public totalBalanceHedgingCapital;
    uint256 public totalBalanceHedgingCapitalExposed;

    string description;
    uint256 lastPrice;
    uint256 minUsd = 50 * 10**18;
    uint256 eqTolerance = 5;
    uint256 basisPoint = 10000;
    uint256 hundredPercent = 100 * basisPoint;

    AggregatorV3Interface public underlyingPriceFeed;

    address public contractOwner;
    uint256 timeStampExpiry;
    uint256 annualizedFee;

    event NewFunding(address _address, uint256 balance, string book);
    event ConratctStatus(string status, uint256 balance);
    event BookStatus(uint256 balanceLong, uint256 balanceShort);

    constructor(
        address _underlyingPriceFeed,
        string memory _description,
        uint256 _timeStampExpiry,
        uint256 _annualizedFee10000 // e.g. to get 4.55% _annualizedFee10000 = 455
    ) public {
        underlyingPriceFeed = AggregatorV3Interface(_underlyingPriceFeed);
        description = _description;
        contractOwner = msg.sender;
        timeStampExpiry = _timeStampExpiry;
        annualizedFee = _annualizedFee10000;

        (
            uint80 _latestRoundID,
            int256 _latestPrice,
            uint256 _latestTimestamp,
            ,

        ) = underlyingPriceFeed.latestRoundData();

        uint256 _ulatestPrice = abs(_latestPrice);

        previousRoundId = _latestRoundID;
        previousPrice = _ulatestPrice;
        previousTimeStamp = _latestTimestamp;
    }

    function getContractDescription() public view returns (string memory) {
        // print a description of the derivative
        return description;
    }

    function getResidual() public view returns (uint8, uint256) {
        // status: long: 1, short: 2, equilibrium: 0
        int256 bookdiff = int256(totalBalanceShortSide) -
            int256(totalBalanceLongSide);
        uint256 bookResidual = abs(bookdiff);
        // Case 1: Long side is underexposed
        if (
            totalBalanceShortSide >
            ((basisPoint + eqTolerance) / basisPoint) * totalBalanceLongSide
        ) {
            return (1, bookResidual);
            // Case 2: Short side is underexposed
        } else if (
            totalBalanceLongSide >
            ((basisPoint + eqTolerance) / basisPoint) * totalBalanceShortSide
        ) {
            return (2, bookResidual);
        } else {
            // Case 0: Equilibrium
            return (0, 0);
        }
    }

    function updateBooks() internal {
        // ToDo: Simplify with general function
        uint256 sumWeights = 0;
        totalBalanceLongSide = 0;
        totalBalanceShortSide = 0;
        totalBalanceHedgingCapital = 0;

        uint256 balance;
        uint256 weight;

        for (uint256 i = 0; i < investorsLongSide.length; i++) {
            balance = bookLongSide[investorsLongSide[i]][0];
            totalBalanceLongSide += balance;
        }

        for (uint256 i = 0; i < investorsLongSide.length; i++) {
            balance = bookLongSide[investorsLongSide[i]][0];
            weight = (balance / totalBalanceLongSide) * basisPoint;
            bookLongSide[investorsLongSide[i]][1] = weight;
            sumWeights += weight;
        }

        //require(sumWeights <= hundredPercent,"LongSide: Weights do not sum to 100%");

        sumWeights = 0;
        for (uint256 i = 0; i < investorsShortSide.length; i++) {
            balance = bookShortSide[investorsShortSide[i]][0];
            totalBalanceShortSide += balance;
        }
        for (uint256 i = 0; i < investorsShortSide.length; i++) {
            weight = (balance / totalBalanceShortSide) * basisPoint;
            bookShortSide[investorsShortSide[i]][1] = weight;
            sumWeights += weight;
        }
        //require(sumWeights <= hundredPercent, "LongSide: Weights do not sum to 100%");

        sumWeights = 0;
        for (uint256 i = 0; i < hedgeProviders.length; i++) {
            balance = bookHedgeProviders[hedgeProviders[i]][0];
            sumWeights += weight;
        }

        for (uint256 i = 0; i < hedgeProviders.length; i++) {
            weight = (balance / totalBalanceHedgingCapital) * basisPoint;
            bookHedgeProviders[investorsShortSide[i]][1] = weight;

            totalBalanceHedgingCapital += balance;
        }
        //require(sumWeights <= hundredPercent,"LongSide: Weights do not sum to 100%");
        emit BookStatus(totalBalanceLongSide, totalBalanceShortSide);
    }

    // ToDo: Summarize in one function
    function enterLongSide() public payable {
        investorsLongSide.push(msg.sender);
        bookLongSide[msg.sender][0] += msg.value;
        totalBalanceLongSide += msg.value;
        emit NewFunding(msg.sender, msg.value, "long");
        updateBooks();
    }

    function enterShortSide() public payable {
        investorsShortSide.push(msg.sender);
        bookShortSide[msg.sender][0] += msg.value;
        totalBalanceShortSide += msg.value;
        emit NewFunding(msg.sender, msg.value, "short");
        updateBooks();
    }

    function provideHedgeCapital() public payable {
        hedgeProviders.push(msg.sender);
        bookHedgeProviders[msg.sender][0] += msg.value;
        totalBalanceHedgingCapital += msg.value;
        emit NewFunding(msg.sender, msg.value, "hedge");
        updateBooks();
    }

    function abs(int256 x) private pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function callSettlement() public {
        (
            uint80 _latestRoundID,
            int256 _latestPrice,
            uint256 _latestTimestamp,
            ,

        ) = underlyingPriceFeed.latestRoundData();

        // The settlement can be time conditioned e.g. only at time expiry (see European Options)
        require(
            timeStampExpiry < block.timestamp || timeStampExpiry == 0,
            "Settlement cannot be excecuted because settlement expiry requirement is not fullfilled"
        );

        uint256 _ulatestPrice = abs(_latestPrice);

        settlementFunction(
            previousPrice,
            previousTimeStamp,
            _ulatestPrice,
            _latestTimestamp
        );

        previousRoundId = _latestRoundID;
        previousPrice = _ulatestPrice;
        previousTimeStamp = _latestTimestamp;
    }

    function settlementFunction(
        uint256 _previousPrice,
        uint256 _previousTimestamp,
        uint256 _latestPrice,
        uint256 _latestTimestamp
    ) internal {
        require(
            totalBalanceLongSide > 0 && totalBalanceShortSide > 0,
            "Long or Side does not have any funds, settelement not possible"
        );
        transferFees(_latestTimestamp, _previousTimestamp);

        uint256 timeDifference = (_latestTimestamp - _previousTimestamp);
        require(timeDifference > 0, "TimeDiffrence");
        require(_previousPrice > 0, "previous Price");
        uint256 asset_return = (_latestPrice - _previousPrice) / _previousPrice;
        uint256 asset_return_annualized = ((asset_return *
            (365 * 24 * 60 * 60)) / timeDifference) * basisPoint;
        require(asset_return_annualized > 0, "asset_return_annualized");

        uint256 returnLongSide = payoffFunction(
            timeDifference,
            asset_return_annualized
        );

        uint256 pnlLongSide = (totalBalanceLongSide * returnLongSide) /
            basisPoint;

        // ToDo: Check Long PnL == Short PnL
        for (uint256 i = 0; i < investorsLongSide.length; i++) {
            bookLongSide[investorsLongSide[i]][0] +=
                pnlLongSide *
                bookLongSide[investorsLongSide[i]][1];
        }
        for (uint256 i = 0; i < investorsShortSide.length; i++) {
            bookLongSide[investorsShortSide[i]][0] -=
                pnlLongSide *
                bookLongSide[investorsShortSide[i]][1];
        }
        hedgeContract();
        updateBooks();
    }

    function payoffFunction(
        uint256 timeDifference,
        uint256 asset_return_annualized10000
    ) public view returns (uint256) {
        // This payoff function tracks the underlying 1:1
        return (asset_return_annualized10000 * timeDifference) / timeDifference;
    }

    function withdrawFunds() public payable {
        callSettlement();

        uint256 refund = bookLongSide[msg.sender][0] +
            bookShortSide[msg.sender][0];
        msg.sender.transfer(refund);
        bookLongSide[msg.sender][0] = 0;
        bookShortSide[msg.sender][0] = 0;
        bookLongSide[msg.sender][1] = 0;
        bookShortSide[msg.sender][1] = 0;
        updateBooks();
    }

    function terminateContract() public {
        require(msg.sender == contractOwner);
        callSettlement();
        for (uint256 i = 0; i < investorsLongSide.length; i++) {
            investorsLongSide[i].transfer(
                bookLongSide[investorsLongSide[i]][0]
            );
        }

        for (uint256 i = 0; i < investorsShortSide.length; i++) {
            investorsShortSide[i].transfer(
                bookShortSide[investorsShortSide[i]][0]
            );
        }
    }

    function resetHedge() internal {
        for (uint256 i = 0; i < hedgeProviders.length; i++) {
            address hedgeProvider = hedgeProviders[i];
            bookLongSide[hedgeProvider][0] = 0;
            bookShortSide[hedgeProvider][0] = 0;
            bookHedgeProviders[hedgeProvider][3] = 0;
        }
        updateBooks();
    }

    function hedgeContract() internal {
        uint256 hedgeProvided;
        resetHedge();

        (uint8 status, uint256 residual) = getResidual();
        // Case 0: Equilibrium
        require(status != 0, "Contract is in equlibrium");
        // Case 1: Long side is underexposed
        if (status == 1) {
            emit ConratctStatus("Long side is underexposed", residual);
            for (uint256 i = 0; i < hedgeProviders.length; i++) {
                hedgeProvided =
                    (residual * bookLongSide[hedgeProviders[i]][1]) /
                    basisPoint;
                bookLongSide[hedgeProviders[i]][0] += hedgeProvided;
                bookHedgeProviders[hedgeProviders[i]][2] = hedgeProvided;
                bookHedgeProviders[hedgeProviders[i]][3] = status;
            }
            // Case 2: Long side is underexposed
        } else if (status == 2) {
            emit ConratctStatus("Short side is underexposed", residual);
            for (uint256 i = 0; i < hedgeProviders.length; i++) {
                hedgeProvided +=
                    (residual * bookShortSide[hedgeProviders[i]][1]) /
                    basisPoint;
                bookLongSide[hedgeProviders[i]][0] += hedgeProvided;
                bookHedgeProviders[hedgeProviders[i]][2] = hedgeProvided;
                bookHedgeProviders[hedgeProviders[i]][3] = status;
            }
        }
    }

    function transferFees(uint256 latestTimestamp, uint256 previousTimestamp)
        internal
    {
        uint256 accountFee;
        uint256 totalFees;
        uint256 timeDifference = (latestTimestamp - previousTimestamp) /
            60 /
            60 /
            24;

        for (uint256 i = 0; i < investorsLongSide.length; i++) {
            accountFee =
                bookLongSide[investorsLongSide[i]][0] *
                (annualizedFee / basisPoint)**(timeDifference / 365);
            bookLongSide[investorsLongSide[i]][0] -= accountFee;
            totalFees += accountFee;
        }

        for (uint256 i = 0; i < investorsShortSide.length; i++) {
            accountFee =
                bookShortSide[investorsShortSide[i]][0] *
                (annualizedFee / basisPoint)**(timeDifference / 365);
            bookShortSide[investorsShortSide[i]][0] -= accountFee;
            totalFees += accountFee;
        }

        for (uint256 i = 0; i < hedgeProviders.length; i++) {
            bookHedgeProviders[hedgeProviders[i]][0] +=
                bookHedgeProviders[hedgeProviders[i]][3] *
                totalFees;
        }
    }
}
