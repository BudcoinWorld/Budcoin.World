

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}


contract TimeLockedWallet {


    address payable public immutable owner;
    uint256 public createdAt; // lock create date
    IERC20 public tokenContract;
    address public toppingContract;



    constructor(IERC20 _tokenContract, address _toppingContract) {

      owner = payable(msg.sender);
      createdAt = block.timestamp;
      tokenContract = _tokenContract;
      toppingContract = _toppingContract;
   }



    // callable by anyone, after specified time, only for Tokens implementing ERC20
    function withdrawTokens() public {
       uint256 tokenBalance = 50000 * 10**18;
       require(block.timestamp >= createdAt + 2592000); //30 days in seconds
       IERC20 token = IERC20(tokenContract);
       token.transfer(toppingContract, tokenBalance);
       emit WithdrewTokens(IERC20(tokenContract), msg.sender, tokenBalance);
       createdAt = block.timestamp;
    }



    event Received(address from, uint256 amount);

    event WithdrewTokens(IERC20 tokenContract, address to, uint256 amount);
}
