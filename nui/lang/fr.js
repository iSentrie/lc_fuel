if (Lang == undefined) {
	var Lang = [];
}
Lang["fr"] = {
	pumpInterface: {
		stationStock: "{0} L",
		vehicleFuel: "{0} L",
		confirm: "CONFIRMER",
		fuelTypes: {
			regular: "Ordinaire",
			plus: "Plus",
			premium: "Premium",
			diesel: "Diesel",
		},
	},
	pumpRefuelDisplay: {
		liters: "L",
		carTank: "Réservoir",
		remaining: "Restant",
	},
	confirmRefuelModal: {
		title: "Confirmer le ravitaillement",
		description: "Vous achetez {0} L de carburant {1} pour {2}.",
		paymentBank: "Payer avec la banque",
		paymentCash: "Payer en espèces",
	},
	confirmBuyJerryCanModal: {
		title: "Confirmer l'achat",
		paymentBank: "Payer avec la banque",
		paymentCash: "Payer en espèces",
	},
	confirmFuelChangeModal: {
		title: "Les carburants ne peuvent pas être mélangés",
		description: "⚠️ Pour changer le type de carburant dans votre véhicule, le réservoir sera vidé.",
	},
	electricInterface: {
		chargerType: {
			title: "TYPE DE CHARGEUR",
			fast: {
				title: "RAPIDE",
				power: "220kW",
			},
			normal: {
				title: "NORMAL",
				power: "100kW",
			},
			pricePerKWh: "{0}/kWh",
		},
		chargerAmount: {
			title: "SÉLECTIONNER LA QUANTITÉ",
			typeSelected: "{0} CHARGEUR",
			placeholder: "Quantité",
			timeToRechargeText: "Temps pour recharger :",
			timeToRechargeValue: "{0} min {1} sec",
		},
		chargerPayment: {
			title: "MODE DE PAIEMENT",
			money: "ESPÈCES",
			bank: "BANQUE",
			payButton: "PAYER {0}",
		},
		continueButton: "CONTINUER",
		outOfStock: "Rupture de stock",
	},
	rechargerDisplay: {
		title: "CHARGE EN COURS...",
		remainingTimeText: "TEMPS RESTANT",
		remainingTimeValue: "{0} min {1} sec",
	},
};
