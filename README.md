# Carbon-Swap Smart Contract

A decentralized carbon credit trading platform built on the Stacks blockchain using Clarity smart contracts. This contract enables the issuance, trading, and retirement of verified carbon offset certificates in a transparent and secure manner.

## Overview

Carbon-Swap facilitates the creation of a marketplace for carbon credits, allowing organizations and individuals to trade verified carbon offset certificates. The contract ensures transparency, prevents double-spending, and maintains a clear audit trail of all carbon credit transactions.

## Features

### Core Functionality
- **Certificate Issuance**: Create new carbon offset certificates with verification standards
- **Marketplace Trading**: List and purchase carbon credits with automatic price discovery
- **Credit Retirement**: Permanently retire credits for carbon offsetting claims
- **Direct Transfers**: Send credits directly between users
- **Balance Management**: Track individual carbon credit holdings

### Security Features
- Owner authorization controls
- Certificate validity verification
- Expiry date enforcement
- Double-spending prevention
- Balance sufficiency checks
- Comprehensive error handling

## Contract Structure

### Data Models

#### Carbon Certificates
```clarity
{
  issuer: principal,           // Certificate issuer
  holder: principal,           // Current holder
  carbon-amount: uint,         // Tons of CO2 equivalent
  verification-standard: string, // e.g., "VCS", "Gold Standard"
  issue-date: uint,           // Block height when issued
  expiry-date: uint,          // Block height when expires
  is-used: bool,              // Whether credits are retired
  project-name: string        // Name of offset project
}
```

#### Certificate Listings
```clarity
{
  seller: principal,          // Address selling credits
  price-per-ton: uint,        // Price in microSTX per ton
  amount-available: uint,     // Available credits for sale
  is-active: bool            // Whether listing is active
}
```

#### User Balances
```clarity
{
  carbon-credits: uint       // Total credits held by user
}
```

## Functions

### Read-Only Functions

#### `get-certificate (cert-id uint)`
Returns certificate details for a given certificate ID.

#### `get-listing (cert-id uint)`
Returns active listing information for a certificate.

#### `get-user-balance (user principal)`
Returns the carbon credit balance for a specific user.

#### `get-contract-fee-rate`
Returns the current contract fee rate in basis points.

### Public Functions

#### `issue-certificate`
```clarity
(issue-certificate 
  (carbon-amount uint)
  (verification-standard (string-ascii 50))
  (expiry-date uint)
  (project-name (string-ascii 100))
  (holder principal))
```
Creates a new carbon certificate. Only authorized issuers can call this function.

**Parameters:**
- `carbon-amount`: Tons of CO2 equivalent
- `verification-standard`: Standard used for verification (e.g., "VCS", "Gold Standard")
- `expiry-date`: Block height when certificate expires
- `project-name`: Name of the carbon offset project
- `holder`: Principal who will hold the certificate

#### `list-certificate`
```clarity
(list-certificate (cert-id uint) (price-per-ton uint) (amount uint))
```
Lists a certificate for sale in the marketplace.

**Parameters:**
- `cert-id`: ID of the certificate to list
- `price-per-ton`: Price per ton in microSTX
- `amount`: Amount of credits to list for sale

#### `buy-credits`
```clarity
(buy-credits (cert-id uint) (amount uint))
```
Purchases carbon credits from an active listing.

**Parameters:**
- `cert-id`: ID of the certificate to purchase from
- `amount`: Amount of credits to purchase

#### `retire-credits`
```clarity
(retire-credits (cert-id uint) (amount uint))
```
Permanently retires carbon credits for offsetting claims.

**Parameters:**
- `cert-id`: ID of the certificate to retire credits from
- `amount`: Amount of credits to retire

#### `transfer-credits`
```clarity
(transfer-credits (recipient principal) (amount uint))
```
Transfers credits directly to another user.

**Parameters:**
- `recipient`: Address to receive the credits
- `amount`: Amount of credits to transfer

#### `cancel-listing`
```clarity
(cancel-listing (cert-id uint))
```
Cancels an active certificate listing.

**Parameters:**
- `cert-id`: ID of the certificate listing to cancel

#### `set-contract-fee-rate`
```clarity
(set-contract-fee-rate (new-rate uint))
```
Updates the contract fee rate. Only callable by contract owner.

**Parameters:**
- `new-rate`: New fee rate in basis points (max 1000 = 10%)

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR-NOT-AUTHORIZED | User not authorized for this action |
| u101 | ERR-INVALID-AMOUNT | Invalid amount specified |
| u102 | ERR-INSUFFICIENT-BALANCE | Insufficient balance for transaction |
| u103 | ERR-CERTIFICATE-NOT-FOUND | Certificate does not exist |
| u104 | ERR-CERTIFICATE-EXPIRED | Certificate has expired |
| u105 | ERR-CERTIFICATE-ALREADY-USED | Certificate has already been used |
| u106 | ERR-INVALID-PRICE | Invalid price specified |
| u107 | ERR-TRANSFER-FAILED | STX transfer failed |

## Usage Examples

### Issuing a Certificate
```clarity
(contract-call? .carbon-swap issue-certificate 
  u100                    ;; 100 tons CO2
  "VCS"                   ;; Verification standard
  u1000000                ;; Expiry block height
  "Amazon Reforestation"  ;; Project name
  'SP1234...)             ;; Holder address
```

### Listing Credits for Sale
```clarity
(contract-call? .carbon-swap list-certificate 
  u1                      ;; Certificate ID
  u50000000               ;; 50 STX per ton (in microSTX)
  u25)                    ;; 25 tons for sale
```

### Buying Credits
```clarity
(contract-call? .carbon-swap buy-credits 
  u1                      ;; Certificate ID
  u10)                    ;; Buy 10 tons
```

### Retiring Credits
```clarity
(contract-call? .carbon-swap retire-credits 
  u1                      ;; Certificate ID
  u5)                     ;; Retire 5 tons
```

## Fee Structure

The contract charges a fee on each trade transaction:
- **Default Fee**: 2.5% (250 basis points)
- **Maximum Fee**: 10% (1000 basis points)
- **Fee Recipient**: Contract owner
- **Adjustable**: Yes, by contract owner only
