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
                                                  params=(self.multisig_wallet.address, 2000 * 10 ** 18, 200000))
        self.crowdsale_controller = self.create_contract('CrowdsaleController/CrowdsaleController.sol',
                                                  params=(self.multisig_wallet.address, self.dutch_auction))
        # import pdb; pdb.set_trace()
        


        

