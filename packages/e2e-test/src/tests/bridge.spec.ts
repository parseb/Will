import { parseEther, parseUnits } from 'viem'
import { beforeAll, describe, expect, it } from 'vitest'
import { testClientByChain, testClients } from '@/utils/clients'
import { envVars } from '@/envVars'
import { L2NativeSuperchainERC20Abi } from '@/abi/L2NativeSuperchainERC20Abi'
import {
  generatePrivateKey,
  privateKeyToAccount,
} from 'viem/accounts'
import {
  createInteropSentL2ToL2Messages,
  decodeRelayedL2ToL2Messages,
} from '@eth-optimism/viem'

const testPrivateKey = generatePrivateKey()
const testAccount = privateKeyToAccount(`0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`);

// Extend the base ABI with Will contract's functions
const WillContractAbi = [
  ...L2NativeSuperchainERC20Abi,
  {
    inputs: [],
    name: 'currentPrice',
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ type: 'uint256', name: 'amt_' }],
    name: 'mintCost',
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ type: 'uint256', name: 'howMany_' }],
    name: 'mint',
    outputs: [],
    stateMutability: 'payable',
    type: 'function'
  }
] as const;

const willContract = {
  address: envVars.VITE_TOKEN_CONTRACT_ADDRESS,
  abi: WillContractAbi,
} as const

describe('bridge token from L2 to L2', async () => {
  const decimals = await testClientByChain.supersimL2A.readContract({
    ...willContract,
    functionName: 'decimals',
  })

  beforeAll(async () => {
    // Deal 1000 ETH to the test account on each chain
    await Promise.all(
      testClients.map((client) =>
        client.setBalance({
          address: testAccount.address,
          value: parseEther('1000'),
        }),
      ),
    )
  })

  beforeAll(async () => {
    // Mint a smaller amount of tokens on each chain
    await Promise.all(
      testClients.map(async (client) => {
        // Start with a small amount - 1 token
        const mintAmount = parseUnits('1', decimals)
        const ethRequired = await client.readContract({
          ...willContract,
          functionName: 'mintCost',
          args: [mintAmount],
        })

        // Mint tokens by sending ETH
        const hash = await client.writeContract({
          account: testAccount,
          ...willContract,
          functionName: 'mint',
          args: [mintAmount],
          value: ethRequired,
        })
        await client.waitForTransactionReceipt({ hash })
      }),
    )
  })

  it.for([
    {
      source: testClientByChain.supersimL2A,
      destination: testClientByChain.supersimL2B,
    },
    {
      source: testClientByChain.supersimL2B,
      destination: testClientByChain.supersimL2A,
    },
  ] as const)(
    'should bridge tokens from $source.chain.id to $destination.chain.id',
    async ({ source: sourceClient, destination: destinationClient }) => {
      const startingDestinationBalance = await destinationClient.readContract({
        ...willContract,
        functionName: 'balanceOf',
        args: [testAccount.address],
      })

      // Bridge a smaller amount - 0.1 token
      const amountToBridge = parseUnits('0.1', decimals)

      // Initiate bridge transfer
      const hash = await sourceClient.sendSupERC20({
        account: testAccount,
        tokenAddress: envVars.VITE_TOKEN_CONTRACT_ADDRESS,
        amount: amountToBridge,
        chainId: destinationClient.chain.id,
        to: testAccount.address,
      })

      const receipt = await sourceClient.waitForTransactionReceipt({
        hash,
      })

      // Extract the cross-chain message from the bridge transaction
      const { sentMessages } = await createInteropSentL2ToL2Messages(
        // @ts-expect-error
        sourceClient,
        { receipt },
      )
      expect(sentMessages).toHaveLength(1)

      // Relay the message on the destination chain
      const relayMessageTxHash = await destinationClient.relayL2ToL2Message({
        account: testAccount,
        sentMessageId: sentMessages[0].id,
        sentMessagePayload: sentMessages[0].payload,
      })

      const relayMessageReceipt =
        await destinationClient.waitForTransactionReceipt({
          hash: relayMessageTxHash,
        })

      // Verify the message was successfully processed
      const { successfulMessages } = decodeRelayedL2ToL2Messages({
        receipt: relayMessageReceipt,
      })
      expect(successfulMessages).length(1)

      // Verify the balance increased by the bridged amount
      const endingBalance = await destinationClient.readContract({
        ...willContract,
        functionName: 'balanceOf',
        args: [testAccount.address],
      })

      expect(endingBalance).toEqual(startingDestinationBalance + amountToBridge)
    },
  )

  it.for([
    {
      source: testClientByChain.supersimL2A,
      destination: testClientByChain.supersimL2B,
    },
  ] as const)(
    'should fail when trying to bridge more tokens than available balance',
    async ({ source: sourceClient }) => {
      const currentBalance = await sourceClient.readContract({
        ...willContract,
        functionName: 'balanceOf',
        args: [testAccount.address],
      })

      const excessiveAmount = currentBalance + parseUnits('1', decimals)

      // Attempt to bridge more tokens than available
      await expect(
        sourceClient.sendSupERC20({
          account: testAccount,
          tokenAddress: envVars.VITE_TOKEN_CONTRACT_ADDRESS,
          amount: excessiveAmount,
          chainId: testClientByChain.supersimL2B.chain.id,
          to: testAccount.address,
        }),
      ).rejects.toThrow(/reverted/i)
    },
  )
})