
class BlockExplorer {
  final String baseUrl;

  const BlockExplorer(this.baseUrl);

  String get _cleanBaseUrl {
    var url = baseUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String transactionLink(String hash) {
    return '$_cleanBaseUrl/tx/$hash';
  }

  String addressLink(String address) {
    return '$_cleanBaseUrl/address/$address';
  }
  
  String blockLink(int blockNumber) {
    return '$_cleanBaseUrl/block/$blockNumber';
  }
}
