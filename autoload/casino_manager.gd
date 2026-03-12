extends Node

# ================================================
# CASINO MANAGER - Single autoload replacing 3 old ones
# Fixed hash logic + mines support + full functionality
# Godot 4.6 - 100% provably fair like Rainbet
# ================================================

signal balance_changed(new_balance: int)
signal insufficient_funds
signal new_round_committed(server_seed_hash: String)

enum GameType { MINES, SLIDE }
var current_game: GameType = GameType.MINES

const SEED_LENGTH: int = 32
const STARTING_BALANCE: int = 10000

var _balance: int = STARTING_BALANCE
var _current_server_seed: String = ""
var _current_server_seed_hash: String = ""
var _current_client_seed: String = ""
var _nonce: int = 0

func _ready() -> void:
	_balance = STARTING_BALANCE
	generate_new_server_seed()
	if _current_client_seed.is_empty():
		set_client_seed("default_client_seed")

# ==================== GAME STATE ====================
func change_scene_to_mines() -> void:
	current_game = GameType.MINES
	get_tree().change_scene_to_file("res://scenes/mines/mines_game.tscn")

func change_scene_to_slide() -> void:
	current_game = GameType.SLIDE
	get_tree().change_scene_to_file("res://scenes/slide/slide_game.tscn")

func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

# ==================== CURRENCY ====================
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

# ==================== PROVABLY FAIR (FIXED) ====================
func generate_new_server_seed() -> void:
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(SEED_LENGTH / 2)
	_current_server_seed = random_bytes.hex_encode()
	
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(random_bytes)
	_current_server_seed_hash = ctx.finish().hex_encode()
	
	new_round_committed.emit(_current_server_seed_hash)

func set_client_seed(seed: String) -> void:
	_current_client_seed = seed if not seed.is_empty() else "default_client_seed"

func get_client_seed() -> String:
	return _current_client_seed

func get_server_seed_hash() -> String:
	return _current_server_seed_hash

func increment_nonce() -> int:
	_nonce += 1
	return _nonce

func get_nonce() -> int:
	return _nonce

func reset_nonce() -> void:
	_nonce = 0

# FIXED HASH LOGIC - extra param makes every random call unique (mines shuffle works!)
func generate_fair_random(min_val: float = 0.0, max_val: float = 1.0, extra: Variant = null) -> float:
	var message := "%s:%s:%d" % [_current_server_seed, _current_client_seed, _nonce]
	if extra != null:
		message += ":%s" % str(extra)
	
	var crypto := Crypto.new()
	var hmac_bytes := crypto.hmac_digest(HashingContext.HASH_SHA256, 
		_current_server_seed.to_utf8_buffer(), message.to_utf8_buffer())
	
	var hex_str := hmac_bytes.hex_encode()
	var uint_val := hex_str.substr(0, 16).hex_to_int()
	var normalized := float(uint_val) / float(0xFFFFFFFFFFFFFFFF)
	
	return min_val + (normalized * (max_val - min_val))

# Verification uses exact same logic (now 100% match)
func verify_fair_random(server_seed: String, client_seed: String, nonce: int, 
		min_val: float = 0.0, max_val: float = 1.0, extra: Variant = null) -> float:
	var message := "%s:%s:%d" % [server_seed, client_seed, nonce]
	if extra != null:
		message += ":%s" % str(extra)
	
	var crypto := Crypto.new()
	var hmac_bytes := crypto.hmac_digest(HashingContext.HASH_SHA256, 
		server_seed.to_utf8_buffer(), message.to_utf8_buffer())
	
	var hex_str := hmac_bytes.hex_encode()
	var uint_val := hex_str.substr(0, 16).hex_to_int()
	var normalized := float(uint_val) / float(0xFFFFFFFFFFFFFFFF)
	
	return min_val + (normalized * (max_val - min_val))

func reveal_server_seed() -> String:
	return _current_server_seed

func start_new_round() -> void:
	generate_new_server_seed()
