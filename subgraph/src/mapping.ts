import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { Crafted } from "../generated/GameItems/GameItems";
import { LiquidityAdded, LiquidityRemoved, Swapped } from "../generated/ResourceAMM/ResourceAMM";
import { Listed, Rented, Unlisted } from "../generated/NFTRentalVault/NFTRentalVault";
import { Craft, Pool, Swap, LiquidityPosition, Rental } from "../generated/schema";

function pool(id: Bytes): Pool {
  let entity = Pool.load(id);
  if (entity == null) {
    entity = new Pool(id);
    entity.reserveA = BigInt.zero();
    entity.reserveB = BigInt.zero();
    entity.liquidityEvents = BigInt.zero();
    entity.swaps = BigInt.zero();
  }
  return entity;
}

export function handleCrafted(event: Crafted): void {
  let entity = new Craft(event.transaction.hash.concatI32(event.logIndex.toI32()));
  entity.player = event.params.player;
  entity.inputId = event.params.inputId;
  entity.outputId = event.params.outputId;
  entity.inputAmount = event.params.inputAmount;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.save();
}

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let p = pool(event.address);
  p.reserveA = p.reserveA.plus(event.params.amountA);
  p.reserveB = p.reserveB.plus(event.params.amountB);
  p.liquidityEvents = p.liquidityEvents.plus(BigInt.fromI32(1));
  p.save();

  let id = event.params.provider.concat(event.address);
  let position = LiquidityPosition.load(id);
  if (position == null) {
    position = new LiquidityPosition(id);
    position.provider = event.params.provider;
    position.liquidityAdded = BigInt.zero();
    position.liquidityRemoved = BigInt.zero();
  }
  position.liquidityAdded = position.liquidityAdded.plus(event.params.liquidity);
  position.save();
}

export function handleLiquidityRemoved(event: LiquidityRemoved): void {
  let p = pool(event.address);
  p.reserveA = p.reserveA.minus(event.params.amountA);
  p.reserveB = p.reserveB.minus(event.params.amountB);
  p.liquidityEvents = p.liquidityEvents.plus(BigInt.fromI32(1));
  p.save();
}

export function handleSwapped(event: Swapped): void {
  let p = pool(event.address);
  p.swaps = p.swaps.plus(BigInt.fromI32(1));
  p.save();

  let swap = new Swap(event.transaction.hash.concatI32(event.logIndex.toI32()));
  swap.trader = event.params.trader;
  swap.tokenIn = event.params.tokenIn;
  swap.amountIn = event.params.amountIn;
  swap.tokenOut = event.params.tokenOut;
  swap.amountOut = event.params.amountOut;
  swap.timestamp = event.block.timestamp;
  swap.save();
}

export function handleListed(event: Listed): void {
  let rental = new Rental(event.params.nft.concatI32(event.params.tokenId.toI32()));
  rental.owner = event.params.owner;
  rental.nft = event.params.nft;
  rental.tokenId = event.params.tokenId;
  rental.price = event.params.price;
  rental.active = false;
  rental.save();
}

export function handleRented(event: Rented): void {
  let rental = Rental.load(event.params.nft.concatI32(event.params.tokenId.toI32()));
  if (rental == null) {
    return;
  }
  rental.renter = event.params.renter;
  rental.expiresAt = event.params.expiresAt;
  rental.active = true;
  rental.save();
}

export function handleUnlisted(event: Unlisted): void {
  let rental = Rental.load(event.params.nft.concatI32(event.params.tokenId.toI32()));
  if (rental == null) {
    return;
  }
  rental.active = false;
  rental.save();
}
