const { expect } = require("chai")
const { ethers } = require("hardhat")


async function approveAndAllotFunds(bettors, amount) {
    const bettingContractAddress = await bettingContract.getContractAddress()
	for (let i = 0; i < bettors.length; i++) {
		await bettingToken.transfer(bettors[i].address, amount)
		await bettingToken.connect(bettors[i]).approve(bettingContractAddress, amount)
	}
}

async function addTeamsAndGetTeamIds() {
    let teamName1 = "Team 1"
    let teamName2 = "Team 2"
	await bettingContract.addTeam(teamName1)
	let teamAId = await bettingContract.teamCount()
	await bettingContract.addTeam(teamName2)
	let teamBId = await bettingContract.teamCount()
    return [teamAId, teamBId];
}

async function createBetAndGetTeamsAndBetId() {
    const minBetAmount = 10
    const [teamAId , teamBId] = await addTeamsAndGetTeamIds()
    await bettingContract.createBet(teamAId, teamBId, minBetAmount)
    const betId = (await bettingContract.betCount()) - BigInt(1)
    return [betId, teamAId, teamBId]
}

async function verifyAmountBettedOnTeams(teamTotalAmountBefore, teamTotalAmountAfter, amount) {
    expect(teamTotalAmountAfter).greaterThan(teamTotalAmountBefore)
	expect(teamTotalAmountAfter).eq(teamTotalAmountBefore + BigInt(amount))
}

function verifyBettorDetailsOnBet(bettorDetailsBefore, bettorDetailsAfter, teamId, amount) {
	const [, bettedAmountBefore] = bettorDetailsBefore
	const [selectedTeamIdAfter, bettedAmountAfter] = bettorDetailsAfter
	expect(selectedTeamIdAfter).eq(teamId)
	expect(bettedAmountAfter).greaterThan(bettedAmountBefore)
	expect(bettedAmountAfter).eq(bettedAmountBefore + BigInt(amount) )
}

function verifyBettorsOnTeam(bettorsCountBefore, bettorsCountAfter, bettorCount) {
	expect(bettorsCountAfter).greaterThan(bettorsCountBefore)
	expect(bettorsCountAfter).eq(bettorsCountBefore + bettorCount)
}
 
async function verifyBettorsBalance(winners, lossers) {
	for(let i =0; i <winners.length; i++ ) {
		const winnerBalance  = await bettingToken.balanceOf(winners[i].address)
		expect(winnerBalance).eq(20)
	}

	for(let i =0; i <lossers.length; i++ ) {
		expect(await bettingToken.balanceOf(bettor1.address)).eq(0)
	}
}

async function pledgeFundsToBetByBettors(amount, betId, teamAId, teamBId, team1Bettors, team2Bettors) {
	for(let i = 0; i < team1Bettors.length; i++) {
		await bettingContract.connect(team1Bettors[i]).pledgeFundsToBet(amount, betId, teamAId)
	}

	for(let i = 0; i < team2Bettors.length; i++) {
		await bettingContract.connect(team2Bettors[i]).pledgeFundsToBet(amount, betId, teamBId)
	}
}

