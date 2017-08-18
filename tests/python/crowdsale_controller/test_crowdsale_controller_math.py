from ..abstract_test import AbstractTestContracts, accounts, keys, TransactionFailed

class TestContract(AbstractTestContracts):
    """
    run test with python -m unittest tests.python.crowdsale_controller.test_crowdsale_controller_math
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
        self.s.mine()
        # Create dutch auction with ceiling of 62.5k Ether and price factor of 78125000000000000
        self.dutch_auction = self.create_contract('DutchAuction/DutchAuction.sol',
                                                  params=(self.multisig_wallet.address, 62500 * 10**18, 78125000000000000))
        # Create Omega token
        self.crowdsale_controller = self.create_contract('CrowdsaleController/CrowdsaleController.sol', 
                                                        params=(self.multisig_wallet.address, self.dutch_auction, 2500000000000000))
        self.s.mine()
        # Get the omega token contract that the crowdsale controller deployed
        omega_token_address = self.crowdsale_controller.omegaToken()
        omega_token_abi = self.create_abi('Tokens/OmegaToken.sol')
        self.omega_token = self.contract_at(omega_token_address, omega_token_abi)
        # Setup dutch auction
        self.dutch_auction.setup(self.omega_token.address, self.crowdsale_controller.address)
        # Run presale
        self.crowdsale_controller.startPresale()
        buyer_1 = 5
        # 100%
        percent_of_presale_1 = 100 * 10 ** 18
        self.crowdsale_controller.usdContribution(accounts[buyer_1], percent_of_presale_1)
        # Start auction
        start_auction_data = self.dutch_auction.translator.encode('startAuction', [])
        self.multisig_wallet.submitTransaction(self.dutch_auction.address, 0, start_auction_data, sender=keys[wa_1])
        # Math
        # Sets up dutch auction total received for presale math
        bidder_1 = 4
        total_received = 62500 * 10 ** 18 #  62.5k Ether
        self.dutch_auction.bid(sender=keys[bidder_1], value=total_received)
        # Check that the presale token supply is calculated correctly
        self.assertEqual(int(self.crowdsale_controller.calcPresaleTokenSupply()), 2000000 * 10**18)
