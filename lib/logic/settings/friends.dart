import 'dart:math';
import 'dart:developer' as developer;
import 'package:built_collection/built_collection.dart';

import '../../actions/actions.dart';
import '../../protocol/protocol.dart';
import '../../protocol/file.dart';
import '../../state/state.dart';

import '../../rand.dart';

AppState handleFriendsSettings(
    NodeName nodeName,
    FriendsSettingsView friendsSettingsView,
    BuiltMap<NodeName, NodeState> nodesStates,
    FriendsSettingsAction friendsSettingsAction,
    Random rand) {
  final createStateInner = (CardSettingsInnerView cardSettingsInnerView) =>
      AppState((b) => b
        ..nodesStates = nodesStates.toBuilder()
        ..viewState = ViewState.view(
            AppView.settings(SettingsView.cardSettings(CardSettingsView((b) => b
              ..nodeName = nodeName
              ..inner = cardSettingsInnerView)))));

  return friendsSettingsAction.match(
      back: () => friendsSettingsView.match(
          home: () => createStateInner(CardSettingsInnerView.home()),
          friendSettings: (_) => createStateInner(
              CardSettingsInnerView.friends(FriendsSettingsView.home())),
          newFriend: (_) => createStateInner(
              CardSettingsInnerView.friends(FriendsSettingsView.home())),
          shareInfo: () => createStateInner(
              CardSettingsInnerView.friends(FriendsSettingsView.home()))),
      selectNewFriend: () => createStateInner(CardSettingsInnerView.friends(
          FriendsSettingsView.newFriend(NewFriendView.select()))),
      newFriend: (newFriendAction) =>
          _handleNewFriend(nodeName, nodesStates, newFriendAction, rand),
      selectFriend: (friendPublicKey) => createStateInner(
          CardSettingsInnerView.friends(
              FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
                ..friendPublicKey = friendPublicKey
                ..inner = FriendSettingsInnerView.home())))),
      friendSettings: (friendSettingsAction) {
        final friendSettingsView = friendsSettingsView.match(
            home: () => null,
            friendSettings: (friendSettingsView) => friendSettingsView,
            newFriend: (_) => null,
            shareInfo: () => null);

        if (friendSettingsView == null) {
          developer
              .log('_handleFriendsSettings(): friendSettings: Incorrect view!');
          return createStateInner(
              CardSettingsInnerView.friends(friendsSettingsView));
        }

        return _handleFriendSettings(nodeName, friendSettingsView, nodesStates,
            friendSettingsAction, rand);
      },
      shareInfo: () =>
          createStateInner(CardSettingsInnerView.friends(FriendsSettingsView.shareInfo())));
}

AppState _handleNewFriend(
    NodeName nodeName,
    BuiltMap<NodeName, NodeState> nodesStates,
    NewFriendAction newFriendAction,
    Random rand) {
  final createStateInner = (CardSettingsInnerView cardSettingsInnerView) =>
      AppState((b) => b
        ..nodesStates = nodesStates.toBuilder()
        ..viewState = ViewState.view(
            AppView.settings(SettingsView.cardSettings(CardSettingsView((b) => b
              ..nodeName = nodeName
              ..inner = cardSettingsInnerView)))));

  return newFriendAction.match(
      back: () => createStateInner(
          CardSettingsInnerView.friends(FriendsSettingsView.home())),
      loadFriend: (friendFile) => createStateInner(
          CardSettingsInnerView.friends(FriendsSettingsView.newFriend(
              NewFriendView.name(friendFile.publicKey, friendFile.relays)))),
      addFriend: (friendName, friendFile) => _handleAddFriend(
          nodeName, nodesStates, friendName, friendFile, rand));
}

