pragma solidity 0.4.11;

/// @title Abstract crowdsale controller contract - Functions to be implemented by crowdsale controller contract
/// @author Karl Floersh - <karl.floersch@consensys.net>
contract CrowdsaleController {
    /*
     * Storage
     */
    Stages public stage;

    enum Stages {
        Deployed,
        Presale,
        MainSale,
        OpenWindow,
        SaleEnded,
        TradingStarted
    }

    /*
     * Public functions
     */
    function finalizeAuction();
    function startOpenWindow(uint256 tokensLeft, uint256 price);
}
