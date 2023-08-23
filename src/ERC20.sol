// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.18;
import {IERC20} from "./IERC20.sol";


contract ERC20 is IERC20 {
/*State variables*/

uint256 private TotalSupply;
mapping(address => uint256) private balances;
mapping(address => mapping(address => uint256)) private _allowance;

address  owner;

//0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925
/*Errors*/
error mustBeOwner();
error valueOverFlow();
error notEnoughBalance();
error addressZero();

/*onlyOwner() modifier*/

modifier onlyOwner(){
    assembly{
        if iszero(eq(caller(),sload(owner.slot))){
            //store the sig of the error: cast sig mustBeOwner()
            mstore(0x00,0x5b11cec6)
            revert(0x1c,0x04)
        }
    }
    _;
}
constructor(){
    owner = msg.sender;
}

//We need to add some tokens to supply
//@dev add tokens to supply,only owner can mint tokens
//@param to The address that receives the initial tokens
//@param amount The amount to mint(add to market)
function mint(address to,uint256 amount) external onlyOwner{
  //Since we use assembly , we have to check for overflows
  //Minting, will add TotalSupply and also balanceOf the sender
    assembly{
        let _totalSupplyBefore := sload(TotalSupply.slot)
        let _totalSupplyAfter := add(_totalSupplyBefore,amount)
        if gt(_totalSupplyBefore,_totalSupplyAfter){
            //we revert with overflow() error
            mstore(0x00,0x29f4cd11)
            revert(0x1c,0x04)
        }
        //we didn't revert, so add amount to TotalSupply
        sstore(TotalSupply.slot,_totalSupplyAfter)
        //we also need to update the balance of the caller()
        //mapping(address => uint256) balanceOf
        //For mappings, we need to get the slot then hash it with the key 
        //let slot := balanceOf.slot
        mstore(0x00,to)
        mstore(0x20,balances.slot)
        let location := keccak256(0x00,0x40)
        sstore(location,add(sload(location),amount))

        //we have added supply and updated balances, so we now emit an event
        mstore(0x00,amount)
        log3(0x00,0x20,0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,0,to)
    }
}


//We can mint tokens, let's burn some
/**Burning is basically removing them from totalSupply and reduce the balance of the burner 
 * 
 * 
*/
//@dev Function to burn tokens - one can only burn his/her tokens, you cannot burn more than you have
//@param amount - Amount of tokens to burn
function burn(uint256 amount) external{
    assembly{
        //validate that msg.sender isn't burning more than they have
        //Get their balance first
        mstore(0x20,balances.slot)
        mstore(0x00, caller())
        let senderBalance := keccak256(0x00,0x40)
        if lt(sload(senderBalance),amount){
            mstore(0x00,0x9b834218)
            revert(0x1c,0x04)
        }
        //if allowed, subtract amount from totalSupply
        sstore(TotalSupply.slot,sub(sload(TotalSupply.slot),amount))
        //update caller() balance
        sstore(senderBalance,sub(sload(senderBalance),amount))

        //we have added supply and updated balances, so we now emit an event
        mstore(0x00,amount)
        log3(0x00,0x20,0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,caller(),0)
    }


}
    //We can mint,burn , let's transfer some to someone else
    //@dev Transfer tokens from sender to the supplied address, don't allow transfer to zero and you must have enough balance
    //@param to - the address to whom you wish to transfer tokens to
    //@param amount - The amount of tokens to transfer
    //@return true on success , false otherwise - compliant with most tokens
    function transfer(address to,uint256 amount) external returns(bool){
        assembly{
            if iszero(to){
                mstore(0x00,0x7299a729)
                revert(0x1c,0x04)
            }
            //Get the balance of the sender and compare against amount
            mstore(0x00,caller())
            mstore(0x20,balances.slot)
            let balanceSlot := keccak256(0x00,0x40)
            if gt(amount,sload(balanceSlot)){
                mstore(0x00,0x9b834218)
                revert(0x1c,0x04)
            }
            // checks passed, move the funds
            sstore(balanceSlot,sub(sload(balanceSlot),amount))
            //update receivers balance
            mstore(0x00,to)
            let receiverBalanceSlot := keccak256(0x00,0x40)
            sstore(receiverBalanceSlot,add(sload(receiverBalanceSlot),amount))
             
        //we have added supply and updated balances, so we now emit an event
        mstore(0x00,amount)
        log3(0x00,0x20,0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,caller(),0)

        }
        return true;    
    }

    //We can transfer to others, but can others transfer on our behalf
    //We need to first allow them to, so we approve
    //mapping(address => mapping(address => uint256)) allowance
    //@dev approve - Allow spender to spend some of our tokens
    //@param spender - Address to allow
    //@param amount - Amount to allow them to spend
    function approve(address spender,uint256 amount) external returns(bool){
        assembly{
            //we can't delegate to address 0
            if iszero(spender){
                mstore(0x00,0x7299a729)
                revert(0x1c,0x04)
            }
            //we need to update the allowance mapping
            //allowance[msg.sender][spender] = amount
            //Get the locations
            mstore(0x00,caller())
            mstore(0x20,_allowance.slot)
            let ownersBalanceSlot := keccak256(0x00,0x40)
            //For the second map, we hash ownersBalanceSlot with spender
            mstore(0x00,spender)
            mstore(0x20,ownersBalanceSlot)
            let spenderBalanceSlot := keccak256(0x00,0x40)
            sstore(spenderBalanceSlot,amount)
            mstore(0x00,amount)
            log3(0x00,0x20,0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,caller(),spender)
        }
        return true;
    }

    //We now have approval to spend some tokens
    //@dev TransferFrom(address from, address to, amount): Note sender is now the spender
    function transferFrom(address from, address to, uint256 amount) external returns(bool){
        //Get the allowed amount
        assembly{
            //To get allowed we use the allowance[msg.sender][spender]
            mstore(0x00,from)
            mstore(0x20,_allowance.slot)
            let ownerSlot := keccak256(0x00,0x40)

            mstore(0x20,ownerSlot)
            mstore(0x00, caller())
            let finalSlot := keccak256(0x00,0x40)

            let allowed := sload(finalSlot)
            if lt(allowed,amount){
                mstore(0x00,0x9b834218)
                revert(0x1c,0x04)  
            }
            //Allowed to transfer so update allowance
            sstore(finalSlot,sub(allowed,amount))

            //Transfer
            //Reduce amount from the from address
            mstore(0x00,from)
            mstore(0x20,balances.slot)
            let fromSlot := keccak256(0x00,0x40)
            if gt(amount,sload(fromSlot)){
                mstore(0x00,0x9b834218)
                revert(0x1c,0x04)  
            }
            sstore(fromSlot,sub(sload(fromSlot),amount))
            //add amount to the receiver
            mstore(0x00,to)
            let toSlot := keccak256(0x00,0x40)
            sstore(toSlot,add(sload(toSlot),amount))

        }
        return true;
    }

    function increaseAllowance(address spender,uint256 addedValue) external returns(bool){
        assembly{
            if iszero(spender){
                mstore(0x00,0x7299a729)
                revert(0x1c,0x04)
            }
            //Get the current allowance: allowance[msg.sender][spender]
            mstore(0x00,caller())
            mstore(0x20,_allowance.slot)
            let ownerSlot := keccak256(0x00,0x40)
            mstore(0x20,ownerSlot)
            mstore(0x00,spender)
            let spenderSlot := keccak256(0x00,0x40)
            let allowed := sload(spenderSlot)
            //We need to add addedValue to the allowed
            let finalAllowance := add(allowed,addedValue)
            //Check for overflows
            if lt(finalAllowance,allowed){
                mstore(0x00,0x29f4cd11)
                revert(0x1c,0x04)  
            }
            //all good, lets update the mappings
            sstore(spenderSlot,finalAllowance)
            //should emit an event
            mstore(0x00,finalAllowance)
            log3(0x00,0x20,0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,caller(),spender)
        }
        return true;
    } 

    function decreaseAllowance(address spender,uint256 subtractedValue) external returns(bool){
        assembly{
            if iszero(spender){
                mstore(0x00,0x7299a729)
                revert(0x1c,0x04)
            }
            //Get the current allowance: allowance[msg.sender][spender]
            mstore(0x00,caller())
            mstore(0x20,_allowance.slot)
            let ownerSlot := keccak256(0x00,0x40)
            mstore(0x20,ownerSlot)
            mstore(0x00,spender)
            let spenderSlot := keccak256(0x00,0x40)
            let allowed := sload(spenderSlot)
            //we now need to subtract the value passed from allowed
            //check for overflows
            if lt(allowed,subtractedValue){
                mstore(0x00,0x29f4cd11)
                revert(0x1c,0x04)  
            }
            //No overflows
            let finalAllowance := sub(allowed,subtractedValue)
            //update the allowance mapping
            sstore(spenderSlot,finalAllowance)
            //should emit an event
            mstore(0x00,finalAllowance)
            log3(0x00,0x20,0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,caller(),spender)

        } 
        return true;
    }  

    function allowance(address spender) external view returns (uint256){
        return _allowance[msg.sender][spender];
    }

    function balanceOf(address _owner) external view returns (uint256 result){
        //return balances[_owner];
        assembly{
            //get the slots
            mstore(0x20,balances.slot)
            mstore(0x00,_owner) 
            
            result := sload(keccak256(0x00,0x40))

        }
    }
    function totalSupply() external view returns(uint256 _totalSupply){
        assembly{
            _totalSupply := sload(TotalSupply.slot)

        }
    }



}