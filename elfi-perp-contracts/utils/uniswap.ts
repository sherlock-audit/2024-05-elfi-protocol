import {
  abi as FACTORY_ABI,
  bytecode as FACTORY_BYTECODE,
} from '@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json'
import {
  abi as SWAP_ROUTER_ABI,
  bytecode as SWAP_ROUTER_BYTECODE,
} from '@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json'
import {
  abi as NFTDescriptor_ABI,
  bytecode as NFTDescriptor_BYTECODE,
} from '@uniswap/v3-periphery/artifacts/contracts/libraries/NFTDescriptor.sol/NFTDescriptor.json'

import {
  abi as NFTPositionManager_ABI,
  bytecode as NFTPositionManager_BYTECODE,
} from '@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json'

import {
  abi as NFTPositionDescriptor_ABI,
  bytecode as NFTPositionDescriptor_BYTECODE,
} from '@uniswap/v3-periphery/artifacts/contracts/NonfungibleTokenPositionDescriptor.sol/NonfungibleTokenPositionDescriptor.json'

import IUniswapV3PoolABI from '@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json'
import { ethers } from 'hardhat'
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { CurrencyAmount, Percent, Price, Token } from '@uniswap/sdk-core'
import {
  AddLiquidityOptions,
  FeeAmount,
  MintOptions,
  NonfungiblePositionManager,
  Pool,
  Position,
  TickMath,
  priceToClosestTick,
} from '@uniswap/v3-sdk'
import JSBI from 'jsbi'
import { MockToken } from 'types'
import { precision } from './precision'

export async function deployUniswapV3(deployer: SignerWithAddress) {
  const uniswapFactory = await ethers.getContractFactory(FACTORY_ABI, FACTORY_BYTECODE, deployer)
  const deployUniswapFactory = await uniswapFactory.deploy()
  const uniswapFactoryAddr = await deployUniswapFactory.getAddress()
  console.log('uniswapFactoryAddr', uniswapFactoryAddr)
  time.increase(1)

  const weth9Factory = await ethers.getContractFactory('WETH', deployer)
  const weth9 = await weth9Factory.deploy()
  const weth9Addr = await weth9.getAddress()
  console.log('weth9Addr', weth9Addr)
  time.increase(1)

  const uniswapRouterFactory = await ethers.getContractFactory(SWAP_ROUTER_ABI, SWAP_ROUTER_BYTECODE, deployer)
  const uniswapRouter = await uniswapRouterFactory.deploy(uniswapFactoryAddr, weth9Addr)
  const uniswapRouterAddr = await uniswapRouter.getAddress()
  console.log('uniswapRouterAddr', uniswapRouterAddr)
  time.increase(1)

  const nftDescriptorLibraryFactory = await ethers.getContractFactory(
    NFTDescriptor_ABI,
    NFTDescriptor_BYTECODE,
    deployer,
  )
  const nftDescriptorLibrary = await nftDescriptorLibraryFactory.deploy()
  console.log('nftDescriptorLibraryAddr', await nftDescriptorLibrary.getAddress())
  time.increase(1)

  const linkedBytecode = linkLibrary(NFTPositionDescriptor_BYTECODE, {
    ['contracts/libraries/NFTDescriptor.sol:NFTDescriptor']: await nftDescriptorLibrary.getAddress(),
  })
  const nftPositionDescriptorFactory = await ethers.getContractFactory(
    NFTPositionDescriptor_ABI,
    linkedBytecode,
    deployer,
  )
  const nftPositionDescriptor = await nftPositionDescriptorFactory.deploy(
    weth9Addr,
    '0x4554480000000000000000000000000000000000000000000000000000000000',
  )
  console.log('nftPositionDescriptorAddr', await nftPositionDescriptor.getAddress())
  time.increase(1)

  const nftPositionManagerFactory = await ethers.getContractFactory(
    NFTPositionManager_ABI,
    NFTPositionManager_BYTECODE,
    deployer,
  )
  const nftPositionManager = await nftPositionManagerFactory.deploy(
    uniswapFactoryAddr,
    weth9Addr,
    await nftPositionDescriptor.getAddress(),
  )
  const nftPositionManagerAddr = await nftPositionManager.getAddress()
  console.log('nftPositionManagerAddr', nftPositionManagerAddr)
  time.increase(1)
  return [uniswapFactoryAddr, weth9Addr, uniswapRouterAddr, nftPositionManagerAddr]
}

