// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

contract Receiver {
    bytes public data;
    uint public val;

    receive() external payable {}

    function test(uint _val) external {
        data = msg.data;
        val = _val;
    }
}
