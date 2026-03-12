extends Control

# ================================================
# MINES GAME - FINAL VERSION (GitHub .tscn structure)
# Warnings fixed + separate current/next labels + 0% edge payouts + single CasinoManager
# Provably-fair, Rainbet style, dynamic updates, zero errors
# ================================================

const GRID_SIZE: int = 25
const HOUSE_EDGE: float = 0.0  # 0% = max payouts (adjust up for edge)

@onready var balance_display: Label = %BalanceDisplay
@onready var mines_count: SpinBox = %MinesCount
@onready var play_button: Button = %PlayButton
@onready var grid_container: GridContainer = %GridContainer
@onready var multiplier_label: Label = %MultiplierLabel
@onready var next_multiplier_label: Label = %NextMultiplierLabel
@onready var cash_out_button: Button = %CashOutButton
@onready var bet_input: HBoxContainer = $MainLayout/BetInput
@onready var fairness_panel: Panel = %FairnessPanel

var tile_buttons: Array[Button] = []
var mine_positions: Array[int] = []
var revealed_safe: int = 0
var current_bet: int = 0
var game_active: bool = false
var current_multiplier: float = 1.0
var num_safe: int = 0

func _ready() -> void:
	CasinoManager.balance_changed.connect(_update_balance_ui)
	_update_balance_ui(CasinoManager.get_balance())
	
	# Cache the 25 pre-instanced tiles (exactly as your .tscn has them)
	for child in grid_container.get_children():
		var btn := child as Button
		if btn:
			btn.pressed.connect(_tile_pressed.bind(tile_buttons.size()))
			tile_buttons.append(btn)
	
	_reset_visual_grid()
	
	multiplier_label.text = "Current: 1.00x"
	next_multiplier_label.text = "Next: 1.00x"
	fairness_panel.visible = false

func _update_balance_ui(new_balance: int) -> void:
	balance_display.text = "Balance: %d" % new_balance

func _reset_visual_grid() -> void:
	for btn in tile_buttons:
		btn.text = "?"
		btn.disabled = false
		btn.modulate = Color.WHITE

func _on_play_pressed() -> void:
	if game_active:
		return
	
	current_bet = bet_input.get_bet()
	if not CasinoManager.place_bet(current_bet):
		multiplier_label.text = "Not enough balance!"
		next_multiplier_label.text = ""
		return
	
	# FIXED RANDOMIZATION - fresh seed every round
	CasinoManager.start_new_round()
	CasinoManager.reset_nonce()
	
	game_active = true
	revealed_safe = 0
	current_multiplier = 1.0
	mine_positions.clear()
	
	play_button.disabled = true
	cash_out_button.disabled = false
	
	# PROVABLY-FAIR MINE PLACEMENT - safe indexing
	var positions = range(GRID_SIZE)
	for i in GRID_SIZE:
		var rand_idx = int(CasinoManager.generate_fair_random(0, float(positions.size()) - 0.000001, "mines_pos_" + str(i)))
		mine_positions.append(positions[rand_idx])
		positions.remove_at(rand_idx)
	
	var num_mines = int(mines_count.value)
	mine_positions = mine_positions.slice(0, num_mines)
	num_safe = GRID_SIZE - num_mines
	
	_reset_visual_grid()
	_update_multiplier_display()  # Show initial "Next: x.xx"

func _tile_pressed(idx: int) -> void:
	if not game_active or tile_buttons[idx].text != "?":
		return
	
	var is_mine = mine_positions.has(idx)
	tile_buttons[idx].disabled = true
	
	if is_mine:
		tile_buttons[idx].text = "💣"
		tile_buttons[idx].modulate = Color.RED
		_lose_game()
	else:
		tile_buttons[idx].text = "💎"
		tile_buttons[idx].modulate = Color.LIME
		revealed_safe += 1
		
		# HIGHER PAYOUTS - scales with mines
		current_multiplier *= (float(GRID_SIZE - (revealed_safe - 1)) / float(num_safe - (revealed_safe - 1))) * (1.0 - HOUSE_EDGE)
		_update_multiplier_display()

func _lose_game() -> void:
	game_active = false
	play_button.disabled = false
	cash_out_button.disabled = true
	multiplier_label.text = "💥 BOOM! Mine hit. Lost %d" % current_bet
	next_multiplier_label.text = ""
	
	# Reveal all mines
	for i in GRID_SIZE:
		if mine_positions.has(i) and tile_buttons[i].text == "?":
			tile_buttons[i].text = "💣"
			tile_buttons[i].modulate = Color.RED
			tile_buttons[i].disabled = true

func _on_cash_out_pressed() -> void:
	if not game_active:
		return
	var winnings = int(current_bet * current_multiplier)
	CasinoManager.add_winnings(winnings)
	multiplier_label.text = "💰 Cashed out +%d!" % winnings
	next_multiplier_label.text = ""
	_end_game_win()

func _end_game_win() -> void:
	game_active = false
	play_button.disabled = false
	cash_out_button.disabled = true

func _update_multiplier_display() -> void:
	if revealed_safe >= num_safe:
		multiplier_label.text = "All safe! x%.2f" % current_multiplier
		next_multiplier_label.text = ""
		return
	
	var next_ratio = (float(GRID_SIZE - revealed_safe) / float(num_safe - revealed_safe)) * (1.0 - HOUSE_EDGE)
	var next_mult = current_multiplier * next_ratio
	multiplier_label.text = "Current: %.2fx" % current_multiplier
	next_multiplier_label.text = "Next: %.2fx" % next_mult

func _on_back_pressed() -> void:
	CasinoManager.return_to_main_menu()
