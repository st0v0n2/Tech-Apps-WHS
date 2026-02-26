extends Panel

@onready var server_seed_label: Label = %ServerSeedLabel
@onready var client_seed_label: Label = %ClientSeedLabel
@onready var nonce_label: Label = %NonceLabel
@onready var outcome_label: Label = %OutcomeLabel
@onready var verification_result: Label = %VerificationResult

var _server_seed: String = ""
var _client_seed: String = ""
var _nonce: int = 0
var _outcome_text: String = ""
var _verify_callback: Callable


func _ready() -> void:
	var verify_button: Button = $VBoxContainer/VerifyButton
	verify_button.pressed.connect(_on_verify_pressed)


func setup(server_seed: String, client_seed: String, nonce: int, 
		outcome_text: String, verify_callback: Callable) -> void:
	_server_seed = server_seed
	_client_seed = client_seed
	_nonce = nonce
	_outcome_text = outcome_text
	_verify_callback = verify_callback
	
	server_seed_label.text = "Server Seed: %s" % server_seed
	client_seed_label.text = "Client Seed: %s" % client_seed
	nonce_label.text = "Nonce: %d" % nonce
	outcome_label.text = "Game Outcome: %s" % outcome_text
	verification_result.text = ""


func _on_verify_pressed() -> void:
	if _verify_callback.is_valid():
		var result: String = _verify_callback.call()
		verification_result.text = "✓ Verification Successful!\nRecomputed: %s" % result
	else:
		verification_result.text = "✗ Verification failed - no callback provided"
