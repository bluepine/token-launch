from ..abstract_test import AbstractTestContracts, accounts, keys, TransactionFailed

class TestContract(AbstractTestContracts):
    """
    run test with python -m unittest contracts.test.python.tokens.test_omega_token
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)

    def test(self):
        dutch_auction_address = accounts[1]
        crowdsale_controller_address = accounts[0]
        multisig_wallet_address = accounts[2]
        self.omega_token= self.create_contract('Tokens/OmegaToken.sol',
                                                  params=(dutch_auction_address, multisig_wallet_address))
        self.assertEqual(self.omega_token.name().decode(), "Omega Token")
        self.assertEqual(self.omega_token.symbol().decode(), "OMG")
        self.assertEqual(self.omega_token.decimals(), 18)
        self.assertEqual(self.omega_token.totalSupply(), 100000000 * 10 ** 18)
        self.assertEqual(self.omega_token.balanceOf(dutch_auction_address), 23700000 * 10 ** 18)
        self.assertEqual(self.omega_token.balanceOf(crowdsale_controller_address), 6300000 * 10 ** 18)
        self.assertEqual(self.omega_token.balanceOf(multisig_wallet_address), 70000000 * 10 ** 18)
        