export async function createPool(
  deployer: SignerWithAddress,
  factoryAddr: string,
  nftPositionManagerAddr: string,
  tokenA: MockToken,
  tokenB: MockToken,
  price0: number,
) {
  const tokenAAddress = await tokenA.getAddress()
  const tokenBAddress = await tokenB.getAddress()
  console.log(tokenAAddress, tokenBAddress, price0)
  const chainId = 31337
  let token0Addr, token1Addr
  let token0Decimals, token1Decimals
  let token0, token1
  let tick
  let isReverse
  if (tokenAAddress <= tokenBAddress) {
    console.log('tokenAAddress <= tokenBAddress')
    isReverse = false
    token0Addr = await tokenA.getAddress()
    token1Addr = await tokenB.getAddress()
    token0Decimals = Number(await tokenA.decimals())
    token1Decimals = Number(await tokenB.decimals())
    token0 = new Token(chainId, token0Addr, token0Decimals, 'Token0', 'TK0')
    token1 = new Token(chainId, token1Addr, token1Decimals, 'Token1', 'TK1')
    tick = priceToClosestTick(
      new Price(
        token0,
        token1,
        precision.pow(1, token0Decimals).toString(),
        precision.pow(price0, token1Decimals).toString(),
      ),
    )
  } else {
    console.log('tokenAAddress > tokenBAddress')
    isReverse = true
    token0Addr = await tokenB.getAddress()
    token1Addr = await tokenA.getAddress()
    token0Decimals = Number(await tokenB.decimals())
    token1Decimals = Number(await tokenA.decimals())
    token0 = new Token(chainId, token0Addr, token0Decimals, 'Token0', 'TK0')
    token1 = new Token(chainId, token1Addr, token1Decimals, 'Token1', 'TK1')
    tick = priceToClosestTick(
      new Price(
        token0,
        token1,
        precision.pow(price0, token0Decimals).toString(),
        precision.pow(1, token1Decimals).toString(),
      ),
    )
  }

  console.log('token0', token0)
  console.log('token1', token1)

  tick = Math.floor(tick / 60) * 60
  const sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick)
  console.log('tick', tick)

  const uniswapFactory = await ethers.getContractFactory(FACTORY_ABI, FACTORY_BYTECODE, deployer)
  const factory = uniswapFactory.attach(factoryAddr)
  const tx = await factory.connect(deployer).createPool(token0Addr, token1Addr, 3000)
  await tx.wait()
  const poolAddress = await factory.getPool(token0Addr, token1Addr, 3000)
  console.log('poolAddress', poolAddress)
  const poolContract = new ethers.Contract(poolAddress, IUniswapV3PoolABI.abi, deployer)
  const initializeTx = await poolContract.connect(deployer).initialize(BigInt(JSBI.toNumber(sqrtPriceX96)))
  await initializeTx.wait()

  const pool = new Pool(token0, token1, FeeAmount.MEDIUM, sqrtPriceX96, 0, tick)
  const tickLower = Math.max(tick - pool.tickSpacing * 2000, TickMath.MIN_TICK)
  const tickUpper = Math.min(tick + pool.tickSpacing * 2000, TickMath.MAX_TICK)
  console.log('tickLower', tickLower)
  console.log('tickUpper', tickUpper)
  console.log('pool.tickSpacing', pool.tickSpacing)

  let amount0, amount1
  if (isReverse) {
    amount0 = precision.token(1000 * price0, token0Decimals)
    amount1 = precision.token(1000, token1Decimals)
    await tokenB.connect(deployer).approve(nftPositionManagerAddr, amount0)
    await tokenA.connect(deployer).approve(nftPositionManagerAddr, amount1)
    console.log('token0 balanceOf deployer', await tokenB.balanceOf(deployer), 'need', amount0)
    console.log('token1 balanceOf deployer', await tokenA.balanceOf(deployer), 'need', amount1)
    console.log('eth balanceOf deployer', await ethers.provider.getBalance(deployer))
    console.log('tokenB approve', await tokenB.allowance(deployer, nftPositionManagerAddr))
    console.log('tokenA approve', await tokenA.allowance(deployer, nftPositionManagerAddr))
  } else {
    amount0 = precision.token(1000, token0Decimals)
    amount1 = precision.token(1000 * price0, token1Decimals)
    await tokenA.connect(deployer).approve(nftPositionManagerAddr, amount0)
    await tokenB.connect(deployer).approve(nftPositionManagerAddr, amount1)
    console.log('token0 balanceOf deployer', await tokenA.balanceOf(deployer), 'need', amount0)
    console.log('token1 balanceOf deployer', await tokenB.balanceOf(deployer), 'need', amount1)
    console.log('eth balanceOf deployer', await ethers.provider.getBalance(deployer))
    console.log('tokenA approve', await tokenA.allowance(deployer, nftPositionManagerAddr))
    console.log('tokenB approve', await tokenB.allowance(deployer, nftPositionManagerAddr))
  }

  const position = Position.fromAmounts({
    pool: pool,
    tickLower: tickLower,
    tickUpper: tickUpper,
    amount0: amount0.toString(),
    amount1: amount1.toString(),
    useFullPrecision: true,
  })

  // const positionManager = new ethers.Contract(nftPositionManagerAddr, NFTPositionManager_ABI, deployer)
  // const mintTx = await positionManager.connect(deployer).mint({
  //   token0: token0Addr,
  //   token1: token1Addr,
  //   fee: 3000,
  //   tickLower: tickLower,
  //   tickUpper: tickUpper,
  //   amount0Desired: amount0,
  //   amount1Desired: amount1,
  //   amount0Min: 0,
  //   amount1Min: 0,
  //   recipient: deployer.address,
  //   deadline: Math.floor(Date.now() / 1000) + 60 * 50, // 10分钟后过期
  // })
  // await mintTx.wait()

  const mintOptions: MintOptions = {
    recipient: deployer.address,
    deadline: Math.floor(Date.now() / 1000) + 60 * 20,
    slippageTolerance: new Percent(50, 10_000),
    createPool: false,
  }
  const { calldata, value } = NonfungiblePositionManager.addCallParameters(position, mintOptions)
  const transaction = {
    data: calldata,
    to: nftPositionManagerAddr,
    value: value,
    from: deployer.address,
    maxFeePerGas: ethers.parseUnits('1', 'gwei'),
    maxPriorityFeePerGas: ethers.parseUnits('0.2', 'gwei'),
  }

  await deployer.sendTransaction(transaction)
  console.log('create and add liquidity successful')
}

