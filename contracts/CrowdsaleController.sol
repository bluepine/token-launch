pragma solidity 0.4.11;
import './Wallets/MultiSigWallet.sol';
import './DutchAuction/DutchAuction.sol';
import './Tokens/OmegaToken.sol';

contract CrowdsaleController {

    /*
     *  Storage
     */
    address omegaMultiSig;
    DutchAuction dutchAuction;
    OmegaToken omegaToken;
    address public owner;

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

    /// @param _multiSigWallet Omega multisig wallet
    function CrowdsaleController(address _multiSigWallet) {
        //initialize gateway to both contracts
        if (address(_multiSigWallet) == 0x0)
            // Argument is null
            revert();
        owner = msg.sender;
        omegaMultiSig = _multiSigWallet;
        dutchAuction = new DutchAuction(address(this), address(omegaMultiSig), 20000000, 4500);
        omegaToken = new OmegaToken(address(dutchAuction), omegaMultiSig);
    }

    
    // function setup() 
    //     public
    //     isOwner
    // {
    //     dutchAuction.setup(omegaToken);
    // }

    /// @param tokensLeft Amount of tokens left after reverse dutch action
    /// @param finalPrice The price the reverse dutch auction ended at
    // function sellRemaining(uint256 tokensLeft, uint256 finalPrice) 
    //     public
    //     isDutchAuction
    // {
    //     //initialize fixed price contract here
    // }
}