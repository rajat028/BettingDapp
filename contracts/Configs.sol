//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Configs {
    IERC20 bettingToken;
    address public owner;

    enum BetStatus {
        INACTIVE,
        ACTIVE,
        COMPLETED
    }

    uint public betCount;
    struct Bet {
        uint betId;
        uint8 teamAId;
        uint8 teamBId;
        uint minBetAmount;
        BetStatus betStatus;
        uint8 wininngTeam;
        uint amountBettedToTeamA;
        uint amountBettedToTeamB;
        mapping(uint8 => address[]) bettorsOnTeam;
        mapping(address => uint8) selectedTeam;
        mapping(address => uint) amountPledgedByBettor;
    }

    struct Team {
        uint8 teamId;
        string name;
        bool isActive;
    }

    Bet[] public bets;
    mapping(address => uint[]) userBets;

    uint8 public teamCount;
    Team[] public teams;
}
