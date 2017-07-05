pragma solidity 0.4.11;

/// @title Abstract dutch auction contract - Functions to be implemented by dutch auction contract
/// @author Karl Floersh - <karl.floersch@consensys.net>
contract DutchAuction {
    /*
     *  Storage
     */
    uint256 public totalReceived;
    mapping (address => uint) public bids;

    /*
     *  Public functions
     */
    function bid(address receiver) payable returns (uint);
    function claimTokens(address receiver);
}
