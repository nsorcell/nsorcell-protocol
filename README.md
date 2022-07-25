# Lottery 6

This project is a hardhat smartcontract lottery, but a little different than the tutorial projects. Only on Rinkeby for now.

## Rules:
- Choose 6 numbers from 45.
- Entry fee is configurable, by default 0.1 ETH
- By entering once the entry fee is paid, but the player is eligible to subsequent draws, until somebody wins.
- By hitting all six numbers the winner takes all balance
- If there are multiple winners, the prize pool is evenly distributed.

## Features: 
- Upkeep is done by Chainlink Keepers.
- Drawing random numbers is done by Chainlink VRF (Verifiable Randomness).
- Automatically verified contracts.
- Mocks are deployed on local chains.
- Contains an npm package under /package, which is installable by `yarn add / npm install @nsorcell/protocol`

## Future ideas:
- Extend the draw interval to about a day or more, and stake the prizepool in a staking protocol
- Create an ERC20 token, which will be minted to players in-game, and could be used to e.g pay etry
- Betting on how many numbers, the players hit
- Add feature to distribute some % of the prizepool from up to 3 hits.


```shell
yarn hardhat node // for local chain (runs all deployments, + mocks)
yarn hardhat deploy -- network [network] // (runs all deployments except mocks)
yarn typechain:package // generates typechain output for the @nsorcell/protocol package

cd package && yarn build // create a production build of the @nsorcell/protocol package
npm version [patch|minor|major] // upgrade the version of the @nsorcell/procotol package
npm publish --access public // publish npm package to npmjs
```
