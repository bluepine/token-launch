pragma solidity 0.4.11;


/// @title Abstract crowdsale controller contract - Functions to be implemented by crowdsale controller contract
contract CrowdsaleController {
    function finalizeAuction();
    function startOpenWindow(uint256 dutchAuctionRaise, uint256 tokensLeft, uint256 price);
}
