pragma solidity 0.4.15;
import 'Tokens/StandardToken.sol';

/// @title Omega token contract
/// @author Karl Floersh- <karl.floersch@consensys.net>
contract OmegaToken is StandardToken {
    /*
     *  Constants
     */
    string public constant NAME = "Omega Token";
    string public constant SYMBOL = "OMT";
    uint256 public constant DECIMALS = 18;
    uint256 constant TOTAL_SUPPLY = 100000000 * 10**DECIMALS; // 100 million tokens
    uint256 public constant DUTCH_AUCTION_ALLOCATION = 23700000 * 10**DECIMALS; // 23.7 million tokens
    uint256 public constant CROWDSALE_CONTROLLER_ALLOCATION = 6300000 * 10**DECIMALS; // 6.3 million
    uint256 public constant OMEGA_MULTISIG_ALLOCATION = 70000000 * 10**DECIMALS; // 70 million tokens

    /*
     *  Public functions
     */
    function OmegaToken(address dutchAuction, address omegaMultisig) 
        public
    {
        // Addresses should not be null
        require(dutchAuction != 0x0 && omegaMultisig != 0x0 && msg.sender != 0x0);
        address crowdsaleController = msg.sender;
        totalSupply = TOTAL_SUPPLY; // 100 million tokens
        allocateTokens(dutchAuction, DUTCH_AUCTION_ALLOCATION);
        allocateTokens(crowdsaleController, CROWDSALE_CONTROLLER_ALLOCATION);
        allocateTokens(omegaMultisig, OMEGA_MULTISIG_ALLOCATION);
        require(DUTCH_AUCTION_ALLOCATION + CROWDSALE_CONTROLLER_ALLOCATION + OMEGA_MULTISIG_ALLOCATION == totalSupply);
    }

    function allocateTokens(address _to, uint256 _amount)
        private
    {
        balances[_to] = _amount;
        Transfer(0, _to, balances[_to]);
    }
}
