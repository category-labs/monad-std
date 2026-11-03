// SPDX-License-Identifier: MIT
object "CallStack" {
    code {
        if callvalue() { revert(0, 0) }
        datacopy(0, dataoffset("CallStack_deployed"), datasize("CallStack_deployed"))
        return(0, datasize("CallStack_deployed"))
    }
    object "CallStack_deployed" {
        code {
            function invalidCalldata() {
                mstore(0, shl(224, 0x8129bbcd)) // InvalidCalldata().
                revert(0, 4)
            }

            function requireInvoker() -> helperDepth {
                helperDepth := verbatim_0i_1o(hex"ae00")
                if iszero(helperDepth) {
                    mstore(0, shl(224, 0x57e8c1ca)) // NoInvoker().
                    revert(0, 4)
                }
            }

            if callvalue() { invalidCalldata() }
            switch shr(224, calldataload(0))
            case 0xba3dbad8 { // callStackDepth().
                if iszero(eq(calldatasize(), 4)) { invalidCalldata() }
                mstore(0, sub(requireInvoker(), 1))
                return(0, 32)
            }
            case 0x0c147986 { // callerN(uint256).
                if iszero(eq(calldatasize(), 36)) { invalidCalldata() }
                let helperDepth := requireInvoker()
                let n := calldataload(4)
                let ancestor := 0
                // Bound before adding one, including when n is uint256.max.
                if lt(n, helperDepth) {
                    ancestor := verbatim_1i_1o(hex"ae01", add(n, 1))
                }
                mstore(0, ancestor)
                return(0, 32)
            }
            default { invalidCalldata() }
        }
    }
}
