extends HBoxContainer

@onready var bet_amount: SpinBox = %BetAmount


func _ready() -> void:
	$MaxBetButton.pressed.connect(_on_max_bet_pressed)
	CurrencyManager.balance_changed.connect(_on_balance_changed)
	_update_max_value()


func get_bet() -> int:  # Explicit return type added
	return int(bet_amount.value)


func set_bet(value: int) -> void:
	bet_amount.value = value


func _on_max_bet_pressed() -> void:
	bet_amount.value = CurrencyManager.get_balance()


func _on_balance_changed(_new_balance: int) -> void:
	_update_max_value()


func _update_max_value() -> void:
	bet_amount.max_value = max(CurrencyManager.get_balance(), 1)
