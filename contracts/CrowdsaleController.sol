pragma solidity 0.4.11;
import './Wallets/MultiSigWallet.sol';
import './DutchAuction/DutchAuction.sol';
import './Tokens/OmegaToken.sol';
import './OpenWindow/OpenWindow.sol';
// /// I'm gonna need Abstract Dutch
// /// I'm gonna need Abstract OpenWindow

contract CrowdsaleController {

    /*
     *  Storage
     */
    address public omegaMultiSig;
    DutchAuction public dutchAuction;
    OpenWindow public openWindow;
    OmegaToken public omegaToken;
    address public owner;
    Stages public stage;

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

    modifier atStage(Stages _stage) {
        if (stage != _stage) {
            // Contract not in expected state
            revert();
        }
        _;
    }


    // @dev Fallback function allows to buy tokens and transfer tokens later on
    function () 
        payable
    {
        if (msg.sender == address(dutchAuction))
            // Refund from dutch auction signals that it's over
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
        omegaToken = new OmegaToken(address(dutchAuction), omegaMultiSig);
        stage = Stages.Deployed;
    }

    function startSale() {
        stage = Stages.Presale;
    }



    function fillOrMarket(address receiver) 
        public
        payable
    {
        // If a bid is done on behalf of a user via ShapeShift, the receiver address is set
        if (receiver == 0x0)
            receiver = msg.sender;
        // uint256 amount = msg.value;
        // if (stage = Stages.MainSale) 
        //     dutchAuction.bid.value(amount));
        // else if (stage = Stages.OpenWindow)
        //     openWindow.buy.value(amount);
        // else revert();
    }

    function claimTokens(address receiver)
        public
        atStage(Stages.TradingStarted)
    {   
        if (receiver == 0x0)
            receiver = msg.sender;
        //it seems cheaper and more efficent to keep track
        // presale.claimTokens(receiver, presalePercent);
        dutchAuction.claimTokens(receiver);
        openWindow.claimTokens(receiver);
    }


    /// @param tokensLeft Amount of tokens left after reverse dutch action
    /// @param price The price the reverse dutch auction ended at
    function startOpenWindow(uint256 tokensLeft, uint256 price) 
        public
        isDutchAuction
    {
        // Add premuim to price
        price = (price * 13)/10;
        // Create fixed price fixed cap toke sale
        openWindow = new OpenWindow(tokensLeft, price, omegaMultiSig, omegaToken);
        stage = Stages.OpenWindow;
    }

    // function finalizeTokenSale()
}