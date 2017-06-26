pragma solidity 0.4.11;
import './Wallets/MultiSigWallet.sol';
import './DutchAuction/DutchAuction.sol';
import './Tokens/OmegaToken.sol';
/// I'm gonna need Abstract Dutch
/// I'm gonna need Abstract OpenWindow

contract CrowdsaleController {

    /*
     *  Storage
     */
    address omegaMultiSig;
    DutchAuction dutchAuction;
    OmegaToken omegaToken;
    address public owner;

    enum Stages {
        Setup,
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

    modifier atStage(Stages _stage) {
        if (stage != _stage) {
            // Contract not in expected state
            revert();
        }
        _;
    }


    /// @dev Fallback function allows to buy tokens and transfer tokens later on
    function () 
        payable
    {
        if (msg.sender == address(dutchAuction))
            RefundReceived(this, msg.value);
        else if (stage == Stages.MainSale || stage == Stages.OpenWindow)
            fillOrMarket(msg.sender);
        else if (stage == Stages.TokensClaimed)
            transferTokens();
        else
            revert();
    }

    /// @param _multiSigWallet Omega multisig wallet
    function CrowdsaleController(address _multiSigWallet, Dutchauction _dutchAuction) {
        //initialize gateway to both contracts
        if (address(_multiSigWallet) == 0x0)
            // Argument is null
            revert();
        owner = msg.sender;
        omegaMultiSig = _multiSigWallet;
        dutchAuction = new DutchAuction(address(this), address(omegaMultiSig), 20000000, 4500);
        omegaToken = new OmegaToken(address(dutchAuction), omegaMultiSig);
    }


    function fillOrMarket(address receiver) 
        public
        payable
    {
        // If a bid is done on behalf of a user via ShapeShift, the receiver address is set
        if (receiver == 0x0)
            receiver = msg.sender;
        uint256 amount = msg.value;
        if (stage = Stages.MainSale) 
            dutchAuction.bid.value(amount));
        else if (stage = Stages.OpenWindow)
            openWindow.buy.value(amount);
        else
            revert();
    };

    

    //put this in OpenWindow contract
    /// @param tokensLeft Amount of tokens left after reverse dutch action
    /// @param finalPrice The price the reverse dutch auction ended at
    // function sellRemaining(uint256 tokensLeft, uint256 finalPrice) 
    //     public
    //     isDutchAuction
    // {
    //     //initialize fixed price contract here
    // }
}