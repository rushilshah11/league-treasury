import {
  CronCapability,
  HTTPClient,
  handler,
  consensusIdenticalAggregation,
  EVMClient,
  getNetwork,
  hexToBase64,
  bytesToHex,
  encodeCallMsg,
  LAST_FINALIZED_BLOCK_NUMBER,
  type Runtime,
  type NodeRuntime,
  Runner,
} from "@chainlink/cre-sdk";
import {
  type Address,
  decodeFunctionResult,
  encodeAbiParameters,
  encodeFunctionData,
  parseAbi,
  parseAbiParameters,
  zeroAddress,
} from "viem";

export type Config = {
  schedule: string;
  espnLeagueId: string; // the league's ID on ESPN
  sport: string; // ESPN game code: ffl, fba, flb or fhl
  season: string; // e.g. "2027"
  allowNonFinal: boolean; // simulation only: accept in-progress standings
  chainName: string; // the chain the treasury is on, in Chainlink's naming
  treasuryAddress: string; // the LeagueTreasury, read to see which teams joined
  receiverAddress: string; // our CreStandingsReceiver contract
  leagueId: string; // the league's ID in LeagueTreasury (not ESPN's ID)
  gasLimit: string; // gas for the write, as a string
};

const ESPN_API = "https://lm-api-reads.fantasy.espn.com/apis/v3/games";

type EspnTeam = {
  id: number;
  rankCalculatedFinal?: number;
  playoffSeed?: number;
  record?: { overall?: { percentage?: number; pointsFor?: number } };
};

// Runs on EVERY node, each on its own machine. Each node calls ESPN itself.
// It returns a plain string like "7,3,12,...": the team IDs in finishing order.
// Nodes must return the same string, so we strip out anything that changes
// between calls (timestamps, live scores) and keep only the ranking.
const fetchRanking = (nodeRuntime: NodeRuntime<Config>): string => {
  const { espnLeagueId, sport, season, allowNonFinal } = nodeRuntime.config;
  const url = `${ESPN_API}/${sport}/seasons/${season}/segments/0/leagues/${espnLeagueId}?view=mTeam&view=mSettings&view=mStandings`;

  const httpClient = new HTTPClient();
  const resp = httpClient
    .sendRequest(nodeRuntime, { url, method: "GET" as const })
    .result();
  if (resp.statusCode !== 200) {
    throw new Error(`ESPN returned status ${resp.statusCode}`);
  }

  const raw = JSON.parse(new TextDecoder().decode(resp.body));
  const teams: EspnTeam[] = raw.teams ?? [];
  if (teams.length === 0) throw new Error("ESPN returned no teams");

  // Same rule as the bot: the season is final once every team has a final rank.
  const isFinal = teams.every((t) => (t.rankCalculatedFinal ?? 0) > 0);
  if (!isFinal && !allowNonFinal) {
    throw new Error("ESPN season is not final yet");
  }

  const hasSeeds = teams.every((t) => (t.playoffSeed ?? 0) > 0);
  teams.sort((a, b) => {
    if (isFinal) return a.rankCalculatedFinal! - b.rankCalculatedFinal!;
    if (hasSeeds) return a.playoffSeed! - b.playoffSeed!;
    const pa = a.record?.overall?.percentage ?? 0;
    const pb = b.record?.overall?.percentage ?? 0;
    return pb - pa || (b.record?.overall?.pointsFor ?? 0) - (a.record?.overall?.pointsFor ?? 0);
  });

  return teams.map((t) => t.id).join(",");
};

// Just the one function we need from the treasury, written as text.
const treasuryAbi = parseAbi([
  "function getMembers(uint256 leagueId) view returns (address[] addresses, (uint32 teamId, bool joined, bool claimed, uint8 finalPlace)[] records)",
]);

