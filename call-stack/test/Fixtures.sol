// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {CallStack} from "../../src/CallStack.sol";

contract Application {
    function observe(address helper, uint256 n) external view returns (uint256, address) {
        return (CallStack.callStackDepth(helper), CallStack.callerN(helper, n));
    }

    function callStackDepth(address helper) external view returns (uint256) {
        return CallStack.callStackDepth(helper);
    }

    function callerN(address helper, uint256 n) external view returns (address) {
        return CallStack.callerN(helper, n);
    }

    function validate(address helper) external view {
        CallStack.validateHelper(helper);
    }

    function around(address helper, uint256 n, address child, bool fail)
        external
        returns (uint256 beforeDepth, address beforeCaller, uint256 afterDepth, address afterCaller)
    {
        beforeDepth = CallStack.callStackDepth(helper);
        beforeCaller = CallStack.callerN(helper, n);
        (bool success,) = child.call(abi.encodeWithSelector(this.visit.selector, helper, fail));
        require(success != fail, "child outcome");
        afterDepth = CallStack.callStackDepth(helper);
        afterCaller = CallStack.callerN(helper, n);
    }

    function visit(address helper, bool fail) external view {
        uint256 d = CallStack.callStackDepth(helper);
        address a = CallStack.callerN(helper, 0);
        require(d > 0 && a == msg.sender, "child context");
        if (fail) revert("child revert");
    }

    function measureCallStackDepth(address helper) external view returns (uint256 cold, uint256 warm, uint256 d) {
        uint256 start = gasleft();
        d = CallStack.callStackDepth(helper);
        cold = start - gasleft();
        start = gasleft();
        d = CallStack.callStackDepth(helper);
        warm = start - gasleft();
    }

    function measureCallerN(address helper, uint256 n) external view returns (uint256 cold, uint256 warm, address a) {
        uint256 start = gasleft();
        a = CallStack.callerN(helper, n);
        cold = start - gasleft();
        start = gasleft();
        a = CallStack.callerN(helper, n);
        warm = start - gasleft();
    }
}

contract MemoryProbe {
    function observe(address helper, uint256 n, bytes memory payload)
        external
        view
        returns (uint256 depth, address ancestor, bytes memory beforeQuery, bytes memory afterQuery, bytes memory empty)
    {
        beforeQuery = abi.encode(payload);
        depth = CallStack.callStackDepth(helper);
        ancestor = CallStack.callerN(helper, n);
        afterQuery = abi.encode(payload);
        return (depth, ancestor, beforeQuery, afterQuery, empty);
    }
}

contract Router {
    function route(address application, address helper, uint256 n) external view returns (uint256, address) {
        return Application(application).observe(helper, n);
    }
}

contract Proxy {
    address private immutable implementation;

    constructor(address target) {
        implementation = target;
    }

    fallback() external {
        address target = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if iszero(success) { revert(0, returndatasize()) }
            return(0, returndatasize())
        }
    }
}

contract ConstructorProbe {
    uint256 public immutable observedDepth;
    address public immutable observedCaller;

    constructor(address helper, uint256 n) {
        observedDepth = CallStack.callStackDepth(helper);
        observedCaller = CallStack.callerN(helper, n);
    }
}

contract Factory {
    function make(address helper, uint256 n, bool deterministic) external returns (uint256, address) {
        ConstructorProbe probe =
            deterministic ? new ConstructorProbe{salt: bytes32(n)}(helper, n) : new ConstructorProbe(helper, n);
        return (probe.observedDepth(), probe.observedCaller());
    }
}

// Negative ABI and call-failure fixtures; these do not emulate MIP-18 context.
contract BadHelper {
    uint256 private immutable responseMode;

    constructor(uint256 mode) {
        responseMode = mode;
    }

    fallback() external {
        uint256 mode = responseMode;
        assembly {
            switch mode
            case 0 { return(0, 0) }
            case 1 { return(0, 1) }
            case 2 { return(0, 31) }
            case 3 { return(0, 33) }
            case 4 { return(0, 64) }
            case 5 {
                mstore(0, shl(160, 1))
                return(0, 32)
            }
            case 6 { return(0, 32) }
            case 7 { revert(0, 0) }
            case 8 { invalid() }
            case 9 { sstore(0, 1) }
            case 10 { return(0, 4096) }
            case 11 { return(0, 1000000) }
            default { return(0, 32) }
        }
    }
}
