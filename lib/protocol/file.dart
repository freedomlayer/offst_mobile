import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
// import 'package:built_union/built_union.dart';
// import 'package:meta/meta.dart';

import 'common.dart';
import 'compact.dart';

part 'file.g.dart';

// Types of shared file extensions we know how to handle
const String INVOICE_EXT = 'invoice';
const String COMMIT_EXT = 'commit';
const String FRIEND_EXT = 'friend';
const String RELAY_EXT = 'relay';
const String INDEX_EXT = 'index';
const String REMOTE_CARD_EXT = 'rcard';

abstract class InvoiceFile implements Built<InvoiceFile, InvoiceFileBuilder> {
  static Serializer<InvoiceFile> get serializer => _$invoiceFileSerializer;

  InvoiceId get invoiceId;
  Currency get currency;
  PublicKey get destPublicKey;
  U128 get destPayment;
  String get description;

  InvoiceFile._();
  factory InvoiceFile([void Function(InvoiceFileBuilder) updates]) =
      _$InvoiceFile;
}

// CommitFile is Commit
// RelayFile is RelayAddress

abstract class IndexServerFile
    implements Built<IndexServerFile, IndexServerFileBuilder> {
  static Serializer<IndexServerFile> get serializer =>
      _$indexServerFileSerializer;

  PublicKey get publicKey;
  NetAddress get address;

  IndexServerFile._();
  factory IndexServerFile([void Function(IndexServerFileBuilder) updates]) =
      _$IndexServerFile;
}

abstract class FriendFile implements Built<FriendFile, FriendFileBuilder> {
  static Serializer<FriendFile> get serializer => _$friendFileSerializer;

  PublicKey get publicKey;
  BuiltList<RelayAddress> get relays;

  FriendFile._();
  factory FriendFile([void Function(FriendFileBuilder) updates]) = _$FriendFile;
}

abstract class RemoteCardFile
    implements Built<RemoteCardFile, RemoteCardFileBuilder> {
  static Serializer<RemoteCardFile> get serializer =>
      _$remoteCardFileSerializer;

  PublicKey get nodePublicKey;
  NetAddress get nodeAddress;
  PrivateKey get appPrivateKey;

  RemoteCardFile._();
  factory RemoteCardFile([void Function(RemoteCardFileBuilder) updates]) =
      _$RemoteCardFile;
}

final fileSerializers = <Serializer>[
  InvoiceFile.serializer,
  IndexServerFile.serializer,
  FriendFile.serializer,
  RemoteCardFile.serializer,
];
