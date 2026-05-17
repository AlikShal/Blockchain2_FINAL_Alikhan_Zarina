import { createConfig, http } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { baseSepolia, foundry, sepolia } from 'wagmi/chains';

const configuredChain = (
  import.meta.env.VITE_CHAIN || 'baseSepolia'
).toLowerCase();

export const expectedChain =
  configuredChain === 'anvil' || configuredChain === 'foundry'
    ? foundry
    : configuredChain === 'sepolia'
      ? sepolia
      : baseSepolia;

export const appConfig = createConfig({
  chains: [expectedChain],
  connectors: [
    injected({
      shimDisconnect: true,
    }),
  ],
  transports: {
    [expectedChain.id]: http(
      import.meta.env.VITE_PUBLIC_RPC_URL ||
        expectedChain.rpcUrls.default.http[0],
    ),
  },
});
