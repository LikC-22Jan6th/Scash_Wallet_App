import 'package:flutter/foundation.dart';

@immutable
class Wallet {
  final String id;
  final String name;
  final String address;
  final String publicKey;
  final String encryptedPrivateKey;
  final String? mnemonic;

  const Wallet({
    required this.id,
    required this.name,
    required this.address,
    required this.publicKey,
    required this.encryptedPrivateKey,
    this.mnemonic,
  });

  Wallet copyWith({
    String? id,
    String? name,
    String? address,
    String? publicKey,
    String? encryptedPrivateKey,
    String? mnemonic,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      publicKey: publicKey ?? this.publicKey,
      encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
      mnemonic: mnemonic ?? this.mnemonic,
    );
  }

  // JSON 序列化 / 反序列化
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'publicKey': publicKey,
    'encryptedPrivateKey': encryptedPrivateKey,
    'mnemonic': mnemonic,
  };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    address: json['address'] ?? '',
    publicKey: json['publicKey'] ?? '',
    encryptedPrivateKey: json['encryptedPrivateKey'] ?? '',
    mnemonic: json['mnemonic'],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Wallet &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name &&
              address == other.address &&
              publicKey == other.publicKey &&
              encryptedPrivateKey == other.encryptedPrivateKey &&
              mnemonic == other.mnemonic;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      address.hashCode ^
      publicKey.hashCode ^
      encryptedPrivateKey.hashCode ^
      (mnemonic?.hashCode ?? 0);
}