AppState _handleAddFriend(
    NodeName nodeName,
    BuiltMap<NodeName, NodeState> nodesStates,
    String friendName,
    FriendFile friendFile,
    Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];
  if (nodeState == null) {
    developer.log('_handleAddFriend(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleAddFriend(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final addFriend = AddFriend((b) => b
    ..friendPublicKey = friendFile.publicKey
    ..relays = friendFile.relays.toBuilder()
    ..name = friendName);

  final userToCompact = UserToCompact.addFriend(addFriend);
  final userToServer = UserToServer.node(nodeId, userToCompact);
  final requestId = genUid(rand);
  final userToServerAck = UserToServerAck((b) => b
    ..requestId = requestId
    ..inner = userToServer);

  final newFriendView =
      NewFriendView.name(friendFile.publicKey, friendFile.relays);
  final oldView = AppView.settings(SettingsView.cardSettings(CardSettingsView(
      (b) => b
        ..nodeName = nodeName
        ..inner = CardSettingsInnerView.friends(
            FriendsSettingsView.newFriend(newFriendView)))));
  final newView =
      AppView.settings(SettingsView.cardSettings(CardSettingsView((b) => b
        ..nodeName = nodeName
        ..inner = CardSettingsInnerView.friends(FriendsSettingsView.home()))));

  final nextRequests = BuiltList<UserToServerAck>([userToServerAck]);
  final optPendingRequest = OptPendingRequest.none();

  return AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.transition(
        oldView, newView, nextRequests, optPendingRequest));
}

AppState _handleFriendSettings(
    NodeName nodeName,
    FriendSettingsView friendSettingsView,
    BuiltMap<NodeName, NodeState> nodesStates,
    FriendSettingsAction friendSettingsAction,
    Random rand) {
  final createStateFriends = (FriendsSettingsView friendsSettingsView) =>
      AppState((b) => b
        ..nodesStates = nodesStates.toBuilder()
        ..viewState = ViewState.view(
            AppView.settings(SettingsView.cardSettings(CardSettingsView((b) => b
              ..nodeName = nodeName
              ..inner = CardSettingsInnerView.friends(friendsSettingsView))))));

  return friendSettingsAction.match(
      back: () => friendSettingsView.inner.match(
          home: () => createStateFriends(FriendsSettingsView.home()),
          resolve: () => createStateFriends(FriendsSettingsView.friendSettings(
              friendSettingsView
                  .rebuild((b) => b..inner = FriendSettingsInnerView.home()))),
          currencySettings: (_currency) => createStateFriends(
              FriendsSettingsView.friendSettings(friendSettingsView
                  .rebuild((b) => b..inner = FriendSettingsInnerView.home()))),
          newCurrency: () =>
              createStateFriends(FriendsSettingsView.friendSettings(friendSettingsView.rebuild((b) => b..inner = FriendSettingsInnerView.home())))),
      enableFriend: () => _handleEnableFriend(nodeName, friendSettingsView.friendPublicKey, nodesStates, rand),
      disableFriend: () => _handleDisableFriend(nodeName, friendSettingsView.friendPublicKey, nodesStates, rand),
      removeFriend: () => _handleRemoveFriend(nodeName, friendSettingsView.friendPublicKey, nodesStates, rand),
      removeCurrency: (currency) => _handleRemoveCurrency(nodeName, friendSettingsView.friendPublicKey, currency, nodesStates, rand),
      selectNewCurrency: () => createStateFriends(FriendsSettingsView.friendSettings(friendSettingsView.rebuild((b) => b..inner = FriendSettingsInnerView.newCurrency()))),
      newCurrency: (currency, remoteMaxDebt, rate) => _handleNewCurrency(currency, remoteMaxDebt, rate, nodeName, friendSettingsView.friendPublicKey, nodesStates, rand),
      selectCurrency: (currency) => createStateFriends(FriendsSettingsView.friendSettings(friendSettingsView.rebuild((b) => b..inner = FriendSettingsInnerView.currencySettings(currency)))),
      openCurrency: (currency) => _handleOpenCurrency(currency, nodeName, friendSettingsView.friendPublicKey, nodesStates, rand),
      closeCurrency: (currency) => _handleCloseCurrency(currency, nodeName, friendSettingsView.friendPublicKey, nodesStates, rand),
      updateCurrency: (currency, remoteMaxDebt, rate) => _handleUpdateCurrency(currency, remoteMaxDebt, rate, nodeName, friendSettingsView.friendPublicKey, nodesStates, rand),
      selectResolve: () => createStateFriends(FriendsSettingsView.friendSettings(friendSettingsView.rebuild((b) => b..inner = FriendSettingsInnerView.resolve()))),
      resolve: () => _handleResolve(nodeName, friendSettingsView.friendPublicKey, nodesStates, rand));
}

