from ..abstract_test import AbstractTestContracts, accounts, keys, TransactionFailed

class TestContract(AbstractTestContracts):
    """
    run test with python -m unittest tests.python.wallet.test_multisig_wallet
    """

    def __init__(self, *args, **kwargs):
        super(TestContract, self).__init__(*args, **kwargs)

    def test(self):
        # Create wallet
        required_accounts = 2
        wa_1 = 1
        wa_2 = 2
        wa_3 = 3
        constructor_parameters = (
            [accounts[wa_1], accounts[wa_2], accounts[wa_3]],
            required_accounts
        )
        gas = self.s.block.gas_used
        self.multisig_wallet = self.create_contract('Wallets/MultiSigWallet.sol',
                                                    params=constructor_parameters)
        self.assertLess(self.s.block.gas_used - gas, 2000000)
        # Validate deployment
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_1]))
        self.assertEqual(self.multisig_wallet.owners(0).decode(), accounts[wa_1].hex())
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_2]))
        self.assertEqual(self.multisig_wallet.owners(1).decode(), accounts[wa_2].hex())
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_3]))
        self.assertEqual(self.multisig_wallet.owners(2).decode(), accounts[wa_3].hex())
        self.assertEqual(self.multisig_wallet.required(), required_accounts)
        self.assertEqual(self.multisig_wallet.getOwners(), [accounts[wa_1].hex().encode(), accounts[wa_2].hex().encode(), accounts[wa_3].hex().encode()])
        # Create ABIs
        multisig_abi = self.multisig_wallet.translator
        # Send money to wallet contract
        deposit = 1000
        self.s.send(keys[wa_1], self.multisig_wallet.address, deposit)
        self.assertEqual(self.s.block.get_balance(self.multisig_wallet.address), 1000)
        # Add owner wa_4
        wa_4 = 4
        add_owner_data = multisig_abi.encode('addOwner', [accounts[wa_4]])
        # A third party cannot submit transactions.
        self.assertRaises(TransactionFailed, self.multisig_wallet.submitTransaction, self.multisig_wallet.address, 0,
                          add_owner_data, sender=keys[0])
        # Wallet owner tries to submit transaction with destination address 0 but fails. 0 address is not allowed.
        self.assertRaises(
            TransactionFailed, self.multisig_wallet.submitTransaction, 0, 0, add_owner_data, sender=keys[wa_1])
        # Only a wallet owner (in this case wa_1) can do this. Owner confirms transaction at the same time.
        transaction_id = self.multisig_wallet.submitTransaction(self.multisig_wallet.address, 0, add_owner_data,
                                                                sender=keys[wa_1])
        # There is one pending transaction
        exclude_pending = False
        include_pending = True
        exclude_executed = False
        include_executed = True
        self.assertEqual(
        self.multisig_wallet.getTransactionIds(0, 1, include_pending, exclude_executed), [transaction_id])
        self.assertTrue(self.multisig_wallet.confirmations(transaction_id, accounts[wa_1]))
        self.assertEqual(self.multisig_wallet.getConfirmationCount(transaction_id), 1)
        self.assertEqual(self.multisig_wallet.getConfirmations(transaction_id), [accounts[wa_1].hex().encode()])
        self.assertEqual(self.multisig_wallet.getTransactionCount(include_pending, exclude_executed), 1)
        # But owner wa_1 revokes confirmation
        self.multisig_wallet.revokeConfirmation(transaction_id, sender=keys[wa_1])
        self.assertFalse(self.multisig_wallet.confirmations(transaction_id, accounts[wa_1]))
        self.assertEqual(self.multisig_wallet.getConfirmationCount(transaction_id), 0)
        # He changes his mind but confirms wrong transaction
        self.assertRaises(TransactionFailed, self.multisig_wallet.confirmTransaction, 100, sender=keys[wa_2])
        # He changes his mind, confirms again
        self.multisig_wallet.confirmTransaction(transaction_id, sender=keys[wa_1])
        self.assertTrue(self.multisig_wallet.confirmations(transaction_id, accounts[wa_1]))
        self.assertEqual(self.multisig_wallet.getConfirmationCount(transaction_id), 1)
        # Other owner wa_2 confirms and executes transaction at the same time as min sig are available
        self.assertFalse(self.multisig_wallet.transactions(transaction_id)[3])
        self.multisig_wallet.confirmTransaction(transaction_id, sender=keys[wa_2])
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_4]))
        self.assertEqual(self.multisig_wallet.getConfirmationCount(transaction_id), 2)
        self.assertEqual(self.multisig_wallet.getConfirmations(transaction_id),
                         [accounts[wa_1].hex().encode(), accounts[wa_2].hex().encode()])
        # Transaction was executed
        self.assertTrue(self.multisig_wallet.transactions(transaction_id)[3])
        self.assertEqual(
            self.multisig_wallet.getTransactionIds(0, 1, exclude_pending, include_executed), [transaction_id])
        # Update required to 4
        update_requirement_data = multisig_abi.encode('changeRequirement', [4])
        # Submit successfully
        transaction_id_2 = self.multisig_wallet.submitTransaction(self.multisig_wallet.address, 0,
                                                                  update_requirement_data, sender=keys[wa_1])
        self.assertEqual(
            self.multisig_wallet.getTransactionIds(0, 1, include_pending, exclude_executed), [transaction_id_2])
        self.assertEqual(self.multisig_wallet.getTransactionCount(include_pending, include_executed), 2)
        # Test slicing
        self.assertEqual(
            self.multisig_wallet.getTransactionIds(0, 1, include_pending, include_executed), [transaction_id])
        self.assertEqual(
            self.multisig_wallet.getTransactionIds(0, 2, include_pending, include_executed),
            [transaction_id, transaction_id_2])
        self.assertEqual(
            self.multisig_wallet.getTransactionIds(1, 2, include_pending, include_executed), [transaction_id_2])
        # Confirm change requirement transaction
        self.multisig_wallet.confirmTransaction(transaction_id_2, sender=keys[wa_2])
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_4]))
        self.assertEqual(self.multisig_wallet.required(), required_accounts + 2)
        self.assertEqual(
            self.multisig_wallet.getTransactionIds(0, 2, exclude_pending, include_executed),
            [transaction_id, transaction_id_2])
        # Delete owner wa_3. All parties have to confirm.
        remove_owner_data = multisig_abi.encode('removeOwner', [accounts[wa_3]])
        transaction_id_3 = self.multisig_wallet.submitTransaction(self.multisig_wallet.address, 0, remove_owner_data,
                                                                  sender=keys[wa_1])
        self.assertEqual(
            self.multisig_wallet.getTransactionIds(0, 1, include_pending, exclude_executed), [transaction_id_3])
        self.multisig_wallet.confirmTransaction(transaction_id_3, sender=keys[wa_2])
        self.multisig_wallet.confirmTransaction(transaction_id_3, sender=keys[wa_3])
        self.multisig_wallet.confirmTransaction(transaction_id_3, sender=keys[wa_4])
        self.assertEqual(self.multisig_wallet.getTransactionIds(0, 3, exclude_pending, include_executed),
                         [transaction_id, transaction_id_2, transaction_id_3])
        # Transaction was successfully processed
        self.assertEqual(self.multisig_wallet.required(), required_accounts + 1)
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_1]))
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_2]))
        self.assertTrue(self.multisig_wallet.isOwner(accounts[wa_4]))
