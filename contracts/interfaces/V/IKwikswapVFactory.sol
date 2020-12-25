pragma solidity >=0.5.0;

interface IKwikswapVFactory {
    function getExchange(address) external view returns (address);
}
