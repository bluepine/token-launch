from ..abstract_test import AbstractTestContracts, accounts, keys, TransactionFailed

class TestContract(AbstractTestContracts):
    """
    run test with python -m unittest contracts.test.python.crowdsale_controller.test_crowdsale_controller
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)

    def test(self):
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
                                                  params=(self.multisig_wallet.address, 600000 * 10 ** 18, 200000))
        # Create Omega token
        self.crowdsale_controller = self.create_contract('CrowdsaleController/CrowdsaleController.sol', 
                                                        params=(self.multisig_wallet.address, self.dutch_auction))
        # Get the omega token contract that the crowdsale controller deployed
        omega_token_address = self.crowdsale_controller.omegaToken()
        omega_token_abi = self.create_abi('Tokens/OmegaToken.sol')
        self.omega_token = self.contract_at(omega_token_address, omega_token_abi)
        # Setup dutch auction
        self.dutch_auction.setup(self.omega_token.address, self.crowdsale_controller.address)
        # Start auction
        start_auction_data = self.dutch_auction.translator.encode('startAuction', [])
        self.multisig_wallet.submitTransaction(self.dutch_auction.address, 0, start_auction_data, sender=keys[wa_1])
        # Math
        # Sets up dutch auction total received for presale math
        bidder_1 = 4
        total_received = 500000 * 10 ** 18
        self.s.block.set_balance(accounts[bidder_1], total_received * 2)
        self.dutch_auction.bid(sender=keys[bidder_1], value=total_received)
        # Check that presale percent is calculated correctly
        self.assertEqual(self.crowdsale_controller.calcPresalePercent()/10 ** 18, (12500 * 10 ** 18)/min(625000 * 10 ** 18, total_received * .75))
        # Check that the presale token supply is calculated correctly
        presalePercent = self.crowdsale_controller.calcPresalePercent()
        # Rounding was an issue so I converted the it to integers at the end
        self.assertEqual(int(self.crowdsale_controller.calcPresaleTokenSupply(presalePercent)/10**18), int((self.omega_token.totalSupply() * presalePercent)/10**36))
        import pdb; pdb.set_trace()
        

