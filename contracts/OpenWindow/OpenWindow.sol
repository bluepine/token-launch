pragma solidity 0.4.11;
import '../Tokens/OmegaToken.sol';

contract OpenWindow {

    /*
     * Events
     */

    event PurchasedTokens(address indexed purchaser, uint amount);

    /*
     * Storage
     */

    address public owner;
    address public wallet;
    Token public omegaToken;
    uint256 public price;
    uint256 public startBlock;
    uint256 public freezeBlock;
    bool public emergencyFlag = false;
    uint256 public tokenSupply;
    Stages public stage;
    mapping (address => uint) public tokensBought;

    enum Stages {
        SaleStarted,
        SaleEnded,
        TradingStarted
    }

    /*
     * Modifiers
     */

    modifier atStage(Stages _stage) {
        if (stage != _stage)
            // Contract not in expected state
            revert();
        _;
    }

    modifier isOwner() {
        if (msg.sender != owner)
            revert();
        _;
    }

    // @dev Fallback function allows to buy tokens and transfer tokens later on
    function ()
        payable
    {
        buy(msg.sender);
    }

    // modifier notFrozen {
    //     require(block.number < freezeBlock);
    //     _;
    // }

    // modifier notInEmergency {
    //     assert(emergencyFlag == false);
    //     _;
    // }

    /*
     * Public functions
     */

    /// @dev Sale(): constructor for Sale contract
    /// @param _wallet the sale's beneficiary address 
    /// @param _tokenSupply the total number of AdToken to mint
    /// @param _price price of the token in Wei (ADT/Wei pair price)
    function OpenWindow(
        uint256 _tokenSupply,
        uint256 _price,
        address _wallet,
        Token _omegaToken
        // uint256 _startBlock,
        // uint256 _freezeBlock
    ) {
        owner = msg.sender;
        wallet = _wallet;
        tokenSupply = _tokenSupply;
        omegaToken = _omegaToken;
        price = _price;
        // startBlock = _startBlock;
        // freezeBlock = _freezeBlock;
        stage = Stages.SaleStarted;

        // if (omegaToken.balanceOf(this) != _tokenSupply)
        //     revert();
    }

    /// @dev purchaseToken(): function that exchanges ETH for ADT (main sale function)
    /// @notice You're about to purchase the equivalent of `msg.value` Wei in ADT tokens
    function buy(address receiver)
        payable
        // setupComplete
        // notInEmergency
        public
        isOwner
        atStage(Stages.SaleStarted)
    {
        /* Calculate whether any of the msg.value needs to be returned to
           the sender. The tokenPurchase is the actual number of tokens which
           will be purchased once any excessAmount included in the msg.value
           is removed from the purchaseAmount. */
        if (receiver == 0x0)
            receiver = msg.sender;
        uint amount = msg.value;
        uint tokenPurchase = amount / price;
        uint256 maxWei = tokenSupply * price;

        // uint maxWei = (MAX_TOKENS_SOLD / 10**18) * calcTokenPrice() - totalReceived;

        // Cannot purchase more tokens than this contract has available to sell
        

        // Return any excess msg.value
        // if (excessmount > 0) {
        //     msg.sender.transfer(excessAmount);
        // }
        if (amount > maxWei) {
            amount = maxWei;
            // Send change back to receiver address. In case of a ShapeShift bid the user receives the change back directly
            receiver.transfer(msg.value - amount);
        }
        // Forward received ether to the wallet
        wallet.transfer(amount);

        // Transfer the sum of tokens tokenPurchase to the msg.sender
        tokenSupply = tokenSupply - tokenPurchase;
        tokensBought[receiver] += tokenPurchase;

        if (maxWei == amount)
            finalizeAuction();
        PurchasedTokens(msg.sender, tokenPurchase);
    }

    function finalizeAuction()
        private
        atStage(Stages.SaleStarted)
    {
        stage = Stages.SaleEnded;
        // endTime = now;
    }

    function claimTokens(address receiver)
        public
        isOwner
        atStage(Stages.TradingStarted)
    {
        uint tokenCount = tokensBought[receiver] * 10**18;
        tokensBought[receiver] = 0;
        omegaToken.transfer(receiver, tokenCount);
    }


    // function emergencyToggle()
    //     onlyOwner
    // {
    //     emergencyFlag = !emergencyFlag;
    // }

}