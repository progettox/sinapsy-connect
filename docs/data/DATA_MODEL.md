# Data Model (MVP)

## users
- id: string
- role: `brand` | `creator`
- username: string
- category: string
- city: string
- instagramConnected: bool
- followers: number?
- verified: bool
- createdAt: timestamp

## campaigns
- id: string
- brandId: string
- title: string
- description: string
- category: string
- minFollowers: number
- locationRequiredCity: string? (opzionale, non bloccante)
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
- note: una candidatura `pending` puo essere rimossa dal creator (delete) o marcata `rejected` come fallback withdraw; poi puo essere inviata di nuovo
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
- status: `matched` | `in_progress` | `delivered` | `completed` | `disputed`
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
