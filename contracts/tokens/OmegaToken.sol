pragma solidity 0.4.11;
import './StandardToken.sol';

/// @title Omega token contract
/// @author Karl Floersh- <karl.floersch@consensys.net>
contract OmegaToken is StandardToken {
    /*
     *  Constants
     */
    string public constant name = "Omega Token";
    string public constant symbol = "OMG";
    uint8 public constant decimals = 18;

    /*
     * Public functions
     */
    function OmegaToken(address dutchAuction, address omegaMultisig) 
        public
    {
        if (dutchAuction  == 0x0 || 
            omegaMultisig == 0x0 ||
            msg.sender    == 0x0)
            // Addresses should not be null
            revert();
        address crowdsaleController = msg.sender;
        totalSupply                     = 100000000 * 10**18; // 100 million tokens
        balances[dutchAuction]          = 23700000 * 10**18; // 23.7 million tokens
        uint256 assignedTokens          = balances[dutchAuction];
        Transfer(0, dutchAuction, balances[dutchAuction]);
        balances[crowdsaleController]   = 6300000 * 10**18; // 6.3 million
        assignedTokens                 += balances[crowdsaleController];
        Transfer(0, dutchAuction, balances[crowdsaleController]);
        balances[omegaMultisig]         = 70000000 * 10**18; // 70 million tokens
        Transfer(0, omegaMultisig, balances[omegaMultisig]);
        assignedTokens                 += balances[omegaMultisig];
        if (assignedTokens != totalSupply)
            revert();
    }
}
