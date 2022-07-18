// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";

contract Registry is Ownable {
  address private s_lottery6;

  function updateLottery6Address(address lottery6) public onlyOwner {
    s_lottery6 = lottery6;
  }

  function getLottery6Address() public view returns (address) {
    return s_lottery6;
  }
}
