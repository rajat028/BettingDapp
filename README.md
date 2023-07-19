# Betting Dapp Readme

The Betting Dapp is a decentralized application (Dapp) that showcases a simple betting application with various functionalities on the Ethereum blockchain. This Dapp allows users to place bets on different teams for specific events and provides functionality for the owner to manage the teams and bets.

## Functionalities

The Betting Dapp provides the following functionalities accessible by the contract owner:

1. **Add Team (addTeam):** The contract owner can add new teams to the betting application. Each team represents a participant in a particular event.

2. **Set Team to Active (setTeamToActive):** The contract owner can set a team to active status, indicating that the team is available for bets.

3. **Set Team to InActive (setTeamInActive):** The contract owner can set a team to inactive status, indicating that the team is not available for bets.

4. **Create Bet (createBet):** The contract owner can create a new bet by specifying the participating teams and other relevant details.

5. **Complete Bet and Transfer Funds to Winners (setBetToCompleteAndTransferFundsToWinners):** After a bet is completed, the contract owner can mark the bet as complete and automatically transfer the funds to the winning bettors.

## View Functions

The Betting Dapp provides the following view functions accessible to all users:

1. **View All Teams (getAllTeams):** Users can view a list of all teams available for betting.

2. **Get Team Details (getTeamDetails):** Users can retrieve detailed information about a specific team, such as its name, status, and other relevant data.

3. **Get Bet Details (getBetDetails):** Users can view the details of a particular bet, including the teams participating, the total amount betted, and its status.

4. **Get Bettor Details on a Bet (getBettorBetDetails):** Users can check their own betting details for a specific bet, such as the amount they betted and whether they won or lost.

5. **Get Total Amount Betted on a Bet (getTotalAmountBettedOnABet):** Users can see the total amount of funds betted on a specific bet.

## User Functionalities

The Betting Dapp allows regular users to participate by providing the following functionality:

1. **Pledge Funds to Bet (pledgeFundsToBet):** Users can pledge a certain amount of cryptocurrency (e.g., Ether) to participate in a specific bet. By calling this function, they indicate their intention to bet on a particular team in a given event.
