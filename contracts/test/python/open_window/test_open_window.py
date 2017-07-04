from ..abstract_test import AbstractTestContracts, accounts, keys, TransactionFailed

class TestContract(AbstractTestContracts):
    """
    run test with python -m unittest contracts.test.python.open_window.test_open_window
    """

    # BLOCKS_PER_DAY = 6000
    # TOTAL_TOKENS = 100000000 * 10**18 # 100 million
    # MAX_TOKENS_SOLD = 23700000 # 30 million
    # WAITING_PERIOD = 60*60*24*7 
    # FUNDING_GOAL = 62500 * 10**18 # 62,500 Ether ~ 25 million dollars
    # PRICE_FACTOR = 307500
    # MAX_GAS = 150000  # Kraken gas limit

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)
        
    def test(self):
        token_supply = 14200000 * 10 ** 18
        dutch_auction_address = accounts[2]
        crowdsale_controller_address = accounts[0]
        price = 1 * 10**18 # In Ether
        # Create wallet
        required_accounts = 1
        wa_1 = 1
        constructor_parameters = (
            [accounts[wa_1]],
            required_accounts
        )
        self.multisig_wallet = self.create_contract('Wallets/MultiSigWallet.sol',
                                                    params=constructor_parameters)
        self.omega_token= self.create_contract('Tokens/OmegaToken.sol',
                                                  params=(dutch_auction_address, self.multisig_wallet.address))
        self.open_window = self.create_contract('OpenWindow/OpenWindow.sol',
                                                  params=(token_supply, price, self.multisig_wallet.address, self.omega_token))
        self.omega_token.transfer(self.open_window.address, token_supply, sender=keys[2])

        # Open window contract initializes with the correct values
        self.assertEqual(self.open_window.owner().decode(), crowdsale_controller_address.hex())
        self.assertEqual(self.open_window.wallet().decode(), self.multisig_wallet.address.hex())
        self.assertEqual(self.open_window.tokenSupply(), token_supply)
        self.assertEqual(self.open_window.price(), price)
        self.assertEqual(self.open_window.stage(), 0)

        import pdb; pdb.set_trace()
        # Buyer can buy tokens (through crowdsale controller)
        # max eth is 14,200,000
        bidder_1 = 2
        value_1 = 1
        # self.open_window.buy()
        