import TokenConfigInterface from '../lib/TokenConfigInterface';
import * as Networks from '../lib/Networks';

const TokenConfig: TokenConfigInterface = {
  testnet: Networks.bscTestnet,
  mainnet: Networks.bscMainnet,
  contractName: "URAGame",
  root: "0xb471A86EC50B2783e44e72eC535c832B586A9ada",
  charity: "0x50773E563fc61Df9B604a1E02b8E369f57f70404",
  busdToken: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
  contractAddress: "0x423237005A35787fB706Fa5F6f436Fe75534daEe",
};

export default TokenConfig;
