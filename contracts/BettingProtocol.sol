// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract BettingProtocol {
    event TeamAdded(uint8 teamId);
    event TeamSetToInActive(uint8 teamId);
    event BetCreated(
        uint betId,
        uint8 teamAId,
        uint8 teamBId,
        uint minBetAmount
    );
    event FundPledgedToBet(uint betId, uint8 teamId, uint amount);
    event UnPledgedFundsFromBet(uint betId, address better, uint returnAmount);
    event BetCompleted(uint betId, uint8 winingTeam);

    IERC20 bettingToken;
    address public owner;

    uint public betCount;
    struct Bet {
        uint betId;
        uint8 teamAId;
        uint8 teamBId;
        uint minBetAmount;
        bool isActive;
        uint8 wininngTeam;
        uint amountBettedToTeamA;
        uint amountBettedToTeamB;
        mapping(uint8 => address[]) bettorsOptedForTeam;
        mapping(address => uint8) selectedTeam;
        mapping(address => uint) amountBettedOnSelectedTeamByBettor;
    }

    struct Team {
        uint8 teamId;
        string name;
        bool isActive;
    }

    Bet[] public bets;
    mapping(address => uint[]) userBets;

    uint8 teamCount;
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
        require(!containsTeamId(teamCount), "team already present");
        teamCount++;
        teams.push(Team(teamCount, name, true));
        emit TeamAdded(teamCount);
    }

    function setTeamInActive(uint8 teamId) external onlyOwner {
        require(teamId <= teams.length, "Invalid team-id");
        Team storage team = teams[teamId];
        team.isActive = false;
        emit TeamSetToInActive(teamCount);
    }

    function createBet(
        uint8 teamAId,
        uint8 teamBId,
        uint minBettingAmount
    ) external {
        require(
            containsTeamId(teamAId) && containsTeamId(teamBId),
            "team ids invalid"
        );
        require(minBettingAmount > 0, "Invalid amount");
        Bet storage bet = bets.push();
        bet.betId = betCount;
        bet.teamAId = teamAId;
        bet.teamBId = teamBId;
        bet.minBetAmount = minBettingAmount;
        bet.isActive = false;

        emit BetCreated(betCount, teamAId, teamBId, minBettingAmount);
        betCount++;
    }

    function setBetToActive(uint betId) external onlyOwner validBetId(betId) {
        Bet storage bet = bets[betId];
        require(!bet.isActive, "already active");
        bet.isActive = true;
    }

    function setBetToInactive(uint betId) external onlyOwner validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.isActive, "bet not active");
        bet.isActive = false;
    }

    function pledgeFundsToBet(
        uint amount,
        uint betId,
        uint8 teamId
    ) external validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.isActive, "bet inactive");
        require(amount >= bet.minBetAmount, "invalid bet amount");
        require(
            bet.selectedTeam[msg.sender] == 0 ||
                bet.selectedTeam[msg.sender] == teamId,
            "already betted on this"
        );

        bettingToken.transferFrom(msg.sender, address(this), amount);
        bet.selectedTeam[msg.sender] = teamId;
        if (bet.teamAId == teamId) {
            bet.amountBettedToTeamA += amount;
        } else {
            bet.amountBettedToTeamB += amount;
        }
        bet.bettorsOptedForTeam[teamId].push(msg.sender);
        bet.amountBettedOnSelectedTeamByBettor[msg.sender] += amount;

        userBets[msg.sender].push(betId);
        emit FundPledgedToBet(betId, teamId, amount);
    }

    function unPledgeFundsFromBet(uint betId) external validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.isActive, "bet inactive");

        uint amountBetted = bet.amountBettedOnSelectedTeamByBettor[msg.sender];
        require(amountBetted > 0, "no funds pledged");

        if (bet.selectedTeam[msg.sender] == bet.teamAId) {
            bet.amountBettedToTeamA -= amountBetted;
        } else {
            bet.amountBettedToTeamB -= amountBetted;
        }

        removeUserBet(betId);
        removeBettorFromBettedTeam(msg.sender, bet);

        bet.selectedTeam[msg.sender] = 0;
        bet.amountBettedOnSelectedTeamByBettor[msg.sender] = 0;
        uint returnAmount = amountBetted - (amountBetted * 10) / 100;
        bettingToken.transfer(msg.sender, returnAmount);

        emit UnPledgedFundsFromBet(betId, msg.sender, returnAmount);
    }

    function setBetToCompleteAndTransferFundsToWinners(
        uint betId,
        uint8 teamId
    ) external validBetId(betId) {
        Bet storage bet = bets[betId];
        require(bet.isActive, "bet inactive");
        require(bet.wininngTeam == 0, "bet already completed");
        require(teamId != 0, "invalid teamId");

        uint8 winingTeam;
        uint totalAmountOnWiningTeam;
        uint totalAmountOnLossingTeam;
        address[] memory winners;

        if (teamId == bet.teamAId) {
            winingTeam = bet.teamAId;
            winners = bet.bettorsOptedForTeam[teamId];
            totalAmountOnWiningTeam = bet.amountBettedToTeamA;
            totalAmountOnLossingTeam = bet.amountBettedToTeamB;
        } else {
            winingTeam = bet.teamBId;
            winners = bet.bettorsOptedForTeam[teamId];
            totalAmountOnWiningTeam = bet.amountBettedToTeamB;
            totalAmountOnLossingTeam = bet.amountBettedToTeamA;
        }

        bet.wininngTeam = teamId;

        for (uint i = 0; i < winners.length; i++) {
            uint pledgedFunds = bet.amountBettedOnSelectedTeamByBettor[
                winners[i]
            ];
            uint winAmount = pledgedFunds +
                ((pledgedFunds * totalAmountOnLossingTeam) /
                    totalAmountOnWiningTeam);
            bettingToken.transferFrom(winners[i], address(this), winAmount);
        }
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
        for (uint i = 0; i < bet.bettorsOptedForTeam[teamId].length; i++) {
            if (bet.bettorsOptedForTeam[teamId][i] == bettor) {
                bet.bettorsOptedForTeam[teamId][i] = bet.bettorsOptedForTeam[
                    teamId
                ][i + 1];
            }
        }
        bet.bettorsOptedForTeam[teamId].pop();
    }

    function containsTeamId(uint8 teamId) internal view returns (bool) {
        for (uint i = 1; i <= teams.length; i++) {
            if (teams[i].teamId == teamId) {
                return true;
            }
        }
        return false;
    }

    function getBetDetails(
        uint betId
    ) external view returns (uint8, uint8, uint, bool, uint8, uint, uint) {
        Bet storage bet = bets[betId];
        return (
            bet.teamAId,
            bet.teamBId,
            bet.minBetAmount,
            bet.isActive,
            bet.wininngTeam,
            bet.amountBettedToTeamA,
            bet.amountBettedToTeamB
        );
    }

    function getBettorsOnTeam(
        uint betId,
        uint8 teamId
    ) external view returns (address[] memory) {
        Bet storage bet = bets[betId];
        return bet.bettorsOptedForTeam[teamId];
    }
}
