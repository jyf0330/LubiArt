extends RefCounted

## Transport port. Production WebSocket/ENet adapters implement this surface;
## GameSession and the authoritative host remain transport-independent.

signal connected(metadata: Dictionary)
signal disconnected(metadata: Dictionary)
signal command_response(response: Dictionary)
signal full_snapshot_received(response: Dictionary)
signal transport_error(error: Dictionary)


func connect_transport() -> bool:
	return false


func disconnect_transport() -> void:
	pass


func is_transport_connected() -> bool:
	return false


func send_command(_request: Dictionary) -> bool:
	return false


func request_full_snapshot() -> bool:
	return false
