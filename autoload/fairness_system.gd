extends Node

signal new_round_committed(server_seed_hash: String)

const SEED_LENGTH: int = 32  # 64 hex characters

var _current_server_seed: String = ""
var _current_server_seed_hash: String = ""
var _current_client_seed: String = ""
var _nonce: int = 0


func _ready() -> void:
	generate_new_server_seed()


func generate_new_server_seed() -> void:
	# Generate random 32 bytes and convert to hex
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(SEED_LENGTH / 2)
	_current_server_seed = random_bytes.hex_encode()
	
	# Create hash for commitment (shown to player before round)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(random_bytes)
	var hash_bytes := ctx.finish()
	_current_server_seed_hash = hash_bytes.hex_encode()
	
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


func generate_fair_random(min_val: float = 0.0, max_val: float = 1.0) -> float:
	# Combine server_seed:client_seed:nonce
	var message := "%s:%s:%d" % [_current_server_seed, _current_client_seed, _nonce]
	
	# HMAC-SHA256 using server_seed as key
	var crypto := Crypto.new()
	var hmac_bytes := crypto.hmac_digest(HashingContext.HASH_SHA256, 
		_current_server_seed.to_utf8_buffer(), message.to_utf8_buffer())
	
	# Convert first 8 bytes to uint64 for float generation
	var hex_str := hmac_bytes.hex_encode()
	var uint_val := hex_str.substr(0, 16).hex_to_int()
	
	# Normalize to 0.0 - 1.0 range
	var normalized := float(uint_val) / float(0xFFFFFFFFFFFFFFFF)
	
	return min_val + (normalized * (max_val - min_val))


func verify_round(server_seed: String, client_seed: String, nonce: int, 
		min_val: float = 0.0, max_val: float = 1.0) -> float:
	"""
	Verification method: Given revealed server_seed, recompute the outcome
	to prove fairness. Should match the original generate_fair_random call.
	"""
	var message := "%s:%s:%d" % [server_seed, client_seed, nonce]
	
	var crypto := Crypto.new()
	var hmac_bytes := crypto.hmac_digest(HashingContext.HASH_SHA256, 
		server_seed.to_utf8_buffer(), message.to_utf8_buffer())
	
	var hex_str := hmac_bytes.hex_encode()
	var uint_val := hex_str.substr(0, 16).hex_to_int()
	var normalized := float(uint_val) / float(0xFFFFFFFFFFFFFFFF)
	
	return min_val + (normalized * (max_val - min_val))


func reveal_server_seed() -> String:
	"""Returns the server seed for verification after round completes."""
	return _current_server_seed


func start_new_round() -> void:
	"""Call this after revealing previous seed to generate new commitment."""
	generate_new_server_seed()
