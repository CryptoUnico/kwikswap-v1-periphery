pragma solidity =0.6.6;

import '@kwikswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/IKwikswapV1Migrator.sol';
import './interfaces/V/IKwikswapVFactory.sol';
import './interfaces/V/IKwikswapVExchange.sol';
import './interfaces/IKwikswapV1Router01.sol';
import './interfaces/IERC20.sol';

contract KwikswapV1Migrator is IKwikswapV1Migrator {
    IKwikswapVFactory immutable factoryV;
    IKwikswapV1Router01 immutable router;

    constructor(address _factoryV, address _router) public {
        factoryV = IKwikswapVFactory(_factoryV);
        router = IKwikswapV1Router01(_router);
    }

    // needs to accept ETH from any v exchange and the router. ideally this could be enforced, as in the router,
    // but it's not possible because it requires a call to the v factory, which takes too much gas
    receive() external payable {}

    function migrate(address token, uint amountTokenMin, uint amountETHMin, address to, uint deadline)
        external
        override
    {
        IKwikswapVExchange exchangeV = IKwikswapVExchange(factoryV.getExchange(token));
        uint liquidityV = exchangeV.balanceOf(msg.sender);
        require(exchangeV.transferFrom(msg.sender, address(this), liquidityV), 'TRANSFER_FROM_FAILED');
        (uint amountETHV, uint amountTokenV) = exchangeV.removeLiquidity(liquidityV, 1, 1, uint(-1));
        TransferHelper.safeApprove(token, address(router), amountTokenV);
        (uint amountTokenV1, uint amountETHV1,) = router.addLiquidityETH{value: amountETHV}(
            token,
            amountTokenV,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
        if (amountTokenV > amountTokenV1) {
            TransferHelper.safeApprove(token, address(router), 0); // be a good blockchain citizen, reset allowance to 0
            TransferHelper.safeTransfer(token, msg.sender, amountTokenV - amountTokenV1);
        } else if (amountETHV > amountETHV1) {
            // addLiquidityETH guarantees that all of amountETHV or amountTokenV will be used, hence this else is safe
            TransferHelper.safeTransferETH(msg.sender, amountETHV - amountETHV1);
        }
    }
}
