// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {BuilderCodes} from "../../src/BuilderCodes.sol";

abstract contract BuilderCodesTest is Test {
    uint256 internal constant OWNER_PK = uint256(keccak256("owner"));
    uint256 internal constant REGISTRAR_PK = uint256(keccak256("registrar"));
    string public constant URI_PREFIX = "https://example.com/builder-codes/metadata";

    BuilderCodes public builderCodes;

    address public owner;
    address public registrar;

    function setUp() public virtual {
        owner = vm.addr(OWNER_PK);
        registrar = vm.addr(REGISTRAR_PK);

        address implementation = address(new BuilderCodes());
        bytes memory initData = abi.encodeWithSelector(BuilderCodes.initialize.selector, owner, registrar, URI_PREFIX);
        builderCodes = BuilderCodes(address(new ERC1967Proxy(implementation, initData)));

        vm.label(owner, "Owner");
        vm.label(registrar, "Registrar");
        vm.label(address(builderCodes), "BuilderCodes");
    }

    /// @notice Generates valid code
    ///
    /// @param seed Random number to seed the valid code generation
    ///
    /// @return code Valid code
    function _generateValidCode(uint256 seed) internal returns (string memory code) {
        bytes memory allowedCharacters = bytes(builderCodes.ALLOWED_CHARACTERS());
        uint256 divisor = allowedCharacters.length;
        uint256 maxLength = 32;
        bytes memory codeBytes = new bytes(maxLength);
        uint256 codeLength = 0;

        // Iteratively generate code with modulo arithmetic on pseudo-random hash
        for (uint256 i; i < maxLength; i++) {
            codeLength++;
            codeBytes[i] = allowedCharacters[seed % divisor];
            seed /= divisor;
            if (seed == 0) break;
        }

        // Resize codeBytes to actual output length
        assembly {
            mstore(codeBytes, codeLength)
        }

        return string(codeBytes);
    }

    /// @notice Generates invalid code with disallowed characters
    ///
    /// @param seed Random number to seed the invalid code generation
    ///
    /// @return code Invalid code containing disallowed characters
    function _generateInvalidCode(uint256 seed) internal pure returns (string memory code) {
        bytes memory invalidCharacters = bytes("!@#$%^&*()ABCDEFGHIJKLMNOPQRSTUVWXYZ");
        uint256 divisor = invalidCharacters.length;
        uint256 len = bound(seed % 100, 1, 32);
        bytes memory codeBytes = new bytes(len);

        for (uint256 i; i < len; i++) {
            codeBytes[i] = invalidCharacters[seed % divisor];
            seed /= divisor;
            if (seed == 0) seed = 1; // Ensure we don't hit zero
        }

        return string(codeBytes);
    }

    /// @notice Generates code over 32 characters
    ///
    /// @param seed Random number to seed the long code generation
    ///
    /// @return code Code over 32 characters long
    function _generateLongCode(uint256 seed) internal pure returns (string memory code) {
        bytes memory allowedCharacters = bytes("0123456789abcdefghijklmnopqrstuvwxyz_");
        uint256 divisor = allowedCharacters.length;
        uint256 len = bound(seed % 100, 33, 100); // 33-100 characters
        bytes memory codeBytes = new bytes(len);

        for (uint256 i; i < len; i++) {
            codeBytes[i] = allowedCharacters[seed % divisor];
            seed /= divisor;
            if (seed == 0) seed = 1;
        }

        return string(codeBytes);
    }

    /// @notice Generates token ID that doesn't normalize properly (has embedded null bytes)
    ///
    /// @param seed Random number to seed the invalid token ID generation
    ///
    /// @return tokenId Invalid token ID that fails normalization
    function _generateInvalidTokenId(uint256 seed) internal pure returns (uint256 tokenId) {
        // Create a bytes32 with null bytes in the middle
        bytes32 invalidBytes = bytes32(seed);
        // Force some null bytes in positions that would break normalization
        invalidBytes = invalidBytes & 0xFFFF00000000FFFF00000000FFFF00000000FFFF00000000FFFF00000000FFFF;
        return uint256(invalidBytes);
    }

    /// @notice Bounds address to non-zero value for fuzz testing
    ///
    /// @param addr Address to bound
    ///
    /// @return boundedAddr Non-zero address
    function _boundNonZeroAddress(address addr) internal pure returns (address boundedAddr) {
        return address(uint160(bound(uint160(addr), 1, type(uint160).max)));
    }

    /// @notice Deploys fresh uninitialized BuilderCodes contract for initialization tests
    ///
    /// @return freshContract Uninitialized BuilderCodes contract
    function _deployFreshBuilderCodes() internal returns (BuilderCodes freshContract) {
        address implementation = address(new BuilderCodes());
        return BuilderCodes(address(new ERC1967Proxy(implementation, "")));
    }
}
