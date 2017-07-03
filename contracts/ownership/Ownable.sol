pragma solidity 0.4.11;


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control 
 * functions, this simplifies the implementation of "user permissions". 
 */
contract Ownable {
    address public owner;


    /** 
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    function Ownable() {
        owner = msg.sender;
    }


    /**
    * @dev Reverts if called by any account other than the owner. 
    */
    modifier isOwner() {
        if (msg.sender != owner)
          revert();
        _;
    }


    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to. 
    */
    function transferOwnership(address newOwner) isOwner {
        if (newOwner == 0x0)
            revert();
        owner = newOwner;
    }

}
