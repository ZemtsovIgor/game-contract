import TokenConfig from './TokenConfig';

// Update the following array if you change the constructor arguments...
const ContractArguments = [
  TokenConfig.root,
  TokenConfig.charity,
  TokenConfig.busdToken,
] as const;

export default ContractArguments;
