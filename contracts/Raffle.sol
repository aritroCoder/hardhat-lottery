// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

error Raffle__NotEnoughEthEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/**@title A sample Raffle Contract
 * @author Aritra Bhaduri
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /* Type declarations*/
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // state variables
    uint256 private immutable i_entranceFee; // global variable so storage
    address payable[] private s_players; // array in storage
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callBackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    // Lottery variables
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callBackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp; // block is a global variable always available.
        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthEntered();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        /**
         * Few things to note:
         * 1. When some money is sent calling the enterRaffle() function, the sender gets added as a player.
         * 2. We cannot store the address of the player directly in the array by calling
         * ```s_players.push(msg.sender)```
         * We need to typecast the address into a payable address, and then store in the array.
         */
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev we wont be using checkData as a variable so commented checkData to avoid unused var warnings.
     * This is the function that the Chainlink Keeper nodes call
     * They look for the 'UpkeepNeeded' to return true
     * The following should be true in order to return true
     * 1. The time interval should have passed
     * 2. The should have at least one player, and have some ETH
     * 3. Our subscription is funded with LINK
     * 4. The lottery should be in an 'open' state
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public override returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && hasPlayers && hasBalance && timePassed);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // request the random number
        // do something with it
        // 2 transaction process
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callBackGasLimit,
            NUM_WORDS
        );
        // This is redundant as the call to vrfCoordinatorV2 emits an event with the requestId
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // reset the players array
        s_lastTimeStamp = block.timestamp;

        // from https://ethereum.stackexchange.com/questions/118859/what-is-returned-from-msg-sender-callvalue-amount
        //(bool success, bytes memory data) = msg.sender.call{value: amount}("");

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    // View / Pure functions
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState){
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256){
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256){
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256){
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256){
        return i_interval;
    }
}