/// Queue outgoing UserToServer messages
AppState _queueUserToServer(
    Iterable<UserToServer> userToServers,
    BuiltMap<NodeName, NodeState> nodesStates,
    AppView oldView,
    AppView newView,
    Random rand) {
  final userToServerAcks = <UserToServerAck>[];
  for (final userToServer in userToServers) {
    final requestId = genUid(rand);
    final userToServerAck = UserToServerAck((b) => b
      ..requestId = requestId
      ..inner = userToServer);
    userToServerAcks.add(userToServerAck);
  }

  final nextRequests = BuiltList<UserToServerAck>(userToServerAcks);
  final optPendingRequest = OptPendingRequest.none();

  return AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.transition(
        oldView, newView, nextRequests, optPendingRequest));
}

AppState _handleEnableFriend(NodeName nodeName, PublicKey friendPublicKey,
    BuiltMap<NodeName, NodeState> nodesStates, Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleEnable(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleEnable(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final userToCompact = UserToCompact.enableFriend(friendPublicKey);
  final userToServer = UserToServer.node(nodeId, userToCompact);

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.home()));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));
  final newView = oldView;

  return _queueUserToServer(
      [userToServer], nodesStates, oldView, newView, rand);
}

AppState _handleDisableFriend(NodeName nodeName, PublicKey friendPublicKey,
    BuiltMap<NodeName, NodeState> nodesStates, Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleDisable(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleDisable(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final userToCompact = UserToCompact.disableFriend(friendPublicKey);
  final userToServer = UserToServer.node(nodeId, userToCompact);

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.home()));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));
  final newView = oldView;

  return _queueUserToServer(
      [userToServer], nodesStates, oldView, newView, rand);
}

AppState _handleRemoveFriend(NodeName nodeName, PublicKey friendPublicKey,
    BuiltMap<NodeName, NodeState> nodesStates, Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleUnfriend(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleUnfriend(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final userToCompact = UserToCompact.removeFriend(friendPublicKey);
  final userToServer = UserToServer.node(nodeId, userToCompact);

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.home()));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));

  final newCardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(FriendsSettingsView.home()));
  final newView =
      AppView.settings(SettingsView.cardSettings(newCardSettingsView));

  return _queueUserToServer(
      [userToServer], nodesStates, oldView, newView, rand);
}

AppState _handleRemoveCurrency(NodeName nodeName, PublicKey friendPublicKey,
    Currency currency, BuiltMap<NodeName, NodeState> nodesStates, Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleRemoveCurrency(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleRemoveCurrency(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final removeFriendCurrency = RemoveFriendCurrency((b) => b
    ..friendPublicKey = friendPublicKey
    ..currency = currency);
  final userToCompact =
      UserToCompact.removeFriendCurrency(removeFriendCurrency);
  final userToServer = UserToServer.node(nodeId, userToCompact);

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.home()));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));
  final newView = oldView;

  return _queueUserToServer(
      [userToServer], nodesStates, oldView, newView, rand);
}

