// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {ICallStack} from "./interfaces/ICallStack.sol";

/// @notice MIP-18 call-stack introspection for the executing application frame.
/// @dev Requires a directly called, trusted helper and a VM with MIP-18 enabled.
/// Internal functions add no frame; the helper compensates for its one STATICCALL frame.
/// Ancestor callers must not be used as a substitute for authorization.
library CallStack {
    /// @notice Maximum execution gas forwarded to the helper, excluding account-access costs.
    uint256 internal constant HELPER_GAS_LIMIT = 2_000;

    /// @notice Runtime hash of the optimized helper in call-stack/artifacts/CallStack.json.
    bytes32 internal constant HELPER_CODE_HASH = 0x11188db450f6bf253c64f447fa794256348f5ff22cb744654e0f2bb0354df20a;

    error MissingHelper(address helper);
    error HelperCallFailed(address helper);
    error InvalidHelperResponse(address helper);
    error UnexpectedHelperCode(address helper);

    /// @notice Checks the configured helper against the published optimized runtime.
    /// @dev Call during application construction or configuration; queries only check code presence.
    function validateHelper(address helper) internal view {
        if (helper.code.length == 0) revert MissingHelper(helper);
        if (helper.codehash != HELPER_CODE_HASH) revert UnexpectedHelperCode(helper);
    }

    /// @notice Returns the executing application's zero-based call depth.
    function callStackDepth(address helper) internal view returns (uint256) {
        return _query(helper, abi.encodeWithSelector(ICallStack.callStackDepth.selector));
    }

    /// @notice Returns the CALLER value n frames above the executing application, or zero.
    /// @dev callerN(helper, 0) equals msg.sender. Delegatecalls may repeat caller values.
    function callerN(address helper, uint256 n) internal view returns (address) {
        uint256 ancestor = _query(helper, abi.encodeWithSelector(ICallStack.callerN.selector, n));
        if (ancestor > type(uint160).max) revert InvalidHelperResponse(helper);
        // The range check above proves that the address cast cannot truncate.
        // forge-lint: disable-next-line(unsafe-typecast)
        return address(uint160(ancestor));
    }

    /// @dev Executes one operation with a bounded STATICCALL and a single-word response.
    /// Validate the helper's identity when configuring it. A decodable response is not proof
    /// of identity. Unsupported opcodes, exhausted gas and other call failures revert explicitly.
    function _query(address helper, bytes memory input) private view returns (uint256) {
        if (helper.code.length == 0) revert MissingHelper(helper);
        // The fixed gas allowance also bounds return-data allocation in the helper.
        // forge-lint: disable-next-line(return-bomb)
        (bool success, bytes memory data) = helper.staticcall{gas: HELPER_GAS_LIMIT}(input);
        if (!success) revert HelperCallFailed(helper);
        if (data.length != 32) revert InvalidHelperResponse(helper);
        return abi.decode(data, (uint256));
    }
}
