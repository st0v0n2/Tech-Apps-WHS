extends Control

const MAX_MULTIPLIER: float = 1000000.0
#const HOUSE_EDGE: float = 0.01  # 1%

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
	CurrencyManager.balance_changed.connect(_on_balance_changed)
	_on_balance_changed(CurrencyManager.get_balance())
	
	_update_win_chance()
	target_multiplier.value_changed.connect(_on_target_changed)
	
	# Connect fairness panel close button
	var close_btn = fairness_panel.get_node_or_null("VBoxContainer/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_hide_fairness)


func _on_balance_changed(new_balance: int) -> void:
	balance_display.text = "Balance: %d" % new_balance


func _on_target_changed(value: float) -> void:
	_target = value
	_update_win_chance()


func _update_win_chance() -> void:
	# For exponential distribution: P(win) = (1 - house_edge) / target
	var win_prob := (1.0 - HOUSE_EDGE) / _target
	win_prob = clamp(win_prob, 0.0001, 0.99)
	win_chance_label.text = "Win Chance: %.4f%%" % (win_prob * 100)

"""
Fairness stuff 

Shifted Exponential Distribution - https://en.wikipedia.org/wiki/Exponential_distribution
var result: float = SHIFT - (1.0 / RATE) * log(1.0 - uniform)
this is inverse transform sampling to generate random numbers
psycologoical effect: https://en.wikipedia.org/wiki/Probability_distribution
"""

const SHIFT: float = 0.85      # Lower = more busts, higher = safer
const RATE: float = 1.2        # Higher = more concentrated around shift
const HOUSE_EDGE: float = 0.02 # 2% house edge (lower due to higher variance)

func _generate_slide_result() -> float:
	var uniform: float = FairnessSystem.generate_fair_random(0.0001, 0.9999)
	var result: float = SHIFT - (1.0 / RATE) * log(1.0 - uniform)
	return clamp(result, 0.1, MAX_MULTIPLIER)


func _on_play_pressed() -> void:
	if result_panel.visible:
		return
	
	var bet: int = bet_input.get_bet()  # Explicit type : int added
	if not CurrencyManager.place_bet(bet):
		return
	
	_current_bet = bet
	_server_seed_used = FairnessSystem.reveal_server_seed()
	_nonce_used = FairnessSystem.get_nonce()
	_target = target_multiplier.value
	
	# Generate result
	_actual_multiplier = _generate_slide_result()
	
	# Determine outcome
	var won := _actual_multiplier >= _target
	var winnings := 0
	
	if won:
		winnings = int(_current_bet * _target)
		CurrencyManager.add_winnings(winnings)
	
	_show_result(won, winnings)
	
	FairnessSystem.increment_nonce()
	FairnessSystem.start_new_round()


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
	
	fairness_panel.setup(_server_seed_used, FairnessSystem.get_client_seed(),
		_nonce_used, outcome_text, _verify_slide_round)
	fairness_panel.visible = true


func _verify_slide_round() -> String:
	"""Recompute the slide result to verify fairness."""
	# Reconstruct the exact same calculation
	var message := "%s:%s:%d" % [_server_seed_used, FairnessSystem.get_client_seed(), _nonce_used]
	
	var crypto := Crypto.new()
	var hmac_bytes := crypto.hmac_digest(HashingContext.HASH_SHA256, 
		_server_seed_used.to_utf8_buffer(), message.to_utf8_buffer())
	
	var hex_str := hmac_bytes.hex_encode()
	var uint_val := hex_str.substr(0, 16).hex_to_int()
	var uniform := 0.000001 + (float(uint_val) / float(0xFFFFFFFFFFFFFFFF)) * (1.0 - 0.000001)
	
	var rate := 1.0 - HOUSE_EDGE
	var verified_result := -log(uniform) / rate
	verified_result = min(verified_result, MAX_MULTIPLIER)
	
	return "Verified: %.6fx (uniform: %.6f)" % [verified_result, uniform]


func _hide_fairness() -> void:
	fairness_panel.visible = false


func _on_play_again_pressed() -> void:
	result_panel.visible = false
	play_button.visible = true


func _on_back_pressed() -> void:
	GameState.return_to_main_menu()