AppState _handleNewCurrency(
    Currency currency,
    U128 remoteMaxDebt,
    Rate rate,
    NodeName nodeName,
    PublicKey friendPublicKey,
    BuiltMap<NodeName, NodeState> nodesStates,
    Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleNewCurrency(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleNewCurrency(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  // Note: We send two messages here (Rate + MaxDebt):
  final userToServers = <UserToServer>[];

  // SetFriendCurrencyRate:
  {
    final setFriendCurrencyRate = SetFriendCurrencyRate((b) => b
      ..friendPublicKey = friendPublicKey
      ..currency = currency
      ..rate = rate.toBuilder());
    final userToCompact =
        UserToCompact.setFriendCurrencyRate(setFriendCurrencyRate);
    final userToServer = UserToServer.node(nodeId, userToCompact);
    userToServers.add(userToServer);
  }

  // SetFriendCurrencyMaxDebt:
  {
    final setFriendCurrencyMaxDebt = SetFriendCurrencyMaxDebt((b) => b
      ..friendPublicKey = friendPublicKey
      ..currency = currency
      ..remoteMaxDebt = remoteMaxDebt);
    final userToCompact =
        UserToCompact.setFriendCurrencyMaxDebt(setFriendCurrencyMaxDebt);
    final userToServer = UserToServer.node(nodeId, userToCompact);
    userToServers.add(userToServer);
  }

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.newCurrency()));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));

  final newFriendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.home()));
  final newCardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(newFriendsSettingsView));
  final newView =
      AppView.settings(SettingsView.cardSettings(newCardSettingsView));

  return _queueUserToServer(userToServers, nodesStates, oldView, newView, rand);
}

AppState _handleUpdateCurrency(
    Currency currency,
    U128 remoteMaxDebt,
    Rate rate,
    NodeName nodeName,
    PublicKey friendPublicKey,
    BuiltMap<NodeName, NodeState> nodesStates,
    Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleUpdateCurrency(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleUpdateCurrency(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  // Note: We send two messages here (Rate + MaxDebt):
  final userToServers = <UserToServer>[];

  // SetFriendCurrencyRate:
  {
    final setFriendCurrencyRate = SetFriendCurrencyRate((b) => b
      ..friendPublicKey = friendPublicKey
      ..currency = currency
      ..rate = rate.toBuilder());
    final userToCompact =
        UserToCompact.setFriendCurrencyRate(setFriendCurrencyRate);
    final userToServer = UserToServer.node(nodeId, userToCompact);
    userToServers.add(userToServer);
  }

  // SetFriendCurrencyMaxDebt:
  {
    final setFriendCurrencyMaxDebt = SetFriendCurrencyMaxDebt((b) => b
      ..friendPublicKey = friendPublicKey
      ..currency = currency
      ..remoteMaxDebt = remoteMaxDebt);
    final userToCompact =
        UserToCompact.setFriendCurrencyMaxDebt(setFriendCurrencyMaxDebt);
    final userToServer = UserToServer.node(nodeId, userToCompact);
    userToServers.add(userToServer);
  }

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.currencySettings(currency)));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));

  final newFriendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.home()));
  final newCardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(newFriendsSettingsView));
  final newView =
      AppView.settings(SettingsView.cardSettings(newCardSettingsView));

  return _queueUserToServer(userToServers, nodesStates, oldView, newView, rand);
}

AppState _handleOpenCurrency(
    Currency currency,
    NodeName nodeName,
    PublicKey friendPublicKey,
    BuiltMap<NodeName, NodeState> nodesStates,
    Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleOpenCurrency(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleOpenCurrency(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final openFriendCurrency = OpenFriendCurrency((b) => b
    ..friendPublicKey = friendPublicKey
    ..currency = currency);
  final userToCompact = UserToCompact.openFriendCurrency(openFriendCurrency);
  final userToServer = UserToServer.node(nodeId, userToCompact);

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.currencySettings(currency)));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));
  final newView = oldView;

  return _queueUserToServer(
      [userToServer], nodesStates, oldView, newView, rand);
}

