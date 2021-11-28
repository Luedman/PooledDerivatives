# Pooled Derivatives

### Overview
Chainlink Hackaton 2021

1. This project provides a framework for on-chain derivatives that are based on liquidity pools instead of counterparty settlement

2. An automated hedging mechanism aims to ensure that the settlement remains stable

3. The contracts features three parties: two parties taking long and short exposure repectivly and one party providing the hedge

Idea: Inclunding a hedging party addresses the issue of synthetic on-chain assets that have instable exposure to the underlying

![Overview](./documentation/overview.png)

### Functions

#### constructor

constructor(
        address _underlyingPriceFeed,
        string memory _description,
        uint256 _timeStampExpiry,
        uint256 _annualizedFee10000
    )

#### getContractDescription (public)
Prints a description of the derivative. Essentially with underlyng is used and the specifics of the settlement function. Depending on the variant, also information about the time constraints of settlement could be given. E.g. settlement could only be allowed on certain dates or occur only once after a given point in time. 

#### getResidual (public)
Computes the residual (green bar in the chart). This is useful information for the potential hedging providers and investors. 

#### updateBooks (intenal)
Update the long, short and hedge books. Especially the share of each investor in the book are computed. This is neede in order to allocate losses and gains accordingly. 

#### enterLongSide, enterShortSide, provideHedgeCapital (public payable)
Function that where investors and hedge providers can fund the pooled derivative with ETH.

#### callSettlement (public)
That function gets the latest price data and and time diffrence and calls the settlement function with this information. Can be conditing on timestamps

#### settlementFunction, payoffFunction (internal)
Computes the settlement given the underlying price change and and time diffrence. Easy examples would be 1:1 price trackers of stocks or exchange rates but also more complex variants are possible. This could include 1:1 tracker that in a diffrent currency (e.g. 1:1 tracker of TESLA in Japanese Yen) or leverage, eurpean/american calls (with a cap), asian options or even structured products. Obviously the hedging requirements and collateral condition could potentially needed to be adapted. The only requirement would be that the loss or commitment of one side does not exceed the invested capital. 

In pratice, one would take the implementation and instentia a child class witch would override the settlementFunction or payoffFunction respectivly.

#### withdrawFunds (public payable)
Settles the contract and returns the balance to the investor or hedging provider

#### terminateContract (public)
Gives the owner of the contract the possibility to terminate the contract and return all funds to the investors. This can be removed once the contracts are properly tested. 

#### resetHedge (internal)
Resets the hedge by removing the balances used for hedging from the respective books.

#### hedgeContract (internal)
Reset the hedge, computes the residual and hedges the contract again. Is used after settlement. If there is too much balances available, the parties provide a hegge witch is proportial to their provided ETH balance. 

#### transferFees (internal)
Computes the feed for a given time period and transfers them to the hedging parties according to the balance that they provided for hedging. 
