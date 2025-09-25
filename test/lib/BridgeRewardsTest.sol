// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC3009Token} from "../../lib/commerce-payments/test/mocks/MockERC3009Token.sol";

import {Flywheel} from "../../src/Flywheel.sol";
import {BridgeRewards} from "../../src/hooks/BridgeRewards.sol";
import {BuilderCodes} from "../../src/BuilderCodes.sol";
import {PseudoRandomRegistrar} from "../../src/registrars/PseudoRandomRegistrar.sol";

contract BridgeRewardsTest is Test {
    uint256 internal constant OWNER_PK = uint256(keccak256("owner"));
    uint256 internal constant USER_PK = uint256(keccak256("user"));
    uint256 internal constant BUILDER_PK = uint256(keccak256("builder"));
    string public constant CAMPAIGN_URI = "https://base.dev/campaign/bridge-rewards";
    string public constant URI_PREFIX = "https://base.dev/campaign/bridge-rewards";

    address public owner;
    address public user;
    address public builder;

    BuilderCodes public builderCodes;
    PseudoRandomRegistrar public pseudoRandomRegistrar;

    Flywheel public flywheel;
    BridgeRewards public bridgeRewards;
    MockERC3009Token public usdc;

    address public bridgeRewardsCampaign;

    function setUp() public {
        owner = vm.addr(OWNER_PK);
        user = vm.addr(USER_PK);
        builder = vm.addr(BUILDER_PK);

        address builderCodesImpl = address(new BuilderCodes());
        bytes memory builderCodesInitData =
            abi.encodeWithSelector(BuilderCodes.initialize.selector, owner, address(0), URI_PREFIX);
        builderCodes = BuilderCodes(address(new ERC1967Proxy(builderCodesImpl, builderCodesInitData)));
        pseudoRandomRegistrar = new PseudoRandomRegistrar(address(builderCodes));

        usdc = new MockERC3009Token("USD Coin", "USDC", 6);
        flywheel = new Flywheel();
        bridgeRewards = new BridgeRewards(address(flywheel), address(builderCodes), CAMPAIGN_URI);

        bridgeRewardsCampaign = flywheel.createCampaign(address(bridgeRewards), 0, "");

        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(builder, "Builder");
        vm.label(address(builderCodes), "BuilderCodes");
        vm.label(pseudoRandomRegistrar, "Registrar");
        vm.label(address(usdc), "USDC");
        vm.label(address(flywheel), "Flywheel");
        vm.label(address(bridgeRewards), "BridgeRewards");
        vm.label(bridgeRewardsCampaign, "BridgeRewardsCampaign");
    }

    function _registerBuilderCode() internal returns (string memory code) {
        vm.prank(builder);
        return pseudoRandomRegistrar.register(builder);
    }
}
