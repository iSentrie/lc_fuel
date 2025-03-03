let currentPumpData;
let selectedFuelType;
let fuelTypeWarnSent;

window.addEventListener("message", async function(event) {
	const item = event.data;
	if (item.data) {
		currentPumpData = item.data;
	}
	if (item.resourceName) {
		Utils.setResourceName(item.resourceName);
	}
	if (item.utils) {
		await Utils.loadLanguageModules(item.utils);
		Utils.post("setNuiVariablesLoaded", null, "setNuiVariablesLoaded");
	}
	if (item.openMainUI) {
		if (currentPumpData.isElectric) {
			$("#electric-time-to-recharge").html(`${Utils.translate("electricInterface.chargerAmount.timeToRechargeText")} <span id="electric-time-to-recharge-value"></span>`);

			$("#electric-charger-type-title").text(Utils.translate("electricInterface.chargerType.title"));
			$("#electric-charger-type-fast").text(Utils.translate("electricInterface.chargerType.fast.title"));
			$("#electric-charger-type-normal").text(Utils.translate("electricInterface.chargerType.normal.title"));
			$("#electric-charger-type-label-item-fast-price").text(Utils.translate("electricInterface.chargerType.pricePerKWh").format(Utils.currencyFormat(currentPumpData.pricePerLiter.electricfast)));
			$("#electric-charger-type-label-item-normal-price").text(Utils.translate("electricInterface.chargerType.pricePerKWh").format(Utils.currencyFormat(currentPumpData.pricePerLiter.electricnormal)));
			$("#electric-charger-type-label-item-fast-power").text(Utils.translate("electricInterface.chargerType.fast.power"));
			$("#electric-charger-type-label-item-normal-power").text(Utils.translate("electricInterface.chargerType.normal.power"));
			$("#electric-charger-continue-type-button").text(Utils.translate("electricInterface.continueButton"));

			$("#electric-charger-amount-title").text(Utils.translate("electricInterface.chargerAmount.title"));
			$("#electric-charger-amount-input").attr("placeholder", Utils.translate("electricInterface.chargerAmount.placeholder"));
			$("#electric-charger-continue-amount-button").text(Utils.translate("electricInterface.continueButton"));

			$("#electric-charger-payment-title").text(Utils.translate("electricInterface.chargerPayment.title"));
			$("#electric-charger-payment-bank").text(Utils.translate("electricInterface.chargerPayment.bank"));
			$("#electric-charger-payment-money").text(Utils.translate("electricInterface.chargerPayment.money"));

			if (currentPumpData.stationStock.electricfast == 0) {
				$("#electric-charger-fast-label-wrapper")
					.attr("data-tooltip", Utils.translate("electricInterface.outOfStock"))
					.attr("data-tooltip-location", "top");
				$("#charger-type-fast").prop("disabled", true);
			} else {
				$("#electric-charger-fast-label-wrapper")
					.removeAttr("data-tooltip")
					.removeAttr("data-tooltip-location");
				$("#charger-type-fast").prop("disabled", false);
			}

			if (currentPumpData.stationStock.electricnormal == 0) {
				$("#electric-charger-normal-label-wrapper")
					.attr("data-tooltip", Utils.translate("electricInterface.outOfStock"))
					.attr("data-tooltip-location", "top");
				$("#charger-type-normal").prop("disabled", true);
			} else {
				$("#electric-charger-normal-label-wrapper")
					.removeAttr("data-tooltip")
					.removeAttr("data-tooltip-location");
				$("#charger-type-normal").prop("disabled", false);
			}

			$(".electric-charger-type-container").css("display", "");
			$(".electric-charger-amount-container").css("display", "none");
			$(".electric-charger-payment-container").css("display", "none");
			$("#electric-charger-container").fadeIn(200);
		} else {
			if (currentPumpData.pumpModel == "prop_gas_pump_1a" || currentPumpData.pumpModel == "prop_gas_pump_1b" || currentPumpData.pumpModel == "prop_gas_pump_1c" || currentPumpData.pumpModel == "prop_gas_pump_1d") {
				$("#gas-pump-container-image").attr("src", `images/${currentPumpData.pumpModel}.png`);
			} else {
				$("#gas-pump-container-image").attr("src", `images/prop_gas_pump_1b.png`);
			}
			fuelTypeWarnSent = false;
			changeSelectedFuelType(currentPumpData.currentFuelType);
			$(".vehicle-fuel").text(Utils.translate("pumpInterface.vehicleFuel").format(Utils.numberFormat(currentPumpData.vehicleFuel, 2)));
			$(".bank-balance").text(Utils.currencyFormat(currentPumpData.bankBalance, 2));
			$(".cash-balance").text(Utils.currencyFormat(currentPumpData.cashBalance, 2));

			$(".fuel-type-button.regular").text(Utils.translate("pumpInterface.fuelTypes.regular"));
			$(".fuel-type-button.plus").text(Utils.translate("pumpInterface.fuelTypes.plus"));
			$(".fuel-type-button.premium").text(Utils.translate("pumpInterface.fuelTypes.premium"));
			$(".fuel-type-button.diesel").text(Utils.translate("pumpInterface.fuelTypes.diesel"));
			$(".confirm-button").text(Utils.translate("pumpInterface.confirm"));

			$("#confirm-refuel-payment-modal-title").text(Utils.translate("confirmRefuelModal.title"));
			$("#confirm-refuel-payment-modal-pay-bank").text(Utils.translate("confirmRefuelModal.paymentBank"));
			$("#confirm-refuel-payment-modal-pay-cash").text(Utils.translate("confirmRefuelModal.paymentCash"));

			$("#confirm-jerry-can-payment-modal-title").text(Utils.translate("confirmBuyJerryCanModal.title"));
			$("#confirm-jerry-can-payment-modal-desc").text(Utils.currencyFormat(currentPumpData.jerryCan.price, 2));
			$("#confirm-jerry-can-payment-modal-pay-bank").text(Utils.translate("confirmBuyJerryCanModal.paymentBank"));
			$("#confirm-jerry-can-payment-modal-pay-cash").text(Utils.translate("confirmBuyJerryCanModal.paymentCash"));

			$("#confirm-fuel-type-modal-title").text(Utils.translate("confirmFuelChangeModal.title"));
			$("#confirm-fuel-type-modal-desc").text(Utils.translate("confirmFuelChangeModal.description"));
			$("#confirm-fuel-type-modal-confirm").text(Utils.translate("confirmation_modal_confirm_button"));
			$("#confirm-fuel-type-modal-cancel").text(Utils.translate("confirmation_modal_cancel_button"));

			if (!currentPumpData.jerryCan.enabled) {
				$(".gas-pump-interactive-button").css("display", "none");
			}

			updateFuelAmountDisplay(true);

			$("#gas-pump-container").fadeIn(200);
		}
	}
	if (item.hideMainUI) {
		$("#gas-pump-container").fadeOut(200);
		$("#electric-charger-container").fadeOut(200);
	}
	if (item.showRefuelDisplay) {
		if (item.isElectric) {
			$("#recharge-display-title").text(Utils.translate("rechargerDisplay.title"));
			$("#recharge-display-battery-level-span").text(`${Utils.numberFormat(item.currentVehicleTank, 0)}%`);
			$("#recharge-display-battery-liquid").css("width", `${item.currentVehicleTank}%`);
			$("#recharge-display-remaining-time-title").text(Utils.translate("rechargerDisplay.remainingTimeText"));
			updateRechargeDisplay(item.remainingFuelAmount, item.fuelTypePurchased);
			$("#recharge-display").fadeIn(200);
		} else {
			$("#refuel-display-pump-value").text(Utils.numberFormat(item.remainingFuelAmount, 2));
			$("#refuel-display-car-value").text(Utils.numberFormat(item.currentVehicleTank, 2));
			$(".refuel-display-liters").text(Utils.translate("pumpRefuelDisplay.liters"));
			$("#refuel-display-car-label").text(Utils.translate("pumpRefuelDisplay.carTank"));
			$("#refuel-display-pump-label").text(Utils.translate("pumpRefuelDisplay.remaining"));
			$("#refuel-display").fadeIn(200);
		}
	}
	if (item.hideRefuelDisplay) {
		$("#refuel-display").fadeOut(200);
		$("#recharge-display").fadeOut(200);
	}
});

