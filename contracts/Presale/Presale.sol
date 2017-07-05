pragma solidity 0.4.11;
import '../Tokens/OmegaToken.sol';

/// @title Presale contract
/// @author Karl Floersh - <karl.floersch@consensys.net>
/// @dev Percents are entered with 10 ** 16 e.g. 6.3% is 63 ** 10 ** 18 and 10% is 1 ** 10 ** 16
contract Presale {
    /*
     *  Constants
     */
    uint256 constant public MAX_PERCENT_OF_SALE = 63 * 10**15;
    uint256 constant public MAX_PERCENT_OF_PRESALE = 100 * 10**16;

    /*
     * Storage
     */
    mapping (address => uint256) public presaleAllocations;
    uint256 public percentOfPresaleSold = 0; 
    uint256 public totalSupply;
    address public crowdsaleController;
    Token public omegaToken;
        /*
     *  Modifiers
     */
    modifier isCrowdsaleController() {
        if (msg.sender != crowdsaleController)
            revert();
        _;
    }

    /*
     *  Public functions
     */
    /// @dev Contract constructor function sets crowdsale controller
    function Presale() 
        public
    {
        crowdsaleController = msg.sender;
    }

    /// @dev Allows the Omega team to give presale participants a percent of the presale
    /// @param buyer The address a percentage of the presale is allocated to
    /// @param presalePercent The percent of presale allocated in exchange for usd
    function usdContribution(address buyer, uint256 presalePercent) 
        public
        isCrowdsaleController
    {
        if (presalePercent == 0 || buyer == 0x0)
            revert();
        
        uint256 maxPercentLeft = MAX_PERCENT_OF_PRESALE - percentOfPresaleSold;
        // Reverts if trying to sell a larger percent of presale than is left
        if (presalePercent > maxPercentLeft)
            revert();
        presaleAllocations[buyer] = presalePercent;
        percentOfPresaleSold += presalePercent;
    }

    /*
     * External functions
     */
    /// @dev Sets up token claims for when trading starts
    /// @param _totalSupply Total supply of tokens
    /// @param _omegaToken Omega token
    function setupClaim(uint256 _totalSupply, Token _omegaToken) 
        external
        isCrowdsaleController
    {
        if (_omegaToken.balanceOf(this) != _totalSupply)
            revert();
        totalSupply = _totalSupply;
        omegaToken = _omegaToken;
    }

    /// @dev Claims tokens for presale participant after sale, permissions are in crowdsale controller
    /// @param receiver Tokens will be assigned to this address if set
    function claimTokens(address receiver)
        external
        isCrowdsaleController
    {
        uint tokenCount = presaleAllocations[receiver] * totalSupply / 10**18;
        presaleAllocations[receiver] = 0;
        omegaToken.transfer(receiver, tokenCount);
    }
}