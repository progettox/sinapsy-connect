# sinapsy-connect
users
collabs
applications
chats
messages
reviews
transactions
users/{userId} {
  username: string
  email: string
  role: "creator" | "brand"
  category: string
  profileImage: string (url)

  bio: string
  location: string

  // Social
  instagramConnected: boolean
  tiktokConnected: boolean
  followers: number

  // Score
  sinapsyScore: number
  reviewsCount: number

  // Metadata
  createdAt: timestamp
}
collabs/{collabId} {
  brandId: string (userId)

  title: string
  description: string
  category: string

  // Requisiti
  minFollowers: number
  locationRequired: string

  // Offerta
  cashOffer: number
  productBenefit: string

  // Media
  coverImage: string (url)

  // Stato
  status: "active" | "matched" | "completed"

  applicantsCount: number

  createdAt: timestamp
  deadline: timestamp
}
applications/{applicationId} {
  collabId: string
  creatorId: string
  brandId: string

  status: "pending" | "accepted" | "rejected"

  proposalMessage: string

  createdAt: timestamp
}
chats/{chatId} {
  collabId: string
  creatorId: string
  brandId: string

  lastMessage: string
  lastMessageAt: timestamp

  createdAt: timestamp
}
chats/{chatId}/messages/{messageId}
{
  senderId: string
  text: string
  imageUrl: string (optional)

  createdAt: timestamp
}
reviews/{reviewId} {
  collabId: string

  fromUserId: string
  toUserId: string

  rating: number (1-5)
  comment: string

  createdAt: timestamp
}
transactions/{transactionId} {
  collabId: string

  brandId: string
  creatorId: string

  amount: number
  platformFee: number

  status: 
    "pending" |
    "in_escrow" |
    "released" |
    "refunded"

  paymentMethod: "apple_pay" | "card"

  createdAt: timestamp
  releasedAt: timestamp
}
Sinapsy Score = media recensioni × fattore affidabilità
