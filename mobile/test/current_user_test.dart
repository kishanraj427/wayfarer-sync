import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/features/auth/models/current_user.dart';

void main() {
  test('parses user json with names', () {
    final user = CurrentUser.fromJson({
      'id': 'u1', 'email': 'kunal@essentia.dev', 'firstName': 'Kunal', 'lastName': 'Sharma',
    });
    expect(user.displayName, 'Kunal Sharma');
  });
  test('falls back to email when names are null', () {
    final user = CurrentUser.fromJson({'id': 'u1', 'email': 'kunal@essentia.dev'});
    expect(user.displayName, 'kunal@essentia.dev');
  });
}
