import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { BigInt, Address } from "@graphprotocol/graph-ts"
import { CampWinnersAdded } from "../generated/schema"
import { CampWinnersAdded as CampWinnersAddedEvent } from "../generated/Campagins/Campagins"
import { handleCampWinnersAdded } from "../src/campagins"
import { createCampWinnersAddedEvent } from "./campagins-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let campaginId = BigInt.fromI32(234)
    let winners = [
      Address.fromString("0x0000000000000000000000000000000000000001")
    ]
    let newCampWinnersAddedEvent = createCampWinnersAddedEvent(
      campaginId,
      winners
    )
    handleCampWinnersAdded(newCampWinnersAddedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("CampWinnersAdded created and stored", () => {
    assert.entityCount("CampWinnersAdded", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "CampWinnersAdded",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "campaginId",
      "234"
    )
    assert.fieldEquals(
      "CampWinnersAdded",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "winners",
      "[0x0000000000000000000000000000000000000001]"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
