if (Lang == undefined) {
	var Lang = [];
}
Lang["zh-cn"] = {
	pumpInterface: {
		stationStock: "{0} 升(L)",
		vehicleFuel: "{0} 升(L)",
		confirm: "确认",
		fuelTypes: {
			regular: "92号燃油",
			plus: "95号燃油",
			premium: "98号燃油",
			diesel: "柴油",
		},
	},
	pumpRefuelDisplay: {
		liters: "升(L)",
		carTank: "车辆油箱",
		remaining: "剩余容量",
	},
	confirmRefuelModal: {
		title: "加油确认",
		description: "您正在为车牌号 {2} 的车辆补充 {0} 升 {1} 类燃油",
		paymentBank: "银行结算",
		paymentCash: "现金结算",
	},
	confirmBuyJerryCanModal: {
		title: "确认购买",
		paymentBank: "银行结算",
		paymentCash: "现金结算",
	},
	confirmFuelChangeModal: {
		title: "燃油类型变更提示",
		description: "⚠️ 更换燃油种类前请确保油箱完全排空",
	},
	electricInterface: {
		chargerType: {
			title: "充电规格选择",
			fast: {
				title: "极速充电",
				power: "220kW",
			},
			normal: {
				title: "标准充电",
				power: "100kW",
			},
			pricePerKWh: "{0}/kWh",
		},
		chargerAmount: {
			title: "充电金额设定",
			typeSelected: "充电桩 {0} 台",
			placeholder: "输入金额",
			timeToRechargeText: "预计充电时长:",
			timeToRechargeValue: "{0} 分 {1} 秒",
		},
		chargerPayment: {
			title: "支付方式选择",
			money: "现金结算",
			bank: "银行解锁",
			payButton: "支付 {0}",
		},
		continueButton: "下一步",
		outOfStock: "库存不足",
	},
	rechargerDisplay: {
		title: "充电中...",
		remainingTimeText: "剩余充电时间",
		remainingTimeValue: "{0} 分 {1} 秒",
	},
};