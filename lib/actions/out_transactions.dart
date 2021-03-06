import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:built_union/built_union.dart';
import 'package:meta/meta.dart';

import '../protocol/common.dart';

part 'out_transactions.g.dart';

@BuiltUnion()
class OutTransactionsAction extends _$OutTransactionsAction {
  static Serializer<OutTransactionsAction> get serializer =>
      _$outTransactionsActionSerializer;

  OutTransactionsAction.back() : super.back();
  OutTransactionsAction.selectPayment(NodeName nodeName, PaymentId paymentId)
      : super.selectPayment(nodeName, paymentId);

  OutTransactionsAction.confirmFees(NodeName nodeName, PaymentId paymentId)
      : super.confirmFees(nodeName, paymentId);
  OutTransactionsAction.cancelPayment(NodeName nodeName, PaymentId paymentId)
      : super.cancelPayment(nodeName, paymentId);

  OutTransactionsAction.discardPayment(NodeName nodeName, PaymentId paymentId)
      : super.discardPayment(nodeName, paymentId);
  // OutTransactionsAction.resendCommit() : super.resendCommit();
}