export async function addPoolLiquidation(
  deployer: SignerWithAddress,
  nftPositionManagerAddr: string,
  tokenA: MockToken,
  tokenB: MockToken,
  price0: number,
) {
  const tokenAAddress = await tokenA.getAddress()
  const tokenBAddress = await tokenA.getAddress()
  const chainId = 31337
  let token0Addr, token1Addr
  let token0Decimals, token1Decimals
  let token0, token1
  let tick
  let isReverse
  if (tokenAAddress <= tokenBAddress) {
    console.log('tokenAAddress <= tokenBAddress, isReverse = false')
    isReverse = false
    token0Addr = await tokenA.getAddress()
    token1Addr = await tokenB.getAddress()
    token0Decimals = Number(await tokenA.decimals())
    token1Decimals = Number(await tokenB.decimals())
    token0 = new Token(chainId, token0Addr, token0Decimals, 'Token0', 'TK0')
    token1 = new Token(chainId, token1Addr, token1Decimals, 'Token1', 'TK1')
    tick = priceToClosestTick(
      new Price(
        token0,
        token1,
        precision.pow(1, token0Decimals).toString(),
        precision.pow(price0, token1Decimals).toString(),
      ),
    )
  } else {
    console.log('tokenAAddress > tokenBAddress, isReverse = true')
    isReverse = true
    token0Addr = await tokenB.getAddress()
    token1Addr = await tokenA.getAddress()
    token0Decimals = Number(await tokenB.decimals())
    token1Decimals = Number(await tokenA.decimals())
    token0 = new Token(chainId, token0Addr, token0Decimals, 'Token0', 'TK0')
    token1 = new Token(chainId, token1Addr, token1Decimals, 'Token1', 'TK1')
    tick = priceToClosestTick(
      new Price(
        token0,
        token1,
        precision.pow(price0, token0Decimals).toString(),
        precision.pow(1, token1Decimals).toString(),
      ),
    )
  }

  console.log('token0', token0)
  console.log('token1', token1)

  tick = Math.floor(tick / 60) * 60
  const sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick)
  console.log('tick', tick)

  const pool = new Pool(token0, token1, FeeAmount.MEDIUM, sqrtPriceX96, 0, tick)
  const tickLower = Math.max(tick - pool.tickSpacing * 2000, TickMath.MIN_TICK)
  const tickUpper = Math.min(tick + pool.tickSpacing * 2000, TickMath.MAX_TICK)
  console.log('tickLower', tickLower)
  console.log('tickUpper', tickUpper)

  let amount0, amount1
  if (isReverse) {
    amount0 = precision.token(1000 * price0, token0Decimals)
    amount1 = precision.token(1000, token1Decimals)
    await tokenB.connect(deployer).approve(nftPositionManagerAddr, amount0)
    await tokenA.connect(deployer).approve(nftPositionManagerAddr, amount1)
    console.log('token0 balanceOf deployer', await tokenB.balanceOf(deployer), 'need', amount0)
    console.log('token1 balanceOf deployer', await tokenA.balanceOf(deployer), 'need', amount1)
    console.log('eth balanceOf deployer', await ethers.provider.getBalance(deployer))
    console.log('tokenB approve', await tokenB.allowance(deployer, nftPositionManagerAddr))
    console.log('tokenA approve', await tokenA.allowance(deployer, nftPositionManagerAddr))
  } else {
    amount0 = precision.token(1000, token0Decimals)
    amount1 = precision.token(1000 * price0, token1Decimals)
    await tokenA.connect(deployer).approve(nftPositionManagerAddr, amount0)
    await tokenB.connect(deployer).approve(nftPositionManagerAddr, amount1)
    console.log('token0 balanceOf deployer', await tokenA.balanceOf(deployer), 'need', amount0)
    console.log('token1 balanceOf deployer', await tokenB.balanceOf(deployer), 'need', amount1)
    console.log('eth balanceOf deployer', await ethers.provider.getBalance(deployer))
    console.log('tokenA approve', await tokenA.allowance(deployer, nftPositionManagerAddr))
    console.log('tokenB approve', await tokenB.allowance(deployer, nftPositionManagerAddr))
  }

  const position = Position.fromAmounts({
    pool: pool,
    tickLower: tickLower,
    tickUpper: tickUpper, 
    amount0: amount0.toString(),
    amount1: amount1.toString(),
    useFullPrecision: true,
  })

  // const positionManager = new ethers.Contract(nftPositionManagerAddr, NFTPositionManager_ABI, deployer)
  // const tokenId = await positionManager.tokenOfOwnerByIndex(deployer.address, 0)
  // console.log("tokenId", tokenId)   
  
  // const positionData = await positionManager.positions(tokenId)
  // console.log(positionData)


  // const mintTx = await positionManager.connect(deployer).increaseLiquidity({
  //   tokenId: tokenId,
  //   amount0Desired: amount0,
  //   amount1Desired: amount1,
  //   amount0Min: 0,
  //   amount1Min: 0,
  //   deadline: Math.floor(Date.now() / 1000) + 60 * 50, // 10分钟后过期
  // })
  // await mintTx.wait()

  const mintOptions: MintOptions = {
    recipient: deployer.address,
    deadline: Math.floor(Date.now() / 1000) + 60 * 20,
    slippageTolerance: new Percent(50, 10_000),
    createPool: false,
  }

  const { calldata, value } = NonfungiblePositionManager.addCallParameters(position, mintOptions)
  const transaction = {
    data: calldata,
    to: nftPositionManagerAddr,
    value: value,
    from: deployer.address,
    maxFeePerGas: ethers.parseUnits('1', 'gwei'),
    maxPriorityFeePerGas: ethers.parseUnits('0.2', 'gwei'),
  }

  await deployer.sendTransaction(transaction)
  console.log('add liquidity successful')
}

function linkLibrary(
  bytecode: string,
  libraries: {
    [name: string]: string
  } = {},
) {
  let linkedBytecode = bytecode
  for (const [name, address] of Object.entries(libraries)) {
    const placeholder = `__\$${ethers.solidityPackedKeccak256(['string'], [name]).slice(2, 36)}\$__`
    const formattedAddress = ethers.getAddress(address).toLowerCase().replace('0x', '')

    if (linkedBytecode.indexOf(placeholder) === -1) {
      throw new Error(`Unable to find placeholder for library ${name}`)
    }
    while (linkedBytecode.indexOf(placeholder) !== -1) {
      linkedBytecode = linkedBytecode.replace(placeholder, formattedAddress)
    }
  }
  return linkedBytecode
}
