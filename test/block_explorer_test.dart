
import 'package:flutter_test/flutter_test.dart';
import 'package:evmrider/utils/block_explorer.dart';

void main() {
  group('BlockExplorer', () {
    test('cleans base url with trailing slash', () {
      const explorer = BlockExplorer('https://etherscan.io/');
      expect(explorer.transactionLink('0x123'), 'https://etherscan.io/tx/0x123');
    });

    test('works without trailing slash', () {
      const explorer = BlockExplorer('https://etherscan.io');
      expect(explorer.transactionLink('0x123'), 'https://etherscan.io/tx/0x123');
    });

    test('generates address link', () {
      const explorer = BlockExplorer('https://etherscan.io');
      expect(explorer.addressLink('0xabc'), 'https://etherscan.io/address/0xabc');
    });

    test('generates block link', () {
      const explorer = BlockExplorer('https://polygonscan.com');
      expect(explorer.blockLink(12345), 'https://polygonscan.com/block/12345');
    });
    
    test('trims whitespace', () {
      const explorer = BlockExplorer('  https://etherscan.io  ');
      expect(explorer.transactionLink('0x123'), 'https://etherscan.io/tx/0x123');
    });
  });
}
