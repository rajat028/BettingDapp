// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./IBettingProtocol.sol";
import "./Configs.sol";

contract BettingProtocol is IBettingProtocol, Configs {
    event TeamAdded(uint8 teamId);
    event TeamInActive(uint8 teamId);
    event TeamActive(uint8 teamId);
    event BetCreated(
        uint betId,
        uint8 teamAId,
        uint8 teamBId,
        uint minBetAmount
    );
    event FundsPledgedToBet(uint betId, uint8 teamId, uint amount);
    event UnPledgedFundsFromBet(uint betId, address bettor, uint returnAmount);
    event BetCompleted(uint betId, uint8 winingTeam);

    constructor(IERC20 _bettingToken) {
        owner = msg.sender;
        bettingToken = _bettingToken;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validBetId(uint betId) {
        require(betId < bets.length, "invalid bet id");
        _;
    }

    function addTeam(string memory name) external override onlyOwner {
        teamCount++;
        teams.push(Team(teamCount, name, true));
        emit TeamAdded(teamCount);
    }

    function setTeamInActive(uint8 teamId) external override onlyOwner {
        require(teamId <= teams.length && teamId > 0, "Invalid team-id");
        Team storage team = teams[teamId - 1];
        require(team.isActive, "already inactive");
        team.isActive = false;
        emit TeamInActive(teamCount);
    }

    function setTeamToActive(uint8 teamId) external override onlyOwner {
        require(teamId <= teams.length && teamId > 0, "Invalid team-id");
        Team storage team = teams[teamId - 1];
        require(!team.isActive, "already active");
        team.isActive = true;
        emit TeamActive(teamCount);
    }

    function createBet(
        uint8 teamAId,
        uint8 teamBId,
        uint minBettingAmount
    ) external override onlyOwner {
        require(teamAId != teamBId, "same teams");
        require(minBettingAmount > 0, "Invalid amount");
        require(teamAId <= teams.length && teamAId > 0, "Invalid teamAId");
        require(teamBId <= teams.length && teamBId > 0, "Invalid teamBId");
        require(
            teams[teamIdIndex(teamAId)].isActive &&
                teams[teamIdIndex(teamBId)].isActive,
            "team's inactive"
        );
        Bet storage bet = bets.push();
        bet.betId = betCount;
        bet.teamAId = teamAId;
        bet.teamBId = teamBId;
        bet.minBetAmount = minBettingAmount;
        bet.betStatus = BetStatus.INACTIVE;

        emit BetCreated(betCount, teamAId, teamBId, minBettingAmount);
        betCount++;
    }

    function setBetToActive(
        uint betId
    ) external override onlyOwner validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.betStatus == BetStatus.INACTIVE, "already active");
        bet.betStatus = BetStatus.ACTIVE;
    }

    function setBetToInActive(
        uint betId
    ) external override onlyOwner validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.betStatus == BetStatus.ACTIVE, "bet already inactive");
        require(
            bet.amountBettedToTeamA + bet.amountBettedToTeamB == 0,
            "bettors already betted"
        );
        bet.betStatus = BetStatus.INACTIVE;
    }

    function pledgeFundsToBet(
        uint amount,
        uint betId,
        uint8 teamId
    ) external override validBetId(betId) {
        Bet storage bet = bets[betId];
        require(
            teamId > 0 && (teamId == bet.teamAId || teamId == bet.teamBId),
            "invalid team-id"
        );
        require(bet.betStatus == BetStatus.ACTIVE, "bet inactive");
        require(amount >= bet.minBetAmount, "invalid bet amount");
        require(
            bet.selectedTeam[msg.sender] != teamId,
            "invalid team/already betted"
        );

        bettingToken.transferFrom(msg.sender, address(this), amount);
        bet.selectedTeam[msg.sender] = teamId;
        if (bet.teamAId == teamId) {
            bet.amountBettedToTeamA += amount;
        } else {
            bet.amountBettedToTeamB += amount;
        }
        bet.bettorsOnTeam[teamId].push(msg.sender);
        bet.amountPledgedByBettor[msg.sender] += amount;

        userBets[msg.sender].push(betId);
        emit FundsPledgedToBet(betId, teamId, amount);
    }

    function setBetToCompleteAndTransferFundsToWinners(
        uint betId,
        uint8 teamId
    ) external override onlyOwner validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.wininngTeam == 0, "team already won");
        require(bet.betStatus == BetStatus.ACTIVE, "bet inactive");
        require(
            teamId != 0 && (teamId == bet.teamAId || teamId == bet.teamBId),
            "invalid teamId"
        );

        address[] memory winners = bet.bettorsOnTeam[teamId];
        uint totalAmountOnWiningTeam;
        uint totalAmountOnLossingTeam;

        if (teamId == bet.teamAId) {
            totalAmountOnWiningTeam = bet.amountBettedToTeamA;
            totalAmountOnLossingTeam = bet.amountBettedToTeamB;
        } else {
            totalAmountOnWiningTeam = bet.amountBettedToTeamB;
            totalAmountOnLossingTeam = bet.amountBettedToTeamA;
        }

        bet.wininngTeam = teamId;
        uint winnersCount = winners.length;

        for (uint i = 0; i < winnersCount; i++) {
            uint pledgedFunds = bet.amountPledgedByBettor[winners[i]];
            uint winAmount = pledgedFunds +
                ((pledgedFunds * totalAmountOnLossingTeam) /
                    totalAmountOnWiningTeam);
            bettingToken.transfer(winners[i], winAmount);
        }
        bet.betStatus = BetStatus.COMPLETED;
        emit BetCompleted(betId, bet.wininngTeam);
    }

    function getTotalAmountBettedOnABet(
        uint betId
    ) external view override returns (uint) {
        return
            bets[betId].amountBettedToTeamA + bets[betId].amountBettedToTeamB;
    }

    function getAllBetsByUsers() external view returns (uint[] memory) {
        return userBets[msg.sender];
    }

    function getBettorBetDetails(
        uint betId
    ) external view override returns (uint, uint) {
        Bet storage bet = bets[betId];
        return (
            bet.selectedTeam[msg.sender],
            bet.amountPledgedByBettor[msg.sender]
        );
    }

    function getBettorsOnTeam(
        uint betId,
        uint8 teamId
    ) external view override returns (address[] memory) {
        Bet storage bet = bets[betId];
        return bet.bettorsOnTeam[teamId];
    }

    function getContractAddress() external view override returns (address) {
        return address(this);
    }

    function getAllTeams() external view returns (Team[] memory) {
        return teams;
    }

    function getBetDetails(
        uint betId
    )
        external
        view
        returns (uint8, uint8, uint, BetStatus, uint8, uint, uint)
    {
        Bet storage bet = bets[betId];
        return (
            bet.teamAId,
            bet.teamBId,
            bet.minBetAmount,
            bet.betStatus,
            bet.wininngTeam,
            bet.amountBettedToTeamA,
            bet.amountBettedToTeamB
        );
    }

    function getTeamDetails(
        uint teamId
    ) external view returns (Team memory) {
        return teams[teamIdIndex(teamId)];
    }

    function teamIdIndex(uint teamId) internal pure returns (uint) {
        return teamId - 1;
    }
}
