// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {CallStack} from "../../src/CallStack.sol";

contract Application {
    function read(address helper, uint256 n) external view returns (uint256, address) {
        return CallStack.read(helper, n);
    }

    function depth(address helper) external view returns (uint256) {
        return CallStack.depth(helper);
    }

    function callerAt(address helper, uint256 n) external view returns (address) {
        return CallStack.callerAt(helper, n);
    }

    function validate(address helper) external view {
        CallStack.validateHelper(helper);
    }

    function around(address helper, uint256 n, address child, bool fail)
        external
        returns (uint256 beforeDepth, address beforeCaller, uint256 afterDepth, address afterCaller)
    {
        (beforeDepth, beforeCaller) = CallStack.read(helper, n);
        (bool success,) = child.call(abi.encodeWithSelector(this.visit.selector, helper, fail));
        require(success != fail, "child outcome");
        (afterDepth, afterCaller) = CallStack.read(helper, n);
    }

    function visit(address helper, bool fail) external view {
        (uint256 d, address a) = CallStack.read(helper, 0);
        require(d > 0 && a == msg.sender, "child context");
        if (fail) revert("child revert");
    }

    function measureRead(address helper, uint256 n)
        external
        view
        returns (uint256 cold, uint256 warm, uint256 d, address a)
    {
        uint256 start = gasleft();
        (d, a) = CallStack.read(helper, n);
        cold = start - gasleft();
        start = gasleft();
        (d, a) = CallStack.read(helper, n);
        warm = start - gasleft();
    }

    function measureDepth(address helper) external view returns (uint256 cold, uint256 warm, uint256 d) {
        uint256 start = gasleft();
        d = CallStack.depth(helper);
        cold = start - gasleft();
        start = gasleft();
        d = CallStack.depth(helper);
        warm = start - gasleft();
    }

    function measureCaller(address helper, uint256 n) external view returns (uint256 cold, uint256 warm, address a) {
        uint256 start = gasleft();
        a = CallStack.callerAt(helper, n);
        cold = start - gasleft();
        start = gasleft();
        a = CallStack.callerAt(helper, n);
        warm = start - gasleft();
    }

    function measureSeparate(address helper, uint256 n)
        external
        view
        returns (uint256 cold, uint256 warm, uint256 d, address a)
    {
        uint256 start = gasleft();
        d = CallStack.depth(helper);
        a = CallStack.callerAt(helper, n);
        cold = start - gasleft();
        start = gasleft();
        d = CallStack.depth(helper);
        a = CallStack.callerAt(helper, n);
        warm = start - gasleft();
    }
}

contract Router {
    function route(address application, address helper, uint256 n) external view returns (uint256, address) {
        return Application(application).read(helper, n);
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
        (observedDepth, observedCaller) = CallStack.read(helper, n);
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
    fallback() external {
        assembly {
            switch calldataload(4)
            case 0 { return(0, 0) }
            case 1 { return(0, 32) }
            case 2 { return(0, 63) }
            case 3 { return(0, 65) }
            case 4 { return(0, 96) }
            case 5 {
                mstore(32, shl(160, 1))
                return(0, 64)
            }
            case 6 { return(0, 64) }
            case 7 { revert(0, 0) }
            case 8 { invalid() }
            case 9 { sstore(0, 1) }
            case 10 { return(0, 4096) }
            case 11 { return(0, 1000000) }
            default { return(0, 64) }
        }
    }
}
