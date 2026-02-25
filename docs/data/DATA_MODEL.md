# Data Model (MVP)
- description: string
- category: string
- minFollowers: number
- locationRequiredCity: string
- cashOffer: number
- productBenefit: string?
- coverImageUrl: string?
- status: `active` | `matched` | `completed` | `cancelled`
- applicantsCount: number
- createdAt: timestamp
- deadline: timestamp?

## applications
- id: string
- campaignId: string
- creatorId: string
- brandId: string
- status: `pending` | `accepted` | `rejected`
- proposalMessage: string?
- createdAt: timestamp

## chats
- id: string
- campaignId: string
- creatorId: string
- brandId: string
- lastMessage: string?
- updatedAt: timestamp

## messages
- id: string
- chatId: string
- senderId: string
- type: `text` | `media` | `link` | `system`
- text: string?
- mediaUrl: string?
- linkUrl: string?
- createdAt: timestamp

## projects (workspace state)
- id: string (same as chatId or campaignId)
- campaignId: string
- chatId: string
- status: `matched` | `escrow_locked` | `in_progress` | `delivered` | `completed` | `disputed`
- escrowStatus: `not_started` | `locked` | `released` | `refunded`
- deliveryItems: array
- disputeTicketId: string?
- updatedAt: timestamp

## reviews
- id: string
- campaignId: string
- fromUserId: string
- toUserId: string
- rating: 1..5
- text: string?
- createdAt: timestamp

## transactions (optional MVP)
- id: string
- campaignId: string
- amount: number
- fee: number
- provider: `mock` | `stripe`
- status: `pending` | `locked` | `released` | `refunded`
- createdAt: timestamp