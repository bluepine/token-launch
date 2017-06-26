pragma solidity 0.4.11;
import './StandardToken.sol';

/// @title Omega token contract
/// @author Karl F - <karl email here>
contract OmegaToken is StandardToken {

    /*
     *  Constants
     */
    string public name = "Omega Token";
    string public symbol = "OM";
    uint8 public constant decimals = 18;

//implement presale later
    function OmegaToken(address dutchAuction, address omegaMultisig) 
        public
    {
        if (dutchAuction  == 0x0 || omegaMultisig == 0x0)
            // Addresses should not be null
            revert();
        uint256 totalSupply     = 9000000 * 10**18;
        balances[dutchAuction]  = 2000000 * 10**18;
        Transfer(0, dutchAuction, balances[dutchAuction]);
        uint256 assignedTokens = balances[dutchAuction];
        // balances[presale]       = 100000 * 10**18;
        // Transfer(0, presale, balances[presale]);
        // assignedTokens += balances[presale]
        balances[omegaMultisig] = 7000000 * 10**18;
        Transfer(0, omegaMultisig, balances[omegaMultisig]);
        assignedTokens += balances[omegaMultisig];

        if (assignedTokens != totalSupply)
            revert();
    }
}