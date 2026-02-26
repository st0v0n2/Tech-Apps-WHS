extends Control

@onready var balance_display: Label = %BalanceDisplay
@onready var fairness_panel: Panel = %FairnessPanel
@onready var server_hash_label: Label = %ServerHashLabel
@onready var client_seed_input: LineEdit = %ClientSeedInput
@onready var nonce_label: Label = %NonceLabel

#sources
#https://en.wikipedia.org/wiki/HMAC

#read
#https://en.wikipedia.org/wiki/Pareto_distribution


func _ready() -> void:
	CurrencyManager.balance_changed.connect(_on_balance_changed)
	_update_balance_display(CurrencyManager.get_balance())
	
	FairnessSystem.new_round_committed.connect(_on_new_round_committed)
	_update_fairness_display()
	
	# Set default client seed if empty
	if FairnessSystem.get_client_seed().is_empty():
		FairnessSystem.set_client_seed("default_client_seed")
	client_seed_input.text = FairnessSystem.get_client_seed()


func _on_balance_changed(new_balance: int) -> void:
	_update_balance_display(new_balance)


func _update_balance_display(balance: int) -> void:
	balance_display.text = "Balance: %s coins" % balance


func _on_new_round_committed(server_seed_hash: String) -> void:
	_update_fairness_display()


func _update_fairness_display() -> void:
	server_hash_label.text = "Server Seed Hash (SHA256):\n%s" % FairnessSystem.get_server_seed_hash()
	nonce_label.text = "Current Nonce: %d" % FairnessSystem.get_nonce()


func _on_mines_button_pressed() -> void:
	GameState.change_scene_to_mines()


func _on_slide_button_pressed() -> void:
	GameState.change_scene_to_slide()


func _on_reset_balance_pressed() -> void:
	CurrencyManager.reset_balance()


func _on_fairness_button_pressed() -> void:
	fairness_panel.visible = true
	_update_fairness_display()


func _on_close_fairness_pressed() -> void:
	fairness_panel.visible = false


func _on_generate_client_seed_pressed() -> void:
	var crypto := Crypto.new()
	var random_bytes := crypto.generate_random_bytes(16)
	var new_seed: String = random_bytes.hex_encode()  # Explicit type added here too
	client_seed_input.text = new_seed
	FairnessSystem.set_client_seed(new_seed)