function updateRechargeDisplay(remainingFuelAmount, chargerType) {
	if (chargerType == "electricfast") chargerType = "fast";
	if (chargerType == "electricnormal") chargerType = "normal";
	if (chargerType && (chargerType === "fast" || chargerType === "normal")) {
		// Calculate the time to recharge based on remaining fuel amount and charger type's time per unit
		let timeToRecharge = remainingFuelAmount * currentPumpData.electric.chargeTypes[chargerType].time;

		// Convert time to minutes and seconds
		let timeToRechargeMinutes = Math.floor(timeToRecharge / 60);
		let timeToRechargeSeconds = timeToRecharge % 60;

		// Update the display with calculated time
		$("#recharge-display-remaining-time-value").text(Utils.translate("rechargerDisplay.remainingTimeValue").format(Utils.numberFormat(timeToRechargeMinutes, 0), Utils.numberFormat(timeToRechargeSeconds, 0)));
	} else {
		console.log("Invalid charger type or no charger type selected");
	}
}

/*=================
	FUNCTIONS
=================*/

function changeSelectedFuelType(fuelType) {
	if (fuelType == "regular" || fuelType == "plus" || fuelType == "premium" || fuelType == "diesel") {
		$(".fuel-type-button").removeClass("selected");
		$(`.fuel-type-button.${fuelType}`).addClass("selected");

		$(".price-per-liter").text(Utils.currencyFormat(currentPumpData.pricePerLiter[fuelType], 2));
		$(".station-stock").text(Utils.translate("pumpInterface.stationStock").format(Utils.numberFormat(currentPumpData.stationStock[fuelType])));
		selectedFuelType = fuelType;
	} else {
		console.log("Invalid fuel type chosen: " + fuelType);
	}
}

