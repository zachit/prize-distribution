# Prize Distribution
Ethereum smart contracts for decentralized distribution of prizes.

Useful for running competitions where multiple entrants compete for a shared prize pool.

The prizes are allocated algorithmically using a modified Fibonacci distribution, such that a larger portion of the prize pool is skewed towards the players that rank highest.

## Compile

Run `truffle compile` to build the contracts.

## Testing

Run `truffle test` to run the tests.

## Code Coverage

Run `truffle run coverage` to run tests and measure code coverage. The HTML coverage report will be available at `coverage/index.html`.

## Dependencies

The following `npm` dependencies are required:

* `solidity-coverage`
* `ganache-time-traveler`
