// SPDX-License-Identifier: MIT LICENSE
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FEWToken is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;
    address[] private admins;
    uint256 public constant subscribeFee = 100000000 gwei;
    uint256 public constant subscribeAmount = 100000e18;
    uint8 public constant inviteeBase = 3;
    uint8 public constant extraBase = 10;
    uint8 public constant rewardsBase = 5;
    uint256 public totalCirculation;

    struct invitationInfo{
        bool    canInvite;
        uint256 invitationNums;
        uint256 unclaimedNums;
        uint256 extraClaimNums;
        uint256 claimed_E;
        uint256 rewards_T;
        uint256 claimed_T;
        uint256 subscribe_E;
        uint256 subscribe_T;
    }

    mapping(address => invitationInfo) invitationInfos;

    event ClaimedRewards(address account,uint256 amount);
    event ClaimedToken(address account,uint256 amount);

    constructor(address controller0,address controller1,address controller2) ERC20("FEWToken", "FEW") {
        uint256  supply = 2100000000e18;
        _mint(address(this), supply);
        admins.push(controller0);
        admins.push(controller1);
        admins.push(controller2);
    }

    function mint(address account,uint256 amount) public onlyOwner{
         _mint(account, amount);
    }

    function burnFrom(address account,uint256 amount) public override{
        super.burnFrom(account,amount);
    }

    function subscribe(address inviter)public payable{
        require(msg.sender != inviter,"users can't invite themselves!");
        require(msg.value == subscribeFee,"value should be 0.1 Ether");
        require(balanceOf(address(this)) >= subscribeAmount,"there is no enough token to subscribe!");
        _transfer(address(this),msg.sender,subscribeAmount);
        totalCirculation += subscribeAmount;
        invitationInfos[msg.sender].subscribe_E += msg.value;
        invitationInfos[msg.sender].subscribe_T += subscribeAmount;

        if(!invitationInfos[msg.sender].canInvite){
            invitationInfos[msg.sender].canInvite = true;     
        }

        if(invitationInfos[inviter].canInvite){
            invitationInfos[inviter].invitationNums += 1;
            invitationInfos[inviter].unclaimedNums += 1;
            invitationInfos[inviter].extraClaimNums +=1;

            uint256 amount = subscribeAmount.mul(rewardsBase).div(100);
            invitationInfos[inviter].rewards_T += amount;
        }
    }

    function claim_E() external{
        require(invitationInfos[msg.sender].canInvite,"No claim qualifications!");
        uint256 num = invitationInfos[msg.sender].unclaimedNums.div(inviteeBase);
        require(num > 0,"It doesn't meet the conditions");
        uint256 amount = subscribeFee * num;
        require(invitationInfos[msg.sender].unclaimedNums >= num.mul(inviteeBase));
        invitationInfos[msg.sender].unclaimedNums -= num.mul(inviteeBase);
        require(address(this).balance >= amount,"No enough rewards to claim!");
        invitationInfos[msg.sender].claimed_E += amount;
        payable(msg.sender).transfer(amount);
        emit ClaimedRewards(msg.sender, amount);
    }

    function claimExtra_E() external{
        require(invitationInfos[msg.sender].canInvite,"No claim qualifications!");
        uint256 num = invitationInfos[msg.sender].extraClaimNums.div(extraBase);
        require(num > 0,"It doesn't meet the conditions");
        uint256 amount = subscribeFee * num;
        require(invitationInfos[msg.sender].extraClaimNums >= num.mul(extraBase));
        invitationInfos[msg.sender].extraClaimNums -= num.mul(extraBase);
        require(address(this).balance >= amount,"No enough rewards to claim!");
        invitationInfos[msg.sender].claimed_E += amount;
        payable(msg.sender).transfer(amount);
        emit ClaimedRewards(msg.sender, amount);
    }

    function claim_T() external {
        require(invitationInfos[msg.sender].canInvite,"No claim qualifications!");
        require(balanceOf(address(this)) >= invitationInfos[msg.sender].rewards_T,"No enough token to claim");
        _transfer(address(this),msg.sender,invitationInfos[msg.sender].rewards_T);
        invitationInfos[msg.sender].claimed_T += invitationInfos[msg.sender].rewards_T;
        totalCirculation += invitationInfos[msg.sender].rewards_T;
        emit ClaimedToken(msg.sender,invitationInfos[msg.sender].rewards_T);
        invitationInfos[msg.sender].rewards_T = 0;
    }

    function getRewardsInfo(address account)external view returns(
        uint256 rewards_e,uint256 claimed_e,uint256 rewards_t,uint256 claimed_t
        ){
        uint256 num = invitationInfos[account].unclaimedNums.div(inviteeBase);
        return (subscribeFee * num,invitationInfos[account].claimed_E,
        invitationInfos[account].rewards_T,invitationInfos[account].claimed_T);
    }

    function getInviteInfo(address account) external view returns(
        bool isInviter,uint256 totalInvitationNums,uint256 UnclaimNum,
        uint256 extraNums,uint256 subscribe_fee,uint256 subscribe_amount) {
        return (invitationInfos[account].canInvite,
            invitationInfos[account].invitationNums,
            invitationInfos[account].unclaimedNums,
            invitationInfos[account].extraClaimNums,
            invitationInfos[account].subscribe_E,
            invitationInfos[account].subscribe_T);
    }

    function IsInviter()public view returns(bool){
        return invitationInfos[msg.sender].canInvite;
    }

    function withDraw()external onlyOwner{
        uint256 amount = address(this).balance;
        require(amount > 0, "NO ETHER TO WITHDRAW");
        for(uint i = 0;i < admins.length;i++){
            payable(admins[i]).transfer(amount.div(3));
        }
    }

    function withDrawToken(address account,uint256 amount)external onlyOwner{
        uint256 balance = balanceOf(address(this));
        require(balance >= amount,"token balance not enough!");
        totalCirculation += amount;
        _transfer(address(this),account,amount);
    }
}