// Show the modal when confirmRefuel is called
function confirmRefuel() {
	if (fuelTypeWarnSent == false && currentPumpData.currentFuelType != selectedFuelType && currentPumpData.vehicleFuel > 0) {
		fuelTypeWarnSent = true;
		$("#confirm-fuel-type-modal").fadeIn();
	} else {
		let $input = $("#input-fuel-amount");
		let fuelAmount = parseInt($input.val());
		$("#confirm-refuel-payment-modal-desc").text(Utils.translate("confirmRefuelModal.description").format(fuelAmount, Utils.translate("pumpInterface.fuelTypes."+selectedFuelType), Utils.currencyFormat(fuelAmount * currentPumpData.pricePerLiter[selectedFuelType])));
		$("#confirm-refuel-payment-modal").fadeIn();
	}
}

// Empty vehicle's tank after user confirm fuel type change
function changeVehicleFuelType() {
	closeModal();
	Utils.post("changeVehicleFuelType", { selectedFuelType });
	currentPumpData.vehicleFuel = 0;
	$(".vehicle-fuel").text(Utils.translate("pumpInterface.vehicleFuel").format(Utils.numberFormat(currentPumpData.vehicleFuel, 2)));
}

// Confirm the buy jerry can action
function openBuyJerryCanModal() {
	closeModal();
	$("#confirm-jerry-can-payment-modal").fadeIn();
}

// Hide the modal
function closeModal() {
	$(".modal").fadeOut();
}

function confirmRefuelPayment(paymentMethod) {
	let $input = $("#input-fuel-amount");
	let fuelAmount = parseInt($input.val());
	Utils.post("confirmRefuel", { selectedFuelType, fuelAmount, paymentMethod });
	closeModal();
}

