# Demo video script (DRAFT, max 2:30)

**DRAFT (Batu, 30 Oct).** Hard limit **2.5 minutes** (CLAUDE.md §1). The voice-over is 275 words, about 1:50 at 150 words per minute, which leaves room for pauses and live screens. Record by **Sat 31 Oct 13:00**.

Must be in the video:
- **Cardano:** target user, problem, business case, one paid job end to end, and its tx on a preprod explorer.
- **API3:** a valid, fresh response triggers the action, then four rejections: (a) edited value, (b) too old, (c) different request, (d) wrong key.

`TODO` marks screens that need things not built yet.

| Time | Screen | Voice-over |
|---|---|---|
| 0:00–0:12 | Title card: "Your supplier was approved last month. That should not approve today's payment." | "Companies check a supplier once, at onboarding. Then they pay instalments for months, and nobody checks again." |
| 0:12–0:30 | Simple slide: robot maker → motor supplier, 3 stages (500 / 1,000 / 1,500). Stage 2 marked red: "supplier in liquidation". | "Meet a small robot maker paying a motor supplier in three stages. If the supplier goes into liquidation after stage one, the next transfer still goes out, and that money is hard to get back. SupplierPulse makes every payment need fresh proof." |
| 0:30–0:45 | Diagram from the README (buyer → Cardano agent → AirnodeHub → contract). | "The buyer hires our agent on Cardano. Before each stage, the agent fetches the supplier's signed status from the UK company register through API3, and our contract decides: active means this one stage is paid; anything else locks the rest." |
| 0:45–1:15 | Live: start a paid job (`buy_job.py` or Sokosumi). Show the escrow lock tx on preprod.cardanoscan.io, the agent log, the result tx. `TODO`: run with the SupplierPulse app, not `mock`. | "Here the buyer hires the agent. Five test ADA go into Masumi escrow on Cardano preprod: here is the lock transaction. The agent runs the check, the contract verifies it on chain, and the agent posts the result. The escrow releases the fee only for a check that really ran. If it fails, the buyer is refunded automatically." |
| 1:15–1:40 | Live: order A (active company `09729896`): evidence accepted → permit → stage paid. Order B (company `07418033`, liquidation): held → buyer refund. Show the "protected remaining balance" screen. `TODO`: deployed contract + demo screen. | "Order A: the supplier is active, so the permit is issued and the stage is paid. Order B: the register says liquidation, so the payment is held and the buyer takes the remaining balance back. These are real, signed register records." |
| 1:40–2:10 | Tamper test, one line per case with a red ✗ and the revert reason: (a) `liquidation`→`active` = `WrongSigner`; (b) old response = `StaleResponse`; (c) another company's response = `WrongRequest`; (d) other key = `WrongSigner`. Replay = `Replayed`. | "Now we try to cheat. Edit liquidation to active: rejected, the signature no longer matches. An old response: rejected as stale. Another company's valid record: rejected, wrong request. Our own signature instead of the Airnode's: rejected, wrong signer. And the same response twice: rejected as a replay." |
| 2:10–2:25 | Two explorer tabs side by side: Cardano preprod tx and the EVM tx. Text: "Agent = bridge between chains." | "Both sides are verifiable on their explorers. Our agent is the bridge between them, and the agent only gets paid for doing the check right." |
| 2:25–2:30 | End card: SupplierPulse, repo URL, "Cardano × API3, TUM Blockchain Hackathon 2026". | "SupplierPulse: payment permits that expire." |

## Recording notes

- Prepare every tab and terminal before recording. Live chain calls can be slow, so record each segment separately and cut them together.
- Use the real signed samples in `docs/samples/companies-house/` for the API3 part, and fresh ones on the day: they must be younger than `maxAge` when submitted.
- Do not show the status changing for one company between stages. That does not happen live, so show two orders (active vs liquidation).
- Do not show private keys, `.env` files or the Masumi admin key on screen.
- Check the final length with a timer. Over 2:30 is not allowed.
