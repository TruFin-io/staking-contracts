// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {IDelegateRegistry} from "../../contracts/interfaces/IDelegateRegistry.sol";
import {ITruStakePOL} from "../../contracts/interfaces/ITruStakePOL.sol";

contract DelegateRegistryState is BaseState {
    address public delegateRegistryAddress = makeAddr("delegateRegistry");

    function setUp() public virtual override {
        super.setUp(); // BaseState functionality
        staker.setDelegateRegistry(delegateRegistryAddress);
    }

    function mockSetGovernanceDelegation(
        string memory context,
        IDelegateRegistry.Delegation[] memory delegates,
        uint256 expirationTimestamp
    ) public {
        bytes memory callData =
            abi.encodeCall(IDelegateRegistry.setDelegation, (context, delegates, expirationTimestamp));
        vm.mockCall(delegateRegistryAddress, callData, "");
    }

    function testSetGovernanceDelegation() public {
        IDelegateRegistry.Delegation[] memory delegation = new IDelegateRegistry.Delegation[](1);

        delegation[0] = IDelegateRegistry.Delegation({delegate: bytes32(bytes20(uint160(alice))), ratio: 1});

        vm.expectEmit();
        emit ITruStakePOL.GovernanceDelegationSet("test", delegation, 123);

        vm.expectCall(
            address(delegateRegistryAddress),
            abi.encodeWithSelector(IDelegateRegistry.setDelegation.selector, "test", delegation, 123)
        );

        mockSetGovernanceDelegation("test", delegation, 123);
        staker.setGovernanceDelegation("test", delegation, 123);
    }

    function testSetGovernanceDelegationClearsDelegationWhenNoneSet() public {
        IDelegateRegistry.Delegation[] memory emptyDelegation = new IDelegateRegistry.Delegation[](0);
        IDelegateRegistry.Delegation[] memory delegation = new IDelegateRegistry.Delegation[](1);

        delegation[0] = IDelegateRegistry.Delegation({delegate: bytes32(bytes20(uint160(alice))), ratio: 1});

        // first set a governance delegation
        mockSetGovernanceDelegation("test", delegation, 123);
        staker.setGovernanceDelegation("test", delegation, 123);

        // then clear it
        vm.expectEmit();
        emit ITruStakePOL.GovernanceDelegationCleared("test");

        vm.expectCall(
            address(delegateRegistryAddress), abi.encodeWithSelector(IDelegateRegistry.clearDelegation.selector, "test")
        );

        staker.setGovernanceDelegation("test", emptyDelegation, 123);
    }
}
