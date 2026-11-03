class SavedHost {
  const SavedHost({
    required this.serverId,
    required this.name,
    required this.addresses,
    required this.port,
    required this.signingPublicKey,
    this.remoteEndpoint,
  });

  final String serverId;
  final String name;
  final List<String> addresses;
  final int port;
  final String signingPublicKey;
  final String? remoteEndpoint;
}
