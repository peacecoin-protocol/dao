import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
import {
  CampWinnersAdded,
  CampWinnersClaimed,
  CampaginCreated,
  Initialized,
  OwnershipTransferred
} from "../generated/Campagins/Campagins"

export function createCampWinnersAddedEvent(
  campaginId: BigInt,
  winners: Array<Address>
): CampWinnersAdded {
  let campWinnersAddedEvent = changetype<CampWinnersAdded>(newMockEvent())

  campWinnersAddedEvent.parameters = new Array()

  campWinnersAddedEvent.parameters.push(
    new ethereum.EventParam(
      "campaginId",
      ethereum.Value.fromUnsignedBigInt(campaginId)
    )
  )
  campWinnersAddedEvent.parameters.push(
    new ethereum.EventParam("winners", ethereum.Value.fromAddressArray(winners))
  )

  return campWinnersAddedEvent
}

export function createCampWinnersClaimedEvent(
  campaginId: BigInt,
  winner: Address
): CampWinnersClaimed {
  let campWinnersClaimedEvent = changetype<CampWinnersClaimed>(newMockEvent())

  campWinnersClaimedEvent.parameters = new Array()

  campWinnersClaimedEvent.parameters.push(
    new ethereum.EventParam(
      "campaginId",
      ethereum.Value.fromUnsignedBigInt(campaginId)
    )
  )
  campWinnersClaimedEvent.parameters.push(
    new ethereum.EventParam("winner", ethereum.Value.fromAddress(winner))
  )

  return campWinnersClaimedEvent
}

export function createCampaginCreatedEvent(
  campaginId: BigInt,
  title: string,
  description: string,
  amount: BigInt,
  startDate: BigInt,
  endDate: BigInt,
  validateSignatures: boolean
): CampaginCreated {
  let campaginCreatedEvent = changetype<CampaginCreated>(newMockEvent())

  campaginCreatedEvent.parameters = new Array()

  campaginCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "campaginId",
      ethereum.Value.fromUnsignedBigInt(campaginId)
    )
  )
  campaginCreatedEvent.parameters.push(
    new ethereum.EventParam("title", ethereum.Value.fromString(title))
  )
  campaginCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "description",
      ethereum.Value.fromString(description)
    )
  )
  campaginCreatedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )
  campaginCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "startDate",
      ethereum.Value.fromUnsignedBigInt(startDate)
    )
  )
  campaginCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "endDate",
      ethereum.Value.fromUnsignedBigInt(endDate)
    )
  )
  campaginCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "validateSignatures",
      ethereum.Value.fromBoolean(validateSignatures)
    )
  )

  return campaginCreatedEvent
}

export function createInitializedEvent(version: BigInt): Initialized {
  let initializedEvent = changetype<Initialized>(newMockEvent())

  initializedEvent.parameters = new Array()

  initializedEvent.parameters.push(
    new ethereum.EventParam(
      "version",
      ethereum.Value.fromUnsignedBigInt(version)
    )
  )

  return initializedEvent
}

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent =
    changetype<OwnershipTransferred>(newMockEvent())

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}
