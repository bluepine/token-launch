pragma solidity 0.4.11;
import '../Tokens/OmegaToken.sol';
import '../CrowdsaleController/AbstractCrowdsaleController.sol';
/// @title Open window contract
/// @author Karl - <karl.floersch@consensys.net>
contract OpenWindow {

    /*
     * Events
     */
    event PurchasedTokens(address indexed purchaser, uint amount);

    /*
     * Storage
     */
    address public wallet;
    address public crowdsaleController;
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
        SaleEnded
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

    modifier isCrowdsaleController() {
        if (msg.sender != crowdsaleController)
            revert();
        _;
    }

    // @dev Fallback function allows to buy tokens and transfer tokens later on
    function ()
        payable
    {
        buy(msg.sender);
    }

    /*
     * Public functions
     */
    /// @dev Sale(): constructor for Sale contract
    /// @param _wallet the sale's beneficiary address 
    /// @param _tokenSupply the total number of AdToken to mint
    /// @param _price price of the token in Wei (ADT/Wei pair price)
    /// @param _omegaToken Omega token
    function OpenWindow(
        uint256 _tokenSupply,
        uint256 _price,
        address _wallet,
        Token _omegaToken
    ) 
    {
        crowdsaleController = msg.sender;
        wallet = _wallet;
        tokenSupply = _tokenSupply;
        omegaToken = _omegaToken;
        price = _price;
        stage = Stages.SaleStarted;
    }

    /// @dev buy(): function that exchanges ETH for ADT (main sale function)
    /// @notice You're about to purchase the equivalent of `msg.value` Wei in ADT tokens
    function buy(address receiver)
        payable
        public
        isCrowdsaleController
        atStage(Stages.SaleStarted)
    {   
        // Check that msg.value is not 0
        uint256 amount = msg.value;
        if (amount < 0)
            revert();
        uint256 maxWei =(tokenSupply/10**18) * price;

        //Cannot purchase more tokens than this contract has available to sell
        if (amount > maxWei) {
            amount = maxWei;
            // Send change back to receiver address. In case of a ShapeShift bid the user receives the change back directly
            receiver.transfer(msg.value - amount);
        }
        uint256 tokenPurchase = amount * 10 ** 18/ price;
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
    }

    function claimTokens(address receiver)
        public
        isCrowdsaleController
    {
        uint tokenCount = tokensBought[receiver];
        tokensBought[receiver] = 0;
        omegaToken.transfer(receiver, tokenCount);
    }
}