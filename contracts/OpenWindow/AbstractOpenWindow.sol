pragma solidity 0.4.11;
import "../Tokens/AbstractToken.sol";

/// @title Abstract open window contract
/// @author Karl - <karl.floersch@consensys.net>
contract OpenWindow {
    /*
     * Public functions
     */
    function OpenWindow(uint256 _tokenSupply, uint256 _price, address _wallet, Token _omegaToken) public;
    function buy(address receiver) public payable;
    function claimTokens(address receiver) public;
}