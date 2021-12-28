// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title UnifiedLiquidityPool Contract
 */

contract RandomNumberConsumer is VRFConsumerBase, Ownable {
    using Address for address;

    bytes32 internal keyHash;
    uint256 internal fee;

    address public ULPAddress;

    bytes32 currentRequestID;

    mapping(bytes32 => uint256) requestToRandom;
    mapping(bytes32 => bool) hasReturned;

    /// @notice Event emitted when ULP address is changed
    event newULP(address ULP);

    /// @notice Event emitted when chainlink verified random number arrived.
    event randomNumberArrived(
        bool arrived,
        uint256 randomNumber,
        bytes32 batchID
    );

    modifier onlyULP() {
        require(ULPAddress == msg.sender, "RNG: Caller is not the ULP address");
        _;
    }

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Polygon(Matic) Mainnet
     * Chainlink VRF Coordinator address: 0x3d2341ADb2D31f1c5530cDC622016af293177AE0
     * LINK token address:                0xb0897686c545045aFc77CF20eC7A532E3120E0F1
     * Key Hash:                          0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da
     * Fee : 0.0001LINK
     */
    constructor(
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _fee
    )
        VRFConsumerBase(
            _vrfCoordinator, // VRF Coordinator
            _link // LINK Token
        )
    {
        keyHash = _keyHash;
        fee = _fee;
    }

    /**
     * @dev Public function to request randomness and returns request Id. This function can be called by only apporved games.
     */
    function requestRandomNumber() public onlyULP returns (bytes32 requestID) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "RandomNumberConsumer: Not enough LINK - fill contract with faucet"
        );

        uint256 prevRandomNumber = requestToRandom[currentRequestID];

        emit randomNumberArrived(false, prevRandomNumber, currentRequestID);

        currentRequestID = requestRandomness(keyHash, fee);
        hasReturned[currentRequestID] = false;

        return currentRequestID;
    }

    /**
     * @dev Callback function used by VRF Coordinator. This function sets new random number with unique request Id.
     * @param _randomness Random Number
     */
    function fulfillRandomness(bytes32 requestID, uint256 _randomness)
        internal
        override
    {
        requestToRandom[requestID] = _randomness;
        hasReturned[requestID] = true;
        emit randomNumberArrived(true, _randomness, requestID);
    }

    /**
     * @dev Public function to return verified random number. This function can be called by only ULP.
     * @param _reqeustId Batching Id of random number.
     */
    function getVerifiedRandomNumber(bytes32 _reqeustId)
        public
        view
        onlyULP
        returns (uint256)
    {
        require(
            hasReturned[_reqeustId] == true,
            "RandomNumberConsumer: Random number is not arrived yet"
        );
        return requestToRandom[_reqeustId];
    }

    /**
     * @dev Public function to set ULP address. This function can be called by only owner.
     * @param _ulpAddr Address of ULP
     */
    function setULPAddress(address _ulpAddr) public onlyOwner {
        require(
            _ulpAddr.isContract() == true,
            "RandomNumberConsumer: This is not a Contract Address"
        );
        ULPAddress = _ulpAddr;
        emit newULP(ULPAddress);
    }
}
