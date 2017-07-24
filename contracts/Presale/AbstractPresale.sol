pragma solidity 0.4.11;
import 'Tokens/OmegaToken.sol';

/// @title Abstract presale contract
/// @author Karl Floersh - <karl.floersch@consensys.net>
contract Presale {
    /*
     *  Public functions
     */
    function Presale() public;
    function setupClaim(uint256 _totalSupply, Token _omegaToken) public;
    function usdContribution(address buyer, uint256 presalePercent) public;
    function claimTokens(address receiver) public;
}