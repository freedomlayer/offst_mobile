import 'package:built_collection/built_collection.dart';

import '../protocol/protocol.dart';
import '../state/state.dart';

bool nodeActive(BuiltMap<NodeName, NodeState> nodesStates, NodeName nodeName) {
  final nodeState = nodesStates[nodeName];
  if (nodeState == null) {
    return false;
  }
  return nodeState.inner.isOpen;
}

bool nodeExists(BuiltMap<NodeName, NodeState> nodesStates, NodeName nodeName) {
  return nodesStates.containsKey(nodeName);
}

CompactReport getCompactReport(
    BuiltMap<NodeName, NodeState> nodesStates, NodeName nodeName) {
  final nodeState = nodesStates[nodeName];
  if (nodeState == null) {
    return null;
  }
  return nodeState.inner.match(
    closed: () => null,
    open: (nodeOpen) => nodeOpen.compactReport,
  );
}

bool invoiceExists(BuiltMap<NodeName, NodeState> nodesStates, NodeName nodeName,
    InvoiceId invoiceId) {
  final compactReport = getCompactReport(nodesStates, nodeName);
  if (compactReport == null) {
    return false;
  }
  final openInvoice = compactReport.openInvoices[invoiceId];
  return openInvoice != null;
}

OpenPayment getOpenPayment(BuiltMap<NodeName, NodeState> nodesStates,
    NodeName nodeName, PaymentId paymentId) {
  final compactReport = getCompactReport(nodesStates, nodeName);
  if (compactReport == null) {
    return null;
  }
  final openPayment = compactReport.openPayments[paymentId];
  return openPayment;
}

/*
FriendReport getFriendReport(
    BuiltMap<NodeName, NodeState> nodesStates, NodeName nodeName, PublicKey friendPublicKey) {
  final compactReport = getCompactReport(nodesStates, nodeName);
  if (compactReport == null) {
    return null;
  }
  return compactReport.friends[friendPublicKey];
}
*/

// ------------------------------------------------------------
// ------------------------------------------------------------

/// Adjust application's view given appState.
/// Relevant mostly for cases where an element is removed or becomes inactive, and the view
/// needs to be adjusted accordingly.
AppView adjustAppView(
    AppView appView, BuiltMap<NodeName, NodeState> nodesStates) {
  return appView.match(
    home: () => appView,
    buy: (buyView) => adjustBuyView(buyView, nodesStates),
    sell: (sellView) => adjustSellView(sellView, nodesStates),
    outTransactions: (outTransactionsView) => AppView.outTransactions(
        adjustOutTransactionsView(outTransactionsView, nodesStates)),
    inTransactions: (inTransactionsView) => AppView.inTransactions(
        adjustInTransactionsView(inTransactionsView, nodesStates)),
    balances: (balancesView) =>
        AppView.balances(adjustBalancesView(balancesView, nodesStates)),
    settings: (settingsView) =>
        AppView.settings(adjustSettingsView(settingsView, nodesStates)),
    about: () => appView,
  );
}

AppView adjustBuyView(
    BuyView buyView, BuiltMap<NodeName, NodeState> nodesStates) {
  return buyView.match(
      invoiceSelect: () => AppView.buy(buyView),
      invoiceInfo: (_invoiceFile) => AppView.buy(buyView),
      selectCard: (_invoiceFile) => AppView.buy(buyView));
}

AppView adjustSellView(
    SellView sellView, BuiltMap<NodeName, NodeState> nodesStates) {
  return sellView.match(
      selectCard: () => AppView.sell(sellView),
      invoiceDetails: (nodeName) => nodeActive(nodesStates, nodeName)
          ? AppView.sell(sellView)
          : AppView.home());
}

OutTransactionsView adjustOutTransactionsView(
    OutTransactionsView outTransactionsView,
    BuiltMap<NodeName, NodeState> nodesStates) {
  return outTransactionsView.match(
      home: () => outTransactionsView,
      transaction: (nodeName, paymentId) =>
          getOpenPayment(nodesStates, nodeName, paymentId) != null
              ? outTransactionsView
              : OutTransactionsView.home());
  /*
      sendCommit: (nodeName, paymentId) {
        final openPayment = getOpenPayment(nodesStates, nodeName, paymentId);
        if (openPayment == null) {
          return OutTransactionsView.home();
        }
        if (!openPayment.status.isCommit) {
          // We are not in the commit stage:
          return OutTransactionsView.transaction(nodeName, paymentId);
        }
        return outTransactionsView;
      });
      */
}

