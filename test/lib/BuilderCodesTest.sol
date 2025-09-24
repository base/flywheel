// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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
        uint256 len = 32;
        bytes memory codeBytes = new bytes(len);

        // Iteratively generate code with modulo arithmetic on pseudo-random hash
        for (uint256 i; i < len; i++) {
            codeBytes[i] = allowedCharacters[seed % divisor];
            seed /= divisor;
            if (seed == 0) break;
        }

        return string(codeBytes);
    }
}