AppState _handleCloseCurrency(
    Currency currency,
    NodeName nodeName,
    PublicKey friendPublicKey,
    BuiltMap<NodeName, NodeState> nodesStates,
    Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleCloseCurrency(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleCloseCurrency(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final closeFriendCurrency = CloseFriendCurrency((b) => b
    ..friendPublicKey = friendPublicKey
    ..currency = currency);
  final userToCompact = UserToCompact.closeFriendCurrency(closeFriendCurrency);
  final userToServer = UserToServer.node(nodeId, userToCompact);

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.currencySettings(currency)));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));
  final newView = oldView;

  return _queueUserToServer(
      [userToServer], nodesStates, oldView, newView, rand);
}

AppState _handleResolve(NodeName nodeName, PublicKey friendPublicKey,
    BuiltMap<NodeName, NodeState> nodesStates, Random rand) {
  final createState = (AppView appView) => AppState((b) => b
    ..nodesStates = nodesStates.toBuilder()
    ..viewState = ViewState.view(appView));

  final nodeState = nodesStates[nodeName];

  if (nodeState == null) {
    developer.log('_handleResolve(): node $nodeName does not exist!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final nodeOpen =
      nodeState.inner.match(open: (nodeOpen) => nodeOpen, closed: () => null);

  final nodeId = nodeOpen.nodeId;
  if (nodeId == null) {
    developer.log('_handleResolve(): node $nodeName is not open!');
    return createState(AppView.settings(SettingsView.home()));
  }

  final friendReport = nodeOpen.compactReport.friends[friendPublicKey];
  if (friendReport == null) {
    developer.log(
        '_handleResolve(): node $nodeName: friend $friendPublicKey does not exist!');
    return createState(
        AppView.settings(SettingsView.cardSettings(CardSettingsView((b) => b
          ..inner = CardSettingsInnerView.friends(FriendsSettingsView.home())
          ..nodeName = nodeName))));
  }

  final channelInconsistentReport = friendReport.channelStatus.match(
      consistent: (channelConsistentReport) => null,
      inconsistent: (channelInconsistentReport) => channelInconsistentReport);

  if (channelInconsistentReport == null) {
    developer.log(
        '_handleResolve(): node $nodeName: friend $friendPublicKey channel is consistent!');
    return createState(
        AppView.settings(SettingsView.cardSettings(CardSettingsView((b) => b
          ..inner = CardSettingsInnerView.friends(FriendsSettingsView.home())
          ..nodeName = nodeName))));
  }

  ResetTermsReport remoteResetTerms;
  if (channelInconsistentReport.optRemoteResetTerms == null) {
    developer.log(
        '_handleResolve(): node $nodeName: friend $friendPublicKey: no remote terms received!');
    final friendSettings = FriendSettingsView((b) => b
      ..friendPublicKey = friendPublicKey
      ..inner = FriendSettingsInnerView.resolve());
    return createState(AppView.settings(SettingsView.cardSettings(
        CardSettingsView((b) => b
          ..inner = CardSettingsInnerView.friends(
              FriendsSettingsView.friendSettings(friendSettings))
          ..nodeName = nodeName))));
  } else {
    remoteResetTerms = channelInconsistentReport.optRemoteResetTerms;
  }

  final resetFriendChannel = ResetFriendChannel((b) => b
    ..friendPublicKey = friendPublicKey
    ..resetToken = remoteResetTerms.resetToken);

  final userToCompact = UserToCompact.resetFriendChannel(resetFriendChannel);
  final userToServer = UserToServer.node(nodeId, userToCompact);

  final friendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.resolve()));
  final cardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(friendsSettingsView));
  final oldView = AppView.settings(SettingsView.cardSettings(cardSettingsView));

  final newFriendsSettingsView =
      FriendsSettingsView.friendSettings(FriendSettingsView((b) => b
        ..friendPublicKey = friendPublicKey
        ..inner = FriendSettingsInnerView.home()));
  final newCardSettingsView = CardSettingsView((b) => b
    ..nodeName = nodeName
    ..inner = CardSettingsInnerView.friends(newFriendsSettingsView));
  final newView =
      AppView.settings(SettingsView.cardSettings(newCardSettingsView));

  return _queueUserToServer(
      [userToServer], nodesStates, oldView, newView, rand);
}
