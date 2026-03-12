extends Control

# ================================================
# SLIDE GAME - Full rewrite, provably fair, Rainbet style
# Single CasinoManager - exponential multiplier with perfect verification
# ================================================

const MAX_MULTIPLIER: float = 1000000.0
const SHIFT: float = 0.85
const RATE: float = 1.2

@onready var balance_display: Label = %BalanceDisplay
@onready var target_multiplier: SpinBox = %TargetMultiplier
@onready var win_chance_label: Label = %WinChanceLabel
@onready var play_button: Button = %PlayButton
@onready var result_panel: Panel = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var details_label: Label = %DetailsLabel
@onready var winnings_label: Label = %WinningsLabel
@onready var bet_input: HBoxContainer = $MainLayout/BetInput
@onready var fairness_panel: Panel = %FairnessPanel

var _current_bet: int = 0
var _target: float = 2.0
var _actual_multiplier: float = 0.0
var _server_seed_used: String = ""
var _nonce_used: int = 0

func _ready() -> void:
	CasinoManager.balance_changed.connect(_on_balance_changed)
	_on_balance_changed(CasinoManager.get_balance())
	
	_update_win_chance()
	target_multiplier.value_changed.connect(_on_target_changed)
	
	# Connect fairness panel close button (same as before)
	var close_btn = fairness_panel.get_node_or_null("VBoxContainer/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_hide_fairness)

func _on_balance_changed(new_balance: int) -> void:
	balance_display.text = "Balance: %d" % new_balance

func _on_target_changed(value: float) -> void:
	_target = value
	_update_win_chance()

func _update_win_chance() -> void:
	var win_prob: float = 1.0
	if _target > SHIFT:
		win_prob = exp(-RATE * (_target - SHIFT))
	win_prob = clamp(win_prob, 0.0001, 0.99)
	win_chance_label.text = "Win Chance: %.4f%%" % (win_prob * 100)

func _generate_slide_result() -> float:
	var uniform: float = CasinoManager.generate_fair_random(0.0001, 0.9999)
	var result: float = SHIFT - (1.0 / RATE) * log(1.0 - uniform)
	return clamp(result, 0.1, MAX_MULTIPLIER)

func _on_play_pressed() -> void:
	if result_panel.visible:
		return
	
	var bet: int = bet_input.get_bet()
	if not CasinoManager.place_bet(bet):
		return
	
	_current_bet = bet
	_server_seed_used = CasinoManager.reveal_server_seed()
	_nonce_used = CasinoManager.get_nonce()
	_target = target_multiplier.value
	
	_actual_multiplier = _generate_slide_result()
	
	var won := _actual_multiplier >= _target
	var winnings := 0
	
	if won:
		winnings = int(_current_bet * _target)
		CasinoManager.add_winnings(winnings)
	
	_show_result(won, winnings)
	
	# Advance provably-fair chain for next round
	CasinoManager.increment_nonce()
	CasinoManager.start_new_round()

func _show_result(won: bool, winnings: int) -> void:
	result_panel.visible = true
	play_button.visible = false
	
	if won:
		result_label.text = "WIN!"
		result_label.modulate = Color(0.2, 0.9, 0.3)
		winnings_label.text = "+%d coins (%.2fx)" % [winnings - _current_bet, _target]
	else:
		result_label.text = "LOSS"
		result_label.modulate = Color(0.9, 0.2, 0.2)
		winnings_label.text = "Lost %d coins" % _current_bet
	
	details_label.text = "Target: %.2fx | Actual: %.2fx" % [_target, _actual_multiplier]

func _on_show_fairness_pressed() -> void:
	var outcome_text := "%s at %.2fx (target: %.2fx)" % [
		"Won" if _actual_multiplier >= _target else "Lost", 
		_actual_multiplier, 
		_target
	]
	
	fairness_panel.setup(_server_seed_used, CasinoManager.get_client_seed(),
		_nonce_used, outcome_text, _verify_slide_round)
	fairness_panel.visible = true

func _verify_slide_round() -> String:
	"""Recompute using EXACT same logic as the round (now 100% verifiable)."""
	var uniform := CasinoManager.verify_fair_random(_server_seed_used, CasinoManager.get_client_seed(), _nonce_used, 0.0001, 0.9999)
	var verified_result := SHIFT - (1.0 / RATE) * log(1.0 - uniform)
	verified_result = clamp(verified_result, 0.1, MAX_MULTIPLIER)
	return "Verified: %.6fx (uniform: %.6f)" % [verified_result, uniform]

func _hide_fairness() -> void:
	fairness_panel.visible = false

func _on_play_again_pressed() -> void:
	result_panel.visible = false
	play_button.visible = true

func _on_back_pressed() -> void:
	CasinoManager.return_to_main_menu()
