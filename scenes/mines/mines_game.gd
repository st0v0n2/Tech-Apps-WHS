extends Control

const GRID_SIZE: int = 25
const MAX_MINES: int = 24

@onready var balance_display: Label = %BalanceDisplay
@onready var mines_count: SpinBox = %MinesCount
@onready var play_button: Button = %PlayButton
@onready var grid_container: GridContainer = %GridContainer
@onready var multiplier_label: Label = %MultiplierLabel
@onready var next_multiplier_label: Label = %NextMultiplierLabel
@onready var cash_out_button: Button = %CashOutButton
@onready var bet_input: HBoxContainer = $MainLayout/BetInput
@onready var fairness_panel: Panel = %FairnessPanel

var _tiles: Array[Button] = []
var _is_playing: bool = false
var _current_bet: int = 0
var _mine_indices: Array[int] = []
var _revealed_count: int = 0
var _current_multiplier: float = 1.0
var _server_seed_used: String = ""
var _nonce_used: int = 0

var _multiplier_table: Dictionary = {}


func _ready() -> void:
	CurrencyManager.balance_changed.connect(_on_balance_changed)
	_on_balance_changed(CurrencyManager.get_balance())
	
	# Cache tile references
	for i in range(grid_container.get_child_count()):
		var tile := grid_container.get_child(i) as Button
		_tiles.append(tile)
		tile.pressed.connect(_on_tile_pressed.bind(i))
		tile.disabled = true
	
	_build_multiplier_table()
	_reset_game_state()
	
	# Connect cash out button
	cash_out_button.pressed.connect(_on_cash_out_pressed)
	
	# Connect fairness panel close button
	var close_btn: Button = fairness_panel.get_node_or_null("VBoxContainer/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_hide_fairness)


func _on_balance_changed(new_balance: int) -> void:
	balance_display.text = "Balance: %d" % new_balance


func _build_multiplier_table() -> void:
	for mines in range(1, 25):
		_multiplier_table[mines] = {}
		var safe_tiles := GRID_SIZE - mines
		
		for revealed in range(1, safe_tiles + 1):
			var compound_prob := 1.0
			for r in range(1, revealed + 1):
				var rs := safe_tiles - (r - 1)
				var rt := GRID_SIZE - (r - 1)
				compound_prob *= float(rs) / float(rt)
			
			var house_edge_multiplier := (1.0 / compound_prob) * 0.99
			_multiplier_table[mines][revealed] = snapped(house_edge_multiplier, 0.01)


func _reset_game_state() -> void:
	_is_playing = false
	_mine_indices.clear()
	_revealed_count = 0
	_current_multiplier = 1.0
	
	play_button.disabled = false
	mines_count.editable = true
	cash_out_button.disabled = true
	
	multiplier_label.text = "Current: 0.00x"
	next_multiplier_label.text = "Next: %.2fx" % _get_multiplier(1)
	
	for tile in _tiles:
		tile.disabled = true
		tile.modulate = Color.WHITE
		tile.get_node("ColorRect").color = Color(0.2, 0.5, 0.8)


func _get_multiplier(revealed: int) -> float:
	var mines := int(mines_count.value)
	if _multiplier_table.has(mines) and _multiplier_table[mines].has(revealed):
		return _multiplier_table[mines][revealed]
	return 1.0


func _on_play_pressed() -> void:
	if _is_playing:
		return
	
	var bet: int = bet_input.get_bet()
	if not CurrencyManager.place_bet(bet):
		return
	
	_current_bet = bet
	_is_playing = true
	_server_seed_used = FairnessSystem.reveal_server_seed()
	_nonce_used = FairnessSystem.get_nonce()
	
	_generate_mines()
	
	play_button.disabled = true
	mines_count.editable = false
	cash_out_button.disabled = false
	
	for tile in _tiles:
		tile.disabled = false
	
	multiplier_label.text = "Current: 1.00x"
	next_multiplier_label.text = "Next: %.2fx" % _get_multiplier(1)
	
	FairnessSystem.increment_nonce()
	FairnessSystem.start_new_round()


func _generate_mines() -> void:
	var num_mines := int(mines_count.value)
	var available_indices := range(GRID_SIZE)
	_mine_indices.clear()
	
	for i in range(GRID_SIZE - 1, 0, -1):
		var j = int(FairnessSystem.generate_fair_random(0, i + 1))
		if j>i:
			j=i
		var temp = available_indices[i]
		available_indices[i] = available_indices[j]
		available_indices[j] = temp


func _on_tile_pressed(index: int) -> void:
	if not _is_playing:
		return
	
	var tile := _tiles[index]
	tile.disabled = true
	
	if index in _mine_indices:
		tile.get_node("ColorRect").color = Color(0.9, 0.2, 0.2)
		_game_over(false)
	else:
		tile.get_node("ColorRect").color = Color(0.2, 0.8, 0.3)
		_revealed_count += 1
		_current_multiplier = _get_multiplier(_revealed_count)
		
		multiplier_label.text = "Current: %.2fx" % _current_multiplier
		
		var next_mult := _get_multiplier(_revealed_count + 1)
		if _revealed_count < (GRID_SIZE - int(mines_count.value)):
			next_multiplier_label.text = "Next: %.2fx" % next_mult
		else:
			next_multiplier_label.text = "Max reached!"
			_cash_out()


func _on_cash_out_pressed() -> void:
	if not _is_playing:
		return
	_cash_out()


func _cash_out() -> void:
	var winnings := int(_current_bet * _current_multiplier)
	CurrencyManager.add_winnings(winnings)
	_game_over(true)


func _game_over(won: bool) -> void:
	_is_playing = false
	cash_out_button.disabled = true
	
	for mine_idx in _mine_indices:
		var tile := _tiles[mine_idx]
		tile.get_node("ColorRect").color = Color(0.9, 0.2, 0.2)
	
	for tile in _tiles:
		tile.disabled = true
	
	var outcome_text := "Won %d coins (%.2fx)" % [int(_current_bet * _current_multiplier), _current_multiplier] if won else "Lost %d coins (hit mine)" % _current_bet
	
	fairness_panel.setup(_server_seed_used, FairnessSystem.get_client_seed(), 
		_nonce_used, outcome_text, _verify_mines_round)
	fairness_panel.visible = true
	
	play_button.text = "PLAY AGAIN"
	play_button.disabled = false


func _verify_mines_round() -> String:
	var crypto := Crypto.new()
	var message := "%s:%s:%d" % [_server_seed_used, FairnessSystem.get_client_seed(), _nonce_used]
	var hmac_bytes: PackedByteArray = crypto.hmac_digest(HashingContext.HASH_SHA256, 
		_server_seed_used.to_utf8_buffer(), message.to_utf8_buffer())
	
	var verification_indices := range(GRID_SIZE)
	for i in range(GRID_SIZE - 1, 0, -1):
		var hex_str := hmac_bytes.hex_encode()
		var uint_val := hex_str.substr(0, 16).hex_to_int()
		var j := int((float(uint_val) / float(0xFFFFFFFFFFFFFFFF)) * (i + 1))
		
		var temp = verification_indices[i]
		verification_indices[i] = verification_indices[j]
		verification_indices[j] = temp
		
		hmac_bytes = crypto.hmac_digest(HashingContext.HASH_SHA256, 
			hmac_bytes, str(i).to_utf8_buffer())
	
	var num_mines := int(mines_count.value)
	var verified_mines := []
	for i in range(num_mines):
		verified_mines.append(verification_indices[i])
	
	return "Mines at indices: %s" % str(verified_mines)


func _hide_fairness() -> void:
	fairness_panel.visible = false
	_reset_game_state()


func _on_back_pressed() -> void:
	GameState.return_to_main_menu()
