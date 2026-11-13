// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {ERC20ReadPolicy} from "../src/access/ERC20ReadPolicy.sol";
import {IDomainAccessPolicy} from "../src/interfaces/IDomainAccessPolicy.sol";

contract ERC20ReadPolicyTest {
    bytes4 private constant BALANCE_OF = 0x70a08231;
    bytes4 private constant ALLOWANCE = 0xdd62ed3e;

    ERC20ReadPolicy internal policy;

    function setUp() public {
        policy = new ERC20ReadPolicy();
    }

    function testFuzzBalancesAreOnlyReadableByTheirHolder(address caller, address holder, address context) public view {
        bytes memory data = abi.encodeWithSignature("balanceOf(address)", holder);
        assert(policy.canCall(caller, context, data) == (caller == holder));
        assert(policy.canCall(holder, context, data));
    }

    function testFuzzAllowancesAreOnlyReadableByTheirParties(
        address caller,
        address owner,
        address spender,
        address context
    ) public view {
        bytes memory data = abi.encodeWithSignature("allowance(address,address)", owner, spender);
        assert(policy.canCall(caller, context, data) == (caller == owner || caller == spender));
        assert(policy.canCall(owner, context, data));
        assert(policy.canCall(spender, context, data));
    }

    function testTruncatedReadArgumentsAreDenied() public view {
        for (uint256 length; length < 32; ++length) {
            assert(!policy.canCall(address(0), address(this), abi.encodePacked(BALANCE_OF, new bytes(length))));
        }
        for (uint256 length; length < 64; ++length) {
            assert(!policy.canCall(address(0), address(this), abi.encodePacked(ALLOWANCE, new bytes(length))));
        }
    }

    function testFuzzNonCanonicalBalanceAddressReverts(address holder, uint96 highBits) public view {
        uint256 padding = uint256(highBits == 0 ? 1 : highBits) << 160;
        _assertReverts(holder, abi.encodePacked(BALANCE_OF, padding | uint256(uint160(holder))));
    }

    function testFuzzNonCanonicalAllowanceAddressesRevert(address owner, address spender, uint96 highBits) public view {
        uint256 padding = uint256(highBits == 0 ? 1 : highBits) << 160;
        _assertReverts(
            spender, abi.encodePacked(ALLOWANCE, padding | uint256(uint160(owner)), uint256(uint160(spender)))
        );
        _assertReverts(owner, abi.encodePacked(ALLOWANCE, uint256(uint160(owner)), padding | uint256(uint160(spender))));
    }

    function testFuzzTrailingCalldataPreservesReadRules(
        address caller,
        address owner,
        address spender,
        bytes memory suffix
    ) public view {
        bytes memory balance = bytes.concat(abi.encodeWithSelector(BALANCE_OF, owner), suffix);
        bytes memory allowance = bytes.concat(abi.encodeWithSelector(ALLOWANCE, owner, spender), suffix);
        assert(policy.canCall(caller, address(this), balance) == (caller == owner));
        assert(policy.canCall(owner, address(this), balance));
        assert(policy.canCall(caller, address(this), allowance) == (caller == owner || caller == spender));
        assert(policy.canCall(owner, address(this), allowance));
        assert(policy.canCall(spender, address(this), allowance));
    }

    function testShortCalldataIsAllowed() public view {
        assert(policy.canCall(address(1), address(this), hex""));
        assert(policy.canCall(address(1), address(this), hex"70"));
        assert(policy.canCall(address(1), address(this), hex"70a0"));
        assert(policy.canCall(address(1), address(this), hex"70a082"));
    }

    function testFuzzOtherSelectorsAreAllowed(address caller, address context, bytes4 selector, bytes memory arguments)
        public
        view
    {
        if (selector == BALANCE_OF || selector == ALLOWANCE) return;
        assert(policy.canCall(caller, context, abi.encodePacked(selector, arguments)));
    }

    function testMetadataAndTokenOperationsAreAllowed() public view {
        address caller = address(1);
        assert(policy.canCall(caller, address(this), abi.encodeWithSignature("name()")));
        assert(policy.canCall(caller, address(this), abi.encodeWithSignature("symbol()")));
        assert(policy.canCall(caller, address(this), abi.encodeWithSignature("decimals()")));
        assert(policy.canCall(caller, address(this), abi.encodeWithSignature("totalSupply()")));
        assert(policy.canCall(caller, address(this), abi.encodeWithSignature("approve(address,uint256)", caller, 10)));
        assert(policy.canCall(caller, address(this), abi.encodeWithSignature("transfer(address,uint256)", caller, 10)));
        assert(
            policy.canCall(
                caller,
                address(this),
                abi.encodeWithSignature("transferFrom(address,address,uint256)", caller, caller, 10)
            )
        );
        assert(policy.canCall(caller, address(this), abi.encodeWithSignature("mint(address,uint256)", caller, 10)));
        assert(policy.canCall(caller, address(this), abi.encodeWithSignature("burn(address,uint256)", caller, 10)));
    }

    function testReadsReturnCanonicalVerdictsWithinGasBudget() public view {
        address owner = address(1);
        address spender = address(2);
        bytes memory balance = abi.encodeWithSelector(BALANCE_OF, owner);
        bytes memory allowance = abi.encodeWithSelector(ALLOWANCE, owner, spender);
        _assertVerdictWithinGasBudget(owner, balance, true);
        _assertVerdictWithinGasBudget(spender, balance, false);
        _assertVerdictWithinGasBudget(owner, allowance, true);
        _assertVerdictWithinGasBudget(spender, allowance, true);
        _assertVerdictWithinGasBudget(address(3), allowance, false);
    }

    function _assertVerdictWithinGasBudget(address caller, bytes memory data, bool expected) internal view {
        (bool success, bytes memory result) = address(policy).staticcall{gas: 10_000}(
            abi.encodeWithSignature("canCall(address,address,bytes)", caller, address(this), data)
        );
        assert(success && result.length == 32);
        assert(abi.decode(result, (uint256)) == (expected ? 1 : 0));
    }

    function _assertReverts(address caller, bytes memory data) internal view {
        (bool success,) = address(policy)
            .staticcall(abi.encodeWithSelector(IDomainAccessPolicy.canCall.selector, caller, address(this), data));
        assert(!success);
    }
}
