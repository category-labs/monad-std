// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.13 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IMonadStaking} from "../src/interfaces/IMonadStaking.sol";

contract IMonadStakingSelectorTest is Test {
    function testSelectorsMatchCxxImplementation() public pure {
        assertEq(IMonadStaking.addValidator.selector, bytes4(0xf145204c));
        assertEq(IMonadStaking.delegate.selector, bytes4(0x84994fec));
        assertEq(IMonadStaking.undelegate.selector, bytes4(0x5cf41514));
        assertEq(IMonadStaking.compound.selector, bytes4(0xb34fea67));
        assertEq(IMonadStaking.withdraw.selector, bytes4(0xaed2ee73));
        assertEq(IMonadStaking.claimRewards.selector, bytes4(0xa76e2ca5));
        assertEq(IMonadStaking.changeCommission.selector, bytes4(0x9bdcc3c8));
        assertEq(IMonadStaking.externalReward.selector, bytes4(0xe4b3303b));

        assertEq(IMonadStaking.getEpoch.selector, bytes4(0x757991a8));
        assertEq(IMonadStaking.getProposerValId.selector, bytes4(0xfbacb0be));
        assertEq(IMonadStaking.getValidator.selector, bytes4(0x2b6d639a));
        assertEq(IMonadStaking.getDelegator.selector, bytes4(0x573c1ce0));
        assertEq(IMonadStaking.getWithdrawalRequest.selector, bytes4(0x56fa2045));
        assertEq(IMonadStaking.getConsensusValidatorSet.selector, bytes4(0xfb29b729));
        assertEq(IMonadStaking.getSnapshotValidatorSet.selector, bytes4(0xde66a368));
        assertEq(IMonadStaking.getExecutionValidatorSet.selector, bytes4(0x7cb074df));
        assertEq(IMonadStaking.getDelegations.selector, bytes4(0x4fd66050));
        assertEq(IMonadStaking.getDelegators.selector, bytes4(0xa0843a26));
    }

    function testEventSignaturesMatchCxxImplementation() public pure {
        assertEq(
            keccak256(bytes("ValidatorRewarded(uint64,address,uint256,uint64)")),
            bytes32(0x3a420a01486b6b28d6ae89c51f5c3bde3e0e74eecbb646a0c481ccba3aae3754)
        );
        assertEq(
            keccak256(bytes("ValidatorCreated(uint64,address,uint256)")),
            bytes32(0x6f8045cd38e512b8f12f6f02947c632e5f25af03aad132890ecf50015d97c1b2)
        );
        assertEq(
            keccak256(bytes("ValidatorStatusChanged(uint64,uint64)")),
            bytes32(0xc95966754e882e03faffaf164883d98986dda088d09471a35f9e55363daf0c53)
        );
        assertEq(
            keccak256(bytes("Delegate(uint64,address,uint256,uint64)")),
            bytes32(0xe4d4df1e1827dd28252fd5c3cd7ebccd3da6e0aa31f74c828f3c8542af49d840)
        );
        assertEq(
            keccak256(bytes("Undelegate(uint64,address,uint8,uint256,uint64)")),
            bytes32(0x3e53c8b91747e1b72a44894db10f2a45fa632b161fdcdd3a17bd6be5482bac62)
        );
        assertEq(
            keccak256(bytes("Withdraw(uint64,address,uint8,uint256,uint64)")),
            bytes32(0x63030e4238e1146c63f38f4ac81b2b23c8be28882e68b03f0887e50d0e9bb18f)
        );
        assertEq(
            keccak256(bytes("ClaimRewards(uint64,address,uint256,uint64)")),
            bytes32(0xcb607e6b63c89c95f6ae24ece9fe0e38a7971aa5ed956254f1df47490921727b)
        );
        assertEq(
            keccak256(bytes("CommissionChanged(uint64,uint256,uint256)")),
            bytes32(0xd1698d3454c5b5384b70aaae33f1704af7c7e055f0c75503ba3146dc28995920)
        );
        assertEq(
            keccak256(bytes("EpochChanged(uint64,uint64)")),
            bytes32(0x4fae4dbe0ed659e8ce6637e3c273cd8e4d3bf029b9379a9e8b3f3f27dbef809b)
        );
    }
}
