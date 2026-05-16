import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { BrowserProvider, Contract, formatEther, parseEther } from "ethers";
import "./style.css";

const ADDRESSES = {
  chainId: "0x7a69", 
  token: import.meta.env.VITE_GAME_TOKEN,
  governor: import.meta.env.VITE_GOVERNOR,
  amm: import.meta.env.VITE_RESOURCE_AMM,
  vault: import.meta.env.VITE_TREASURY_VAULT,
  subgraph: import.meta.env.VITE_SUBGRAPH_URL
};

const erc20VotesAbi = [
  "function balanceOf(address) view returns (uint256)",
  "function getVotes(address) view returns (uint256)",
  "function delegates(address) view returns (address)",
  "function delegate(address)",
  "function approve(address,uint256) returns (bool)"
];

const vaultAbi = [
  "function deposit(uint256,address) returns (uint256)",
  "function balanceOf(address) view returns (uint256)"
];

const ammAbi = [
  "function reserveA() view returns (uint256)",
  "function reserveB() view returns (uint256)",
  "function swapExactInput(uint256,uint256,uint256) returns (uint256)"
];

const governorAbi = [
  "function castVote(uint256,uint8) returns (uint256)",
  "function state(uint256) view returns (uint8)",
  "function proposalVotes(uint256) view returns (uint256,uint256,uint256)"
];

function getProvider() {
  return window.ethereum ? new BrowserProvider(window.ethereum) : null;
}

function App() {
  const [account, setAccount] = useState("");
  const [message, setMessage] = useState("");
  const [state, setState] = useState({
    balance: 0n,
    votes: 0n,
    delegate: "",
    reserveA: 0n,
    reserveB: 0n
  });
  const [swaps, setSwaps] = useState([]);

  async function withSigner(callback) {
    try {
      const provider = getProvider();
      if (!provider) throw new Error("MetaMask is not installed");

      const network = await window.ethereum.request({ method: "eth_chainId" });

      if (network.toLowerCase() !== ADDRESSES.chainId.toLowerCase()) {
        throw new Error("Wrong network. Switch to Arbitrum Sepolia.");
      }

      const signer = await provider.getSigner();
      await callback(signer);

      await refresh(await signer.getAddress());
    } catch (error) {
      setMessage(
        error.shortMessage ||
          error.reason ||
          error.message ||
          "Transaction failed"
      );
    }
  }

  async function connect() {
    try {
      const provider = getProvider();
      if (!provider) throw new Error("MetaMask is not installed");

      const accounts = await window.ethereum.request({
        method: "eth_requestAccounts"
      });

      setAccount(accounts[0]);
      await refresh(accounts[0]);
    } catch (error) {
      setMessage(error.message);
    }
  }

  async function refresh(user = account) {
    try {
      const provider = getProvider();
      if (!provider || !user || !ADDRESSES.token) return;

      const token = new Contract(ADDRESSES.token, erc20VotesAbi, provider);

      setState({
        balance: await token.balanceOf(user),
        votes: await token.getVotes(user),
        delegate: await token.delegates(user),
        reserveA: 0n,
        reserveB: 0n
      });

      await loadSubgraph();
    } catch (error) {
      setMessage(error.message || "Failed to refresh data");
    }
  }

  async function loadSubgraph() {
    try {
      if (!ADDRESSES.subgraph) return;

      const response = await fetch(ADDRESSES.subgraph, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          query:
            "{ swaps(first: 5, orderBy: timestamp, orderDirection: desc) { id trader amountIn amountOut } }"
        })
      });

      const json = await response.json();
      setSwaps(json.data?.swaps || []);
    } catch {
      setSwaps([]);
    }
  }

  async function delegateSelf() {
    await withSigner(async (signer) => {
      const token = new Contract(ADDRESSES.token, erc20VotesAbi, signer);
      await (await token.delegate(await signer.getAddress())).wait();
      setMessage("Delegated votes");
    });
  }

  async function deposit() {
    await withSigner(async (signer) => {
      const token = new Contract(ADDRESSES.token, erc20VotesAbi, signer);
      const vault = new Contract(ADDRESSES.vault, vaultAbi, signer);

      await (await token.approve(ADDRESSES.vault, parseEther("1"))).wait();
      await (
        await vault.deposit(parseEther("1"), await signer.getAddress())
      ).wait();

      setMessage("Deposited into vault");
    });
  }

  async function swap() {
    await withSigner(async (signer) => {
      const amm = new Contract(ADDRESSES.amm, ammAbi, signer);
      await (await amm.swapExactInput(1, 10, 1)).wait();
      setMessage("Swap submitted");
    });
  }

  async function vote() {
    const proposalId = prompt("Proposal id");
    if (!proposalId) return;

    await withSigner(async (signer) => {
      const governor = new Contract(ADDRESSES.governor, governorAbi, signer);
      await (await governor.castVote(proposalId, 1)).wait();
      setMessage("Vote cast");
    });
  }

  useEffect(() => {
    if (account) refresh(account);
  }, [account]);

  return (
    <main>
      <header>
        <h1>GameFi Economy</h1>
        <button onClick={connect}>
          {account ? `${account.slice(0, 6)}...${account.slice(-4)}` : "Connect"}
        </button>
      </header>

      {message && <p className="notice">{message}</p>}

      <section className="grid">
        <article>
          <h2>Wallet</h2>
          <p>Balance: {formatEther(state.balance)} GOV</p>
          <p>Votes: {formatEther(state.votes)}</p>
          <p>Delegate: {state.delegate || "-"}</p>
          <button onClick={delegateSelf}>Delegate</button>
        </article>

        <article>
          <h2>Resource AMM</h2>
          <p>Reserve A: {state.reserveA.toString()}</p>
          <p>Reserve B: {state.reserveB.toString()}</p>
          <button onClick={swap}>Swap</button>
        </article>

        <article>
          <h2>Treasury</h2>
          <button onClick={deposit}>Deposit 1 GOV</button>
        </article>

        <article>
          <h2>Governance</h2>
          <button onClick={vote}>Vote</button>
        </article>
      </section>

      <section>
        <h2>Indexed Swaps</h2>
        {swaps.map((s) => (
          <p key={s.id}>{`${s.trader}: ${s.amountIn} -> ${s.amountOut}`}</p>
        ))}
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);