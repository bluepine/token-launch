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
     *  Events
     */
    event StartOpenWindow(uint256 startTime, uint256 tokenCount, uint256 price);
    event FinalizeSale(uint256 endTime);

    /*
     *  Constants
     */
    uint256 constant public WAITING_PERIOD = 7 days;
    uint256 constant public MAIN_SALE_VALUE_CAP = 250000000;

    /*
     *  Storage
     */
    address public wallet;
    Presale public presale;
    DutchAuction public dutchAuction;
    OpenWindow public openWindow;
    OmegaToken public omegaToken;
    address public owner;
    Stages public stage;
    uint256 public endTime;
    uint256 public presaleTokenSupply;
    uint256 public exchangeRateInWei; // 1 usd to wei
    address public receiver;

    enum Stages {
        Deployed,
        Presale,
        MainSale,
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

    /// @dev Fallback function, captures the refund when dutch auction and open window sales end and sends it to the receiver
    function ()
        payable
    {   
        if (stage == Stages.MainSale) {
            fillOrMarket(msg.sender);
        } else if (stage == Stages.SaleEnded) {
            // Use send so that it doesn't throw an error when the msg has no value
            receiver.transfer(msg.value);
        } else {
            revert();
        }
    }

    /// @param _dutchAuction Reverse dutch auction contract
    /// @param _wallet Omega multisig wallet
    /// @param _exchangeRateInWei Wei equivalent of 1 usd
    function CrowdsaleController(address _wallet, DutchAuction _dutchAuction, uint256 _exchangeRateInWei) 
    {
        // Initialize gateway to both contracts
        if (_wallet == 0x0 || address(_dutchAuction) == 0x0 || _exchangeRateInWei == 0)
            // An argument is null
            revert();
        owner = msg.sender;
        wallet = _wallet;
        dutchAuction = _dutchAuction;
        exchangeRateInWei = _exchangeRateInWei;
        presale = new Presale();
        omegaToken = new OmegaToken(address(dutchAuction), wallet);
        stage = Stages.Deployed;
        openWindow = new OpenWindow();
    }

    /// @dev Starts the presale
    function startPresale()
        public
        isOwner
        atStage(Stages.Deployed)
    {
        stage = Stages.Presale;
    }

    /// @dev Wrapper that allows the Omega team to give presale participants a percent of the presale from the crowdsale controller
    /// @param _buyer The address a percentage of the presale is allocated to
    /// @param _presalePercent The percent of presale allocated in exchange for usd
    function usdContribution(address _buyer, uint256 _presalePercent) 
        public
        isOwner
        atStage(Stages.Presale)
    {
        presale.usdContribution(_buyer, _presalePercent);
        // Presale ends when it reaches 100%
        if (presale.percentOfPresaleSold() == presale.MAX_PERCENT_OF_PRESALE()) 
            stage = Stages.MainSale;
    }

    /// @dev Determines whether value sent to crowdsale controller should got to the dutch auction or to the open window contracts
    /// @param receiver Bid on or bought tokens will be assigned to this address if set
    function fillOrMarket(address receiver) 
        public
        payable
        isValidPayload(receiver)
    {
        // If a bid is done on behalf of a user via ShapeShift, the receiver address is set
        if (receiver == 0x0)
            receiver = msg.sender;
        uint256 amount = msg.value;
        if (stage == Stages.MainSale) {
            dutchAuction.bid.value(amount)(receiver);
        } else if (stage == Stages.OpenWindow) {
            openWindow.buy.value(amount)(receiver);
            // Checks if open window sale is over
            if (openWindow.tokenSupply() == 0)
                finalizeSale();
        }  else {
            revert();
        }
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
        // Checks if the receiver has any tokens in each contract and if they do claims their tokens
        if (dutchAuction.bids(receiver) > 0)
            dutchAuction.claimTokens(receiver);
        if (presale.presaleAllocations(receiver) > 0) {
            presale.claimTokens(receiver);
        }
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
        // Add in tokens already allocated for the presale
        tokensLeft += 6300000 * 10 ** 18;
        presaleTokenSupply = calcPresaleTokenSupply();
        // Add premuim to price
        price = price * 13/10;
        // transfer required amount of tokens to open window
        omegaToken.transfer(address(openWindow),  tokensLeft - presaleTokenSupply);
        // Create fixed price fixed cap toke sale
        openWindow.setupSale(tokensLeft - presaleTokenSupply, price, wallet, omegaToken); 
        StartOpenWindow(now, tokensLeft - presaleTokenSupply, price);
        stage = Stages.OpenWindow;
    }

    /// @dev Finishes the sale from the dutch auction (occurs if dutch auction token stop price is reached)
    function finishFromDutchAuction()
        public
        isDutchAuction
    {
        presaleTokenSupply = calcPresaleTokenSupply();
        finalizeSale();
    }

    /// @dev Calculates the token supply for the presale contract
    function calcPresaleTokenSupply()
        public 
        constant
        returns (uint256)
    {   
        // uint256 reverseDutchValuation = (100000000 * 10 ** 18/omegaToken.balanceOf(dutchAuction) * 625000*10**18);
        // uint256 reverseDutchValuationWithPremium =(reverseDutchValuation * 3) / 4;
        // uint256 valueCap = exchangeRateInWei * 250000000; // 250 million USD in wei
        // uint256 presaleCap = exchangeRateInWei * 5000000; // 5 million USD in wei
        // return omegaToken.totalSupply() * presaleCap/min256(valueCap, reverseDutchValuationWithPremium);
        return omegaToken.totalSupply() * exchangeRateInWei * 5000000/ min256(exchangeRateInWei * 250000000, ((100000000 * 10 ** 18/omegaToken.balanceOf(dutchAuction) * 625000*10**18 * 3) / 4));
    }

    /*
     *  Private functions
     */
    /// @dev Finishes the token sale
    function finalizeSale() 
        private
    {
        setupPresaleClaim();
        stage = Stages.SaleEnded;
        endTime = now;
        FinalizeSale(endTime);
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
        // Transfer tokens to the presale
        omegaToken.transfer(address(presale), presaleTokenSupply);
        // Sets up the presale with the necesary amount of tokens based on the result of the dutch auction  
        presale.setupClaim(presaleTokenSupply, omegaToken);
    }
}
