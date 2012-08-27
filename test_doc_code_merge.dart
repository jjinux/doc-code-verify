#import('package:unittest/unittest.dart');

#import('doc_code_merge.dart');

void main() {
  // This is just a test of a test :)
  test('add', () =>
    expect(add(2, 2), 4));
}