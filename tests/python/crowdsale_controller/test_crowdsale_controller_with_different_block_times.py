from ..abstract_test import AbstractTestContracts, accounts, keys, TransactionFailed

class TestContract(AbstractTestContracts):
    """
    run test with python -m unittest tests.python.crowdsale_controller.test_crowdsale_controller_with_different_block_times
    """

    BLOCKS_PER_DAY = 6000
    TOTAL_TOKENS = int(100000000 * 10**18)
    WAITING_PERIOD = 60*60*24*7
    FUNDING_GOAL = 62500 * 10**18 # 62,500 Ether ~ 25 million dollars
    PRICE_FACTOR = 78125000000000000

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)

    def test(self):
        owner = 0
        # Create wallet
        required_accounts = 1
        wa_1 = 1
        constructor_parameters = (
            [accounts[wa_1]],
            required_accounts
        )
        self.multisig_wallet = self.create_contract('Wallets/MultiSigWallet.sol',
                                                    params=constructor_parameters)
        # Create dutch auction with ceiling of 2 billion and price factor of 200,000
        self.dutch_auction = self.create_contract('DutchAuction/DutchAuction.sol',
                                                    params=(self.multisig_wallet.address, 62500 * 10 ** 18, 78125000000000000))
        # Create crowdsale controller
        self.crowdsale_controller = self.create_contract('CrowdsaleController/CrowdsaleController.sol', 
                                                        params=(self.multisig_wallet.address, self.dutch_auction, 2500000000000000))
        # Get the omega token contract that the crowdsale controller deployed
        omega_token_address = self.crowdsale_controller.omegaToken()
        presale_address = self.crowdsale_controller.presale()
        open_window_address = self.crowdsale_controller.openWindow()
        omega_token_abi = self.create_abi('Tokens/OmegaToken.sol')
        presale_abi = self.create_abi('Presale/Presale.sol')
        open_window_abi = self.create_abi('OpenWindow/OpenWindow.sol')
        self.omega_token = self.contract_at(omega_token_address, omega_token_abi)
        self.presale = self.contract_at(presale_address, presale_abi)
        self.open_window = self.contract_at(open_window_address, open_window_abi)

        # Setup dutch auction
        self.dutch_auction.setup(self.omega_token.address, self.crowdsale_controller.address)
        # Crowdsale controller is initialized with the correct values
        self.assertEqual(self.crowdsale_controller.owner().decode(), accounts[owner].hex())
        self.assertEqual(self.crowdsale_controller.wallet().decode(), self.multisig_wallet.address.hex())
        self.assertEqual(self.crowdsale_controller.dutchAuction().decode(), self.dutch_auction.address.hex())
        self.assertEqual(self.crowdsale_controller.presale().decode(), self.presale.address.decode())
        self.assertEqual(self.crowdsale_controller.omegaToken().decode(), self.omega_token.address.decode())
        self.assertEqual(self.crowdsale_controller.stage(), 0)
        self.assertEqual(self.crowdsale_controller.openWindow().decode(), self.open_window.address.decode())
        # Raises if anyone but the owners tries to start the presale
        self.assertRaises(TransactionFailed, self.crowdsale_controller.startPresale, sender=keys[3])
        # Owner can start the presale
        self.crowdsale_controller.startPresale()
        # Crowdsale is now in presale stage
        self.assertEqual(self.crowdsale_controller.stage(), 1)
        # Owner can allocate presale percentages to address (in exchange for usd)
        buyer_1 = 3
        # 9.5%
        percent_of_presale_1 = 95 * 10 ** 17
        self.crowdsale_controller.usdContribution(accounts[buyer_1], percent_of_presale_1)
        # Fails if dutch auction tries to start before presale is over
        start_auction_data = self.dutch_auction.translator.encode('startAuction', [])
        self.multisig_wallet.submitTransaction(self.dutch_auction.address, 0, start_auction_data, sender=keys[wa_1])
        self.assertEqual(self.dutch_auction.stage(), 1)
        # Presale stores the presale percent in presaleAllocations and percentOfPresaleSold
        self.assertEqual(self.presale.presaleAllocations(accounts[buyer_1]), percent_of_presale_1)
        self.assertEqual(self.presale.percentOfPresaleSold(), percent_of_presale_1)
        buyer_2 = 4
        # 90.5%
        percent_of_presale_2 = 905 * 10 ** 17
        self.crowdsale_controller.usdContribution(accounts[buyer_2], percent_of_presale_2)
        # Presale stores the presale percent in presaleAllocations and percentOfPresaleSold
        self.assertEqual(self.presale.presaleAllocations(accounts[buyer_2]), percent_of_presale_2)
        self.assertEqual(self.presale.percentOfPresaleSold(), percent_of_presale_1 + percent_of_presale_2)
        # After presale funding has reached 100% presale is over
        self.assertEqual(self.crowdsale_controller.stage(), 2)
        # Before the dutch auction is started the funding goal can be changed
        change_ceiling_data = self.dutch_auction.translator.encode('changeSettings',
                                                                   [self.FUNDING_GOAL, self.PRICE_FACTOR])
        self.multisig_wallet.submitTransaction(self.dutch_auction.address, 0, change_ceiling_data, sender=keys[wa_1])
        # Dutch auction cannow start
        start_auction_data = self.dutch_auction.translator.encode('startAuction', [])
        self.multisig_wallet.submitTransaction(self.dutch_auction.address, 0, start_auction_data, sender=keys[wa_1])
        # Buyer 3 bids through the dutch auction on the 2nd day
        self.s.block.number += self.BLOCKS_PER_DAY * 2
        # day_2
        price = self.dutch_auction.calcTokenPrice()
        buyer_3 = 5
        value_3 = 20000 * 10**18  # 20k Ether
        self.dutch_auction.bid(sender=keys[buyer_3], value=value_3)
        # Buyer 4 bids through the crowdsale controller on the 4th day
        self.s.block.number += self.BLOCKS_PER_DAY * 2
        day_4_token_price = self.dutch_auction.calcTokenPrice()
        buyer_4 = 6
        value_4 = 20000 * 10**18  # 20k Ether
        self.crowdsale_controller.fillOrMarket(sender=keys[buyer_4], value=value_4)
        # Dutch auction receives buyer 4's bid
        self.assertEqual(self.dutch_auction.bids(accounts[buyer_4]), 20000 * 10**18)
        self.assertEqual(self.dutch_auction.totalReceived(), value_3 + value_4)
        # When dutch auction is ended by a bid through the crowdsale the bid is transferred into the open window sale
        buyer_5 = 7
        value_5 = 30000 * 10**18  # 30k Ether
        self.crowdsale_controller.fillOrMarket(sender=keys[buyer_5], value=value_5)
        # Check for refund to buyer 5
        refund_buyer_5 = (value_3 + value_4 + value_5) - self.FUNDING_GOAL
        self.assertGreater(self.s.block.get_balance(accounts[buyer_5]), 0.98 * (value_5 + refund_buyer_5))
        # Make sure correct amounts have been kept in the crowdsale controller (for the presale) and dutch auction as well was transferred to the open window
        self.assertEqual(round(self.omega_token.balanceOf(self.dutch_auction.address)/10**24, 3), 3.524)
        self.assertEqual(round(self.omega_token.balanceOf(self.crowdsale_controller.address)/10**24, 3), 2)
        self.assertEqual(round(self.omega_token.balanceOf(self.open_window.address)/10**24, 3), 24.476)
        # Open window has the correct token supply and price
        self.assertEqual(self.open_window.tokenSupply(), self.omega_token.balanceOf(self.open_window.address))
        self.assertEqual(round(int(self.open_window.price()), -1), round(int(self.dutch_auction.calcCurrentTokenPrice() * 1.3), -1))
        # The crowdsale controller is now in the OpenWindow stage
        self.assertEqual(self.crowdsale_controller.stage(), 3)
        # Now fillOrMarket sends Ether to the open window sale
        buyer_6 = 8
        value_6 =  500000 * 10**18  # 500 K Ether
        self.s.block.set_balance(accounts[buyer_6], value_6 * 2)
        self.crowdsale_controller.fillOrMarket(sender=keys[buyer_6], value=value_6)
        # Open window receives buyer 6's purchase
        self.assertEqual(round(self.open_window.tokensBought(accounts[buyer_6]), -10), round(int(value_6/ self.open_window.price()*10**18), - 10))
        self.assertEqual(round(self.open_window.tokenSupply(), -10), round(int(self.omega_token.balanceOf(self.open_window.address) - value_6 * 10**18/self.open_window.price()), -10))
        # After open window ends the remaining value is refunded to the buyer
        buyer_7 = 9
        value_7 =  500000 * 10**18  # 500 K Ether
        tokensLeft = self.open_window.tokenSupply()
        self.s.block.set_balance(accounts[buyer_7], value_7 * 2)
        self.crowdsale_controller.fillOrMarket(sender=keys[buyer_7], value=value_7)
        # Token supply is 0 after open window sale ends
        self.assertEqual(self.open_window.tokenSupply(), 0)
        # Buyer 7 receives the refund
        refund_buyer_7 = value_7 - tokensLeft * self.open_window.price()/10**18
        self.assertEqual(round(self.s.block.get_balance(accounts[buyer_7]), -9), round(int(value_7 + refund_buyer_7), -9))
        self.assertEqual(round(self.s.block.get_balance(accounts[buyer_7]), -10), round(int(value_7 * 2 - self.open_window.tokensBought(accounts[buyer_7]) * self.open_window.price()/10**18), -10))
        # Crowdsale controller is at stage SaleEnded
        self.assertEqual(self.crowdsale_controller.stage(), 4)
        # Sale ended but trading is not possible yet, because there is one week pause after auction ends
        self.s.block.timestamp += self.WAITING_PERIOD
        self.assertRaises(TransactionFailed, self.crowdsale_controller.claimTokens, sender=keys[buyer_1])
        # Go past one week
        self.s.block.timestamp += 1
        # Each buyer claims their tokens through the crowdsale controller
        self.crowdsale_controller.claimTokens(accounts[buyer_1])
        self.crowdsale_controller.claimTokens(accounts[buyer_2])
        self.crowdsale_controller.claimTokens(accounts[buyer_3])
        self.crowdsale_controller.claimTokens(accounts[buyer_4])
        self.crowdsale_controller.claimTokens(accounts[buyer_5])
        self.crowdsale_controller.claimTokens(accounts[buyer_6])
        self.crowdsale_controller.claimTokens(accounts[buyer_7])
        presale_tokens = self.TOTAL_TOKENS * .02
        dutch_auction_tokens = self.TOTAL_TOKENS * .03524
        open_window_tokens = self.TOTAL_TOKENS * .24476
        # Presale buyers have received the correct amount of tokens
        self.assertEqual(self.omega_token.balanceOf(accounts[buyer_1]), round(int(presale_tokens * .095), -8))
        self.assertEqual(self.omega_token.balanceOf(accounts[buyer_2]), round(int(presale_tokens * .905), -9))
        buyer_3_tokens = round(int(value_3 *10**18/ self.dutch_auction.calcCurrentTokenPrice()), -9)
        self.assertEqual(round(self.omega_token.balanceOf(accounts[buyer_3]), -9), buyer_3_tokens)
        buyer_3_tokens = round(int(value_3 *10**18/ self.dutch_auction.calcCurrentTokenPrice()), -9)
        self.assertEqual(round(self.omega_token.balanceOf(accounts[buyer_3]), -9), buyer_3_tokens)
        buyer_4_tokens = round(int(value_4 *10**18/ self.dutch_auction.calcCurrentTokenPrice()), -9)
        self.assertEqual(round(self.omega_token.balanceOf(accounts[buyer_4]), -9), buyer_4_tokens)
        buyer_5_tokens = round(int((value_5 - refund_buyer_5) *10**18/ self.dutch_auction.calcCurrentTokenPrice()), -10)
        self.assertEqual(round(self.omega_token.balanceOf(accounts[buyer_5]), -10), buyer_5_tokens)
        buyer_6_tokens = round(int(value_6 *10**18/ self.open_window.price()), -10)
        self.assertEqual(round(self.omega_token.balanceOf(accounts[buyer_6]), -10), buyer_6_tokens)
        buyer_7_tokens = round(int((value_7 - refund_buyer_7) *10**18/ self.open_window.price()), -10)
        self.assertEqual(round(self.omega_token.balanceOf(accounts[buyer_7]), -10), buyer_7_tokens)

