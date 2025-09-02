# Weavepoint Contracts

<div align="center">
  <img src="https://arweave.net/a1oV1GL54mZ7UYA9whTCRCBF00M2SxkjEkIqL9L2HLE" alt="Weavepoint Logo" width="300">
</div>

AO is a powerful decentralized ecosystem where autonomous agents run independently, executing complex tasks all on their own.

**The problem?** An agent is only as good as the data it has access to and unfortunately it's very cumbersome to provide high quality data to an agent on a decentralized system like AO.

**This is what Weavepoint solves.** Easy access to high quality, trusted agent data as a service.

🌐 **Visit Weavepoint:** https://weavepoint-server.onrender.com

All your agent needs is a simple call to one of Weavepoint's AO Relays and your agent will have access to a world of high quality data:

```lua
function GetLatestData()
    ao.send({ Target = NCAA_RELAY, Action = "get-latest-data" })
    local res = Receive({Action = "Latest-Data-Response"})
    if res then
        LATEST_RELAY_DATA = res.Data
    end
end
```

## Relay Services

### Botega
<img src="https://arweave.net/xLhA02fXSgZ1USx4wJ3_wcTx8ONk7kslo99zUyh2OQ4" alt="Botega Logo" width="100">

Track how tokens are moving across the ecosystem with data directly from one of the best DEX's on AO.

### Pyth
<img src="https://arweave.net/0Cw9f2GIzM6NvfMDof3n95HLCOK3YUe_60uz_trhIDo" alt="Pyth Logo" width="70">

Track some of the most popular tokens with super fast refresh rates on the Pyth network.

### CoinGecko
<img src="https://arweave.net/GK4qGR4T3N4a0Xq4bMF42QJI6jYK6bh3epwVIHXKXJ8" alt="CoinGecko Logo" width="100">

Give your agent a broad set of data from the overall crypto market. Track stats like ETH dominance or 24hr changes.

### Astro USDA
<img src="https://arweave.net/5ni8_67p9tb9b4twi24OPLGfBb6gY0eijep0r7OK4Yc" alt="Astro USDA" width="100">

USDA will be the primary source of liquidity entering and exiting the DEX markets so tracking its movement is an extremely powerful tool for every AO Agent.

### ESPN
<img src="https://arweave.net/-dFa1kPKMpVx7xlcysH2nNOc3GJfU9pjX6saEVZKq_A" alt="ESPN" width="100">

Whether it is a prediction market or fantasy football, Weavepoint's ESPN relay has the latest NCAA data ready for your agents.

## Project Structure

### Agents
- `apusPredictionAgent.lua` - APUS prediction agent
- `ncaaFootballPredictionAgent.lua` - NCAA Football prediction agent

### Relays
- `astroRelay.lua` - Astro relay implementation
- `botegaRelay.lua` - Botega relay implementation
- `geckoRelay.lua` - Gecko relay implementation
- `ncaaFootballRelay.lua` - NCAA Football relay implementation
- `pythRelay.lua` - Pyth relay implementation

## Validators

Run your own Weavepoint Validator: [Weavepoint Validator](https://github.com/FUDBear/Weavepoint-Validator)

## FAQ

**Q: Doesn't Hyperbeam's ability to get outside data make Weavepoint obsolete?**

A: It doesn't at all because the data being pulled into the AO ecosystem with Weavepoint is validated by users running Weavepoint Validators, thus making the data trustworthy. This is important for agents deciding outcomes for groups, like prediction markets where the data must be accurate and verifiable.

**Q: Do I have to run a validator to use the service?**

A: No, any process on AO can query data from any relay.

**Q: Do Validators get token emission rewards for running?**

A: That is the plan but not currently implemented. Users that run Validators would get tokens as rewards.

**Q: How do I get a CoinGecko API key to run my validator?**

A: [Setting up your API key](https://docs.coingecko.com/reference/setting-up-your-api-key)

## Contributing

@FUDBear
