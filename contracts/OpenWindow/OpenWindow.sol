pragma solidity 0.4.11;
import "Tokens/AbstractToken.sol";

/// @title Open window contract
/// @author Karl Floersh - <karl.floersch@consensys.net>
contract OpenWindow {
    /*
     * Events
     */
    event PurchasedTokens(address indexed purchaser, uint amount);

    /*
     *  Constants
     */
    uint256 constant public SALE_LENGTH = 30 days;

    /*
     * Storage
     */
    address public wallet;
    address public crowdsaleController;
    Token public omegaToken;
    uint256 public price;
    uint256 public startTime;
    uint256 public tokenSupply;
    mapping (address => uint) public tokensBought;

    /*
     * Modifiers
     */
    modifier isCrowdsaleController() {
        if (msg.sender != crowdsaleController)
            revert();
        _;
    }

    modifier timedTransitions() {
        if (now > startTime + SALE_LENGTH)
            // Ends the sale after 30 days
            finalizeSale();
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor function sets crowdsale controller
    function OpenWindow()
        public
    {
        crowdsaleController = msg.sender;
    }

    /// @dev Sets up the open window sale
    /// @param _wallet The sale's beneficiary address 
    /// @param _tokenSupply The number of OMG available to sell
    /// @param _price Price of the token in Wei (OMG/Wei pair price)
    /// @param _omegaToken Omega token
    function setupSale(uint256 _tokenSupply, uint256 _price, address _wallet, Token _omegaToken) 
        public
        isCrowdsaleController
    {
        wallet = _wallet;
        tokenSupply = _tokenSupply;
        omegaToken = _omegaToken;
        price = _price;
        startTime = now;
    }

    /// @dev Exchanges ETH for OMG (sale function)
    /// @notice You're about to purchase the equivalent of `msg.value` Wei in OMG tokens
    function buy(address receiver)
        payable
        public
        timedTransitions
        isCrowdsaleController
    {   
        // Check that msg.value is not 0
        uint256 amount = msg.value;
        if (amount < 0)
            revert();
        uint256 maxWei = tokenSupply * price / 10**18;
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
            finalizeSale();
        PurchasedTokens(msg.sender, tokenPurchase);
    }

    /// @dev Claims tokens for buyer after sale, permissions are in crowdsale controller
    /// @param receiver Tokens will be assigned to this address if set
    function claimTokens(address receiver)
        public
        isCrowdsaleController
    {
        uint tokenCount = tokensBought[receiver];
        tokensBought[receiver] = 0;
        omegaToken.transfer(receiver, tokenCount);
    }

    /*
     *  Private functions
     */
    /// @dev Finishes the open window and then the overall token sale
    function finalizeSale()
        private
    {
        // Finalizes the token sale
        omegaToken.transfer(crowdsaleController, tokenSupply);
        tokenSupply = 0;
    }
}
