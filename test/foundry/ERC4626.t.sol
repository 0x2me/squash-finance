// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./mocks/ERC20Mock.sol";
import "../../contracts/Erc4626Vault.sol";

contract ERC4626Test is Test {
    MockERC20 underlying;
    ERC4626Vault vault;

    function setUp() public {
        underlying = new MockERC20("Mock Token", "MT", 18);
        vault = new ERC4626Vault(underlying, "Vault Token Mock", "VTM");
    }

    function testDeposit() public {
        uint256 depoitAmount = 10 ether;
        address bob = makeAddr("bob");
        underlying.mint(bob, depoitAmount);
        vm.prank(bob);
        underlying.approve(address(vault), depoitAmount);
        vm.prank(bob);
        vault.deposit(depoitAmount, bob);

        
        
        assertEq(underlying.balanceOf(bob), 0);
        assertEq(underlying.balanceOf(address(vault)), depoitAmount);
        assertEq(vault.balanceOf(bob), depoitAmount);
        assertEq(vault.totalSupply(), vault.balanceOf(bob));
    }
}