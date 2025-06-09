// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title FundMeTest
 * @author Patrick Collins (GitHub: @PatrickAlphaC)
 * @dev From https://github.com/Cyfrin/foundry-fund-me-f23
 * @notice Test contract for FundMe.sol
 * @dev This contract contains unit tests for the FundMe contract using Foundry's testing framework
 */
import {Test, console} from "forge-std/Test.sol"; // Test is the base contract for Foundry tests
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

/**
 * @dev FundMeTest inherits from Foundry's Test contract which provides testing utilities
 */
contract FundMeTest is Test {
    // Contract instance to be tested
    FundMe fundMe;

    // Test constants and variables
    address USER = makeAddr("user"); // Cheatcode: Creates a new address labeled "user"
    uint256 constant SEND_VALUE = 0.1 ether; // Amount to send in fund() tests
    uint256 constant STARTING_BALANCE = 10 ether; // Initial balance for test users
    uint256 constant GAS_PRICE = 1;

    /**
     * @dev Setup function that runs before each test
     * @notice This function deploys a fresh FundMe contract and sets up test conditions
     * @dev Uses the same deployment script that would be used in production for consistency
     */
    function setUp() external {
        //fundMe = new FundMe(); // Direct instantiation (not used)
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run(); // Deploy using the deployment script
        vm.deal(USER, STARTING_BALANCE); // Cheatcode: Sets USER's ETH balance to STARTING_BALANCE
    }

    /**
     * @dev Tests that the minimum USD amount is set correctly
     * @notice Verifies the MINIMUM_USD constant is set to 5 USD (with 18 decimals)
     */
    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18); // Assertion: Checks if values are equal
    }

    /**
     * @dev Tests that the contract owner is set correctly during deployment
     * @notice Verifies that the deployer address is set as the contract owner
     */
    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender); // Checks if contract owner is the test contract
    }

    /**
     * @dev Tests that the price feed version is correct based on the current network
     * @notice Different networks have different price feed versions
     * @dev Uses block.chainid to conditionally test based on which network we're using
     */
    function testPriceFeedVersionIsAccurate() public view {
        if (block.chainid == 11155111) {
            // Sepolia testnet
            uint256 version = fundMe.getVersion();
            assertEq(version, 4); // Sepolia uses version 4
        } else if (block.chainid == 1) {
            // Ethereum mainnet
            uint256 version = fundMe.getVersion();
            assertEq(version, 6); // Mainnet uses version 6
        }
        // For local Anvil chain, we use a mock so no assertion needed
    }

    /**
     * @dev Tests that funding fails when not enough ETH is sent
     * @notice Verifies the require statement in fund() function works correctly
     */
    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // Cheatcode: Expects the next call to revert
        fundMe.fund(); // Calling fund() with 0 ETH should revert
    }

    /**
     * @dev Tests that funding updates the data structures correctly
     * @notice Verifies that the funding amount is recorded for the correct address
     */
    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // Cheatcode: Next transaction will be sent from USER address
        fundMe.fund{value: SEND_VALUE}(); // Send 0.1 ETH to fund()

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE); // Verify the amount was recorded correctly
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithDrawWithASingleFunder() public funded {
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() public funded {
        //Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders + startingFunderIndex; i++) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //Assert

        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
        assert((numberOfFunders + 1) * SEND_VALUE == fundMe.getOwner().balance - startingOwnerBalance);
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders + startingFunderIndex; i++) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
        assert((numberOfFunders + 1) * SEND_VALUE == fundMe.getOwner().balance - startingOwnerBalance);
    }
}
