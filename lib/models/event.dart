class Event {
  final String eventName;
  final String transactionHash;
  final int blockNumber;
  final Map<String, dynamic> data;

  Event({
    required this.eventName,
    required this.transactionHash,
    required this.blockNumber,
    required this.data,
  });
}
