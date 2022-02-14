// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./ITimeLock.sol";

contract TimeLock is ITimeLock {
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint newDelay);
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value,
        string signature,
        bytes data,
        uint eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value,
        string signature,
        bytes data,
        uint eta
    );
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value,
        string signature,
        bytes data,
        uint eta
    );

    uint public constant MIN_DELAY = 2 days;
    uint public constant MAX_DELAY = 30 days;
    //  Time period a tx is valid for execution after eta has elapsed.
    uint public constant GRACE_PERIOD = 14 days;

    address public admin;
    address public pendingAdmin;

    // Cool-off before a queued transaction is executed
    uint public delay;
    // Queued status of a transaction (txHash => tx status).
    mapping(bytes32 => bool) public queuedTransactions;

    constructor(uint _delay) {
        require(_delay >= MIN_DELAY, "delay < min");
        require(_delay <= MAX_DELAY, "delay > max");
        admin = msg.sender;
        delay = _delay;
    }

    receive() external payable {}

    /* ========== RESTRICTED FUNCTIONS ========== */
    modifier onlyTimeLock() {
        require(msg.sender == address(this), "not time lock");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    /**
     * @dev Sets the the new value of {delay}.
     * It allows setting of new delay value through queued tx by the admin
     *
     * Requirements:
     * - only current contract can call it
     * - `_delay` param must be within the min and max delay range
     */
    function setDelay(uint _delay) external onlyTimeLock {
        require(_delay >= MIN_DELAY, "delay < min");
        require(_delay <= MAX_DELAY, "delay > max");
        delay = _delay;
        emit NewDelay(_delay);
    }

    /**
     * @dev Sets the the new value of {_pendingAdmin}.
     * It allows setting of new pendingAdmin value through queued tx by the admin
     *
     * Requirements:
     * - only current admin can call it
     */
    function setPendingAdmin(address _pendingAdmin) external onlyAdmin {
        pendingAdmin = _pendingAdmin;
        emit NewPendingAdmin(_pendingAdmin);
    }

    /**
     * @dev Sets {pendingAdmin} to admin of current contract.
     *
     * Requirements:
     * - only callable by {pendingAdmin}
     */
    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "not pending admin");
        admin = msg.sender;
        pendingAdmin = address(0);
        emit NewAdmin(admin);
    }

    function _getTxHash(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }

    function getTxHash(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) external pure returns (bytes32) {
        return _getTxHash(target, value, signature, data, eta);
    }

    /**
     * @dev Queues a transaction by setting its status in {queuedTransactions} mapping.
     *
     * Requirements:
     * - only callable by {admin}
     * - `eta` must lie in future compared to delay referenced from current block
     */
    function queueTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) external onlyAdmin returns (bytes32 txHash) {
        require(eta >= block.timestamp + delay, "eta < now + delay");

        txHash = _getTxHash(target, value, signature, data, eta);
        require(!queuedTransactions[txHash], "queued");
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
    }

    /**
     * @dev Cancels a transaction by setting its status in {queuedTransactions} mapping.
     *
     * Requirements:
     * - only callable by {admin}
     */
    function cancelTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) external onlyAdmin {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);
        require(queuedTransactions[txHash], "not queued");
        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    /**
     * @dev Executes a transaction by making a low level call to its `target`.
     * The call reverts if the low-level call made to `target` reverts.
     *
     * Requirements:
     * - only callable by {admin}
     * - tx must already be queued
     * - current timestamp is ahead of tx's eta
     * - grace period associated with the tx must not have passed
     * - the low-level call to tx's `target` must not revert
     */
    function executeTransaction(
        address target,
        uint value,
        string calldata signature,
        bytes calldata data,
        uint eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);

        require(queuedTransactions[txHash], "not queued");
        require(block.timestamp >= eta, "timestamp < eta");
        require(
            block.timestamp <= eta + GRACE_PERIOD,
            "timestamp > grace period"
        );

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(
            callData
        );
        require(success, "tx reverted");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }
}
