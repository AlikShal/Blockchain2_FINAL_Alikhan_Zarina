export function getReadableError(error) {
  const message = String(
    error?.shortMessage ||
      error?.message ||
      error?.cause?.message ||
      'Transaction failed.'
  );

  if (message.includes('User rejected') || message.includes('denied')) {
    return 'The transaction was rejected in the wallet.';
  }

  if (message.includes('insufficient funds')) {
    return 'The connected wallet does not have enough native gas token to send this transaction.';
  }

  if (message.includes('AMM: slippage')) {
    return 'The swap failed because the minimum output was set too high.';
  }

  if (message.includes('wrong chain') || message.includes('chain')) {
    return 'The wallet is connected to the wrong network. Switch to Base Sepolia and try again.';
  }

  if (message.includes('AssetVault: zero assets')) {
    return 'The vault amount must be greater than zero.';
  }

  return message;
}
