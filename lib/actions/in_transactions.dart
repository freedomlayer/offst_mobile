import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:built_union/built_union.dart';
import 'package:meta/meta.dart';

import '../protocol/common.dart';
import '../protocol/compact.dart';

part 'in_transactions.g.dart';

@BuiltUnion()
class InTransactionsAction extends _$InTransactionsAction {
  static Serializer<InTransactionsAction> get serializer =>
      _$inTransactionsActionSerializer;

  InTransactionsAction.back() : super.back();
  InTransactionsAction.selectInvoice(NodeName nodeName, InvoiceId invoiceId)
      : super.selectInvoice(nodeName, invoiceId);
  InTransactionsAction.applyCommit(NodeName nodeName, Commit commit)
      : super.applyCommit(nodeName, commit);
  /*
  InTransactionsAction.resendInvoice(NodeName nodeName, InvoiceId invoiceId)
      : super.resendInvoice(nodeName, invoiceId);
  */
  InTransactionsAction.collectInvoice(NodeName nodeName, InvoiceId invoiceId)
      : super.collectInvoice(nodeName, invoiceId);
  InTransactionsAction.cancelInvoice(NodeName nodeName, InvoiceId invoiceId)
      : super.cancelInvoice(nodeName, invoiceId);
}
