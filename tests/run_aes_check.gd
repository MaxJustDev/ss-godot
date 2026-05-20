## Standalone AES verification runner — does NOT require GUT.
##
## Run with:
##   godot --headless --path . -s tests/run_aes_check.gd
##
## Prints OK per vector and exits 0 on success. On mismatch, prints the
## expected/actual hex for the first failing vector and exits 1.
##
## Same vectors as tests/unit/test_aes_helper.gd. Kept separate so the M1
## verification can be run on a CI box that does not yet have GUT vendored.
extends SceneTree

const AesHelper := preload("res://addons/sai_services/util/aes_helper.gd")

const FIXED_KEY_HEX := "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
const FIXED_IV_HEX := "0f0e0d0c0b0a09080706050403020100"


static func _hex_to_bytes(hex: String) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	while i < hex.length():
		out.append(hex.substr(i, 2).hex_to_int())
		i += 2
	return out


static func _bytes_to_hex(b: PackedByteArray) -> String:
	var s := ""
	for byte in b:
		s += "%02x" % byte
	return s


func _initialize() -> void:
	var failures := 0
	var total := 0

	# Vector set A — default passphrase (base64 output via wrapper)
	var default_cases := [
		["hello world", "9oHnTIaE82JI92J35spSSQ=="],
		[
			"The quick brown fox jumps over the lazy dog.",
			"65XbAiIQ4ejK63nBNX67eaw85m4KTp8v4XaGFtUk1RVdOOvYLBhHHOcCyb0higZw"
		],
		["café 🎮", "W2AqNZj/AHWp5gtJjMjiZQ=="],
		["YELLOW SUBMARINE", "7wesbJvaHXsc8QVWaoS0Wa0PtI0tzcMt3DEiFG3IbRk="],
	]
	for case in default_cases:
		total += 1
		var plain: String = case[0]
		var expected: String = case[1]
		var got := AesHelper.encrypt_with_default_passphrase(plain)
		if got != expected:
			failures += 1
			printerr("FAIL default-passphrase encrypt: plain=%s" % plain)
			printerr("   expected b64: %s" % expected)
			printerr("   actual   b64: %s" % got)
		else:
			print("OK   default-passphrase encrypt: %s" % plain)
		# round-trip
		total += 1
		var roundtrip := AesHelper.decrypt_with_default_passphrase(expected)
		if roundtrip != plain:
			failures += 1
			printerr("FAIL default-passphrase decrypt: plain=%s got=%s" % [plain, roundtrip])
		else:
			print("OK   default-passphrase decrypt: %s" % plain)

	# Empty short-circuit
	total += 2
	if AesHelper.encrypt_with_default_passphrase("") == "":
		print('OK   default-passphrase encrypt("") = ""')
	else:
		failures += 1
		printerr('FAIL default-passphrase encrypt("") did not short-circuit')
	if AesHelper.decrypt_with_default_passphrase("") == "":
		print('OK   default-passphrase decrypt("") = ""')
	else:
		failures += 1
		printerr('FAIL default-passphrase decrypt("") did not short-circuit')

	# Vector set B — raw encrypt() with fixed key/IV (hex output)
	var key := _hex_to_bytes(FIXED_KEY_HEX)
	var iv := _hex_to_bytes(FIXED_IV_HEX)
	var raw_cases := [
		[PackedByteArray(), "daf015b15d25544a9510b84fb6d94efd"],
		["hello world".to_utf8_buffer(), "7e9a97128ef0b4a45935313b08430fda"],
		[
			"The quick brown fox jumps over the lazy dog.".to_utf8_buffer(),
			"925c81ee81fae7d66040fade898963245afeab7af7697a0762fe3f72ebfe8a356d6c722d7f08f7c5d45a6db04d8606f3"
		],
		["café 🎮".to_utf8_buffer(), "8e3b135e9c503d50131bd92c54661c38"],
		[
			"YELLOW SUBMARINE".to_utf8_buffer(),
			"134deee4fb08e5e807b242cc549520fa416bd663fb5effca9f85f9dcc6b305f5"
		],
	]
	for case in raw_cases:
		total += 1
		var plain: PackedByteArray = case[0]
		var expected_hex: String = case[1]
		var cipher := AesHelper.encrypt(plain, key, iv)
		var got_hex := _bytes_to_hex(cipher)
		if got_hex != expected_hex:
			failures += 1
			printerr("FAIL raw encrypt: plain_hex=%s" % _bytes_to_hex(plain))
			printerr("   expected hex: %s" % expected_hex)
			printerr("   actual   hex: %s" % got_hex)
		else:
			print("OK   raw encrypt: plain_hex=%s" % _bytes_to_hex(plain))
		total += 1
		var decrypted := AesHelper.decrypt(cipher, key, iv)
		if _bytes_to_hex(decrypted) != _bytes_to_hex(plain):
			failures += 1
			printerr("FAIL raw decrypt round-trip")
			printerr("   expected: %s" % _bytes_to_hex(plain))
			printerr("   actual:   %s" % _bytes_to_hex(decrypted))
		else:
			print("OK   raw decrypt round-trip")

	# Random round-trip stress
	total += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE
	var stress_failures := 0
	for trial in 32:
		var plain_len: int = rng.randi_range(0, 64)
		var plain := PackedByteArray()
		plain.resize(plain_len)
		for i in plain_len:
			plain[i] = rng.randi() & 0xff
		var k := PackedByteArray()
		k.resize(32)
		for i in 32:
			k[i] = rng.randi() & 0xff
		var v := PackedByteArray()
		v.resize(16)
		for i in 16:
			v[i] = rng.randi() & 0xff
		var c := AesHelper.encrypt(plain, k, v)
		if c.size() == 0 or c.size() % 16 != 0:
			stress_failures += 1
			continue
		var d := AesHelper.decrypt(c, k, v)
		if _bytes_to_hex(d) != _bytes_to_hex(plain):
			stress_failures += 1
	if stress_failures == 0:
		print("OK   random round-trip stress (32 trials)")
	else:
		failures += 1
		printerr("FAIL random round-trip stress: %d/32 trials failed" % stress_failures)

	print("")
	print("Summary: %d/%d checks passed" % [total - failures, total])
	if failures == 0:
		print("ALL VECTORS PASSED — M2 gate CLEAR")
		quit(0)
	else:
		printerr("FAILED — M2 gate BLOCKED")
		quit(1)
