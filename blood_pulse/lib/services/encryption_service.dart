/// BloodPulse — Encryption Service
///
/// Hybrid RSA-2048 + AES-256-GCM End-to-End Encryption Engine.
///
/// Architecture:
///   • On first run, generates an RSA-2048 keypair for the local user.
///   • Private key is stored in [FlutterSecureStorage] (never leaves the device).
///   • Public key is stored in Firestore at `/users/{uid}/publicKey`.
///   • Encryption: one-time AES-256-GCM key → encrypt message → RSA-OAEP-encrypt
///     the AES key with recipient's public key → both ciphertexts go to Firestore.
///   • Decryption: RSA-OAEP-decrypt AES key with local private key → AES-GCM-decrypt.
///   • Firestore stores only ciphertext — the server cannot read any message.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

// ─── Storage Key Constants ────────────────────────────────────────────────────

const String _kPrivateKeyPem = 'bp_e2ee_rsa_private_key';
const String _kPublicKeyPem  = 'bp_e2ee_rsa_public_key';

// ─── EncryptedMessagePayload ──────────────────────────────────────────────────

/// Wire-format for an E2EE message sent to Firestore.
///
/// Both fields are Base64-encoded so they can be stored as Firestore strings.
final class EncryptedMessagePayload {
  const EncryptedMessagePayload({
    required this.encryptedAesKey,
    required this.ciphertext,
    required this.iv,
    required this.authTag,
  });

  /// RSA-OAEP-encrypted AES-256 session key (Base64).
  final String encryptedAesKey;

  /// AES-GCM ciphertext (Base64).
  final String ciphertext;

  /// 12-byte GCM nonce (Base64).
  final String iv;

  /// 16-byte GCM authentication tag (Base64).
  final String authTag;

  Map<String, dynamic> toMap() => {
        'encryptedAesKey': encryptedAesKey,
        'ciphertext':      ciphertext,
        'iv':              iv,
        'authTag':         authTag,
      };

  factory EncryptedMessagePayload.fromMap(Map<String, dynamic> m) =>
      EncryptedMessagePayload(
        encryptedAesKey: m['encryptedAesKey'] as String,
        ciphertext:      m['ciphertext']      as String,
        iv:              m['iv']              as String,
        authTag:         m['authTag']         as String,
      );
}

// ─── EncryptionService ────────────────────────────────────────────────────────

