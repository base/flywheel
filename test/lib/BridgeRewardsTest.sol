// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {MockERC3009Token} from "../../lib/commerce-payments/test/mocks/MockERC3009Token.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Flywheel} from "../../src/Flywheel.sol";
import {BridgeRewards} from "../../src/hooks/BridgeRewards.sol";
import {BuilderCodes} from "builder-codes/BuilderCodes.sol";

contract BridgeRewardsTest is Test {
    uint256 internal constant OWNER_PK = uint256(keccak256("owner"));
    uint256 internal constant USER_PK = uint256(keccak256("user"));
    uint256 internal constant BUILDER_PK = uint256(keccak256("builder"));
    string public constant CAMPAIGN_URI = "https://base.dev/campaign/bridge-rewards";
    string public constant URI_PREFIX = "https://base.dev/campaign/bridge-rewards";
    uint16 public constant MAX_FEE_BASIS_POINTS = 10_000; // 100%

    address public owner;
    address public user;
    address public builder;

    BuilderCodes public builderCodes;

    Flywheel public flywheel;
    BridgeRewards public bridgeRewards;
    MockERC3009Token public usdc;

    address public bridgeRewardsCampaign;

    function setUp() public {
        owner = vm.addr(OWNER_PK);
        user = vm.addr(USER_PK);
        builder = vm.addr(BUILDER_PK);

        address builderCodesImpl = address(new BuilderCodes());

        // Initialize BuilderCodes with owner as initial registrar (this gives owner REGISTER_ROLE)
        bytes memory builderCodesInitData =
            abi.encodeWithSelector(BuilderCodes.initialize.selector, owner, owner, URI_PREFIX);
        builderCodes = BuilderCodes(address(new ERC1967Proxy(builderCodesImpl, builderCodesInitData)));

        usdc = new MockERC3009Token("USD Coin", "USDC", 6);
        flywheel = new Flywheel();
        bridgeRewards = new BridgeRewards(address(flywheel), address(builderCodes), CAMPAIGN_URI, MAX_FEE_BASIS_POINTS);

        bridgeRewardsCampaign = flywheel.createCampaign(address(bridgeRewards), 0, "");

        // Set campaign to active status so tests can send funds
        flywheel.updateStatus(bridgeRewardsCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(builder, "Builder");
        vm.label(address(builderCodes), "BuilderCodes");
        vm.label(address(usdc), "USDC");
        vm.label(address(flywheel), "Flywheel");
        vm.label(address(bridgeRewards), "BridgeRewards");
        vm.label(bridgeRewardsCampaign, "BridgeRewardsCampaign");
    }

    function _registerBuilderCode(uint256 seed) internal returns (string memory code) {
        vm.prank(owner);
        code = _computeCode(seed);
        builderCodes.register(code, builder, builder);
        return code;
    }

    function _computeCode(uint256 seed) internal view returns (string memory code) {
        bytes memory allowedCharacters = bytes("0123456789abcdefghijklmnopqrstuvwxyz");
        uint256 len = allowedCharacters.length;
        uint256 CODE_LENGTH = 8;
        bytes memory codeBytes = new bytes(CODE_LENGTH);

        // Iteratively generate code with modulo arithmetic on pseudo-random hash
        uint256 hashNum =
            uint256(keccak256(abi.encodePacked(seed, block.timestamp, blockhash(block.number - 1), block.prevrandao)));
        for (uint256 i; i < CODE_LENGTH; i++) {
            codeBytes[i] = allowedCharacters[hashNum % len];
            hashNum /= len;
        }

        return string(codeBytes);
    }
}
