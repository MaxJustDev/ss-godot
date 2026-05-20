## AesHelper - AES-256-CBC + PKCS7 helper, matches .NET's `Aes.Create()`
## defaults used by the upstream Unity SDK so that ciphertext produced here
## can be decrypted by the C# build, and vice-versa.
##
## upstream: ss-unity/Assets/SaiGame/Scripts/Common/SaiEncryption.cs:8
##
## Test vectors must be verified against .NET output before relying on
## interop. See `_test_vectors()` for a quick self-check that uses the
## SDK's built-in passphrase; cross-platform parity is a separate M1 task
## (see CLAUDE.md §F.4).
class_name AesHelper
extends RefCounted

## Same passphrase used by the upstream SDK. Anything encrypted with
## `encrypt_with_default_passphrase()` is wire-compatible with the C# SDK.
## upstream: SaiEncryption.cs:10
const ENCRYPTION_PASSPHRASE := "SaiGame2026SecureKeyForEncryption"

const AES_BLOCK_SIZE := 16
const AES_KEY_SIZE := 32


## Encrypt raw bytes. `iv` length MUST be 16, `key` length MUST be 16/24/32.
## Returns the ciphertext including PKCS7 padding. Returns an empty byte
## array on error.
##
## upstream: SaiEncryption.cs:26
static func encrypt(
	plaintext: PackedByteArray, key: PackedByteArray, iv: PackedByteArray
) -> PackedByteArray:
	if iv.size() != AES_BLOCK_SIZE:
		push_error("AesHelper.encrypt: IV must be 16 bytes, got %d" % iv.size())
		return PackedByteArray()
	if not _is_valid_key_size(key.size()):
		push_error("AesHelper.encrypt: key must be 16/24/32 bytes, got %d" % key.size())
		return PackedByteArray()
	var padded: PackedByteArray = _pkcs7_pad(plaintext, AES_BLOCK_SIZE)
	var ctx := AESContext.new()
	var err: int = ctx.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	if err != OK:
		push_error("AesHelper.encrypt: AESContext.start failed (%d)" % err)
		return PackedByteArray()
	var cipher: PackedByteArray = ctx.update(padded)
	ctx.finish()
	return cipher


## Decrypt raw bytes. Strips PKCS7 padding. Returns an empty byte array on error.
##
## upstream: SaiEncryption.cs:62
static func decrypt(
	ciphertext: PackedByteArray, key: PackedByteArray, iv: PackedByteArray
) -> PackedByteArray:
	if iv.size() != AES_BLOCK_SIZE:
		push_error("AesHelper.decrypt: IV must be 16 bytes, got %d" % iv.size())
		return PackedByteArray()
	if not _is_valid_key_size(key.size()):
		push_error("AesHelper.decrypt: key must be 16/24/32 bytes, got %d" % key.size())
		return PackedByteArray()
	if ciphertext.size() == 0 or ciphertext.size() % AES_BLOCK_SIZE != 0:
		push_error("AesHelper.decrypt: ciphertext size must be a positive multiple of 16")
		return PackedByteArray()
	var ctx := AESContext.new()
	var err: int = ctx.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	if err != OK:
		push_error("AesHelper.decrypt: AESContext.start failed (%d)" % err)
		return PackedByteArray()
	var padded: PackedByteArray = ctx.update(ciphertext)
	ctx.finish()
	return _pkcs7_unpad(padded, AES_BLOCK_SIZE)


## Encrypt a UTF-8 string and return a base64-encoded ciphertext string.
## Mirrors `SaiEncryption.Encrypt(string)` from the Unity SDK.
##
## upstream: SaiEncryption.cs:12
static func encrypt_with_default_passphrase(plaintext: String) -> String:
	if plaintext.is_empty():
		return ""
	var key: PackedByteArray = _derive_default_key()
	var iv: PackedByteArray = _derive_default_iv()
	var cipher: PackedByteArray = encrypt(plaintext.to_utf8_buffer(), key, iv)
	if cipher.is_empty():
		return ""
	return Marshalls.raw_to_base64(cipher)


## Decrypt a base64-encoded ciphertext produced by `encrypt_with_default_passphrase`
## (or the .NET counterpart). Returns "" on failure.
##
## upstream: SaiEncryption.cs:48
static func decrypt_with_default_passphrase(base64_ciphertext: String) -> String:
	if base64_ciphertext.is_empty():
		return ""
	var key: PackedByteArray = _derive_default_key()
	var iv: PackedByteArray = _derive_default_iv()
	var cipher: PackedByteArray = Marshalls.base64_to_raw(base64_ciphertext)
	if cipher.is_empty():
		return ""
	var plain: PackedByteArray = decrypt(cipher, key, iv)
	if plain.is_empty():
		return ""
	return plain.get_string_from_utf8()


## Quick self-check. Encrypt-then-decrypt the same string and confirm we
## get back the input. NOT a real cross-platform vector test — that lives
## in a tests scene per CLAUDE.md §F.4.
##
## Returns true if the round trip succeeded.
static func _test_vectors() -> bool:
	var sample := "SaiGame2026 — round trip test ✔"
	var cipher: String = encrypt_with_default_passphrase(sample)
	if cipher.is_empty():
		return false
	var roundtrip: String = decrypt_with_default_passphrase(cipher)
	return roundtrip == sample


# -------------------------------------------------------------------------
# Internals
# -------------------------------------------------------------------------


static func _derive_default_key() -> PackedByteArray:
	# upstream: SaiEncryption.cs:19-24 — copy first 32 bytes of UTF-8 passphrase
	# into a zero-padded 32-byte buffer.
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(AES_KEY_SIZE)
	buf.fill(0)
	var src: PackedByteArray = ENCRYPTION_PASSPHRASE.to_utf8_buffer()
	var copy_len: int = min(src.size(), AES_KEY_SIZE)
	for i in copy_len:
		buf[i] = src[i]
	return buf


static func _derive_default_iv() -> PackedByteArray:
	# upstream: SaiEncryption.cs:19-24 — first 16 bytes of UTF-8 passphrase,
	# zero-padded.
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(AES_BLOCK_SIZE)
	buf.fill(0)
	var src: PackedByteArray = ENCRYPTION_PASSPHRASE.to_utf8_buffer()
	var copy_len: int = min(src.size(), AES_BLOCK_SIZE)
	for i in copy_len:
		buf[i] = src[i]
	return buf


static func _is_valid_key_size(size: int) -> bool:
	return size == 16 or size == 24 or size == 32


static func _pkcs7_pad(data: PackedByteArray, block_size: int) -> PackedByteArray:
	var pad_len: int = block_size - (data.size() % block_size)
	# PKCS7 always adds at least one byte; if data is block-aligned we add a
	# full block of `block_size` bytes.
	var out: PackedByteArray = data.duplicate()
	for _i in pad_len:
		out.append(pad_len)
	return out


static func _pkcs7_unpad(data: PackedByteArray, block_size: int) -> PackedByteArray:
	if data.size() == 0:
		return data
	var pad_len: int = data[data.size() - 1]
	if pad_len <= 0 or pad_len > block_size or pad_len > data.size():
		# Padding looks invalid — return as-is rather than silently truncating
		# so callers can see something is off in tests.
		push_error("AesHelper._pkcs7_unpad: invalid padding length %d" % pad_len)
		return PackedByteArray()
	# Verify all padding bytes match.
	for i in range(data.size() - pad_len, data.size()):
		if data[i] != pad_len:
			push_error("AesHelper._pkcs7_unpad: corrupt padding byte at %d" % i)
			return PackedByteArray()
	return data.slice(0, data.size() - pad_len)
