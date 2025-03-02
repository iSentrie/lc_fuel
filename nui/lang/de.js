if (Lang == undefined) {
	var Lang = [];
}
Lang["de"] = {
	pumpInterface: {
		stationStock: "{0} L",
		vehicleFuel: "{0} L",
		confirm: "Bestätigen",
		fuelTypes: {
			regular: "Regulär",
			plus: "Plus",
			premium: "Premium",
			diesel: "Diesel",
		},
	},
	pumpRefuelDisplay: {
		liters: "L",
		carTank: "Autotank",
		remaining: "Übrig",
	},
	confirmRefuelModal: {
		title: "Bestätigen Sie „Tanken“.",
		description: "Sie kaufen {0}L {1} Kraftstoff für {2}.",
		paymentBank: "Bezahlen Sie mit der Bank",
		paymentCash: "Bezahlen Sie mit Bargeld",
	},
	confirmBuyJerryCanModal: {
		title: "Kauf Bestätigen",
		paymentBank: "Bezahlen Sie mit der Bank",
		paymentCash: "Bezahlen Sie mit Bargeld",
	},
	confirmFuelChangeModal: {
		title: "Kraftstoffe können nicht gemischt werden",
		description: "⚠️ Kraftstoffe können nicht gemischt werden",
	},
	electricInterface: {
		chargerType: {
			title: "LADEGERÄTETYP",
			fast: {
				title: "SCHNELL",
				power: "220kW",
			},
			normal: {
				title: "NORMAL",
				power: "100kW",
			},
			pricePerKWh: "{0}/kWh",
		},
		chargerAmount: {
			title: "BETRAG WÄHLEN",
			typeSelected: "{0} AUSGEWÄHLT",
			placeholder: "Menge",
			timeToRechargeText: "Zeit zum Aufladen:",
			timeToRechargeValue: "{0} min {1} sec",
		},
		chargerPayment: {
			title: "Bezahlmethode",
			money: "Bar",
			bank: "Karte",
			payButton: "Bezahlen {0}",
		},
		continueButton: "Bestätigen",
		outOfStock: "Ausverkauft",
	},
	rechargerDisplay: {
		title: "AUFLADEN...",
		remainingTimeText: "VERBLEIBENDE ZEIT",
		remainingTimeValue: "{0} min {1} sek",
	},
};