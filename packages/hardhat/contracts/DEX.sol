pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DEX {
  using SafeMath  for uint256;
  uint256 public HALWA_SUPPLY = 1000000 * 10**18;
  IERC20 token;
  IERC20 lpToken;

  AggregatorV3Interface internal priceFeed;

  uint256 public totalLiquidity;
  mapping (address => uint256) public liquidity;

  address[] public lp;
  mapping(address => uint256) public lpFees;
  uint256 public totalFees;

  constructor(address token_addr, address lpToken_addr) {
    token = IERC20(token_addr);
    lpToken = IERC20(lpToken_addr);
    // rinkeby - 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
    // kovan - 0x9326BFA02ADD2366b30bacB125260Af641031331
    priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
  }

  function init(uint256 tokens) public payable returns (uint256) {
    require(totalLiquidity == 0, "DEX: init - already has liquidity");
    totalLiquidity = address(this).balance;
    liquidity[msg.sender] = totalLiquidity;
    require(token.transferFrom(msg.sender, address(this), tokens));
    require(lpToken.transferFrom(msg.sender, address(this), 1000000 * 10**18));
    return totalLiquidity;
  }

  function price(uint256 input_amount, uint256 input_reserve, uint256 output_reserve) public view returns (uint256) {
    uint256 input_amount_with_fee = input_amount * 997 / 1000;
    return (input_amount_with_fee  * output_reserve) / (input_reserve + input_amount_with_fee);
  }

  function calLPFees(uint256 input_amount) public view returns (uint256) {
    // (,int256 price,,,) = priceFeed.latestRoundData();
    // price / 10**8;
    uint256 scaledPrice = 283865519773 / uint256(10**8);
    uint256 fee = (input_amount * 25 * scaledPrice) / 10000;
    if (totalFees + fee > HALWA_SUPPLY) return 0;
    else return fee;
  }

  function distLPFees(uint256 _amt) public returns (uint256) {
    uint256 txFees = calLPFees(_amt);
    totalFees += txFees;
    for (uint256 i = 0; i < lp.length; i++) {
      uint256 liq_ratio_bps = liquidity[lp[i]] * 10000 / totalLiquidity;
      lpFees[lp[i]] += txFees * liq_ratio_bps / 10000;
    }
  }

  function ethToToken() public payable returns (uint256) {
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 tokens_bought = price(msg.value, address(this).balance - msg.value, token_reserve);
    require(token.transfer(msg.sender, tokens_bought));
    distLPFees(msg.value);
    return tokens_bought;
  }

  function tokenToEth(uint256 tokens) public returns (uint256) {
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_bought = price(tokens, token_reserve, address(this).balance);
    (bool sent, ) = msg.sender.call{value: eth_bought}("");
    require(sent, "Failed to send user eth.");
    require(token.transferFrom(msg.sender, address(this), tokens));
    distLPFees(tokens);
    return eth_bought;
  }

  function deposit() public payable returns (uint256) {
    uint256 eth_reserve = address(this).balance - msg.value;
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 token_amount = ((msg.value * token_reserve) / eth_reserve) + 1;
    uint256 liquidity_minted = (msg.value * totalLiquidity) / eth_reserve;

    if (liquidity[msg.sender] == 0) {
      lp.push(msg.sender);
    }

    liquidity[msg.sender] += liquidity_minted;
    totalLiquidity += liquidity_minted;
    require(token.transferFrom(msg.sender, address(this), token_amount));
    return liquidity_minted;
  }

  function withdraw(uint256 liq_amount) public returns (uint256, uint256) {
    require(liq_amount <= liquidity[msg.sender], "DEX: can't withdraw more than you deposited");
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_amount = (liq_amount * address(this).balance) / totalLiquidity;
    console.log("token_reserve: %s,  eth_amount: %s, liq_amount: %s", token_reserve, eth_amount, liq_amount);
    uint256 token_amount = (token_reserve * liq_amount) / totalLiquidity;
    liquidity[msg.sender] -= liq_amount;

    if (liquidity[msg.sender] == 0) {
      uint256 i;
      for (i = 0; i < lp.length; i++) {
        if (lp[i] == msg.sender) {
          delete lp[i];
          break;
        }
      }
      console.log("lp: %d", i);
      for (i = i + 1; i < lp.length; i++) {
        lp[i - 1] = lp[i];
      }
      lp.pop();
    }
    totalLiquidity -= liq_amount;

    (bool sent,) = msg.sender.call{value: eth_amount}("");
    require(sent, "Failed to send user eth.");
    require(token.transfer(msg.sender, token_amount));
    return (eth_amount, token_amount);
  }

  function getLiquidityProviders() public view returns (address[] memory) {
    return lp;
  }

  function claimFees() public returns (uint256) {
    uint256 fee_to_claim = lpFees[msg.sender];
    require(fee_to_claim > 0, "DEX: no fees to claim");
    lpFees[msg.sender] = 0;
    console.log("fee_to_claim: %s", fee_to_claim);
    require(lpToken.transfer(msg.sender, fee_to_claim));
    return fee_to_claim;
  }

}