pragma solidity 0.4.11;
import './Wallets/MultiSigWallet.sol';
import './Presale/Presale.sol';
import './DutchAuction/DutchAuction.sol';
import './Tokens/OmegaToken.sol';
import './OpenWindow/OpenWindow.sol';

/// @title Omega token contract
/// @author Karl - <karl.floersch@consensys.net>
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


    // @dev Fallback function allows to buy tokens and transfer tokens later on
    function () 
        payable
    {
        if (msg.sender == address(dutchAuction))
            //  Refund from dutch auction or open to signal that the sale is over
            fillOrMarket(msg.sender);
        else if (stage == Stages.MainSale || stage == Stages.OpenWindow)
            fillOrMarket(msg.sender);
        else if (stage == Stages.TradingStarted)
            claimTokens(msg.sender);
        else
            revert();
    }


    /// @param _dutchAuction Reverse dutch auction contract
    /// @param _multiSigWallet Omega multisig wallet
    function CrowdsaleController(address _multiSigWallet, DutchAuction _dutchAuction) {
        //initialize gateway to both contracts
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

    function startPresale() {
        stage = Stages.Presale;
    }

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

    function claimTokens(address receiver)
        public
        isValidPayload(receiver)
        timedTransitions
        atStage(Stages.TradingStarted)
    {   
        if (receiver == 0x0)
            receiver = msg.sender;
        presale.claimTokens(receiver);
        dutchAuction.claimTokens(receiver);
        if (address(openWindow) != 0x0) 
            openWindow.claimTokens(receiver);
    }


    /// @param tokensLeft Amount of tokens left after reverse dutch action
    /// @param price The price the reverse dutch auction ended at
    function startOpenWindow(uint256 dutchAuctionRaise, uint256 tokensLeft, uint256 price) 
        public
        isDutchAuction
    {   
        uint256 presalePercent = calPresalePercent(dutchAuctionRaise);
        uint256 totalSupply = omegaToken.totalSupply();
        uint256 presaleTokenSupply = calcPresaleTokenSupply(presalePercent, totalSupply)

        // Add premuim to price
        price = (price * 13)/10;
        // transfer required amount of tokens to open window
        omegaToken.transfer(address(openWindow),  tokensLeft);
        // Create fixed price fixed cap toke sale
        openWindow = new OpenWindow(tokensLeft, price, omegaMultiSig, omegaToken);
        stage = Stages.OpenWindow;
    }

    function finalizeAuction() 
        public
        // Make sure that this can only be called once
    {
        // Only dutch auction or open window sale can end auction
        if (address(dutchAuction) != msg.sender || (stage == Stages.OpenWindow && address(openWindow) !=msg.sender))
            revert();
        stage = Stages.SaleEnded;
        endTime = now;
    }

    function calcPresaleTokenSupply(uint256 presalePercent, uint256 totalSupply)
    public
    constant
    returns (uint256)
    {
        pre
    }

    function calcPresalePercent(uint256 dutchAuctionRaise)
        public
        constant
        returns (uint256)
    {   
        return (5000000*10**18)/ min256(250000000*10**18, dutchAuctionRaise * 75/100);
    }

    function min256(uint256 a, uint256 b) 
        private 
        constant 
        returns (uint256) 
    {
        return a < b ? a : b;
    }
}