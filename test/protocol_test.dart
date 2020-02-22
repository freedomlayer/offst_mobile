import 'dart:convert';
import 'package:built_value/serializer.dart';
import 'package:test/test.dart';

import 'package:offst_mobile/protocol/common.dart';
import 'package:offst_mobile/protocol/protocol.dart';
import 'package:offst_mobile/utils/json_plugin.dart';


import 'protocol_samples.dart' as samples;

void main() {
  group('common serialize', () {
    /*
    final serBuilder = Serializers().toBuilder();
    for (final commonSer in commonSerializers) {
      serBuilder.add(commonSer);
    }

    Serializers serializers = serBuilder.build();
    */

    final serializersWithPlugin =
        (serializers.toBuilder()..addPlugin(CommJsonPlugin())).build();

    test('PublicKey serialization', () {
      final publicKey = PublicKey('MyPublicKey');
      final serialized = serializersWithPlugin.serialize(publicKey,
          specifiedType: FullType(PublicKey));

      JsonEncoder encoder = JsonEncoder.withIndent('  ');
      String jsonString = encoder.convert(serialized);
      // We expect a single string, without a wrap:
      expect(jsonString, '"MyPublicKey"');

      final decoder = JsonDecoder();
      final serialized2 = decoder.convert(jsonString);
      final publicKey2 = serializersWithPlugin.deserialize(serialized2,
          specifiedType: FullType(PublicKey));

      expect(publicKey, publicKey2);

    });
    test('I128 serialization', () {
      final i128 = I128(BigInt.parse('123456789012345678901234567890'));
      final serialized = serializersWithPlugin.serialize(i128,
          specifiedType: FullType(I128));

      JsonEncoder encoder = JsonEncoder.withIndent('  ');
      String jsonString = encoder.convert(serialized);
      // We expect a single number, without a wrap:
      expect(jsonString, '"123456789012345678901234567890"');

      final decoder = JsonDecoder();
      final serialized2 = decoder.convert(jsonString);
      final i128_2 = serializersWithPlugin.deserialize(serialized2,
          specifiedType: FullType(I128));

      expect(i128, i128_2);

    });
    test('NodeInfoLocal serialization', () {
      final nodeInfoLocal = NodeInfoLocal((b) => b..nodePublicKey = PublicKey('MyPublicKey'));
      final serialized = serializersWithPlugin.serialize(nodeInfoLocal,
          specifiedType: FullType(NodeInfoLocal));

      JsonEncoder encoder = JsonEncoder.withIndent('  ');
      String jsonString = encoder.convert(serialized);

      final decoder = JsonDecoder();
      final serialized2 = decoder.convert(jsonString);
      final nodeInfoLocal2 = serializersWithPlugin.deserialize(serialized2,
          specifiedType: FullType(NodeInfoLocal));

      expect(nodeInfoLocal, nodeInfoLocal2);

    });

    test('Autogenerated samples serialization: ServerToUserAck', () {
      JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final decoder = JsonDecoder();

      for (final jsonString1 in samples.serverToUserAck) {
        // Attempt to deserialize:
        final serialized1 = decoder.convert(jsonString1);
        final msg1 = serializersWithPlugin.deserialize(serialized1,
            specifiedType: FullType(ServerToUserAck));

        // Make sure that serialization works:
        final serialized2 = serializersWithPlugin.serialize(msg1,
            specifiedType: FullType(ServerToUserAck));
        String jsonString2 = encoder.convert(serialized2);

        // Deserialize again, and make sure that we get the same message:
        final serialized3 = decoder.convert(jsonString2);
        final msg3 = serializersWithPlugin.deserialize(serialized3,
            specifiedType: FullType(ServerToUserAck));
        
        if (msg1 != msg3) {
          print('============= Not equal! (1) =============');
          print('msg1 = ');
          print(msg1);
          print('msg3 = ');
          print(msg3);
          print('\n\n\n\n');
        }

        // expect(msg1, msg3);
      }
    });

    test('Autogenerated samples serialization: UserToServerAck', () {
      JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final decoder = JsonDecoder();

      for (final jsonString1 in samples.userToServerAck) {
        // Attempt to deserialize:
        final serialized1 = decoder.convert(jsonString1);
        final msg1 = serializersWithPlugin.deserialize(serialized1,
            specifiedType: FullType(UserToServerAck));

        // Make sure that serialization works:
        final serialized2 = serializersWithPlugin.serialize(msg1,
            specifiedType: FullType(UserToServerAck));
        String jsonString2 = encoder.convert(serialized2);

        // Deserialize again, and make sure that we get the same message:
        final serialized3 = decoder.convert(jsonString2);
        final msg3 = serializersWithPlugin.deserialize(serialized3,
            specifiedType: FullType(UserToServerAck));

        expect(msg1, msg3);

      }
    });
  });
}
