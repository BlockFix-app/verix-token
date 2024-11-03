# Verix Token Project Structure

```
verix-token/
│
├── .github/
│   └── workflows/
│       ├── main.yml               # Main CI pipeline
│       └── audit.yml              # Security audit workflow
│
├── contracts/
│   ├── core/
│   │   ├── VerixToken.sol         # Main token contract
│   │   └── VerixTokenVesting.sol  # Vesting contract
│   │
│   ├── governance/
│   │   ├── VerixGovernor.sol      # Governance implementation
│   │   └── VerixTimelock.sol      # Timelock controller
│   │
│   ├── dividend/
│   │   └── VerixDividend.sol      # Dividend distribution logic
│   │
│   ├── interfaces/
│   │   ├── IVerixToken.sol        # Token interface
│   │   ├── IVerixGovernor.sol     # Governance interface
│   │   └── IVerixDividend.sol     # Dividend interface
│   │
│   └── libraries/
│       ├── VerixMath.sol          # Custom math functions
│       └── VerixSecurity.sol      # Security utilities
│
├── scripts/
│   ├── deploy/
│   │   ├── 001_deploy_token.ts    # Token deployment
│   │   ├── 002_deploy_vesting.ts  # Vesting deployment
│   │   └── 003_setup_roles.ts     # Role configuration
│   │
│   └── utils/
│       ├── constants.ts           # Contract constants
│       └── verification.ts        # Contract verification
│
├── test/
│   ├── unit/
│   │   ├── VerixToken.test.ts     # Token unit tests
│   │   ├── VerixVesting.test.ts   # Vesting unit tests
│   │   └── VerixGovernor.test.ts  # Governance unit tests
│   │
│   ├── integration/
│   │   ├── TokenSystem.test.ts    # System integration tests
│   │   └── Scenarios.test.ts      # Complex scenario tests
│   │
│   └── utils/
│       ├── fixtures.ts            # Test fixtures
│       └── helpers.ts             # Test helpers
│
├── docs/
│   ├── technical/
│   │   ├── architecture.md        # System architecture
│   │   ├── contracts.md          # Contract documentation
│   │   └── deployment.md         # Deployment guide
│   │
│   ├── guides/
│   │   ├── integration.md        # Integration guide
│   │   └── security.md           # Security considerations
│   │
│   └── api/
│       └── reference.md          # API documentation
│
├── tasks/
│   ├── accounts.ts               # Account management tasks
│   ├── deploy.ts                # Deployment tasks
│   └── verify.ts                # Verification tasks
│
├── frontend/
│   ├── src/
│   │   ├── components/          # React components
│   │   ├── contracts/           # Contract ABIs
│   │   ├── hooks/               # Custom hooks
│   │   └── utils/               # Frontend utilities
│   │
│   ├── public/                  # Static assets
│   └── package.json             # Frontend dependencies
│
├── config/
│   ├── networks.ts              # Network configurations
│   └── constants.ts             # Project constants
│
├── .env.example                 # Environment variables template
├── .gitignore                   # Git ignore rules
├── .prettierrc                  # Code formatting rules
├── .solhint.json               # Solidity linting rules
├── hardhat.config.ts           # Hardhat configuration
├── package.json                # Project dependencies
├── tsconfig.json               # TypeScript configuration
└── README.md                   # Project documentation
```

Key files to implement:


import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-contract-sizer";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: "auto"
    },
    mumbai: {
      url: process.env.MUMBAI_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: "auto"
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY
  },
  etherscan: {
    apiKey: {
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || ""
    }
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false
  }
};

export default config;
