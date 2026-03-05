// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVRFConsumerBase {
    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) external;
}

contract MockVRFCoordinatorV2 {
    uint256 private requestCounter;
    mapping(uint256 => address) public requestIdToConsumer;
    mapping(uint256 => bytes32) public requestIdToKeyHash;
    mapping(uint256 => uint64) public requestIdToSubId;

    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 indexed requestId,
        uint256 preSeed,
        uint64 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        address sender
    );

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId) {
        requestId = ++requestCounter;
        requestIdToConsumer[requestId] = msg.sender;
        requestIdToKeyHash[requestId] = keyHash;
        requestIdToSubId[requestId] = subId;

        emit RandomWordsRequested(
            keyHash,
            requestId,
            0,
            subId,
            minimumRequestConfirmations,
            callbackGasLimit,
            numWords,
            msg.sender
        );

        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) external {
        address consumer = requestIdToConsumer[requestId];
        require(consumer != address(0), "Request not found");

        IVRFConsumerBase(consumer).rawFulfillRandomWords(
            requestId,
            randomWords
        );
    }

    function getRequestCounter() external view returns (uint256) {
        return requestCounter;
    }
}
