extends HBoxContainer

# ================================================
# BET INPUT - Shared reusable component for ALL games
# Now powered by single CasinoManager - works with mines, slide, and future games
# ================================================

@onready var bet_amount: SpinBox = %BetAmount

func _ready() -> void:
	$MaxBetButton.pressed.connect(_on_max_bet_pressed)
	CasinoManager.balance_changed.connect(_on_balance_changed)
	_update_max_value()

func get_bet() -> int:
	return int(bet_amount.value)

func set_bet(value: int) -> void:
	bet_amount.value = value

func _on_max_bet_pressed() -> void:
	bet_amount.value = CasinoManager.get_balance()

func _on_balance_changed(_new_balance: int) -> void:
	_update_max_value()

func _update_max_value() -> void:
	bet_amount.max_value = max(CasinoManager.get_balance(), 1)
