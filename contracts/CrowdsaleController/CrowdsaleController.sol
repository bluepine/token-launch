pragma solidity 0.4.11;
import '../Wallets/MultiSigWallet.sol';
import '../Presale/Presale.sol';
import '../DutchAuction/AbstractDutchAuction.sol';
import '../Tokens/OmegaToken.sol';
import '../OpenWindow/OpenWindow.sol';

/// @title Crowdsale controller token contract
/// @author Karl Floersh - <karl.floersch@consensys.net>
contract CrowdsaleController {
    /*
     *  Constants
     */
    uint256 constant public WAITING_PERIOD = 7 days;

    /*
     *  Storage
     */
    address public omegaMultiSig;
    Presale public presale;
    DutchAuction public dutchAuction;
    OpenWindow public openWindow;
    OmegaToken public omegaToken;
    address public owner;
    Stages public stage;
    uint256 public endTime;
    uint256 public presaleTokenSupply;

    enum Stages {
        Deployed,
        Presale,
        MainSale,
        SetupPresaleClaim,
        OpenWindow,
        SaleEnded,
        TradingStarted
    }

    /*
     *  Modifiers
     */
    modifier isOwner() {
        if (msg.sender != owner)
            // Only owner is allowed to proceed
            revert();
        _;
    }

    modifier isDutchAuction() {
        if (msg.sender != address(dutchAuction))
            // Only dutch auction is allowed to proceed
            revert();
        _; 
    }

    modifier timedTransitions() {
        if (stage == Stages.SaleEnded && now > endTime + WAITING_PERIOD)
            stage = Stages.TradingStarted;
        _;
    }

    modifier atStage(Stages _stage) {
        if (stage != _stage) {
            // Contract not in expected state
            revert();
        }
        _;
    }

    modifier isValidPayload(address receiver) {
        if (msg.data.length != 4 && msg.data.length != 36
            || receiver == address(this)
            || receiver == address(omegaToken))
            // Payload length has to have correct length and receiver should not be dutch auction or omega token contract
            revert();
        _;
    }

    /// @dev Fallback function, captures the refund when reverse dutch auction and open window sales end
    function () 
        payable
    {
        if (stage == Stages.MainSale || stage == Stages.OpenWindow)
            fillOrMarket(msg.sender);
        else if (stage == Stages.TradingStarted)
            claimTokens(msg.sender);
        else
            revert();
    }

    /// @param _dutchAuction Reverse dutch auction contract
    /// @param _multiSigWallet Omega multisig wallet
    function CrowdsaleController(address _multiSigWallet, DutchAuction _dutchAuction) 
    {
        // Initialize gateway to both contracts
        if (_multiSigWallet == 0x0 || address(_dutchAuction) == 0x0)
            // Argument is null
            revert();
        owner = msg.sender;
        omegaMultiSig = _multiSigWallet;
        dutchAuction = _dutchAuction;
        presale = new Presale();
        omegaToken = new OmegaToken(address(dutchAuction), omegaMultiSig);
        stage = Stages.Deployed;
    }

    /// @dev Starts the presale
    function startPresale()
        public
    {
        stage = Stages.Presale;
    }

    /// @dev Wrapper that allows the Omega team to give presale participants a percent of the presale from the crowdsale controller
    /// @param _buyer The address a percentage of the presale is allocated to
    /// @param _presalePercent The percent of presale allocated in exchange for usd
    function usdContribution(address _buyer, uint256 _presalePercent) 
        public
        atStage(Stages.Presale)
    {
        presale.usdContribution(_buyer, _presalePercent);
    }

    // Needs to start after the dutch auction is over


    /// @dev Determines whether value sent to crowdsale controller should got to the dutch auction or to the open window contracts
    /// @param receiver Bid on or bought tokens will be assigned to this address if set
    function fillOrMarket(address receiver) 
        public
        payable
    {
        // If a bid is done on behalf of a user via ShapeShift, the receiver address is set
        if (receiver == 0x0)
            receiver = msg.sender;
        uint256 amount = msg.value;
        if (stage == Stages.MainSale) 
            dutchAuction.bid.value(amount);
        else if (stage == Stages.OpenWindow)
            openWindow.buy.value(amount);
        else 
            revert();
    }

    /// @dev Claims tokens for bidder after auction
    /// @param receiver Tokens will be assigned to this address if set
    function claimTokens(address receiver)
        public
        isValidPayload(receiver)
        timedTransitions
        atStage(Stages.TradingStarted)
    {   
        if (receiver == 0x0)
            receiver = msg.sender;
        // Checks if the receiever has any tokens in each contract and if they do claims their tokens
        if (dutchAuction.bids(receiver) > 0)
            dutchAuction.claimTokens(receiver);
        // if (presale.presaleAllocations(receiver) > 0)
            // presale.claimTokens(receiver);
        if (address(openWindow) != 0x0 && openWindow.tokensBought(receiver) > 0) 
            openWindow.claimTokens(receiver);
    }


    /// @dev Starts the open window auction and gives it the correct amount of tokens
    /// @param tokensLeft Amount of tokens left after reverse dutch action
    /// @param price The price the reverse dutch auction ended at
    function startOpenWindow(uint256 tokensLeft, uint256 price) 
        public
        isDutchAuction
    {  
        stage = Stages.SetupPresaleClaim; 
        setupPresaleClaim();
        omegaToken.transfer(address(presale), presaleTokenSupply);
        // Add premuim to price
        price = (price * 13)/10;
        // transfer required amount of tokens to open window
        omegaToken.transfer(address(openWindow),  tokensLeft - presaleTokenSupply);
        // Create fixed price fixed cap toke sale
        openWindow = new OpenWindow(tokensLeft, price, omegaMultiSig, omegaToken);
        stage = Stages.OpenWindow;
    }

    /// @dev Finishes the token sale
    function finalizeAuction() 
        public
    {
        // Only dutch auction or open window sale can end auction
        if (address(dutchAuction) != msg.sender || (stage == Stages.OpenWindow && address(openWindow) !=msg.sender))
            revert();
        stage = Stages.SetupPresaleClaim;
        setupPresaleClaim();
        stage = Stages.SaleEnded;
        endTime = now;
    }

    /*
     *  Private functions
     */
    /// @dev Calculates the token supply for the presale contract
    /// @param presalePercent The percentage of the total tokens that the presale will receive
    function calcPresaleTokenSupply(uint256 presalePercent)
        public 
        constant
        returns (uint256)
    {
        return omegaToken.totalSupply() * presalePercent / 10**18;
    }

    /// @dev Calculates the percentage of the total tokens that the presale will receive
    function calcPresalePercent()
        public
        constant
        returns (uint256)
    {   
        return (12500*10**36)/min256(625000*10**18, (500000*10**18) * (75 *10** 16)/(10**18));
    }

    /// @dev Calculates the minimum between two numbers
    /// @param a The first number
    /// @param b The second number
    function min256(uint256 a, uint256 b) 
        private 
        constant 
        returns (uint256) 
    {
        return a < b ? a : b;
    }

    function setupPresaleClaim()
        private
    {   
        uint256 presalePercent = calcPresalePercent();
        presaleTokenSupply = calcPresaleTokenSupply(presalePercent);
        // Sets up the presale with the necesary amount of tokens based on the result of the dutch auction  
        presale.setupClaim(presaleTokenSupply, omegaToken);
    }
}
