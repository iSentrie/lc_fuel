if (Lang == undefined) {
	var Lang = [];
}
Lang["en"] = {
	pumpInterface: {
		stationStock: "{0} L",
		vehicleFuel: "{0} L",
		confirm: "CONFIRM",
		fuelTypes: {
			regular: "Regular",
			plus: "Plus",
			premium: "Premium",
			diesel: "Diesel",
		},
	},
	pumpRefuelDisplay: {
		liters: "L",
		carTank: "Car Tank",
		remaining: "Remaining",
	},
	confirmRefuelModal: {
		title: "Confirm Refuel",
		description: "You are purchasing {0}L of {1} fuel for {2}.",
		paymentBank: "Pay with bank",
		paymentCash: "Pay with cash",
	},
	confirmBuyJerryCanModal: {
		title: "Confirm Purchase",
		paymentBank: "Pay with bank",
		paymentCash: "Pay with cash",
	},
	confirmFuelChangeModal: {
		title: "Fuels cannot be mixed",
		description: "⚠️ To change the fuel type in your vehicle, the tank will be emptied.",
	},
	electricInterface: {
		chargerType: {
			title: "CHARGER TYPE",
			fast: {
				title: "FAST",
				power: "220kW",
			},
			normal: {
				title: "NORMAL",
				power: "100kW",
			},
			pricePerKWh: "{0}/kWh",
		},
		chargerAmount: {
			title: "SELECT AMOUNT",
			typeSelected: "{0} CHARGER",
			placeholder: "Amount",
			timeToRechargeText: "Time to recharge:",
			timeToRechargeValue: "{0} min {1} sec",
		},
		chargerPayment: {
			title: "PAYMENT METHOD",
			money: "MONEY",
			bank: "BANK",
			payButton: "PAY {0}",
		},
		continueButton: "CONTINUE",
		outOfStock: "Out of stock",
	},
	rechargerDisplay: {
		title: "CHARGING...",
		remainingTimeText: "REMAINING TIME",
		remainingTimeValue: "{0} min {1} sec",
	},
};