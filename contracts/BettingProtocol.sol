// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract BettingProtocol {
    event TeamAdded(uint8 teamId);
    event TeamInActive(uint8 teamId);
    event BetCreated(
        uint betId,
        uint8 teamAId,
        uint8 teamBId,
        uint minBetAmount
    );
    event FundsPledgedToBet(uint betId, uint8 teamId, uint amount);
    event UnPledgedFundsFromBet(uint betId, address better, uint returnAmount);
    event BetCompleted(uint betId, uint8 winingTeam);

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

    function addTeam(string memory name) external onlyOwner {
        teamCount++;
        teams.push(Team(teamCount, name, true));
        emit TeamAdded(teamCount);
    }

    function setTeamInActive(uint8 teamId) external onlyOwner {
        require(teamId <= teams.length && teamId > 0, "Invalid team-id");
        Team storage team = teams[teamId - 1];
        require(team.isActive, "already inactive");
        team.isActive = false;
        emit TeamInActive(teamCount);
    }

    function createBet(
        uint8 teamAId,
        uint8 teamBId,
        uint minBettingAmount
    ) external onlyOwner {
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

    function setBetToActive(uint betId) external onlyOwner validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.betStatus == BetStatus.INACTIVE, "already active");
        bet.betStatus = BetStatus.ACTIVE;
    }

    function setBetToInActive(uint betId) external onlyOwner validBetId(betId) {
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
    ) external validBetId(betId) {
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

    function unPledgeFundsFromBet(uint betId) external validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.betStatus == BetStatus.ACTIVE, "bet inactive");

        uint amountBetted = bet.amountPledgedByBettor[msg.sender];
        require(amountBetted > 0, "no funds pledged");

        if (bet.selectedTeam[msg.sender] == bet.teamAId) {
            bet.amountBettedToTeamA -= amountBetted;
        } else {
            bet.amountBettedToTeamB -= amountBetted;
        }

        removeUserBet(betId);
        removeBettorFromBettedTeam(msg.sender, bet);

        bet.selectedTeam[msg.sender] = 0;
        bet.amountPledgedByBettor[msg.sender] = 0;
        uint returnAmount = amountBetted - (amountBetted * 10) / 100;
        bettingToken.transfer(msg.sender, returnAmount);

        emit UnPledgedFundsFromBet(betId, msg.sender, returnAmount);
    }

    function setBetToCompleteAndTransferFundsToWinners(
        uint betId,
        uint8 teamId
    ) external onlyOwner validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.betStatus == BetStatus.ACTIVE, "bet inactive");
        require(bet.wininngTeam == 0, "bet already completed");
        require(teamId != 0, "invalid teamId");

        uint8 winingTeam;
        uint totalAmountOnWiningTeam;
        uint totalAmountOnLossingTeam;
        address[] memory winners;

        if (teamId == bet.teamAId) {
            winingTeam = bet.teamAId;
            winners = bet.bettorsOnTeam[teamId];
            totalAmountOnWiningTeam = bet.amountBettedToTeamA;
            totalAmountOnLossingTeam = bet.amountBettedToTeamB;
        } else {
            winingTeam = bet.teamBId;
            winners = bet.bettorsOnTeam[teamId];
            totalAmountOnWiningTeam = bet.amountBettedToTeamB;
            totalAmountOnLossingTeam = bet.amountBettedToTeamA;
        }

        bet.wininngTeam = teamId;

        for (uint i = 0; i < winners.length; i++) {
            uint pledgedFunds = bet.amountPledgedByBettor[winners[i]];
            uint winAmount = pledgedFunds +
                ((pledgedFunds * totalAmountOnLossingTeam) /
                    totalAmountOnWiningTeam);
            bettingToken.transferFrom(winners[i], address(this), winAmount);
        }
        bet.betStatus = BetStatus.COMPLETED;
        emit BetCompleted(betId, bet.wininngTeam);
    }

    function getTotalAmountBettedOnABet(
        uint betId
    ) external view returns (uint) {
        return
            bets[betId].amountBettedToTeamA + bets[betId].amountBettedToTeamB;
    }

    function getAllBetsByUsers() external view returns (uint[] memory) {
        return userBets[msg.sender];
    }

    function removeUserBet(uint betId) internal {
        for (uint i = 0; i < userBets[msg.sender].length; i++) {
            if (userBets[msg.sender][i] == betId) {
                userBets[msg.sender][i] = userBets[msg.sender][i + 1];
            }
        }
        userBets[msg.sender].pop();
    }

    function changeTeamName(string memory newName, uint8 teamId) external {
        Team storage team = teams[teamId];
        team.name = newName;
    }

    function removeBettorFromBettedTeam(
        address bettor,
        Bet storage bet
    ) internal {
        uint8 teamId = bet.selectedTeam[msg.sender];
        for (uint i = 0; i < bet.bettorsOnTeam[teamId].length; i++) {
            if (bet.bettorsOnTeam[teamId][i] == bettor) {
                bet.bettorsOnTeam[teamId][i] = bet.bettorsOnTeam[
                    teamId
                ][i + 1];
            }
        }
        bet.bettorsOnTeam[teamId].pop();
    }

    function containsTeamId(uint8 teamId) internal view returns (bool) {
        for (uint i = 0; i < teams.length; i++) {
            if (teams[i].teamId == teamId) {
                return true;
            }
        }
        return false;
    }

    function getBettorBetDetails(
        uint betId
    ) external view returns (uint, uint) {
        Bet storage bet = bets[betId];
        return (
            bet.selectedTeam[msg.sender],
            bet.amountPledgedByBettor[msg.sender]
        );
    }

    function getBetDetails(
        uint betId
    ) external view returns (uint8, uint8, uint, BetStatus, uint8, uint, uint) {
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

    function getTotalNumberOfTeams() external view returns (uint) {
        return teams.length;
    }

    function getTeamDetails(uint teamId) external view returns (Team memory) {
        return teams[teamId];
    }

    function getBettorsOnTeam(
        uint betId,
        uint8 teamId
    ) external view returns (address[] memory) {
        Bet storage bet = bets[betId];
        return bet.bettorsOnTeam[teamId];
    }

    function teamIdIndex(uint teamId) internal pure returns (uint) {
        return teamId - 1;
    }

    function getContractAddress() external view returns (address) {
        return address(this);
    }

    function getSelectedTeamByBettor(uint betId) external view returns (uint) {
        Bet storage bet = bets[betId];
        return bet.selectedTeam[msg.sender];
    }

    function getTotalAmountPledgedByBettor(
        uint betId
    ) external view returns (uint) {
        Bet storage bet = bets[betId];
        return bet.amountPledgedByBettor[msg.sender];
    }
}
