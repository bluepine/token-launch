pragma solidity 0.4.11;
import '../Tokens/OmegaToken.sol';
import "../ownership/Ownable.sol";

contract Presale is Ownable {

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
    Token public omegaToken;

    function Presale() {
        owner = msg.sender;
    }

    function setupPresale(uint256 _totalSupply, Token _omegaToken) 
        public
        isOwner
    {
        totalSupply = _totalSupply * 10 ** 18;
        omegaToken = _omegaToken;
    }

    function usdContribution(address buyer, uint256 presalePercent) 
        public
        isOwner
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

    function claimTokens(address receiver)
        public
        isOwner
    {
        uint256 tokenCount = presaleAllocations[receiver] * totalSupply;
        presaleAllocations[receiver] = 0;
        omegaToken.transfer(receiver, tokenCount);
    }
}