InTransactionsView adjustInTransactionsView(
    InTransactionsView inTransactionsView,
    BuiltMap<NodeName, NodeState> nodesStates) {
  final calcView = (nodeName, invoiceId) =>
      invoiceExists(nodesStates, nodeName, invoiceId)
          ? inTransactionsView
          : InTransactionsView.home();

  return inTransactionsView.match(
      home: () => inTransactionsView,
      transaction: (nodeName, invoiceId) => calcView(nodeName, invoiceId),
      collected: (nodeName, invoiceId) => calcView(nodeName, invoiceId),
      selectCardApplyCommit: (commit) => inTransactionsView);
}

BalancesView adjustBalancesView(
    BalancesView balancesView, BuiltMap<NodeName, NodeState> nodesStates) {
  return balancesView.match(
      selectCard: () => balancesView,
      cardBalances: (nodeName) {
        final nodeState = nodesStates[nodeName];
        if (nodeState == null) {
          return BalancesView.selectCard();
        }

        final nodeOpen = nodeState.inner
            .match(open: (nodeOpen) => nodeOpen, closed: () => null);

        if (nodeOpen == null) {
          return BalancesView.selectCard();
        }
        return balancesView;
      });
}

SettingsView adjustSettingsView(
    SettingsView settingsView, BuiltMap<NodeName, NodeState> nodesStates) {
  return settingsView.match(
      home: () => settingsView,
      cardSettings: (cardSettingsView) {
        final nodeState = nodesStates[cardSettingsView.nodeName];
        if (nodeState == null) {
          return SettingsView.home();
        }

        final cardSettingsInnerView =
            adjustCardSettingsInnerView(cardSettingsView.inner, nodeState);
        final newCardSettingsView = CardSettingsView((b) => b
          ..nodeName = cardSettingsView.nodeName
          ..inner = cardSettingsInnerView);
        return SettingsView.cardSettings(newCardSettingsView);
      },
      newCard: (_newCardView) => settingsView,
      selectCardAddRelay: (_) => settingsView,
      selectCardAddIndex: (_) => settingsView,
      selectCardAddFriend: (_) => settingsView);
}

CardSettingsInnerView adjustCardSettingsInnerView(
    CardSettingsInnerView cardSettingsInnerView, NodeState nodeState) {
  final compactReport = nodeState.inner.match(
    closed: () => null,
    open: (nodeOpen) => nodeOpen.compactReport,
  );

  if (compactReport == null) {
    return CardSettingsInnerView.home();
  }

  return cardSettingsInnerView.match(
      home: () => cardSettingsInnerView,
      friends: (friendsSettings) => CardSettingsInnerView.friends(
          adjustFriendsSettingsView(friendsSettings, compactReport)),
      relays: (relaysSettings) => CardSettingsInnerView.relays(
          adjustRelaysSettingsView(relaysSettings, compactReport)),
      indexServers: (indexServersSettingsView) =>
          CardSettingsInnerView.indexServers(adjustIndexServersSettingsView(
              indexServersSettingsView, compactReport)));
}

FriendsSettingsView adjustFriendsSettingsView(
    FriendsSettingsView friendsSettings, CompactReport compactReport) {
  return friendsSettings.match(
      home: () => friendsSettings,
      friendSettings: (friendSettings) {
        final friendReport =
            compactReport.friends[friendSettings.friendPublicKey];
        if (friendReport == null) {
          return FriendsSettingsView.home();
        }
        final newFriendSettingsInner =
            adjustFriendSettingsInnerView(friendSettings.inner, friendReport);
        final newFriendSettings = FriendSettingsView((b) => b
          ..inner = newFriendSettingsInner
          ..friendPublicKey = friendSettings.friendPublicKey);
        return FriendsSettingsView.friendSettings(newFriendSettings);
      },
      newFriend: (_newFriend) => friendsSettings,
      shareInfo: () => friendsSettings);
}

RelaysSettingsView adjustRelaysSettingsView(
    RelaysSettingsView relaysSettings, CompactReport compactReport) {
  return relaysSettings.match(
      home: () => relaysSettings,
      newRelaySelect: () => relaysSettings,
      newRelayName: (_) => relaysSettings);
}

IndexServersSettingsView adjustIndexServersSettingsView(
    IndexServersSettingsView indexServersSettings,
    CompactReport compactReport) {
  return indexServersSettings.match(
      home: () => indexServersSettings,
      newIndexSelect: () => indexServersSettings,
      newIndexName: (_) => indexServersSettings);
}

FriendSettingsInnerView adjustFriendSettingsInnerView(
    FriendSettingsInnerView friendSettingsInner, FriendReport friendReport) {
  return friendSettingsInner.match(
      home: () => friendSettingsInner,
      currencySettings: (currency) {
        return friendReport.channelStatus.match(
            inconsistent: (_) => FriendSettingsInnerView.home(),
            consistent: (channelConsistentReport) =>
                friendReport.currencyConfigs[currency] != null
                    ? friendSettingsInner
                    : FriendSettingsInnerView.home());
      },
      newCurrency: () => friendSettingsInner);
}
