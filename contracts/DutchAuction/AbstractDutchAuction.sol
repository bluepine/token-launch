pragma solidity 0.4.11;


/// @title Abstract dutch auction contract - Functions to be implemented by dutch auction contract
contract DutchAuction {
    function bid(address receiver) payable returns (uint);
    function claimTokens(address receiver);
}
