// SPDX-License-Identifier: MIT
object "Reference" {
    code {
        datacopy(0, dataoffset("Reference_deployed"), datasize("Reference_deployed"))
        return(0, datasize("Reference_deployed"))
    }
    object "Reference_deployed" {
        code {
            // Raw calldata: helper address, uint256 index.
            let helper := calldataload(0)
            let n := calldataload(32)
            mstore(0, verbatim_0i_1o(hex"ae00"))
            mstore(32, verbatim_1i_1o(hex"ae01", n))
            mstore(128, shl(224, 0xba3dbad8)) // callStackDepth().
            if iszero(staticcall(2000, helper, 128, 4, 64, 32)) { revert(0, 0) }
            if iszero(eq(returndatasize(), 32)) { revert(0, 0) }
            mstore(128, shl(224, 0x0c147986)) // callerN(uint256).
            mstore(132, n)
            if iszero(staticcall(2000, helper, 128, 36, 96, 32)) { revert(0, 0) }
            if iszero(eq(returndatasize(), 32)) { revert(0, 0) }
            // Native and adjusted helper results must match in this same frame.
            if or(iszero(eq(mload(0), mload(64))), iszero(eq(mload(32), mload(96)))) { revert(0, 0) }
            return(0, 128)
        }
    }
}