// Reads the teams that joined this league from the treasury contract. Runs once for the
// whole network (not per node): the nodes read the same finalized block and agree.
const readJoinedTeamIds = (runtime: Runtime<Config>, evmClient: EVMClient): Set<number> => {
  const callData = encodeFunctionData({
    abi: treasuryAbi,
    functionName: "getMembers",
    args: [BigInt(runtime.config.leagueId)],
  });

  const reply = evmClient
    .callContract(runtime, {
      call: encodeCallMsg({
        from: zeroAddress,
        to: runtime.config.treasuryAddress as Address,
        data: callData,
      }),
      // Only read data the chain has finalized, so a reorg can't change the answer.
      blockNumber: LAST_FINALIZED_BLOCK_NUMBER,
    })
    .result();

  const [, records] = decodeFunctionResult({
    abi: treasuryAbi,
    functionName: "getMembers",
    data: bytesToHex(reply.data),
  });
  return new Set(records.map((member) => Number(member.teamId)));
};

// Runs once per trigger. Four moves:
//   1. every node fetches ESPN and the network agrees on the ranking
//   2. read which teams joined the league from the treasury, and keep only those
//   3. the ranking is packed into a report and signed by the network
//   4. the signed report is sent to our receiver contract through the forwarder
const onCronTrigger = (runtime: Runtime<Config>): string => {
  // Move 1: hand fetchRanking to every node; a majority must return the same string.
  const ranking = runtime
    .runInNodeMode(fetchRanking, consensusIdenticalAggregation<string>())()
    .result();
  runtime.log(`Agreed ranking (team IDs, 1st to last): ${ranking}`);

  const { chainName, receiverAddress, leagueId, gasLimit } = runtime.config;
  if (/^0x0{40}$/i.test(receiverAddress)) {
    throw new Error("Set receiverAddress in the config to the deployed CreStandingsReceiver");
  }

  // Move 2: ESPN ranks every team in its league, but the contract only accepts the teams
  // that joined (the bot does the same filtering). Ask the treasury who joined.
  const network = getNetwork({ chainFamily: "evm", chainSelectorName: chainName, isTestnet: true });
  if (!network) throw new Error(`Unknown chain: ${chainName}`);
  const evmClient = new EVMClient(network.chainSelector.selector);

  const joined = readJoinedTeamIds(runtime, evmClient);
  const teamIds = ranking
    .split(",")
    .map((id) => Number(id))
    .filter((id) => joined.has(id));
  if (teamIds.length !== joined.size) {
    throw new Error(`ESPN is missing a joined team: ${teamIds.length} matched, ${joined.size} joined`);
  }
  runtime.log(`Teams that joined league ${leagueId}, in finishing order: ${teamIds.join(",")}`);

  // Move 3: pack (leagueId, ranking) the way the receiver's abi.decode expects,
  // then ask the network to sign it. The types and order must match the contract.
  const payload = encodeAbiParameters(parseAbiParameters("uint256 leagueId, uint32[] ranking"), [
    BigInt(leagueId),
    teamIds,
  ]);
  const report = runtime
    .report({
      encodedPayload: hexToBase64(payload),
      encoderName: "evm",
      signingAlgo: "ecdsa",
      hashingAlgo: "keccak256",
    })
    .result();

  // Move 4: send the signed report to our receiver on the treasury's chain.
  const written = evmClient
    .writeReport(runtime, {
      receiver: receiverAddress,
      report,
      gasConfig: { gasLimit },
    })
    .result();

  // Without --broadcast the simulator skips the real transaction and the hash is empty.
  const txHash = bytesToHex(written.txHash || new Uint8Array(32));
  runtime.log(`Report sent to ${receiverAddress}. Transaction: ${txHash}`);
  return txHash;
};

export const initWorkflow = (config: Config) => {
  const cron = new CronCapability();
  return [handler(cron.trigger({ schedule: config.schedule }), onCronTrigger)];
};

export async function main() {
  const runner = await Runner.newRunner<Config>();
  await runner.run(initWorkflow);
}