function confirmJerryCanPayment(paymentMethod) {
	Utils.post("confirmJerryCanPurchase", { paymentMethod });
	closeModal();
}

function increaseZoom() {
	// Get the current zoom level
	let currentZoom = parseFloat($("#gas-pump-container").css("zoom")) || 1;

	// Increase zoom by 5%
	let newZoom = currentZoom + 0.05;

	// Limit the zoom to a maximum of 1.4 (140%)
	if (newZoom > 1.4) {
		newZoom = 1.4;
	}

	// Apply the new zoom level
	$("#gas-pump-container").css("zoom", newZoom);
}

function decreaseZoom() {
	// Get the current zoom level
	let currentZoom = parseFloat($("#gas-pump-container").css("zoom")) || 1;

	// Decrease zoom by 5%
	let newZoom = currentZoom - 0.05;

	// Limit the zoom to a minimum of 0.8 (80%)
	if (newZoom < 0.8) {
		newZoom = 0.8;
	}

	// Apply the new zoom level
	$("#gas-pump-container").css("zoom", newZoom);
}

// Function to update the display with the 'L' suffix
function updateFuelAmountDisplay(setToMax = false) {
	let $input = $("#input-fuel-amount");
	let value = parseInt($input.val());

	// Set value to 1 if it's not a positive number
	if (isNaN(value) || value <= 0) {
		value = 1;
	}

	// Don't let it purchase more L than the vehicle can hold in the tank
	if (setToMax || (!isNaN(value) && value > 100 - currentPumpData.vehicleFuel)) {
		value = Math.floor(100 - currentPumpData.vehicleFuel);
	}

	$input.val(value + " L");
}

// Pagination for electric chargers
function chargerTypeContinue() {
	let chargerType = getSelectedChargerType();
	if (chargerType && (chargerType == "fast" || chargerType == "normal")) {
		$("#electric-charger-amount-input").val(Math.floor(100 - currentPumpData.vehicleFuel));
		calculateTimeToRecharge();
		$("#electric-charger-amount-type-selected").text(Utils.translate("electricInterface.chargerAmount.typeSelected").format(Utils.translate(`electricInterface.chargerType.${chargerType}.title`)));
		$(".electric-charger-type-container").css("display", "none");
		$(".electric-charger-amount-container").css("display", "");
	}
}

function chargerAmountContinue() {
	let $input = $("#electric-charger-amount-input");
	let currentValue = parseInt($input.val()) || 0;
	let newWidthPercentage = currentPumpData.vehicleFuel + currentValue;

	if (currentValue <= 0 || newWidthPercentage > 100) {
		return;
	}

	let chargerType = getSelectedChargerType();
	$("#electric-charger-pay-button").text(Utils.translate("electricInterface.chargerPayment.payButton").format(Utils.currencyFormat(currentValue * currentPumpData.pricePerLiter["electric"+chargerType], 2)));
	$(".electric-charger-amount-container").css("display", "none");
	$(".electric-charger-payment-container").css("display", "");
}

function chargerAmountReturn() {
	$(".electric-charger-type-container").css("display", "");
	$(".electric-charger-amount-container").css("display", "none");
	$(".electric-charger-payment-container").css("display", "none");
}

function confirmRecharge() {
	let $input = $("#electric-charger-amount-input");
	let fuelAmount = parseInt($input.val()) || 0;
	Utils.post("confirmRefuel", { selectedFuelType: "electric" + getSelectedChargerType(), fuelAmount, paymentMethod: getSelectedElectricPaymentMethod() });
}

function chargerPaymentReturn() {
	$(".electric-charger-type-container").css("display", "none");
	$(".electric-charger-amount-container").css("display", "");
	$(".electric-charger-payment-container").css("display", "none");
}

function getSelectedChargerType() {
	const selectedInput = $("input[name='charger-type']:checked");
	return selectedInput.length && !selectedInput.prop("disabled") ? selectedInput.val() : null;
}

