// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address account, uint256 amount) external;
}

contract BotInteractions {
    address public owner;
    IUniswapV2Router public uniswapRouter;

    event FundsTransferred(address indexed from, address indexed to, uint256 amount);
    event TokenTransferred(address indexed from, address indexed to, uint256 amount, address token);
    event TokenSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event Received(address indexed from, uint256 amount);
    event TokenApproved(address indexed owner, address spender, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Fallback to receive Ether
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function setUniSwapRouter(address _uniswapRouter) external onlyOwner {
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
    }

    /**
     * Transfer native blockchain currency (like ETH on Ethereum)
     */
    function transferFunds(address payable _to) external payable {
        require(msg.value > 0, "Must send some value");
        _to.transfer(msg.value);
        emit FundsTransferred(msg.sender, _to, msg.value);
    }

    /**
     * Transfer ERC20 tokens in a single function call
     */
    function transferERC20(address _tokenAddress, address _to, uint256 _amount) external {
        IERC20 token = IERC20(_tokenAddress);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(token.transferFrom(msg.sender, _to, _amount), "Transfer failed");
        emit TokenTransferred(msg.sender, _to, _amount, _tokenAddress);
    }

    /**
     * Approve tokens for spending by a specific address
     */
    function approveERC20(address _tokenAddress, address _spender, uint256 _amount) external {
        IERC20 token = IERC20(_tokenAddress);
        require(token.approve(_spender, _amount), "Approval failed");
        emit TokenApproved(msg.sender, _spender, _amount);
    }

    /**
     * Swap tokens using Uniswap in a single function
     */
    function swapTokens(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external {
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).approve(address(uniswapRouter), _amountIn);

        address[] memory path;
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        uint deadline = block.timestamp + 300; // 5 minutes deadline
        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            msg.sender,
            deadline
        );

        emit TokenSwapped(msg.sender, _tokenIn, _tokenOut, _amountIn, amounts[1]);
    }

    /**
     * Deposit native currency (for contract storage)
     */
    function depositFunds() external payable {
        require(msg.value > 0, "No funds sent");
        emit Received(msg.sender, msg.value);
    }

    /**
     * Withdraw all native currency from contract (owner-only)
     */
    function withdrawAllFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
    }

    /**
     * Withdraw specific amount of native currency (owner-only)
     */
    function withdrawFunds(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract balance");
        payable(owner).transfer(amount);
    }

    /**
     * Withdraw specific ERC20 tokens from the contract (owner-only)
     */
    function withdrawERC20(address _tokenAddress, uint256 _amount) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        require(token.balanceOf(address(this)) >= _amount, "No sufficient token balance");
        token.transfer(owner, _amount);
    }

    /**
     * Check contract balance for native currency
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * Check user's ERC20 token balance
     */
    function getERC20Balance(address _tokenAddress, address _user) external view returns (uint256) {
        IERC20 token = IERC20(_tokenAddress);
        return token.balanceOf(_user);
    }

    /**
     * Get expected swap amount for a token pair
     */
    function getExpectedSwapAmount(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) external view returns (uint256) {
        address[] memory path;

        path[0] = _tokenIn;
        path[1] = _tokenOut;

        uint[] memory amountsOut = uniswapRouter.getAmountsOut(_amountIn, path);
        return amountsOut[1];
    }
}
