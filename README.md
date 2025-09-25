# Trade Secrets Smart Contract

A comprehensive IP registry smart contract for confidential business information and trade secret protection on the Stacks blockchain.

## Overview

The Trade Secrets smart contract provides a secure, blockchain-based registry for companies to establish ownership and protection of confidential business information. Built on the Stacks blockchain using Clarity, this contract ensures transparency, immutability, and verifiable ownership of trade secrets while maintaining confidentiality through cryptographic hashing.

## Features

### Core Functionality
- **Trade Secret Registration**: Register confidential business information with metadata and cryptographic hashes
- **Ownership Management**: Transfer ownership with complete audit trails and historical tracking
- **Access Control**: Grant and revoke granular access permissions with configurable expiration dates
- **Confidentiality Levels**: Five-tier confidentiality classification system (1-5 scale)
- **Dispute Resolution**: Built-in dispute filing and tracking system
- **Audit Trail**: Complete ownership history and access logs

### Security Features
- **Hash-Based Storage**: Actual trade secret content stored as SHA256 hashes for confidentiality
- **Owner-Only Operations**: Strict ownership validation for all sensitive operations
- **Access Level Control**: Three-tier access system (metadata, hash, full access)
- **Deactivation System**: Soft delete functionality for trade secret lifecycle management

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Epoch**: 2.5
- **Contract Version**: 1.0.0

### Data Structures

#### Trade Secret Registry
```clarity
{
  owner: principal,
  title: (string-ascii 100),
  description-hash: (buff 32),
  category: (string-ascii 50),
  registration-date: uint,
  last-updated: uint,
  is-active: bool,
  confidentiality-level: uint
}
```

#### Access Control
```clarity
{
  granted-by: principal,
  granted-date: uint,
  access-level: uint,
  expiry-date: (optional uint)
}
```

#### Ownership History
```clarity
{
  previous-owner: (optional principal),
  new-owner: principal,
  transfer-date: uint,
  reason: (string-ascii 100)
}
```

## Installation

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) (latest version)
- [Node.js](https://nodejs.org/) (v14 or higher)
- [Stacks CLI](https://docs.stacks.co/docs/write-smart-contracts/cli-wallet-quickstart)

### Setup
1. Clone the repository:
```bash
git clone <repository-url>
cd trade-secrets
```

2. Navigate to the contract directory:
```bash
cd trade-secrets_contract
```

3. Install dependencies:
```bash
npm install
```

4. Check contract syntax:
```bash
clarinet check
```

## Usage Examples

### Register a Trade Secret
```clarity
(contract-call? .trade-secrets register-trade-secret
  "Manufacturing Process Alpha"
  0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
  "Manufacturing"
  u4)
```

### Transfer Ownership
```clarity
(contract-call? .trade-secrets transfer-ownership
  u1
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  "Corporate acquisition")
```

### Grant Access
```clarity
(contract-call? .trade-secrets grant-access
  u1
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  u2
  (some u500000)) ;; Expires at block 500000
```

### Query Trade Secret
```clarity
(contract-call? .trade-secrets get-trade-secret u1)
```

## Contract Functions

### Public Functions

#### `register-trade-secret`
Registers a new trade secret in the registry.
- **Parameters**: title, description-hash, category, confidentiality-level
- **Returns**: Trade secret ID
- **Access**: Any user

#### `transfer-ownership`
Transfers ownership of a trade secret to a new owner.
- **Parameters**: trade-secret-id, new-owner, reason
- **Returns**: Boolean success
- **Access**: Current owner only

#### `grant-access`
Grants access to a trade secret with specified permissions.
- **Parameters**: trade-secret-id, accessor, access-level, expiry-date
- **Returns**: Boolean success
- **Access**: Owner only

#### `revoke-access`
Revokes previously granted access permissions.
- **Parameters**: trade-secret-id, accessor
- **Returns**: Boolean success
- **Access**: Owner only

#### `file-dispute`
Files a dispute regarding trade secret ownership or validity.
- **Parameters**: trade-secret-id, dispute-reason
- **Returns**: Dispute ID
- **Access**: Any user (except owner)

#### `update-trade-secret`
Updates trade secret information and metadata.
- **Parameters**: trade-secret-id, title, description-hash, category, confidentiality-level
- **Returns**: Boolean success
- **Access**: Owner only

#### `deactivate-trade-secret`
Deactivates a trade secret (soft delete).
- **Parameters**: trade-secret-id
- **Returns**: Boolean success
- **Access**: Owner only

### Read-Only Functions

#### `get-trade-secret`
Retrieves complete trade secret information.
- **Parameters**: trade-secret-id
- **Returns**: Trade secret data or none

#### `has-access`
Checks if a principal has access to a trade secret.
- **Parameters**: trade-secret-id, accessor
- **Returns**: Boolean access status

#### `get-access-level`
Returns the access level for a specific accessor.
- **Parameters**: trade-secret-id, accessor
- **Returns**: Access level (1-3) or none

#### `get-ownership-history`
Retrieves ownership history for a specific sequence.
- **Parameters**: trade-secret-id, sequence
- **Returns**: Ownership record or none

#### `get-dispute`
Retrieves dispute information by ID.
- **Parameters**: dispute-id
- **Returns**: Dispute data or none

#### `get-total-trade-secrets`
Returns the total number of registered trade secrets.
- **Returns**: Total count

#### `get-total-disputes`
Returns the total number of filed disputes.
- **Returns**: Total dispute count

#### `is-active-trade-secret`
Checks if a trade secret is active.
- **Parameters**: trade-secret-id
- **Returns**: Boolean active status

### Access Levels
- **Level 1**: View metadata only (title, category, dates)
- **Level 2**: View metadata and description hash
- **Level 3**: Full access to all trade secret information

### Confidentiality Levels
- **Level 1**: Public/Low sensitivity
- **Level 2**: Internal use
- **Level 3**: Confidential
- **Level 4**: Highly confidential
- **Level 5**: Top secret

## Deployment

### Local Development
1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy contract:
```clarity
::deploy_contract trade-secrets
```

### Testnet Deployment
1. Configure testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deploy --testnet
```

### Mainnet Deployment
1. Configure mainnet settings in `settings/Mainnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deploy --mainnet
```

## Security Considerations

### Data Protection
- Trade secret descriptions are stored as SHA256 hashes, not plaintext
- Original content must be maintained off-chain for verification
- Access controls prevent unauthorized information disclosure

### Access Control
- All sensitive operations require ownership verification
- Time-based access expiration prevents indefinite permissions
- Three-tier access system provides granular control

### Audit Trail
- Complete ownership history maintained on-chain
- All access grants and revocations are logged
- Dispute system provides transparent conflict resolution

### Best Practices
- Always validate input parameters before contract calls
- Use secure hash generation for trade secret descriptions
- Implement off-chain backup systems for critical data
- Regular access permission audits recommended
- Monitor dispute filings for potential security issues

## Error Codes

- `u100`: Owner-only operation attempted by non-owner
- `u101`: Trade secret or resource not found
- `u102`: Resource already exists
- `u103`: Unauthorized operation
- `u104`: Invalid input parameters

## Contributing

This smart contract is designed for production use in intellectual property protection. Any modifications should be thoroughly tested and audited before deployment.

## License

This project is provided as-is for intellectual property protection purposes. Please ensure compliance with relevant trade secret and intellectual property laws in your jurisdiction.