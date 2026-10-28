// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MetadataOnlyToken, MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract ReadingVotesToken is ERC20Votes {
    constructor() ERC20("Reading token", "READ") EIP712("Reading token", "1") {
        _mint(msg.sender, 1_000 ether);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

contract FixedReadingToken is ERC20 {
    uint8 private immutable tokenDecimals;

    constructor(uint8 decimals_, uint256 supply) ERC20("Fixed token", "FIX") {
        tokenDecimals = decimals_;
        _mint(msg.sender, supply);
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }
}

contract MarketCapReaderTest is Test {
    ReadingVotesToken internal token;
    MockBasePool internal pool;
    BasePoolReader internal prices;
    MarketCapReader internal caps;

    function setUp() public {
        vm.roll(500);
        vm.warp(1_000);
        token = new ReadingVotesToken();
        MockReadingToken quote = new MockReadingToken(18, 0);
        pool = new MockBasePool(address(token), address(quote));
        pool.write(0);
        prices = new BasePoolReader(address(pool), address(token), 30);
        caps = new MarketCapReader(prices, MarketCapReader.SupplyMode.Checkpoints, 0);
    }

    function testFlashMintCaptureUsesFinalEndBlockSupplyAndIgnoresLaterMint() public {
        vm.roll(515);
        vm.warp(1_030);
        token.mint(1_000_000 ether);
        prices.capture();
        token.burn(1_000_000 ether);
        token.mint(500 ether); // Final endpoint supply is 1,500, after capture.
        vm.roll(516);
        vm.warp(1_032);
        token.mint(5_000 ether); // Current supply must not replace historical supply.
        MarketCapReader.MarketCapReading memory reading = caps.readMarketCap(515);
        assertEq(reading.reading.price, 1e36);
        assertEq(reading.totalSupply, 1_500 ether);
        assertEq(reading.marketCap, 1_500e36);
    }

    function testCurrentAndFutureBlockMarketCapIsRejected() public {
        vm.roll(515);
        vm.warp(1_030);
        prices.capture();
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        caps.readMarketCap(515);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        caps.readMarketCap(516);
    }

    function testUnsupportedTokenStillHasPriceWithoutTotalSupply() public {
        MetadataOnlyToken priceToken = new MetadataOnlyToken();
        MockBasePool pricePool = new MockBasePool(address(priceToken), address(pool.token1()));
        pricePool.write(0);
        BasePoolReader priceReader = new BasePoolReader(address(pricePool), address(priceToken), 30);
        MarketCapReader unsupported = new MarketCapReader(priceReader, MarketCapReader.SupplyMode.Unsupported, 0);
        vm.roll(515);
        vm.warp(1_030);
        assertEq(priceReader.capture().price, 1e36);
        vm.roll(516);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        unsupported.readMarketCap(515);
        assertEq(priceReader.read(515).price, 1e36);
    }

    function testMissingCheckpointInterfaceRejectsMarketCapOnly() public {
        MarketCapReader missing = new MarketCapReader(
            new BasePoolReader(address(pool), pool.token1(), 30), MarketCapReader.SupplyMode.Checkpoints, 0
        );
        vm.roll(515);
        vm.warp(1_030);
        missing.i_priceReader().capture();
        vm.roll(516);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        missing.readMarketCap(515);
        assertEq(missing.i_priceReader().read(515).price, 1e36);
    }

    function testTimestampClockAndFaultySourcesRejectMarketCapOnly() public {
        vm.roll(515);
        vm.warp(1_030);
        prices.capture();
        vm.roll(516);
        bytes memory modeCall = abi.encodeWithSignature("CLOCK_MODE()");
        vm.mockCall(address(token), modeCall, abi.encode("mode=timestamp"));
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        caps.readMarketCap(515);
        vm.clearMockedCalls();

        bytes memory clockCall = abi.encodeWithSignature("clock()");
        vm.mockCall(address(token), clockCall, abi.encode(uint48(515)));
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        caps.readMarketCap(515);
        vm.clearMockedCalls();

        vm.mockCallRevert(address(token), abi.encodeWithSignature("getPastTotalSupply(uint256)", 515), "missing");
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        caps.readMarketCap(515);
        vm.clearMockedCalls();
        assertEq(prices.read(515).price, 1e36);
    }

    function testMissingPriceCaptureCannotProduceMarketCap() public {
        vm.roll(516);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        caps.readMarketCap(515);
    }

    function testVettedFixedSupplySupportsBothDecimalDirections() public {
        FixedReadingToken six = new FixedReadingToken(6, 1_000e6);
        FixedReadingToken eighteen = new FixedReadingToken(18, 2_000 ether);
        MockBasePool mixed = new MockBasePool(address(six), address(eighteen));
        mixed.write(276324);
        BasePoolReader forward = new BasePoolReader(address(mixed), address(six), 30);
        BasePoolReader reverse = new BasePoolReader(address(mixed), address(eighteen), 30);
        MarketCapReader forwardCap = new MarketCapReader(forward, MarketCapReader.SupplyMode.Fixed, 1_000e6);
        MarketCapReader reverseCap = new MarketCapReader(reverse, MarketCapReader.SupplyMode.Fixed, 2_000 ether);
        vm.roll(515);
        vm.warp(1_030);
        forward.capture();
        reverse.capture();
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        forwardCap.readMarketCap(515);
        vm.roll(516);
        assertApproxEqRel(forwardCap.readMarketCap(515).marketCap, 1_000e36, 0.0001 ether);
        assertApproxEqRel(reverseCap.readMarketCap(515).marketCap, 2_000e36, 0.0001 ether);
        assertEq(forwardCap.readMarketCap(515).totalSupply, 1_000e6);
        assertEq(reverseCap.readMarketCap(515).totalSupply, 2_000 ether);
    }

    function testMarketCapBeyondUint256RejectsWithoutPanic() public {
        FixedReadingToken huge = new FixedReadingToken(18, 1e60);
        MockBasePool hugePool = new MockBasePool(address(huge), pool.token1());
        hugePool.write(400000); // About 2.4e17 quote per base: 2.4e53 * 1e60 / 1e18 exceeds uint256.
        BasePoolReader hugePrices = new BasePoolReader(address(hugePool), address(huge), 30);
        MarketCapReader hugeCaps = new MarketCapReader(hugePrices, MarketCapReader.SupplyMode.Fixed, 1e60);
        vm.roll(515);
        vm.warp(1_030);
        hugePrices.capture();
        vm.roll(516);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        hugeCaps.readMarketCap(515);
    }

    function testFixedSupplyConfigurationMustMatchTheVettedValue() public {
        vm.expectRevert(MarketCapReader.InvalidSupplyConfiguration.selector);
        new MarketCapReader(prices, MarketCapReader.SupplyMode.Fixed, 0);
        vm.expectRevert(MarketCapReader.InvalidSupplyConfiguration.selector);
        new MarketCapReader(prices, MarketCapReader.SupplyMode.Fixed, 2_000 ether);
        vm.expectRevert(MarketCapReader.InvalidSupplyConfiguration.selector);
        new MarketCapReader(prices, MarketCapReader.SupplyMode.Checkpoints, 1_000 ether);
    }
}
