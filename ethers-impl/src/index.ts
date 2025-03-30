import { ethers } from "ethers";
import { abi as escrowAbi } from "../../abi/Escrow.json";
import dotenv from "dotenv";

dotenv.config();

const escrowContractAddress = "0xYourEscrowContractAddress";
const baseProviderUrl = "https://your.ethereum.node";

if (!process.env.PRIVATE_KEY) {
  throw new Error("PRIVATE_KEY is not defined in the environment variables.");
}
const privateKey = process.env.PRIVATE_KEY as string;
const providerUrl = (process.env.PROVIDER_URL as string) || baseProviderUrl;

async function rewardWinners(winners: string[], amounts: number[]) {
  try {
    const provider = new ethers.JsonRpcProvider(providerUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const contract = new ethers.Contract(
      escrowContractAddress,
      escrowAbi,
      wallet
    );

    const parsedAmounts = amounts.map((amt) =>
      ethers.parseUnits(amt.toString(), 18)
    );
    const parsedWinners = winners.map((winner) => ethers.getAddress(winner));
    const tx = await contract.rewardWinners(parsedWinners, parsedAmounts);
    console.log("Transaction sent:", tx);

    const receipt = await tx.wait();
    console.log("Transaction confirmed:", receipt);
  } catch (error) {
    console.error("Error sending transaction:", error);
  }
}