/// Singleton encryption service providing RSA keypair management and
/// hybrid RSA+AES-256-GCM message encryption/decryption.
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  // flutter_secure_storage 10.x: use default AndroidOptions (no deprecated params).
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Keypair Management ──────────────────────────────────────────────────

  /// Ensures an RSA-2048 keypair exists on this device.
  ///
  /// Returns the PEM-encoded public key to be uploaded to Firestore.
  Future<String> ensureKeypairExists() async {
    final existing = await _secureStorage.read(key: _kPublicKeyPem);
    if (existing != null && existing.isNotEmpty) return existing;
    return _generateAndStoreKeypair();
  }

  /// Returns the locally stored RSA public key PEM string, or `null`.
  Future<String?> getLocalPublicKey() =>
      _secureStorage.read(key: _kPublicKeyPem);

  /// Deletes the local keypair from secure storage.
  Future<void> deleteKeypair() async {
    await _secureStorage.delete(key: _kPrivateKeyPem);
    await _secureStorage.delete(key: _kPublicKeyPem);
  }

  // ── Message Encryption ──────────────────────────────────────────────────

  /// Encrypts [plaintext] with AES-256-GCM, then RSA-OAEP-encrypts the AES key.
  EncryptedMessagePayload encrypt({
    required String plaintext,
    required String recipientPublicKeyPem,
  }) {
    final aesKey = _randomBytes(32); // 256-bit
    final iv     = _randomBytes(12); // 96-bit GCM nonce

    final plainBytes = Uint8List.fromList(utf8.encode(plaintext));
    final gcmResult  = _aesGcmEncrypt(aesKey, iv, plainBytes);

    final rsaPublicKey    = _publicKeyFromPem(recipientPublicKeyPem);
    final encryptedAesKey = _rsaEncrypt(aesKey, rsaPublicKey);

    return EncryptedMessagePayload(
      encryptedAesKey: base64.encode(encryptedAesKey),
      ciphertext:      base64.encode(gcmResult.ciphertext),
      iv:              base64.encode(iv),
      authTag:         base64.encode(gcmResult.authTag),
    );
  }

  // ── Message Decryption ──────────────────────────────────────────────────

  /// Decrypts an [EncryptedMessagePayload] using the locally stored private key.
  ///
  /// Returns plaintext, or `null` on any decryption failure.
  Future<String?> decrypt(EncryptedMessagePayload payload) async {
    try {
      final privateKeyPem = await _secureStorage.read(key: _kPrivateKeyPem);
      if (privateKeyPem == null) return null;

      final rsaPrivateKey   = _privateKeyFromPem(privateKeyPem);
      final encryptedAesKey = base64.decode(payload.encryptedAesKey);
      final ciphertext      = base64.decode(payload.ciphertext);
      final iv              = base64.decode(payload.iv);
      final authTag         = base64.decode(payload.authTag);

      final aesKey     = _rsaDecrypt(encryptedAesKey, rsaPrivateKey);
      final plainBytes = _aesGcmDecrypt(
        Uint8List.fromList(aesKey),
        Uint8List.fromList(iv),
        Uint8List.fromList(ciphertext),
        Uint8List.fromList(authTag),
      );
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }

  // ── RSA Keypair Generation ──────────────────────────────────────────────

  String _generateAndStoreKeypair() {
    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          _buildSecureRandom(),
        ),
      );

    final pair    = keyGen.generateKeyPair();
    final pubKey  = pair.publicKey;
    final privKey = pair.privateKey;

    final pubPem  = _encodePublicKeyToPem(pubKey);
    final privPem = _encodePrivateKeyToPem(privKey);

    // Store asynchronously — caller awaits ensureKeypairExists().
    _secureStorage.write(key: _kPublicKeyPem,  value: pubPem);
    _secureStorage.write(key: _kPrivateKeyPem, value: privPem);

    return pubPem;
  }

  // ── RSA Encrypt / Decrypt ───────────────────────────────────────────────

  Uint8List _rsaEncrypt(Uint8List data, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return _processBlocks(cipher, data);
  }

  List<int> _rsaDecrypt(List<int> data, RSAPrivateKey privateKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return _processBlocks(cipher, Uint8List.fromList(data));
  }

  Uint8List _processBlocks(AsymmetricBlockCipher cipher, Uint8List input) {
    final output = <int>[];
    var offset   = 0;
    while (offset < input.length) {
      final end = (offset + cipher.inputBlockSize).clamp(0, input.length);
      output.addAll(cipher.process(input.sublist(offset, end)));
      offset = end;
    }
    return Uint8List.fromList(output);
  }

  // ── AES-256-GCM ────────────────────────────────────────────────────────

  ({Uint8List ciphertext, Uint8List authTag}) _aesGcmEncrypt(
    Uint8List key,
    Uint8List iv,
    Uint8List plaintext,
  ) {
    final params = AEADParameters(
      KeyParameter(key),
      128, // 128-bit auth tag
      iv,
      Uint8List(0),
    );
    final cipher = GCMBlockCipher(AESEngine())..init(true, params);
    final output = Uint8List(cipher.getOutputSize(plaintext.length));
    var len = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
    len += cipher.doFinal(output, len);
    // GCM appends the 16-byte auth tag after the ciphertext.
    return (
      ciphertext: Uint8List.sublistView(output, 0, output.length - 16),
      authTag:    Uint8List.sublistView(output, output.length - 16),
    );
  }

  Uint8List _aesGcmDecrypt(
    Uint8List key,
    Uint8List iv,
    Uint8List ciphertext,
    Uint8List authTag,
  ) {
    final params = AEADParameters(
      KeyParameter(key),
      128,
      iv,
      Uint8List(0),
    );
    // Reattach auth tag so GCM can verify it.
    final combined = Uint8List(ciphertext.length + authTag.length)
      ..setAll(0, ciphertext)
      ..setAll(ciphertext.length, authTag);
    final cipher = GCMBlockCipher(AESEngine())..init(false, params);
    final output = Uint8List(cipher.getOutputSize(combined.length));
    var len = cipher.processBytes(combined, 0, combined.length, output, 0);
    len += cipher.doFinal(output, len);
    return Uint8List.sublistView(output, 0, len);
  }

  // ── PEM Encoding ───────────────────────────────────────────────────────

  /// Encodes an RSA public key to PKCS#1 PEM format.
  String _encodePublicKeyToPem(RSAPublicKey key) {
    final seq = ASN1Sequence();
    seq.add(ASN1Integer(key.modulus));
    seq.add(ASN1Integer(key.exponent));
    final der = seq.encode();
    return '-----BEGIN PUBLIC KEY-----\n'
        '${_breakBase64(base64.encode(der))}\n'
        '-----END PUBLIC KEY-----';
  }

  /// Encodes an RSA private key to PKCS#1 PEM format.
  String _encodePrivateKeyToPem(RSAPrivateKey key) {
    final seq = ASN1Sequence();
    seq.add(ASN1Integer(BigInt.zero));
    seq.add(ASN1Integer(key.modulus));
    seq.add(ASN1Integer(key.publicExponent));
    seq.add(ASN1Integer(key.privateExponent));
    seq.add(ASN1Integer(key.p));
    seq.add(ASN1Integer(key.q));
    seq.add(ASN1Integer(
        key.privateExponent! % (key.p! - BigInt.one)));
    seq.add(ASN1Integer(
        key.privateExponent! % (key.q! - BigInt.one)));
    seq.add(ASN1Integer(key.q!.modInverse(key.p!)));
    final der = seq.encode();
    return '-----BEGIN RSA PRIVATE KEY-----\n'
        '${_breakBase64(base64.encode(der))}\n'
        '-----END RSA PRIVATE KEY-----';
  }

  // ── PEM Decoding ───────────────────────────────────────────────────────

  RSAPublicKey _publicKeyFromPem(String pem) {
    final b64 = _stripPemHeaders(pem);
    final der = base64.decode(b64);
    final seq = ASN1Sequence.fromBytes(Uint8List.fromList(der));
    final n   = (seq.elements![0] as ASN1Integer).integer!;
    final e   = (seq.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(n, e);
  }

  RSAPrivateKey _privateKeyFromPem(String pem) {
    final b64 = _stripPemHeaders(pem);
    final der = base64.decode(b64);
    final seq = ASN1Sequence.fromBytes(Uint8List.fromList(der));
    final e   = seq.elements!;
    return RSAPrivateKey(
      (e[1] as ASN1Integer).integer!, // modulus
      (e[3] as ASN1Integer).integer!, // private exponent
      (e[4] as ASN1Integer).integer!, // p
      (e[5] as ASN1Integer).integer!, // q
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────

  Uint8List _randomBytes(int count) {
    final rng  = Random.secure();
    final buf  = Uint8List(count);
    for (var i = 0; i < count; i++) {
      buf[i] = rng.nextInt(256);
    }
    return buf;
  }

  SecureRandom _buildSecureRandom() {
    final r    = FortunaRandom();
    final seed = _randomBytes(32);
    r.seed(KeyParameter(seed));
    return r;
  }

  String _stripPemHeaders(String pem) => pem
      .replaceAll(RegExp(r'-----[^-]+-----'), '')
      .replaceAll('\n', '')
      .replaceAll('\r', '')
      .trim();

  String _breakBase64(String b64, [int lineLen = 64]) {
    final buf = StringBuffer();
    for (var i = 0; i < b64.length; i += lineLen) {
      buf.writeln(b64.substring(i, (i + lineLen).clamp(0, b64.length)));
    }
    return buf.toString().trimRight();
  }
}
