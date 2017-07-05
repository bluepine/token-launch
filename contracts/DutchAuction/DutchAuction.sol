pragma solidity 0.4.11;
import "../Tokens/AbstractToken.sol";
import "../CrowdsaleController/AbstractCrowdsaleController.sol";

/// @title Dutch auction contract - distribution of Omega tokens using an auction
/// @author Karl Floersh - <karl.floersch@consensys.net>
/// Based on code by Stefan George: https://github.com/gnosis/gnosis-contracts/blob/dutch_auction/contracts/solidity/DutchAuction/DutchAuction.sol
contract DutchAuction {
    /*
     *  Events
     */
    event BidSubmission(address indexed sender, uint256 amount);

    /*
     *  Constants
     */
    uint256 constant public MAX_TOKENS_SOLD = 23700000 * 10**18; // 30M
    uint256 constant public AUCTION_LENGTH = 5 days;

    /*
     *  Storage
     */
    Token public omegaToken;
    CrowdsaleController public crowdsaleController;
    address public wallet;
    address public owner;
    uint256 public ceiling;
    uint256 public priceFactor;
    uint256 public startBlock;
    uint256 public endTime;
    uint256 public totalReceived;
    uint256 public finalPrice;
    mapping (address => uint) public bids;
    Stages public stage;

    enum Stages {
        AuctionDeployed,
        AuctionSetUp,
        AuctionStarted,
        AuctionEnded
    }

    /*
     *  Modifiers
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

    modifier isCrowdsaleController() {
        if (msg.sender != address(crowdsaleController))
            revert();
        _;
    }

    modifier isWallet() {
        if (msg.sender != wallet)
            // Only wallet is allowed to proceed
            revert();
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

    modifier timedTransitions() {
        if (stage == Stages.AuctionStarted && calcTokenPrice() <= calcStopPrice())
            finalizeAuction();
        _;
    }

    /*
     *  Public functions
     */
    /// @dev Contract constructor function sets owner
    /// @param _wallet Omega wallet
    /// @param _ceiling Auction ceiling
    /// @param _priceFactor Auction price factor
    function DutchAuction(address _wallet, uint256 _ceiling, uint256 _priceFactor)
        public
    {
        if (_wallet == 0x0 || _ceiling == 0x0 || 
            _priceFactor == 0x0)
            // Arguments are null
            revert();
        owner = msg.sender;
        wallet = _wallet;
        ceiling = _ceiling;
        priceFactor = _priceFactor;
        stage = Stages.AuctionDeployed;
    }

    /// @dev Setup function sets external contracts' addresses
    /// @param _omegaToken Omega token initialized in crowdsale controller
    /// @param _crowdsaleController Crowdsaler controller
    function setup(Token _omegaToken, CrowdsaleController _crowdsaleController)
        public
        isOwner
        atStage(Stages.AuctionDeployed)
    {
        if (address(_omegaToken) == 0x0 || address(_crowdsaleController) == 0x0)
            // Argument is null
            revert();
        omegaToken = _omegaToken;
        crowdsaleController = _crowdsaleController;
        // Validate token balance
        if (omegaToken.balanceOf(this) != MAX_TOKENS_SOLD)
            revert();
        stage = Stages.AuctionSetUp;
    }

    /// @dev Starts auction and sets startBlock
    function startAuction()
        public
        isWallet
        atStage(Stages.AuctionSetUp)
    {
        stage = Stages.AuctionStarted;
        startBlock = block.number;
    }

    /// @dev Changes auction ceiling and start price factor before auction is started
    /// @param _ceiling Updated auction ceiling
    /// @param _priceFactor Updated start price factor
    function changeSettings(uint256 _ceiling, uint256 _priceFactor)
        public
        isWallet
        atStage(Stages.AuctionSetUp)
    {
        ceiling = _ceiling;
        priceFactor = _priceFactor;
    }

    /// @dev Calculates current token price
    /// @return Returns token price
    function calcCurrentTokenPrice()
        public
        constant
        timedTransitions
        returns (uint256)
    {
        if (stage == Stages.AuctionEnded)
            return finalPrice;
        return calcTokenPrice();
    }

    /// @dev Returns correct stage, even if a function with timedTransitions modifier has not yet been called yet
    /// @return Returns current auction stage
    function updateStage()
        public
        constant
        timedTransitions
        returns (Stages)
    {
        return stage;
    }

    /// @dev Allows to send a bid to the auction
    /// @param receiver Bid will be assigned to this address if set
    function bid(address receiver)
        public
        payable
        isValidPayload(receiver)
        timedTransitions
        atStage(Stages.AuctionStarted)
        returns (uint256 amount)
    {
        // If a bid is done on behalf of a user via ShapeShift, the receiver address is set
        if (receiver == 0x0)
            receiver = msg.sender;
        amount = msg.value;
        require(amount > 0);
        // Prevent that more than 90% of tokens are sold. Only relevant if cap not reached
        uint maxWei = (MAX_TOKENS_SOLD / 10**18) * calcTokenPrice() - totalReceived;
        uint maxWeiBasedOnTotalReceived = ceiling - totalReceived;
        if (maxWeiBasedOnTotalReceived < maxWei)
            maxWei = maxWeiBasedOnTotalReceived;
        // Only invest maximum possible amount
        if (amount > maxWei)
            amount = maxWei;
        // Forward funding to ether wallet
        wallet.transfer(amount);
        bids[receiver] += amount;
        totalReceived += amount;
        if (amount == maxWei) {
            // When maxWei is equal to the big amount the auction is ended and finalizeAuction is triggered
            finalizeAuction();
            // Send change back to receiver address. In case of a ShapeShift bid the user receives the change back directly
            receiver.transfer(msg.value - amount);
        }
        BidSubmission(receiver, amount);
    }

    /// @dev Claims tokens for bidder after auction, permissions are in crowdsale controller
    /// @param receiver Tokens will be assigned to this address if set
    function claimTokens(address receiver)
        public
        isCrowdsaleController
    {
        uint256 tokenCount = bids[receiver] * 10**18 / finalPrice;
        bids[receiver] = 0;
        omegaToken.transfer(receiver, tokenCount);
    }

    /// @dev Calculates stop price
    /// @return Returns stop price
    function calcStopPrice()
        constant
        public
        returns (uint256)
    {
        return totalReceived * 10**18 / MAX_TOKENS_SOLD + 1;
    }

    /// @dev Calculates token price
    /// @return Returns token price
    function calcTokenPrice()
        constant
        public
        returns (uint)
    {   
        // Calculated at 6,000 blocks mined per day
        // Auction calculated to stop after 5.76 days
        return priceFactor * 10 ** 18/ ((block.number - startBlock) * 3  + 7500) + 1;
    }

    /*
     *  Private functions
     */
    /// @dev Finishes dutch auction and finalizes the token sale or starts the open window sale depending on how it ends
    function finalizeAuction()
        private
    {
        stage = Stages.AuctionEnded;
        if (totalReceived == ceiling) {
            finalPrice = calcTokenPrice();
            crowdsaleController.finalizeAuction();
        } else {
            finalPrice = calcStopPrice();
            // Auction contract transfers all unsold tokens to the crowdsale controller
            uint256 tokensLeft = MAX_TOKENS_SOLD - totalReceived * 10**18 / finalPrice;
            omegaToken.transfer(address(crowdsaleController),  tokensLeft);
            crowdsaleController.startOpenWindow(tokensLeft, finalPrice);
        }
    }
}