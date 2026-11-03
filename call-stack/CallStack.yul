// SPDX-License-Identifier: MIT
object "CallStack" {
    code {
        if callvalue() { revert(0, 0) }
        datacopy(0, dataoffset("CallStack_deployed"), datasize("CallStack_deployed"))
        return(0, datasize("CallStack_deployed"))
    }
    object "CallStack_deployed" {
        code {
            // readForInvoker(uint256): selector 0x8485ba60, one full-width argument.
            if or(callvalue(), or(iszero(eq(calldatasize(), 36)), iszero(eq(shr(224, calldataload(0)), 0x8485ba60)))) {
                mstore(0, shl(224, 0x8129bbcd)) // InvalidCalldata().
                revert(0, 4)
            }

            let helperDepth := verbatim_0i_1o(hex"ae00")
            if iszero(helperDepth) {
                mstore(0, shl(224, 0x57e8c1ca)) // NoInvoker().
                revert(0, 4)
            }

            let n := calldataload(4)
            let ancestor := 0
            // Bound before adding one, including when n is uint256.max.
            if lt(n, helperDepth) {
                ancestor := verbatim_1i_1o(hex"ae01", add(n, 1))
            }
            mstore(0, sub(helperDepth, 1))
            mstore(32, ancestor)
            return(0, 64)
        }
    }
}
