pragma solidity 0.4.11;
import '../Tokens/OmegaToken.sol';

/// @title Presale contract
/// @author Karl Floersh - <karl.floersch@consensys.net>
contract Presale {
    /*
     *  Constants
     */
    uint256 constant public MAX_PERCENT_OF_PRESALE = 100 * 10**18;
    uint256 constant public MAX_PERCENT_OF_SALE = 6.9 * 10**18;

    /*
     * Storage
     */
    mapping (address => uint256) public presaleAllocations;
    uint256 public percentOfPresaleSold = 0; 
    uint256 public totalSupply;
    address public crowdsaleController;
    Token public omegaToken;
    Stages public stage;

    enum Stages {
        Presale,
        SetupClaim,
        TradingStarted
    }

    /*
     *  Modifiers
     */
    modifier isCrowdsaleController() {
        if (msg.sender != crowdsaleController)
            revert();
        _;
    }

    modifier atStage(Stages _stage) {
        if (stage != _stage)
            // Contract not in expected state
            revert();
        _;
    }

    /*
     *  Public functions
     */
    /// @dev Contract constructor function sets crowdsale controller and the stage
    function Presale() 
        public
    {
        crowdsaleController = msg.sender;
        stage = Stages.Presale;
    }

    /// @dev Sets up token claims for when trading starts
    /// @param _totalSupply Total supply of tokens
    /// @param _omegaToken Omega token
    function setupClaim(uint256 _totalSupply, Token _omegaToken) 
        public
        isCrowdsaleController
    {
        totalSupply = _totalSupply * 10 ** 18;
        omegaToken = _omegaToken;
    }

    /// @dev Allows the Omega team to give presale participants a percent of the presale
    /// @param buyer The address a percentage of the presale is allocated to
    /// @param presalePercent The percent of presale allocated in exchange for usd
    function usdContribution(address buyer, uint256 presalePercent) 
        public
        isCrowdsaleController
        atStage(Stages.Presale)
    {
        if (presalePercent == 0 || buyer == 0x0)
            revert();
        // Use 16 instead of 18 to account for the percent 
        presalePercent = presalePercent * 10 ** 16;
        uint256 maxPercentLeft = MAX_PERCENT_OF_PRESALE - percentOfPresaleSold;
        // Reverts if trying to sell a larger percent of presale than is left
        if (presalePercent > maxPercentLeft)
            revert();
        presaleAllocations[buyer] = presalePercent;
        percentOfPresaleSold += presalePercent;
    }


    /// @dev Claims tokens for presale participant after sale, permissions are in crowdsale controller
    /// @param receiver Tokens will be assigned to this address if set
    function claimTokens(address receiver)
        public
        isCrowdsaleController
    {
        uint256 tokenCount = presaleAllocations[receiver] * totalSupply;
        presaleAllocations[receiver] = 0;
        omegaToken.transfer(receiver, tokenCount);
    }
}