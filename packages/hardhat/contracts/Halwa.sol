pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Halwa is ERC20 {
  constructor() ERC20("Halwa", "HLWA") {
      // This mints to the deployer
      _mint(msg.sender, 1000000 ether);
  }
}