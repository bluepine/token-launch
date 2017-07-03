pragma solidity 0.4.11;
import './StandardToken.sol';

/// @title Omega token contract
/// @author Karl - <karl.floersch@consensys.net>
contract OmegaToken is StandardToken {

    /*
     *  Constants
     */
    string public constant name = "Omega Token";
    string public constant symbol = "OMT";
    uint8 public constant decimals = 18;

    function OmegaToken(address dutchAuction, address omegaMultisig) 
        public
    {
        if (dutchAuction  == 0x0 || omegaMultisig == 0x0)
            // Addresses should not be null
            revert();
        totalSupply     = 100000000 * 10**18; // 100 million tokens
        balances[dutchAuction]      = 30000000 * 10**18; // 30 million tokens
        uint256 assignedTokens      = balances[dutchAuction];
        Transfer(0, dutchAuction, balances[dutchAuction]);
        balances[omegaMultisig]     = 70000000 * 10**18; // 70 million tokens
        Transfer(0, omegaMultisig, balances[omegaMultisig]);
        assignedTokens             += balances[omegaMultisig];

        if (assignedTokens != totalSupply)
            revert();
    }
}