describe("Betting Protocol", () => {
    let teamName1 = "Team 1"
    let teamName2 = "Team 2"
	beforeEach(async () => {
		;[owner, bettor1, bettor2, bettor3, bettor4, _] = await ethers.getSigners()

		bettingToken = await ethers.deployContract("BettingToken");

		BettingProtocol = await ethers.getContractFactory("BettingProtocol")
		bettingContract = await BettingProtocol.deploy(bettingToken)
	})

    describe("Owner Operations", () => {
		it("should assign correct values in constructor", async () => {
			expect(await bettingContract.owner()).equal(owner.address)
		})

        it("should throw error addTeam called by non-owner", async() => {
            await expect(bettingContract.connect(bettor1).addTeam(teamName1)).to.be.revertedWith(
				"Not owner"
			)
        })

        it("should be able to add team by owner only", async() => {
            // Given
            const teamCountBefore = await bettingContract.teamCount();

            // When
            await bettingContract.addTeam(teamName1)

            // Then
            const teamCountAfter = await bettingContract.teamCount();
            expect(teamCountAfter).greaterThan(teamCountBefore)
            expect(teamCountAfter).eq(teamCountBefore + BigInt(1))
            
            const team = await bettingContract.teams(teamCountBefore);
            expect(team.teamId).eq(1)  
            expect(team.name).eq(teamName1)  
            expect(team.isActive).eq(true)  
        })

        it("should emit TeamAdded Event with correct arguments when new team added", async () => {
			// Given
			const teamCountBefore = await bettingContract.teamCount()

			await expect(bettingContract.addTeam(teamName1))
				.to.emit(bettingContract, "TeamAdded")
				.withArgs(teamCountBefore + BigInt(1))
		})

        it("should throw error when team set to Inactive by non-owner", async () => {
			// Given
			await bettingContract.addTeam(teamName1)
            const teamCount = await bettingContract.teamCount();

			await expect(
				bettingContract.connect(bettor1).setTeamInActive(teamCount)
			).to.be.revertedWith("Not owner")
		})

        it("should throw error when team set to Inactive with invalid team-id", async () => {
			// Given
			await bettingContract.addTeam(teamName1)
            const teamId = (await bettingContract.teamCount()) + BigInt(1)

			await expect(
				bettingContract.setTeamInActive(teamId)
			).to.be.revertedWith("Invalid team-id")
		})

        it("should throw error when team set to Inactive where team already inactive", async () => {
			// Given
			await bettingContract.addTeam(teamName1)
            const teamId = await bettingContract.teamCount()
            await bettingContract.setTeamInActive(teamId)

            // When & Then
			await expect(
				bettingContract.setTeamInActive(teamId)
			).to.be.revertedWith("already inactive")
		})

        it("should emit TeamInActive when team set to In-active", async () => {
            //Given
			await bettingContract.addTeam("teamName1")
            const teamId1 = await bettingContract.teamCount()

			// When
			await bettingContract.setTeamInActive(teamId1)

			// Then
			const teamDetails = await bettingContract.getTeamDetails(teamId1)
			expect(teamDetails[2]).eq(false)


            await bettingContract.addTeam("teamName2")
            const teamId2 = await bettingContract.teamCount()

            // When & Then
			await expect(bettingContract.setTeamInActive(teamId2))
				.to.emit(bettingContract, "TeamInActive")
				.withArgs(teamId2)
		})

		it("should emit TeamActive when team set to Active", async () => {
            //Given
			await bettingContract.addTeam("teamName1")
            const teamId1 = await bettingContract.teamCount()
			await bettingContract.setTeamInActive(teamId1)

			// When
			await bettingContract.setTeamToActive(teamId1)

			// Then
			const teamDetails = await bettingContract.getTeamDetails(teamId1)
			expect(teamDetails[2]).eq(true)


            await bettingContract.addTeam("teamName2")
            const teamId2 = await bettingContract.teamCount()
			await bettingContract.setTeamInActive(teamId2)

            // When & Then
			await expect(bettingContract.setTeamToActive(teamId2))
				.to.emit(bettingContract, "TeamActive")
				.withArgs(teamId2)
		})

        describe("\n Bet Operations", () => {

            it("shoukd throw error when createBet gets called  by non-owner", async() => {
                // Given
                const teamAId = 1;
                const teaBId = 2;
                const minBetAmount = 10;
                
                // When & Then
                await expect(
					bettingContract.connect(bettor1).createBet(teamAId, teaBId, minBetAmount)
				).to.be.revertedWith("Not owner")
            })

            it("shoukd throw error if same teams bet created", async() => {
				// Given
				const minBetAmount = 10
				await bettingContract.addTeam(teamName1)
				let teamAId = await bettingContract.teamCount()

				// When & Then
				await expect(
					bettingContract.createBet(teamAId, teamAId, minBetAmount)
				).to.be.revertedWith("same teams")
			})

            it("should throw error when teamIds are invalid", async() => {
                // Given
                let [teamAId, teamBId] = await addTeamsAndGetTeamIds()
                teamAId = (await bettingContract.teamCount()) + BigInt(2)
                const minBetAmount = 10;
                
                // When & Then
                await expect(
					bettingContract.createBet(teamAId, teamBId, minBetAmount)
				).to.be.revertedWith("Invalid teamAId")

                teamAId = await bettingContract.teamCount()
                teamBId = (await bettingContract.teamCount()) + BigInt(2)

                // When & Then
                await expect(
					bettingContract.createBet(teamAId, teamBId, minBetAmount)
				).to.be.revertedWith("Invalid teamBId")
            })

            it("should throw error when one or both teams are inactive", async() => {
                // Given
                const minBetAmount = 10;
                const [teamAId, teamBId] = await addTeamsAndGetTeamIds()
                
                await bettingContract.setTeamInActive(teamAId);

                // When & Then
                await expect(
					bettingContract.createBet(teamAId, teamBId, minBetAmount)
				).to.be.revertedWith("team's inactive")

                await bettingContract.setTeamInActive(teamBId);

                await expect(
					bettingContract.createBet(teamAId, teamBId, minBetAmount)
				).to.be.revertedWith("team's inactive")
            })

            it("should throw error when betting amount is 0", async() => {
                // Given
                const minBetAmount = 0;
                const [teamAId, teamBId] = await addTeamsAndGetTeamIds()

                // When & Then
                await expect(
					bettingContract.createBet(teamAId, teamBId, minBetAmount)
				).to.be.revertedWith("Invalid amount")
            })

            it("should be able to create bet", async () => {
				// Given
				const [teamAId, teamBId] = await addTeamsAndGetTeamIds()
                const minBetAmount = 10

				const betCountBefore = await bettingContract.betCount()

				// When
				await bettingContract.createBet(teamAId, teamBId, minBetAmount)

				// Then
				const betCountAfter = await bettingContract.betCount()
				expect(betCountAfter).greaterThan(betCountBefore)
				expect(betCountAfter).eq(betCountBefore + BigInt(1))

				const bet = await bettingContract.bets(0)
				expect(bet.teamAId).eq(teamAId)
				expect(bet.teamBId).eq(teamBId)
				expect(bet.minBetAmount).eq(minBetAmount)
				expect(bet.betStatus).eq(0)
			})

            it("should not be able to set bet active by non-owner", async () => {
				// Given
				const [betId,,]  = await createBetAndGetTeamsAndBetId()

				//when & Then
				await expect(
					bettingContract.connect(bettor1).setBetToActive(betId)
				).to.be.revertedWith("Not owner")
			})

            it("should not set bet status active if provided invalid betId", async () => {
                // Given
                let [betId,,]  = await createBetAndGetTeamsAndBetId()
				betId = betId + BigInt(1)

                //when & Then
                await expect(
					bettingContract.setBetToActive(betId)
				).to.be.revertedWith("invalid bet id")
            })

            it("should not set bet status active if already active", async () => {
                // Given
                const [betId,,] = await createBetAndGetTeamsAndBetId()
                await bettingContract.setBetToActive(betId)

                //when & Then
                await expect(bettingContract.setBetToActive(betId)).to.be.revertedWith(
					"already active"
				)
            })

            it("should be able tto set bet status to Active by owner only", async() => {
                // Given
				const [betId,,] = await createBetAndGetTeamsAndBetId()

                // When
                await bettingContract.setBetToActive(betId)

                // Then
                const bet = await bettingContract.bets(0)
                expect(bet.betStatus).eq(1)
            })

            it("should not be able to set bet inactive by non-owner",async () => {
				// Given
				const [betId,,] = await createBetAndGetTeamsAndBetId()
                await bettingContract.setBetToActive(betId)

                 //when & Then
                 await expect(
						bettingContract.connect(bettor1).setBetToInActive(betId)
					).to.be.revertedWith("Not owner")
			})

            it("betId should be valid to set status as Inactive", async() => {
                // Given
				let [betId,,]  = await createBetAndGetTeamsAndBetId()
				betId = betId + BigInt(1)

                 //when & Then
                 await expect(
                    bettingContract.setBetToInActive(betId)
                ).to.be.revertedWith("invalid bet id")
            })

            it("should not set bet status to InActive when already Active", async () => {
				// Given
				const [betId,,] = await createBetAndGetTeamsAndBetId()

				// When & Then
				await expect(bettingContract.setBetToInActive(betId)).to.be.revertedWith(
					"bet already inactive"
				)
			})

            it("should not set bet status to InActive when bettors already betted", async () => {
				// Given
				const [betId,,] = await createBetAndGetTeamsAndBetId()
                const teamId = 1
                const amount = 10
				await bettingContract.setBetToActive(betId)
				await approveAndAllotFunds([bettor1], amount)
                await bettingContract.connect(bettor1).pledgeFundsToBet(amount, betId, teamId)


				// When & Then
				await expect(bettingContract.setBetToInActive(betId)).to.be.revertedWith(
					"bettors already betted"
				)
			})

            it("should update bet status to InActive by owner", async () => {
				// Given
				const [betId,,] = await createBetAndGetTeamsAndBetId()
                await bettingContract.setBetToActive(betId)

				// When & Then
				await bettingContract.setBetToInActive(betId)

                // Then
                const bet = await bettingContract.bets(0)
                expect(bet.betStatus).eq(0)
			})
        })

        describe("\n Pledge Funds", () => {
            it("should not be able to pledge funds when betId is not valid", async () => {
				// Given
				let [betId,,]  = await createBetAndGetTeamsAndBetId()
				betId = betId + BigInt(1)
				const teamId = 1
				const amount = 10

				// When & Then
				await expect(
					bettingContract.connect(bettor1).pledgeFundsToBet(amount, betId, teamId)
				).to.be.revertedWith("invalid bet id")
			})

            it("should not be able to pledge funds when bet is InActive", async () => {
				// Given
				const [betId,,] = await createBetAndGetTeamsAndBetId()
				const teamId = 1
				const amount = 10

				// When & Then
				await expect(
					bettingContract.connect(bettor1).pledgeFundsToBet(amount, betId, teamId)
				).to.be.revertedWith("bet inactive")
			})

            it("should not be able to pledge funds when bet amount < minBetAmount", async () => {
				// Given
				const [betId,,] = await createBetAndGetTeamsAndBetId()
				const teamId = 1
				const amount = 5
                await bettingContract.setBetToActive(betId)

				// When & Then
				await expect(
					bettingContract.connect(bettor1).pledgeFundsToBet(amount, betId, teamId)
				).to.be.revertedWith("invalid bet amount")
			})

            it("should not be able to pledge funds when selected team is invalid", async () => {
				// Given
				const [betId,,] = await createBetAndGetTeamsAndBetId()
				const [teamCId , teamDId] = await addTeamsAndGetTeamIds()
				const teamId = 0
				const amount = 10
                await bettingContract.setBetToActive(betId)

				// When & Then
				await expect(
					bettingContract.connect(bettor1).pledgeFundsToBet(amount, betId, teamId)
				).to.be.revertedWith("invalid team-id")

				await expect(
					bettingContract.connect(bettor1).pledgeFundsToBet(amount, betId, teamCId)
				).to.be.revertedWith("invalid team-id")
			})

            it("should able to bet amount", async () => {
                // Given
                const [betId, teamAId, teamBId] = await createBetAndGetTeamsAndBetId()
				const amount = 10
                await bettingContract.setBetToActive(betId)

                const betDeatilsBefore = await bettingContract.getBetDetails(betId)
				const teamATotalAmountBefore = betDeatilsBefore[5]
                const teamBTotalAmountBefore = betDeatilsBefore[6]

				const bettorsOnTeamABefore = await bettingContract.getBettorsOnTeam(betId, teamAId)
				const bettorsOnTeamBBefore = await bettingContract.getBettorsOnTeam(betId, teamBId)

				const bettor1BetDetailsBefore = await bettingContract.connect(bettor1).getBettorBetDetails(betId)
				const bettor2BetDetailsBefore = await bettingContract.connect(bettor2).getBettorBetDetails(betId)

                await approveAndAllotFunds([bettor1, bettor2], amount)
                
                // When
                await bettingContract.connect(bettor1).pledgeFundsToBet(amount, betId, teamAId)
                await bettingContract.connect(bettor2).pledgeFundsToBet(amount, betId, teamBId)

                // Then
                const betDetailsAfter = await bettingContract.getBetDetails(betId)
                const teamATotalAmountAfter = betDetailsAfter[5]
                const teamBTotalAmountAfter = betDetailsAfter[6]

                verifyAmountBettedOnTeams(teamATotalAmountBefore, teamATotalAmountAfter, amount)
				verifyAmountBettedOnTeams(teamBTotalAmountBefore, teamBTotalAmountAfter, amount)

				const bettor1BetDetailsAfter = await bettingContract.connect(bettor1).getBettorBetDetails(betId)
				const bettor2BetDetailsAfter = await bettingContract.connect(bettor2).getBettorBetDetails(betId)

				verifyBettorDetailsOnBet(bettor1BetDetailsBefore, bettor1BetDetailsAfter, teamAId, amount)
				verifyBettorDetailsOnBet(bettor2BetDetailsBefore, bettor2BetDetailsAfter, teamBId, amount)

				const bettorsOnTeamAAfter = await bettingContract.getBettorsOnTeam(betId, teamAId)
				const bettorsOnTeamBAfter = await bettingContract.getBettorsOnTeam(betId, teamBId)
				
				verifyBettorsOnTeam(bettorsOnTeamABefore.length, bettorsOnTeamAAfter.length, 1)
				verifyBettorsOnTeam(bettorsOnTeamBBefore.length, bettorsOnTeamBAfter.length, 1)
			})
        })

		describe("\n Complete Bet", () => {
			it("should throw error for invalid bet operations", async() => {
				const [betId, teamAId, teamBId] = await createBetAndGetTeamsAndBetId()
				const amount = 10;
				// throw error in case of non-owner
				await expect(
					bettingContract
						.connect(bettor1)
						.setBetToCompleteAndTransferFundsToWinners(betId, teamAId)
				).to.be.revertedWith("Not owner")

				// throw error in case of invalid betId
				const invalidBetId = betId + BigInt(1)
				await expect(
					bettingContract
						.setBetToCompleteAndTransferFundsToWinners(invalidBetId, teamAId)
				).to.be.revertedWith("invalid bet id")

				// throw error in case of bet InActive
				await expect(
					bettingContract
						.setBetToCompleteAndTransferFundsToWinners(betId, teamAId)
				).to.be.revertedWith("bet inactive")

				// throw error in case of invalid teamId
				await bettingContract.setBetToActive(betId)
				const [teamCId] = await addTeamsAndGetTeamIds()
				await expect(
					bettingContract
						.setBetToCompleteAndTransferFundsToWinners(betId, teamCId)
				).to.be.revertedWith("invalid teamId")

				// throw error if wining team already specified
				await approveAndAllotFunds([bettor1, bettor2, bettor3, bettor4], amount)
				await pledgeFundsToBetByBettors(
					amount,
					betId,
					teamAId,
					teamBId,
					[bettor1, bettor3],
					[bettor2, bettor4]
				)
				await bettingContract.setBetToCompleteAndTransferFundsToWinners(betId, teamBId);

				await expect(
					bettingContract.setBetToCompleteAndTransferFundsToWinners(betId, teamBId)
				).to.be.revertedWith("team already won")
			})

			it("should be able to complete bet and return funds to wining team bettors", async() => {
				// Given
				// Case 1 : Where Team 2 Wins
				const amount = 10
				const [betId, teamAId, teamBId] = await createBetAndGetTeamsAndBetId()
				await bettingContract.setBetToActive(betId)

				await approveAndAllotFunds([bettor1, bettor2, bettor3, bettor4], amount)

				await pledgeFundsToBetByBettors(
					amount,
					betId,
					teamAId,
					teamBId,
					[bettor1, bettor3],
					[bettor2, bettor4]
				)

				// When
				await bettingContract.setBetToCompleteAndTransferFundsToWinners(betId, teamBId)

				// Then
				verifyBettorsBalance([bettor2, bettor4], [bettor1, bettor3])

				const betDetails = await bettingContract.getBetDetails(betId)
				expect(betDetails[3]).eq(2) // bet status
				expect(betDetails[4]).eq(teamBId)

				// Case 2 : Where Team 1 Wins
				const [betId1, teamCId, teamDId] = await createBetAndGetTeamsAndBetId()
				await bettingContract.setBetToActive(betId1)

				await approveAndAllotFunds([bettor1, bettor2, bettor3, bettor4], amount)

				await pledgeFundsToBetByBettors(
					amount,
					betId1,
					teamCId,
					teamDId,
					[bettor1, bettor3],
					[bettor2, bettor4]
				)

				// When
				await bettingContract.setBetToCompleteAndTransferFundsToWinners(betId1, teamCId)

				// Then
				verifyBettorsBalance([bettor1, bettor3], [bettor2, bettor4])

				const betDetails1 = await bettingContract.getBetDetails(betId1)
				expect(betDetails1[3]).eq(2) // bet status
				expect(betDetails1[4]).eq(teamCId)
			})
		})

		describe("\n Get Data Operations", () => {
			it("should return total amount betted on a bet", async() => {
				// Given
				const amount = 10
				const [betId, teamAId, teamBId] = await createBetAndGetTeamsAndBetId()
				await bettingContract.setBetToActive(betId)

				await approveAndAllotFunds([bettor1, bettor2, bettor3, bettor4], amount)

				await pledgeFundsToBetByBettors(
					amount,
					betId,
					teamAId,
					teamBId,
					[bettor1, bettor3],
					[bettor2, bettor4]
				)

				// When
				const betTotalPledgedFunds = await bettingContract.getTotalAmountBettedOnABet(betId)	
				
				// Then
				const betDetails = await bettingContract.getBetDetails(betId)
				const amountBettedOnTeamA = betDetails[5]
				const amountBettedOnTeamB = betDetails[6]
				expect(betTotalPledgedFunds).eq(amountBettedOnTeamA + amountBettedOnTeamB)
			})

			it("should return numbers of bets of a user", async() => {
				// Given
				const totalAmount = 20
				const betAmount = 10;

				const [betId, teamAId, teamBId] = await createBetAndGetTeamsAndBetId()
				await bettingContract.setBetToActive(betId)

				const [betId1, teamCId, teamDId] = await createBetAndGetTeamsAndBetId()
				await bettingContract.setBetToActive(betId1)

				await approveAndAllotFunds([bettor1], totalAmount)

				await pledgeFundsToBetByBettors(betAmount, betId, teamAId, teamBId, [bettor1], [])
				await pledgeFundsToBetByBettors(betAmount, betId1, teamCId, teamDId, [bettor1], [])

				// When
				const betCountOfBettor1 = await bettingContract.connect(bettor1).getAllBetsByUsers()

				// Then
				expect(betCountOfBettor1.length).eq(2)
				expect(betCountOfBettor1[0]).eq(betId)
				expect(betCountOfBettor1[1]).eq(betId1)
			})

			it("should return all teams", async() => {
				// Given
				await addTeamsAndGetTeamIds()
				await addTeamsAndGetTeamIds()
				const teamCount = await bettingContract.teamCount();

				// When
				const teams = await bettingContract.getAllTeams()
				
				// Then
				expect(teams.length).eq(teamCount)
			})
		})
	})
})

