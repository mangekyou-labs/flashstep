// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PayerDeployFixture } from "./PayerDeployFixture.sol";
import { DeployPayerCampaign } from "../../script/DeployPayerCampaign.s.sol";
import { MockReadingToken } from "../mocks/MockBasePool.sol";
import { MockV3Factory, MockV3Pool } from "../mocks/MockUniswapV3.sol";

/// @notice Seam: `preflight()` (the vetting the driver shows before funding) and `run()` (which must refuse
/// before it broadcasts anything). Pool and stake token addresses are checked with code and identity calls.
contract PayerVettingTest is PayerDeployFixture {
    // Deliberately a second copy of the script's factory constants: a test that imported them would pass even if the
    // script's constants were wrong. These are the official Uniswap V3 factory addresses on each chain.
    address internal constant BASE_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant BASE_SEPOLIA_FACTORY = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;

    function test_aMatchingPoolAndStakeTokenPassPreflight() public {
        _prepare();
        script.preflight();
    }

    function test_aPoolWithNoCodeIsRefused() public {
        pool = MockV3Pool(makeAddr("not a pool"));
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployPayerCampaign.NotAContract.selector, DeployPayerCampaign.Vetted.Pool, address(pool)
            )
        );
        script.preflight();
    }

    function test_aStakeTokenWithNoCodeIsRefused() public {
        configuredStakeToken = makeAddr("not a token");
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployPayerCampaign.NotAContract.selector, DeployPayerCampaign.Vetted.StakeToken, configuredStakeToken
            )
        );
        script.preflight();
    }

    function test_ethAsTheStakeTokenNeedsNoCode() public {
        configuredStakeToken = address(0);
        // ETH stakes: the payer needs ETH, and the Stake cap rule does not apply (no quote token to measure).
        _prepare();
        script.preflight();
    }

    function test_aPoolFromAnotherFactoryIsRefused() public {
        MockV3Factory expected = new MockV3Factory();
        configuredFactory = address(expected);
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(DeployPayerCampaign.WrongFactory.selector, address(factory), address(expected))
        );
        script.preflight();
    }

    function test_aBaseTokenThatIsNotInThePoolIsRefused() public {
        MockReadingToken stranger = new MockReadingToken(18, 1e18);
        (address a, address b) = address(stranger) < address(quote)
            ? (address(stranger), address(quote))
            : (address(quote), address(stranger));
        pool = new MockV3Pool(address(factory), a, b, 500);
        factory.setPool(a, b, 500, address(pool));
        _prepare(); // config still names `base`, which this pool does not trade
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.PoolTokensMismatch.selector, address(base)));
        script.preflight();
    }

    function test_aFeeTierThatIsNotThePoolsIsRefused() public {
        configuredFee = 3_000;
        _prepare();
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.PoolFeeMismatch.selector, 500, 3_000));
        script.preflight();
    }

    function test_aPoolTheFactoryDoesNotRegisterIsRefused() public {
        (address token0, address token1) = _sortedTokens();
        factory.setPool(token0, token1, 500, address(0));
        _prepare();
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.PoolNotRegistered.selector, address(0)));
        script.preflight();
    }

    function test_runRefusesBeforeItBroadcastsAnything() public {
        configuredFee = 3_000;
        _prepare();
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.PoolFeeMismatch.selector, 500, 3_000));
        script.run();
        assertFalse(vm.exists(outPath), "nothing was deployed or written");
    }

    function test_anUnknownChainIsRefused() public {
        vm.chainId(1);
        _prepare();
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.UnsupportedChain.selector, 1));
        script.preflight();
    }

    function _etchBaseFactoryWithThePool() internal returns (MockV3Pool basePool) {
        vm.etch(BASE_FACTORY, type(MockV3Factory).runtimeCode);
        (address token0, address token1) = _sortedTokens();
        basePool = new MockV3Pool(BASE_FACTORY, token0, token1, 500);
        MockV3Factory(BASE_FACTORY).setPool(token0, token1, 500, address(basePool));
    }

    function test_onBaseTheFactoryIsTheUniswapV3FactoryAndTheConfigCannotChangeIt() public {
        vm.chainId(8453);
        pool = _etchBaseFactoryWithThePool();
        // A config naming a friendly factory must make no difference on Base.
        configuredFactory = address(factory);
        _prepare();
        script.preflight();
    }

    function test_onBaseAPoolFromAnotherFactoryIsRefusedEvenIfTheConfigNamesThatFactory() public {
        vm.chainId(8453);
        _etchBaseFactoryWithThePool();
        configuredFactory = address(factory); // pool still points at the mock factory
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(DeployPayerCampaign.WrongFactory.selector, address(factory), BASE_FACTORY)
        );
        script.preflight();
    }

    function test_onBaseSepoliaTheFactoryIsItsOwnConstant() public {
        vm.chainId(84532);
        vm.etch(BASE_SEPOLIA_FACTORY, type(MockV3Factory).runtimeCode);
        (address token0, address token1) = _sortedTokens();
        pool = new MockV3Pool(BASE_SEPOLIA_FACTORY, token0, token1, 500);
        MockV3Factory(BASE_SEPOLIA_FACTORY).setPool(token0, token1, 500, address(pool));
        _prepare();
        script.preflight();
    }
}
