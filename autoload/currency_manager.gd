extends Node

signal balance_changed(new_balance: int)
signal insufficient_funds

const STARTING_BALANCE: int = 10000

var _balance: int = STARTING_BALANCE


func _ready() -> void:
	# Initialize with starting balance
	_balance = STARTING_BALANCE


func get_balance() -> int:
	return _balance


func can_afford(amount: int) -> bool:
	return amount > 0 and amount <= _balance


func place_bet(amount: int) -> bool:
	if not can_afford(amount):
		insufficient_funds.emit()
		return false
	
	_balance -= amount
	balance_changed.emit(_balance)
	return true


func add_winnings(amount: int) -> void:
	_balance += amount
	balance_changed.emit(_balance)


func reset_balance() -> void:
	_balance = STARTING_BALANCE
	balance_changed.emit(_balance)
