// NotchDeck Example Web Widget: Crypto Price Monitor
// Demonstrates window.notch bridge: config, storage, notify, run

document.addEventListener("DOMContentLoaded", async () => {
  const btcPriceEl = document.getElementById("btc-price");
  const ethPriceEl = document.getElementById("eth-price");
  const solPriceEl = document.getElementById("sol-price");
  const lastUpdateEl = document.getElementById("last-update");
  const refreshBtn = document.getElementById("refreshBtn");
  const notifyBtn = document.getElementById("notifyBtn");

  // Read widget configuration injected by NotchDeck
  if (window.notch && window.notch.config) {
    console.log("Widget Config:", window.notch.config);
  }

  // Restore last cached prices from persistent storage
  if (window.notch && window.notch.storage) {
    try {
      const cached = await window.notch.storage.get("last_prices");
      if (cached && typeof cached === "object") {
        if (cached.btc) btcPriceEl.textContent = cached.btc;
        if (cached.eth) ethPriceEl.textContent = cached.eth;
        if (cached.sol) solPriceEl.textContent = cached.sol;
      }
    } catch (err) {
      console.warn("Storage get failed:", err);
    }
  }

  async function fetchPrices() {
    try {
      lastUpdateEl.textContent = "Updating...";
      // Fetch public CoinGecko simple price API
      const res = await fetch(
        "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd"
      );
      if (res.ok) {
        const data = await res.json();
        const btc = "$" + data.bitcoin.usd.toLocaleString();
        const eth = "$" + data.ethereum.usd.toLocaleString();
        const sol = "$" + data.solana.usd.toLocaleString();

        btcPriceEl.textContent = btc;
        ethPriceEl.textContent = eth;
        solPriceEl.textContent = sol;

        // Persist to widget storage
        if (window.notch && window.notch.storage) {
          await window.notch.storage.set("last_prices", { btc, eth, sol });
        }
      }
      lastUpdateEl.textContent = "Updated " + new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } catch (e) {
      lastUpdateEl.textContent = "Offline";
    }
  }

  refreshBtn.addEventListener("click", () => {
    fetchPrices();
  });

  notifyBtn.addEventListener("click", () => {
    if (window.notch && window.notch.notify) {
      window.notch.notify("BTC is currently " + btcPriceEl.textContent);
    }
  });

  // Fetch prices initially and poll every 60 seconds
  fetchPrices();
  setInterval(fetchPrices, 60000);
});
