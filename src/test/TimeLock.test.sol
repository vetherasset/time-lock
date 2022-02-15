// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "ds-test/test.sol";
import "./IHevm.sol";
import "./Receiver.sol";
import "../TimeLock.sol";

contract User {
    TimeLock private timeLock;

    constructor(address payable _timeLock) {
        timeLock = TimeLock(_timeLock);
    }

    function setPendingAdmin(address _admin) public {
        timeLock.setPendingAdmin(_admin);
    }

    function acceptAdmin() public {
        timeLock.acceptAdmin();
    }

    function queueTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) public {
        timeLock.queueTransaction(target, value, signature, data, eta);
    }

    function cancelTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) public {
        timeLock.cancelTransaction(target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) public {
        timeLock.cancelTransaction(target, value, signature, data, eta);
    }
}

uint constant DELAY = 2 weeks;

contract TimeLockTest is DSTest {
    IHevm private hevm;

    TimeLock private timeLock;
    User private user;
    Receiver private receiver;

    // queue inputs
    address private target;
    uint private constant value = 0;
    string private constant sig = "test(uint256)";
    uint private constant val = 999;
    bytes private constant data = abi.encode(val);
    uint private eta;

    function setUp() public {
        hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        timeLock = new TimeLock(DELAY);
        user = new User(payable(address(timeLock)));
        receiver = new Receiver();

        target = address(receiver);
        eta = block.timestamp + DELAY;
    }

    function testFail_setPendingAdmin_not_admin() public {
        user.setPendingAdmin(address(user));
    }

    function test_setPendingAdmin() public {
        timeLock.setPendingAdmin(address(user));
        assertEq(timeLock.pendingAdmin(), address(user));
    }

    function testFail_acceptAdmin_not_pending_admin() public {
        user.acceptAdmin();
    }

    function test_acceptPendingAdmin() public {
        timeLock.setPendingAdmin(address(user));
        user.acceptAdmin();

        assertEq(timeLock.pendingAdmin(), address(0));
        assertEq(timeLock.admin(), address(user));
    }

    function testFail_queueTransaction_not_admin() public {
        user.queueTransaction(
            target,
            value,
            sig,
            data,
            block.timestamp + DELAY
        );
    }

    function testFail_queueTransaction_eta() public {
        user.queueTransaction(target, value, sig, data, block.timestamp);
    }

    function test_queueTransaction() public {
        bytes32 txHash = timeLock.queueTransaction(
            target,
            value,
            sig,
            data,
            eta
        );

        assertEq(txHash, timeLock.getTxHash(target, value, sig, data, eta));
        assertTrue(timeLock.queuedTransactions(txHash));
    }

    function testFail_queueTransaction_queued() public {
        user.queueTransaction(target, value, sig, data, eta);
        user.queueTransaction(target, value, sig, data, eta);
    }

    function testFail_cancelTransaction_not_admin() public {
        timeLock.queueTransaction(target, value, sig, data, eta);
        user.cancelTransaction(target, value, sig, data, eta);
    }

    function testFail_cancelTransaction_not_queued() public {
        timeLock.cancelTransaction(target, value, sig, data, eta);
    }

    function test_cancelTransaction() public {
        bytes32 txHash = timeLock.queueTransaction(
            target,
            value,
            sig,
            data,
            eta
        );
        timeLock.cancelTransaction(target, value, sig, data, eta);
        assertTrue(!timeLock.queuedTransactions(txHash));
    }

    function testFail_executeTransaction_not_admin() public {
        timeLock.queueTransaction(target, value, sig, data, eta);
        user.executeTransaction(target, value, sig, data, eta);
    }

    function testFail_executeTransaction_not_queued() public {
        timeLock.executeTransaction(target, value, sig, data, eta);
    }

    function testFail_executeTransaction_eta() public {
        timeLock.queueTransaction(target, value, sig, data, eta);
        timeLock.executeTransaction(target, value, sig, data, eta);
    }

    function test_executeTransaction() public {
        bytes32 txHash = timeLock.queueTransaction(
            target,
            value,
            sig,
            data,
            eta
        );
        hevm.warp(eta);
        timeLock.executeTransaction(target, value, sig, data, eta);

        assertTrue(!timeLock.queuedTransactions(txHash));
        assertEq(receiver.val(), val);
    }

    function test_executeTransaction_send_eth() public {
        timeLock.queueTransaction(target, 1 ether, "", "", eta);
        hevm.warp(eta);
        timeLock.executeTransaction{value: 1 ether}(
            target,
            1 ether,
            "",
            "",
            eta
        );

        assertEq(address(receiver).balance, 1 ether);
    }

    function testFail_setDelay_not_time_lock() public {
        timeLock.setDelay(DELAY + 1);
    }

    function test_setDelay() public {
        timeLock.queueTransaction(
            address(timeLock),
            0,
            "setDelay(uint256)",
            abi.encode(DELAY + 1),
            eta
        );
        hevm.warp(eta);
        timeLock.executeTransaction(
            address(timeLock),
            0,
            "setDelay(uint256)",
            abi.encode(DELAY + 1),
            eta
        );

        assertEq(timeLock.delay(), DELAY + 1);
    }
}
