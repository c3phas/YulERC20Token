pragma solidity 0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "../src/ERC20.sol";

contract ERC is Test{
    ERC20 erc20token;
    address ZERO = address(0);
    address JANE = address(1);
    address BOB = address(2);
    address ALICE = address(3);

    function setUp() public{
        erc20token = new ERC20();
    }

    function testTotalSupply() public{
        //Test before mints
        assertEq(erc20token.totalSupply(),0,"Total supply should be zero before mints");
    }

    function testNotOwnerMints() public{
        //The function mint should revert if called by someone who is not owner
        vm.expectRevert(0x5b11cec6);
        vm.startPrank(ALICE);
        erc20token.mint(BOB,50);
        vm.stopPrank();

    }

    function testOwnerMints() public{
        erc20token.mint(BOB,30);
        //After Mints, totalsupply should increase and Bob balance to
        assertEq(erc20token.totalSupply(),30,"Total supply should be zero before mints");
        assertEq(erc20token.balanceOf(BOB),30,"Bob's balace should be amount minted");
       
    }
    //What happens if we mint more than type(uint256).max
    function testMintOverflows() public{
        vm.expectRevert();
        erc20token.mint(BOB,type(uint256).max + 1);
    }
    function testTransfer() public {
        erc20token.mint(BOB,30);
        //test the transfer
        assertEq(erc20token.balanceOf(ALICE),0,"Alice's balance before transfer ");
        //Pretend to be BOB in order to make transfers
        vm.prank(BOB);
        erc20token.transfer(ALICE,15);
        //Check status for variables affected after the transfer
        assertEq(erc20token.totalSupply(),30,"Total supply affected by transfers");
        assertEq(erc20token.balanceOf(BOB),15,"Bob's balance should be amount after transfer");
        assertEq(erc20token.balanceOf(ALICE),15,"Alice's balance should be amount transfered to her plus any other balance she had");
    }

    function testTransferToZeroAddress() public{
        erc20token.mint(BOB,30);
        //test the transfer
        //We expect to revert with the error selector for addressZero()
        vm.expectRevert(0x7299a729);
        vm.prank(BOB);
        erc20token.transfer(ZERO,15);

    }

    function testTransferMoreThanOurBalance() public{
        erc20token.mint(BOB,30);
        //test the transfer
        //We expect to revert with the error selector for notEnoughBalance()
        vm.expectRevert(0x9b834218);
        vm.prank(BOB);
        erc20token.transfer(ALICE,35);
    }

    function testApprove() public{
        //Mint to alice
        erc20token.mint(ALICE,30);
        vm.startPrank(ALICE);
        //Alice wants bob to be able to spend some of her tokens
        erc20token.approve(BOB,10);
        //console.log(erc20token.getAllowance(BOB));
        assertEq(erc20token.allowance(BOB),10,"Allowance not correct");
        vm.stopPrank();
    }

    function testApproveToZeroAddress() public{
        //Mint to alice
        erc20token.mint(ALICE,30);
        vm.startPrank(ALICE);
        //Alice wants approve ZERO address, which should revert
        vm.expectRevert(0x7299a729);
        erc20token.approve(ZERO,10);
        vm.stopPrank();
    }

    function testTransferFrom() public {
        erc20token.mint(BOB,30);
        //After Mints, totalsupply should increase and Bob balance to
        assertEq(erc20token.totalSupply(),30,"Total supply should be zero before mints");
        assertEq(erc20token.balanceOf(BOB),30,"Bob's balace should be amount minted");
        vm.startPrank(BOB);
        //Approve Alice to spend some of Bob's tokens
        erc20token.approve(ALICE,25);
        //console.log(erc20token.getAllowance(BOB));
        assertEq(erc20token.allowance(ALICE),25," First Allowance not correct");
        assertEq(erc20token.balanceOf(ALICE),0,"Alice's balance before and after approve should not change");
        assertEq(erc20token.balanceOf(JANE),0,"Jane's balance before the transfer not correct");
        vm.stopPrank();

        //WE now test if alice can actually transfer on behalf of BOB
        vm.prank(ALICE);
        assertTrue(erc20token.transferFrom(BOB,JANE,20));
        assertEq(erc20token.balanceOf(ALICE),0,"Alice's balance should be zero");
        assertEq(erc20token.balanceOf(JANE),20,"Jane's balance should be amount transferedTo");
        assertEq(erc20token.balanceOf(BOB),10,"Bob's balance should be amount minted - transferedTo");
        vm.prank(BOB);
        assertEq(erc20token.allowance(ALICE),5," Second Allowance not correct");
    }

    function testTransferMoreThanAllowance() public {
        erc20token.mint(BOB,30);
        vm.prank(BOB);
        //Approve Alice to spend some of Bob's tokens
        erc20token.approve(ALICE,20);
        //Alice attempts to transfer more than 20 : we expect it to revert with notEnoughBalance()
        vm.expectRevert(0x9b834218);
        vm.prank(ALICE);
        erc20token.transferFrom(BOB,JANE,25);

    }
    //Since approval doesn't check how much the owner has before approving, what happens if they approve more than they have
    //Should we revert during the approval period or wait for a transfer to be initiated
    function testTransferMoreThanOwnerBalance() public{
        erc20token.mint(BOB,30);
        vm.prank(BOB);
        //Approve Alice to spend some of Bob's tokens
        erc20token.approve(ALICE,35);
        //Alice attempts to transfer more than everything approved to her : we expect it to revert with notEnoughBalance()
        vm.expectRevert(0x9b834218);
        vm.prank(ALICE);
        erc20token.transferFrom(BOB,JANE,35); 
    }

    function testTransferFromWhenNotApproved() public{
        erc20token.mint(BOB,30);
        vm.expectRevert(0x9b834218);
        vm.prank(ALICE);
        erc20token.transferFrom(BOB,JANE,20);
    }
    function testBurn() public{
        //Burning should reduce total supply and also msg.senders balance
        erc20token.mint(BOB,30);
        assertEq(erc20token.totalSupply(),30, "Supply before burning");
        vm.prank(BOB);
        erc20token.burn(20);
        assertEq(erc20token.totalSupply(),10, "Supply After burning");
        assertEq(erc20token.balanceOf(BOB),10, "Bob's balance after burning");

    }
    function testBurnMoreThanBalance() public{
        erc20token.mint(BOB,30);
        assertEq(erc20token.balanceOf(BOB),30, "Balance of Bob before burning");
        //If Bob tries to burn more than they have , we expect a revert
        vm.expectRevert(0x9b834218);
        vm.prank(BOB);
        erc20token.burn(35); 
    }
    function testIncreaseAllowance() public{
        erc20token.mint(BOB,30);
        vm.startPrank(BOB);
        erc20token.approve(ALICE,20);
        assertTrue(erc20token.increaseAllowance(ALICE,5));
        assertEq(erc20token.allowance(ALICE), 25, "Alice allowance should be initial + the value increased with");   
        vm.stopPrank();
    }
    function testIncreaseAllowanceWhenBalanceIsZero() public{
        erc20token.mint(BOB,30);
        vm.startPrank(BOB);
        assertTrue(erc20token.increaseAllowance(ALICE,5));
        assertEq(erc20token.allowance(ALICE), 5, "Alice allowance should be initial + the value increased with");      
        vm.stopPrank();
    }
    function testIncreaseAllowanceForZeroAddress() public{
        erc20token.mint(BOB,30);
        vm.expectRevert(0x7299a729);
        vm.prank(BOB);
        assertFalse(erc20token.increaseAllowance(ZERO,5));
    }
    function testIncreaseAllowanceOverflows() public{
        erc20token.mint(BOB,30);
        vm.startPrank(BOB);
        erc20token.approve(ALICE,type(uint256).max);
        vm.expectRevert(0x29f4cd11);
        erc20token.increaseAllowance(ALICE,1);
        vm.stopPrank();
    }

    function testDecreaseAllowance() public{
        erc20token.mint(BOB,30);
        vm.startPrank(BOB);
        erc20token.approve(ALICE,20);
        assertTrue(erc20token.decreaseAllowance(ALICE,5));
        assertEq(erc20token.allowance(ALICE), 15, "Alice allowance should be initial + the value increased with");   
        vm.stopPrank();
    }
    function testDecreaseAllowanceForAddressZero() public{
        erc20token.mint(BOB,30);
        vm.expectRevert(0x7299a729);
        vm.prank(BOB);
        assertFalse(erc20token.decreaseAllowance(ZERO,5));
    }
    function testDecreaseAllowanceOverflows() public{
        erc20token.mint(BOB,30);
        vm.startPrank(BOB);
        erc20token.approve(ALICE,10);
        vm.expectRevert(0x29f4cd11);
        erc20token.decreaseAllowance(ALICE,20);
        vm.stopPrank();
    }
    function testDecreaseAllowanceFromZero() public{
        erc20token.mint(BOB,30);
        vm.startPrank(BOB);
        vm.expectRevert(0x29f4cd11);
        erc20token.decreaseAllowance(ALICE,20);
        vm.stopPrank();
    }
    
}

