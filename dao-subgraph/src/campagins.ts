import {
  CampWinnersAdded as CampWinnersAddedEvent,
  CampWinnersClaimed as CampWinnersClaimedEvent,
  CampaginCreated as CampaginCreatedEvent,
  Initialized as InitializedEvent,
  OwnershipTransferred as OwnershipTransferredEvent
} from "../generated/Campagins/Campagins"
import {
  CampWinnersAdded,
  CampWinnersClaimed,
  CampaginCreated,
  Initialized,
  OwnershipTransferred
} from "../generated/schema"
import { Bytes } from "@graphprotocol/graph-ts"

export function handleCampWinnersAdded(event: CampWinnersAddedEvent): void {
  let entity = new CampWinnersAdded(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.campaginId = event.params.campaginId
  entity.winners = changetype<Bytes[]>(event.params.winners)

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleCampWinnersClaimed(event: CampWinnersClaimedEvent): void {
  let entity = new CampWinnersClaimed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.campaginId = event.params.campaginId
  entity.winner = event.params.winner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleCampaginCreated(event: CampaginCreatedEvent): void {
  let entity = new CampaginCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.campaginId = event.params.campaginId
  entity.title = event.params.title
  entity.description = event.params.description
  entity.amount = event.params.amount
  entity.startDate = event.params.startDate
  entity.endDate = event.params.endDate
  entity.validateSignatures = event.params.validateSignatures

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleInitialized(event: InitializedEvent): void {
  let entity = new Initialized(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.version = event.params.version

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
