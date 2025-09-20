pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PublisherTestSetup} from "../lib/PublisherSetupHelper.sol";

import {BuilderCodes} from "../../src/BuilderCodes.sol";
import {PseudoRandomRegistrar} from "../../src/registrars/PseudoRandomRegistrar.sol";

contract PseudoRandomRegistrarTest is PublisherTestSetup {
    BuilderCodes public builderCodes;
    PseudoRandomRegistrar public registrar;
    
    address private owner = address(this);
    address private signer = address(0x123);
    address private user1 = address(0x456);
    address private user2 = address(0x789);

    function setUp() public {
        // Deploy BuilderCodes
        BuilderCodes implementation = new BuilderCodes();
        bytes memory initData = abi.encodeWithSelector(
            BuilderCodes.initialize.selector, 
            owner, 
            signer, 
            "https://api.example.com/"
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        builderCodes = BuilderCodes(address(proxy));

        // Deploy PseudoRandomRegistrar
        registrar = new PseudoRandomRegistrar(address(builderCodes));

        // Grant REGISTER_ROLE to registrar
        builderCodes.grantRole(builderCodes.REGISTER_ROLE(), address(registrar));
    }

    function test_constructor() public {
        assertEq(address(registrar.codes()), address(builderCodes));
        assertEq(registrar.nonce(), 0);
        assertEq(registrar.PREFIX(), "bc_");
        assertEq(registrar.ALPHANUMERIC(), "0123456789abcdefghijklmnopqrstuvwxyz");
        assertEq(registrar.SUFFIX_LENGTH(), 8);
    }

    function test_computeCode_deterministic() public {
        // Same nonce should generate same code
        string memory code1 = registrar.computeCode(1);
        string memory code2 = registrar.computeCode(1);
        assertEq(code1, code2);

        // Different nonces should generate different codes
        string memory code3 = registrar.computeCode(2);
        assertFalse(keccak256(bytes(code1)) == keccak256(bytes(code3)));
    }

    function test_computeCode_format() public {
        string memory code = registrar.computeCode(123);
        
        // Should start with "bc_"
        bytes memory codeBytes = bytes(code);
        assertEq(codeBytes[0], "b");
        assertEq(codeBytes[1], "c");
        assertEq(codeBytes[2], "_");
        
        // Should be exactly 11 characters (3 prefix + 8 suffix)
        assertEq(codeBytes.length, 11);
        
        // All characters after prefix should be from allowed set
        string memory allowed = registrar.ALPHANUMERIC();
        bytes memory allowedBytes = bytes(allowed);
        
        for (uint256 i = 3; i < codeBytes.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < allowedBytes.length; j++) {
                if (codeBytes[i] == allowedBytes[j]) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "Invalid character in generated code");
        }
    }

    function test_computeCode_validForBuilderCodes() public {
        string memory code = registrar.computeCode(456);
        assertTrue(builderCodes.isValidCode(code));
    }

    function test_register_success() public {
        address payoutAddr = address(0xabc);
        
        vm.prank(user1);
        string memory code = registrar.register(payoutAddr);
        
        // Verify code was registered
        assertTrue(builderCodes.isRegistered(code));
        assertEq(builderCodes.ownerOf(builderCodes.toTokenId(code)), user1);
        assertEq(builderCodes.payoutAddress(code), payoutAddr);
        
        // Verify nonce incremented
        assertEq(registrar.nonce(), 1);
        
        // Verify code format
        assertTrue(bytes(code).length == 11); // bc_ + 8 chars
        bytes memory codeBytes = bytes(code);
        assertEq(codeBytes[0], "b");
        assertEq(codeBytes[1], "c");
        assertEq(codeBytes[2], "_");
    }

    function test_register_multipleUsers() public {
        address payout1 = address(0xabc);
        address payout2 = address(0xdef);
        
        vm.prank(user1);
        string memory code1 = registrar.register(payout1);
        
        vm.prank(user2);
        string memory code2 = registrar.register(payout2);
        
        // Codes should be different
        assertFalse(keccak256(bytes(code1)) == keccak256(bytes(code2)));
        
        // Both should be registered correctly
        assertTrue(builderCodes.isRegistered(code1));
        assertTrue(builderCodes.isRegistered(code2));
        assertEq(builderCodes.ownerOf(builderCodes.toTokenId(code1)), user1);
        assertEq(builderCodes.ownerOf(builderCodes.toTokenId(code2)), user2);
        assertEq(builderCodes.payoutAddress(code1), payout1);
        assertEq(builderCodes.payoutAddress(code2), payout2);
        
        // Nonce should be 2
        assertEq(registrar.nonce(), 2);
    }

    function test_register_collision_handling() public {
        address payoutAddr = address(0xabc);
        
        // Register first code
        vm.prank(user1);
        string memory code1 = registrar.register(payoutAddr);
        
        // Mock collision by pre-registering the next computed code
        string memory nextCode = registrar.computeCode(registrar.nonce() + 1);
        vm.prank(signer);
        builderCodes.register(nextCode, user2, address(0x999));
        
        // Registration should still work (find next available code)
        vm.prank(user2);
        string memory code2 = registrar.register(payoutAddr);
        
        // Should not be the colliding code
        assertFalse(keccak256(bytes(code2)) == keccak256(bytes(nextCode)));
        
        // Should be registered successfully
        assertTrue(builderCodes.isRegistered(code2));
        assertEq(builderCodes.ownerOf(builderCodes.toTokenId(code2)), user2);
    }

    function test_register_withZeroPayoutAddress() public {
        vm.prank(user1);
        vm.expectRevert(BuilderCodes.ZeroAddress.selector);
        registrar.register(address(0));
    }

    function test_register_emitsEvents() public {
        address payoutAddr = address(0xabc);
        
        vm.prank(user1);
        
        // Can't easily predict the exact code, but we can verify events are emitted
        vm.recordLogs();
        string memory code = registrar.register(payoutAddr);
        
        // Check that CodeRegistered event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool foundCodeRegistered = false;
        bool foundPayoutAddressUpdated = false;
        
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("CodeRegistered(uint256,string)")) {
                foundCodeRegistered = true;
            }
            if (logs[i].topics[0] == keccak256("PayoutAddressUpdated(uint256,address)")) {
                foundPayoutAddressUpdated = true;
            }
        }
        
        assertTrue(foundCodeRegistered, "CodeRegistered event not emitted");
        assertTrue(foundPayoutAddressUpdated, "PayoutAddressUpdated event not emitted");
    }

    function test_register_gasUsage() public {
        address payoutAddr = address(0xabc);
        
        vm.startPrank(user1);
        uint256 gasBefore = gasleft();
        registrar.register(payoutAddr);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        // Reasonable gas usage (adjust based on actual measurements)
        assertLt(gasUsed, 200_000, "Gas usage too high");
    }

    function test_computeCode_fuzz(uint256 nonce) public {
        vm.assume(nonce > 0 && nonce < type(uint128).max);
        
        string memory code = registrar.computeCode(nonce);
        
        // Verify basic properties
        assertTrue(builderCodes.isValidCode(code));
        assertEq(bytes(code).length, 11);
        
        // Verify prefix
        bytes memory codeBytes = bytes(code);
        assertEq(codeBytes[0], "b");
        assertEq(codeBytes[1], "c");
        assertEq(codeBytes[2], "_");
    }

    function test_register_integration_withBuilderCodes() public {
        address payoutAddr = address(0xabc);
        
        vm.prank(user1);
        string memory code = registrar.register(payoutAddr);
        
        // Test all BuilderCodes functionality works
        uint256 tokenId = builderCodes.toTokenId(code);
        assertEq(builderCodes.toCode(tokenId), code);
        assertEq(builderCodes.payoutAddress(tokenId), payoutAddr);
        
        // Test URI generation
        string memory uri = builderCodes.tokenURI(tokenId);
        assertEq(uri, string.concat("https://api.example.com/", code));
        
        // Test code URI
        assertEq(builderCodes.codeURI(code), uri);
        
        // Test updating payout address
        address newPayout = address(0x999);
        vm.prank(user1);
        builderCodes.updatePayoutAddress(code, newPayout);
        assertEq(builderCodes.payoutAddress(code), newPayout);
    }

    function test_multiple_registrations_nonce_increment() public {
        address payout = address(0xabc);
        uint256 initialNonce = registrar.nonce();
        
        // Register 5 codes
        for (uint256 i = 0; i < 5; i++) {
            address user = address(uint160(0x1000 + i));
            vm.prank(user);
            registrar.register(payout);
        }
        
        // Nonce should have incremented by 5
        assertEq(registrar.nonce(), initialNonce + 5);
    }

    function test_register_different_blocks() public {
        address payout = address(0xabc);
        
        vm.prank(user1);
        string memory code1 = registrar.register(payout);
        
        // Roll to different block
        vm.roll(block.number + 10);
        
        vm.prank(user2);
        string memory code2 = registrar.register(payout);
        
        // Codes should be different due to different block context
        assertFalse(keccak256(bytes(code1)) == keccak256(bytes(code2)));
    }
}