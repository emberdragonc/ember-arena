// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { EmberArena } from "../src/EmberArena.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock EMBER token for testnet deployment
contract MockEMBER is ERC20 {
    constructor() ERC20("Ember Token", "EMBER") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DeployEmberArenaScript is Script {
    // Ember Treasury address (receives fees/is owner)
    address constant EMBER_TREASURY = 0xE3c938c71273bFFf7DEe21BDD3a8ee1e453Bdd1b;

    // Minimum backing threshold: 10 EMBER
    uint256 constant MIN_BACKING_THRESHOLD = 10 ether;

    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock EMBER token for testnet
        MockEMBER emberToken = new MockEMBER();
        console.log("MockEMBER deployed at:", address(emberToken));

        // Deploy EmberArena
        EmberArena arena = new EmberArena(address(emberToken), MIN_BACKING_THRESHOLD);
        console.log("EmberArena deployed at:", address(arena));

        // Transfer ownership to Ember Treasury
        arena.transferOwnership(EMBER_TREASURY);
        console.log("Ownership transferred to:", EMBER_TREASURY);
        console.log("(Pending acceptance via acceptOwnership)");

        // Mint some test tokens to treasury for testing
        emberToken.mint(EMBER_TREASURY, 100_000 ether);
        console.log("Minted 100,000 EMBER to treasury");

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Base Sepolia");
        console.log("EMBER Token:", address(emberToken));
        console.log("EmberArena:", address(arena));
        console.log("Min Backing Threshold:", MIN_BACKING_THRESHOLD / 1e18, "EMBER");
        console.log("Owner (pending):", EMBER_TREASURY);
    }
}
