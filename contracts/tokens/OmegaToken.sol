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

    function OmegaToken(address dutchAuction) 
        public
    {
        if (dutchAuction == 0x0)
            // Address should not be null
            revert();
        uint256 totalSupply = 10000000 * 10**18;
        balances[dutchAuction] = 300000 * 10**18;
        // omegaToken.balances[fixed_price]  = totalSupply * .27;
        // omegaToken.balances[presale]      = totalSupply * .05;
        // omegaToken.balances[team]         = totalSupply * .6;
        // omegaToken.balances[company]      = totalSupply * .05;
        Transfer(0, dutchAuction, balances[dutchAuction]);
        uint256 assignedTokens = balances[dutchAuction];
        // for (uint256 i = 0; i<owners.length; i++) {
        //     if (owners[i] == 0x0)
        //         // Address should not be null
        //         revert();
        //     balances[owners[i]] += tokens[i];
        //     Transfer(0x0, owners[i], tokens[i]);
        //     assignedTokens += tokens[i];
        // }
        if (assignedTokens != totalSupply)
            revert();
        
    }
}