# Stacks Freelance Marketplace Smart Contract

A decentralized freelance marketplace built on the Stacks blockchain, enabling secure job posting, bidding, milestone-based payments, and dispute resolution.

## Overview

This smart contract implements a complete freelance marketplace system with the following key features:
- Job posting and management
- Secure bidding system
- Escrow-based payments
- Milestone tracking
- Dispute resolution
- User rating system

## Contract Features

### Job Management
- Post new freelance jobs with detailed descriptions
- Set multiple payment milestones
- Automatic escrow of funds
- Job status tracking

### Bidding System
- Freelancers can submit detailed proposals
- Bid amount specification
- Prevention of duplicate bids
- Bid acceptance mechanism

### Payment System
- Secure escrow holding
- Milestone-based payment release
- Automatic fund distribution
- Payment verification

### Dispute Resolution
- Fair dispute initiation system
- Voting mechanism for dispute resolution
- Payment release or refund based on votes
- Dispute status tracking

### Rating System
- User rating submission (1-5 scale)
- Cumulative rating tracking
- Average rating calculation
- Rating history preservation

## Functions

### Public Functions

1. Job Management
```clarity
(post-freelance-job (job-title (string-utf8 100)) (job-description (string-utf8 500)) (job-budget uint) (payment-milestones (list 10 uint)))
```
- Posts a new job with title, description, budget, and milestone payments

```clarity
(submit-bid (freelance-job-id uint) (bid-amount uint) (bid-proposal (string-utf8 500)))
```
- Submits a bid for a specific job

```clarity
(accept-freelancer-bid (freelance-job-id uint) (chosen-freelancer principal))
```
- Accepts a freelancer's bid

2. Payment Functions
```clarity
(complete-payment-milestone (freelance-job-id uint))
```
- Releases payment for completed milestone

3. Dispute Functions
```clarity
(initiate-dispute (freelance-job-id uint) (dispute-reason (string-utf8 500)))
```
- Initiates a dispute for a job

```clarity
(cast-dispute-vote (freelance-job-id uint) (vote-to-release bool))
```
- Casts a vote in an active dispute

4. Rating Functions
```clarity
(submit-user-rating (rated-user principal) (rating-value uint))
```
- Submits a rating for a user

### Read-Only Functions

```clarity
(get-job-details (freelance-job-id uint))
(get-freelancer-rating (rated-user principal))
(get-job-bids (freelance-job-id uint))
(get-job-dispute-details (freelance-job-id uint))
```

## Error Codes

- `ERR_UNAUTHORIZED_ACCESS (u100)`: Unauthorized access attempt
- `ERR_JOB_NOT_FOUND (u101)`: Job ID not found
- `ERR_INVALID_JOB_STATUS (u102)`: Invalid job status for operation
- `ERR_INSUFFICIENT_BALANCE (u103)`: Insufficient balance for operation
- `ERR_DUPLICATE_BID (u104)`: Duplicate bid attempt
- `ERR_EXISTING_DISPUTE (u105)`: Dispute already exists
- `ERR_INVALID_RATING_RANGE (u106)`: Invalid rating value

## Security Considerations

- All funds are held in escrow until milestone completion
- Only authorized users can access specific functions
- Dispute resolution requires multiple votes
- Payment releases are milestone-based
- Input validation for all critical parameters

## Best Practices

1. Always verify job details before bidding
2. Set clear milestones when posting jobs
3. Document all disputes thoroughly
4. Maintain professional ratings standards