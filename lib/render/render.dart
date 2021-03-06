import 'package:flutter/material.dart';

import 'package:built_collection/built_collection.dart';

import '../state/state.dart';
import '../protocol/protocol.dart';
import '../actions/actions.dart';

import 'consts.dart';
import 'home.dart';
import 'buy.dart';
import 'sell.dart';
import 'in_transactions.dart';
import 'out_transactions.dart';
import 'balances.dart';
import 'settings.dart';
import 'about.dart';
import 'frame.dart';

import 'theme.dart';

import '../logger.dart';

final logger = createLogger('render::render');

/// This is what we show to the user before we open the process
Widget renderNotReady() {
  final home = frame(
      title: Text(APP_TITLE),
      body: Center(child: CircularProgressIndicator(value: null)));

  return MaterialApp(title: APP_TITLE, theme: appTheme(), home: home);
}

/// Rendering when we are connected to the process
Widget render(AppState appState, Function(AppAction) queueAction) {
  final home = appState.viewState.match(
      view: (appView) =>
          renderAppView(appView, appState.nodesStates, queueAction),
      transition: (oldView, newView, nextRequests, optPendingRequest) =>
          renderTransition(oldView, appState.nodesStates));

  return MaterialApp(title: APP_TITLE, theme: appTheme(), home: home);
}

Widget renderAppView(AppView appView, BuiltMap<NodeName, NodeState> nodesStates,
    Function(AppAction) queueAction) {
  return appView.match(
    home: () => renderHome(
        nodesStates, (homeAction) => queueAction(AppAction.home(homeAction))),
    buy: (buyView) => renderBuy(buyView, nodesStates,
        (buyAction) => queueAction(AppAction.buy(buyAction))),
    sell: (sellView) => renderSell(sellView, nodesStates,
        (sellAction) => queueAction(AppAction.sell(sellAction))),
    inTransactions: (inTransactionsView) => renderInTransactions(
        inTransactionsView,
        nodesStates,
        (inTransactionsAction) =>
            queueAction(AppAction.inTransactions(inTransactionsAction))),
    outTransactions: (outTransactionsView) => renderOutTransactions(
        outTransactionsView,
        nodesStates,
        (outTransactionsAction) =>
            queueAction(AppAction.outTransactions(outTransactionsAction))),
    balances: (balancesView) => renderBalances(balancesView, nodesStates,
        (balancesAction) => queueAction(AppAction.balances(balancesAction))),
    settings: (settingsView) => renderSettings(settingsView, nodesStates,
        (settingsAction) => queueAction(AppAction.settings(settingsAction))),
    about: () =>
        renderAbout((aboutAction) => queueAction(AppAction.about(aboutAction))),
  );
}

/// A transition view: We are waiting for some operations to complete
Widget renderTransition(
    AppView oldView, BuiltMap<NodeName, NodeState> nodesStates) {
  final noQueueAction = (AppAction appAction) {
    logger.w('Received action $appAction during transition.');
  };
  // TODO: Possibly add some kind of shading over the old view, to let the user know
  // something is in progress.
  return MaterialApp(
      title: APP_TITLE,
      theme: appTheme(),
      home: Stack(children: <Widget>[
        renderAppView(oldView, nodesStates, noQueueAction),
        Center(child: CircularProgressIndicator(value: null)),
      ]));
}
