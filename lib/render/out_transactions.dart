import 'package:flutter/material.dart';
import 'package:built_collection/built_collection.dart';

import '../protocol/protocol.dart';
import '../state/state.dart';
import '../actions/actions.dart';

import 'frame.dart';

Widget renderOutTransactions(
    OutTransactionsView outTransactionsView,
    BuiltMap<NodeName, NodeState> nodesStates,
    Function(OutTransactionsAction) queueAction) {
  return outTransactionsView.match(
      home: () => _renderHome(nodesStates, queueAction),
      transaction: (nodeName, paymentId) =>
          _renderTransaction(nodeName, paymentId, nodesStates, queueAction),
      sendCommit: (nodeName, paymentId) =>
          _renderSendCommit(nodeName, paymentId, nodesStates, queueAction));
}

/// A single outgoing transaction's information
class OutTransaction {
  final NodeName nodeName;
  Currency currency;
  final PaymentId paymentId;
  U128 destPayment;
  final String description;
  Generation generation;
  String status;

  OutTransaction(
      {this.nodeName,
      this.currency,
      this.paymentId,
      this.destPayment,
      this.description,
      this.generation,
      this.status});
}

String _statusAsString(OpenPaymentStatus openPaymentStatus) {
  return openPaymentStatus.match(
      searchingRoute: (_) => 'searching route',
      foundRoute: (_a, _b) => 'found route',
      sending: (_) => 'sending',
      commit: (_a, _b) => 'commit',
      success: (_a, _b, _c) => 'success',
      failure: (_) => 'failure');
}

List<OutTransaction> _loadTransactions(
    BuiltMap<NodeName, NodeState> nodesStates) {
  final outTransactions = <OutTransaction>[];

  nodesStates.forEach((nodeName, nodeState) {
    final nodeOpen =
        nodeState.inner.match(closed: () => null, open: (nodeOpen) => nodeOpen);

    if (nodeOpen == null) {
      return; // continue
    }

    final openPayments = nodeOpen.compactReport.openPayments;
    openPayments.forEach((paymentId, openPayment) {
      final outTransaction = OutTransaction(
          nodeName: nodeName,
          currency: openPayment.currency,
          paymentId: paymentId,
          destPayment: openPayment.destPayment,
          description: openPayment.description,
          generation: openPayment.generation,
          status: _statusAsString(openPayment.status));
      outTransactions.add(outTransaction);
    });
  });

  outTransactions.sort((a, b) {
    final cmpList = [
      // Sort chronologically
      a.generation.compareTo(b.generation),
      // Use PaymentId as tie breaker:
      a.paymentId.compareTo(b.paymentId)
    ];
    for (final val in cmpList) {
      if (val != 0) {
        return val;
      }
    }
    return 0;
  });

  return outTransactions;
}

Widget _renderHome(BuiltMap<NodeName, NodeState> nodesStates,
    Function(OutTransactionsAction) queueAction) {
  final outTransactions = _loadTransactions(nodesStates);
  final children = <Widget>[];

  for (final outTransaction in outTransactions) {
    final outEntry = Card(
        key: Key(outTransaction.paymentId.inner),
        child: InkWell(
            onTap: () => queueAction(OutTransactionsAction.selectPayment(
                outTransaction.nodeName, outTransaction.paymentId)),
            child: Text(
                '${outTransaction.nodeName.inner}: ${outTransaction.destPayment.inner}\n' +
                    '${outTransaction.description}\n' +
                    'status: ${outTransaction.status}')));
    children.add(outEntry);
  }

  final listView = ListView(padding: EdgeInsets.all(8), children: children);

  return frame(
      title: Text('Outgoing transactions'),
      body: listView,
      backAction: () => queueAction(OutTransactionsAction.back()));
}

Widget _renderTransaction(
    NodeName nodeName,
    PaymentId paymentId,
    BuiltMap<NodeName, NodeState> nodesStates,
    Function(OutTransactionsAction) queueAction) {
  throw UnimplementedError();
  /*
  return frame(
      title: Text('Outgoing transaction'),
      body: body,
      backAction: () => queueAction(OutTransactionsAction.back()));
  */
}

Widget _renderSendCommit(
    NodeName nodeName,
    PaymentId paymentId,
    BuiltMap<NodeName, NodeState> nodesStates,
    Function(OutTransactionsAction) queueAction) {
  throw UnimplementedError();
}
