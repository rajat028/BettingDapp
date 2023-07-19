// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "./Configs.sol";

interface IBettingProtocol {
    function addTeam(string memory name) external;

    function setTeamInActive(uint8 teamId) external;

    function setTeamToActive(uint8 teamId) external;

    function createBet(
        uint8 teamAId,
        uint8 teamBId,
        uint minBettingAmount
    ) external;

    function setBetToActive(uint betId) external;

    function setBetToInActive(uint betId) external;

    function pledgeFundsToBet(uint amount, uint betId, uint8 teamId) external;

    function setBetToCompleteAndTransferFundsToWinners(
        uint betId,
        uint8 teamId
    ) external;

    function getTotalAmountBettedOnABet(uint betId) external returns (uint);

    function getAllBetsByUsers() external returns (uint[] memory);

    function getBettorBetDetails(uint betId) external returns (uint, uint);

    function getBettorsOnTeam(
        uint betId,
        uint8 teamId
    ) external returns (address[] memory);

    function getContractAddress() external returns (address);
}
