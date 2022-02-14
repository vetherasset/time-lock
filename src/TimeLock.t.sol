// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./TimeLock.sol";

contract TimeLockTest is DSTest {
    TimeLock lock;

    function setUp() public {
        lock = new TimeLock();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
