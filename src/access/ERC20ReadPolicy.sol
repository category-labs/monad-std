// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {IDomainAccessPolicy} from "../interfaces/IDomainAccessPolicy.sol";

/// @notice ERC-20 read policy: balances are readable by their holder and allowances by
/// their owner or spender. Other calls retain the token's own authorization checks.
/// @dev Stateless and reusable across tokens; ignores context and requires no initialization.
/// Install through the domain's access control to enforce these rules. This policy does not
/// restrict logs, storage access, or reads performed internally by the token.
contract ERC20ReadPolicy is IDomainAccessPolicy {
    bytes4 private constant BALANCE_OF = 0x70a08231; // balanceOf(address)
    bytes4 private constant ALLOWANCE = 0xdd62ed3e; // allowance(address,address)

    /// @inheritdoc IDomainAccessPolicy
    /// @dev Truncated arguments to protected selectors return false. Non-canonical ABI
    /// address words revert during decoding and must be treated as denied by the consumer.
    function canCall(address caller, address, bytes calldata data) external pure returns (bool) {
        if (data.length < 4) return true;
        bytes4 selector = bytes4(data[:4]);
        if (selector == BALANCE_OF) {
            return data.length >= 36 && caller == abi.decode(data[4:], (address));
        }
        if (selector == ALLOWANCE) {
            if (data.length < 68) return false;
            (address owner, address spender) = abi.decode(data[4:], (address, address));
            return caller == owner || caller == spender;
        }
        return true;
    }
}