function getSelectedElectricPaymentMethod() {
	const selectedInput = $("input[name='charger-payment']:checked");
	return selectedInput.length ? selectedInput.val() : null;
}

function calculateTimeToRecharge() {
	let $input = $("#electric-charger-amount-input");
	let currentValue = parseInt($input.val());

	// Allow empty input temporarily; validate only non-empty values
	if ($input.val().trim() === "" || isNaN(currentValue) || currentValue <= 0) {
		currentValue = 0;
	}

	let chargerType = getSelectedChargerType();
	if (chargerType && (chargerType == "fast" || chargerType == "normal")) {
		let timeToRecharge = currentValue * currentPumpData.electric.chargeTypes[chargerType].time;

		// Calculate minutes and seconds
		let timeToRechargeMinutes = Math.floor(timeToRecharge / 60);
		let timeToRechargeSeconds = timeToRecharge % 60;

		$("#electric-time-to-recharge-value").text(Utils.translate("electricInterface.chargerAmount.timeToRechargeValue").format(Utils.numberFormat(timeToRechargeMinutes, 0), Utils.numberFormat(timeToRechargeSeconds, 0)));

		let newWidthPercentage = currentPumpData.vehicleFuel + currentValue;
		$("#electric-amount-progress-bar").css("width", newWidthPercentage + "%");

		if (newWidthPercentage > 100) {
			$("#electric-amount-progress-bar").css("background", "red");
		} else {
			$("#electric-amount-progress-bar").css("background", "");
		}
	} else {
		console.log("No charger type selected");
	}
}

/*=================
	LISTENERS
=================*/

$(window).click(function(event) {
	// Close the modal when clicking outside of it
	if ($(event.target).is(".modal")) {
		closeModal();
	}
});

$(document).on("keydown", function(event) {
	// Handle press of Esc key
	if (event.key === "Escape" || event.keyCode === 27) {
		// Check if the modal is open by checking if it's visible
		if ($(".modal").is(":visible")) {
			closeModal();
		} else {
			closeUI();
		}
	}
});

$(document).ready(function() {
	// Handle the add button
	$(".refuel-add").click(function() {
		let $input = $("#input-fuel-amount");
		let currentValue = parseInt($input.val()) || 0;
		if (currentValue < Math.floor(100 - currentPumpData.vehicleFuel)) {
			$input.val((currentValue + 1) + " L");
		}
	});
	$(".recharge-add").click(function() {
		let $input = $("#electric-charger-amount-input");
		let currentValue = parseInt($input.val()) || 0;
		if (currentValue < Math.floor(100 - currentPumpData.vehicleFuel)) {
			$input.val((currentValue + 1));
			calculateTimeToRecharge();
		}
	});

	// Handle the sub button
	$(".refuel-sub").click(function() {
		let $input = $("#input-fuel-amount");
		let currentValue = parseInt($input.val()) || 0;
		if (currentValue > 1) {
			$input.val((currentValue - 1) + " L");
		}
	});
	$(".recharge-sub").click(function() {
		let $input = $("#electric-charger-amount-input");
		let currentValue = parseInt($input.val()) || 0;
		if (currentValue > 1) {
			$input.val((currentValue - 1));
			calculateTimeToRecharge();
		}
	});

	// Remove 'L' suffix on focus to allow numeric input, and add it back on blur
	$("#input-fuel-amount").on("focus", function() {
		$(this).val(parseInt($(this).val()) || 1);
	}).on("blur", function() {
		updateFuelAmountDisplay();
	});

	// Recalculate time when change input
	$("#electric-charger-amount-input").on("input", function() {
		calculateTimeToRecharge();
	});
	$("#electric-charger-amount-input").on("blur", function() {
		let $input = $(this);
		let currentValue = parseInt($input.val());

		// If invalid, reset to 0
		if (isNaN(currentValue) || currentValue <= 0) {
			$input.val(0);
		}
	});
});


/*=================
	CALLBACKS
=================*/

function closeUI(){
	Utils.post("close","");
}