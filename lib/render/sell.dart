import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:built_collection/built_collection.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../protocol/protocol.dart';
import '../state/state.dart';
import '../actions/actions.dart';

import 'utils/amount.dart';

import 'frame.dart';

Widget renderSell(SellView sellView, BuiltMap<NodeName, NodeState> nodesStates,
    Function(SellAction) queueAction) {
  return sellView.match(
      selectCard: () => _renderSelectCard(nodesStates, queueAction),
      invoiceDetails: (nodeName) =>
          InvoiceDetails(nodeName, nodesStates, queueAction));
}

Widget _renderSelectCard(BuiltMap<NodeName, NodeState> nodesStates,
    Function(SellAction) queueAction) {
  final children = <Widget>[];

  for (final nodeName in nodesStates.keys.toList()..sort()) {
    final nodeState = nodesStates[nodeName];
    // We only card that can be used for payment.
    final canCardPay = nodeState.inner.match(
        closed: () => false,
        open: (openNode) {
          for (final entry in openNode.compactReport.friends.entries) {
            final res = entry.value.channelStatus.match(
                inconsistent: (_) => false,
                consistent: (channelConsistentReport) =>
                    channelConsistentReport.currencyReports.isNotEmpty);
            if (res == true) {
              return true;
            }
          }
          return false;
        });

    final cardEntry = canCardPay
        ? ListTile(
            leading: Icon(Icons.credit_card),
            key: Key(nodeName.inner),
            title: Text('${nodeName.inner}'),
            onTap: () => queueAction(SellAction.selectCard(nodeName)))
        : ListTile(
            leading: Icon(Icons.credit_card),
            key: Key(nodeName.inner),
            title: Text('${nodeName.inner}'),
            enabled: false);

    children.add(cardEntry);
  }

  final body = Padding(
      padding: EdgeInsets.only(top: 14.0),
      child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Please select a card',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.all(8), children: children))
          ]));

  return frame(
      title: Text('New Invoice'),
      body: body,
      backAction: () => queueAction(SellAction.back()));
}

String _amountValidator(String amountString) {
  if (!verifyAmountString(amountString)) {
    return 'Must be a non negative value, up to $ACCURACY digits after decimal dot';
  }

  return null;
}

/// Get all useable currencies for a given card
List<Currency> _loadCurrencies(NodeState nodeState) {
  final currencies = Set<Currency>();

  nodeState.inner.match(
      closed: () => null,
      open: (openNode) {
        for (final entry in openNode.compactReport.friends.entries) {
          entry.value.channelStatus.match(
              inconsistent: (_) => null,
              consistent: (channelConsistentReport) =>
                  channelConsistentReport.currencyReports.forEach(
                      (currency, _currencyReport) => currencies.add(currency)));
        }
      });
  return List.from(currencies)..sort();
}

class InvoiceDetails extends StatefulWidget {
  final NodeName nodeName;
  final BuiltMap<NodeName, NodeState> nodesStates;
  final Function(SellAction) queueAction;

  InvoiceDetails(this.nodeName, this.nodesStates, this.queueAction, {Key key})
      : super(key: key);

  @override
  _InvoiceDetailsState createState() => _InvoiceDetailsState();
}

class _InvoiceDetailsState extends State<InvoiceDetails> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final nodeState = this.widget.nodesStates[this.widget.nodeName];
    assert(nodeState != null);
    final currencies = _loadCurrencies(nodeState);
    assert(currencies.isNotEmpty);

    Currency _currency;
    U128 _amount;
    String _description;

    final _submitForm = () {
      final FormState form = _formKey.currentState;

      if (!form.validate()) {
        // Form is not valid
      } else {
        // Save form fields:
        form.save();
        this.widget.queueAction(SellAction.createInvoice(
            this.widget.nodeName, _currency, _amount, _description));
      }
    };

    final body =
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
      final form = Form(
          key: _formKey,
          autovalidate: true,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: <Widget>[
              ListTile(
                  leading: const FaIcon(FontAwesomeIcons.creditCard),
                  title: Text('${this.widget.nodeName.inner}')),
              ListTile(
                  leading: const FaIcon(FontAwesomeIcons.yenSign),
                  title: DropdownButton<Currency>(
                      hint: Text('Select Currency'),
                      items: currencies
                          .map((currency) => DropdownMenuItem<Currency>(
                              key: Key(currency.inner),
                              child: Text('${currency.inner}'),
                              value: currency))
                          .toList(),
                      value: _currency,
                      onChanged: (newCurrency) =>
                          setState(() => _currency = newCurrency),
                      isExpanded: true)),
              ListTile(
                  leading: const FaIcon(FontAwesomeIcons.coins),
                  title: TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'Amount of currency units',
                      labelText: 'Amount',
                    ),
                    validator: _amountValidator,
                    keyboardType: TextInputType.number,
                    onSaved: (amountString) =>
                        _amount = stringToAmount(amountString),
                  )),
              ListTile(
                  leading: const FaIcon(FontAwesomeIcons.comment),
                  title: TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'What is this invoice for?',
                      labelText: 'Description',
                    ),
                    // TODO: Possibly add a validator?
                    keyboardType: TextInputType.text,
                    inputFormatters: [LengthLimitingTextInputFormatter(64)],
                    onSaved: (description) => _description = description,
                  )),
              SizedBox(height: 24.0),
              Center(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    RaisedButton.icon(
                      icon: Icon(Icons.done, color: Colors.green),
                      label: const Text('Ok'),
                      onPressed: _submitForm,
                    ),
                    SizedBox(width: 10.0),
                    FlatButton.icon(
                      icon: Icon(Icons.cancel, color: Colors.red),
                      label: const Text('Cancel'),
                      onPressed: () =>
                          this.widget.queueAction(SellAction.back()),
                    )
                  ])),
            ],
          ));

      return SafeArea(
          top: false,
          bottom: false,
          child: Padding(padding: EdgeInsets.only(top: 16.0), child: form));
    });

    return frame(
        title: Text('New invoice'),
        body: body,
        backAction: () => this.widget.queueAction(SellAction.back()));
  }
}
