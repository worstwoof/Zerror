import 'package:flutter_test/flutter_test.dart';
import 'package:zerror/core/constants.dart';

void main() {
  test('default API endpoints are built without duplicate slashes', () {
    expect(AppConstants.apiBaseUrl, 'http://101.35.214.120');
    expect(
      AppConstants.analysisEndpoint,
      'http://101.35.214.120/api/v1/analysis/text',
    );
  });

  test('invite links use the configured share base URL and encode codes', () {
    expect(
      AppConstants.inviteLink('abc 123'),
      'https://zerror.app/invite/abc%20123',
    );
  });

  test('snapshot storage keys are scoped and URL-safe', () {
    expect(AppConstants.snapshotStorageKey(null), 'app_snapshot_v2_guest');
    expect(
      AppConstants.snapshotStorageKey('user@example.com'),
      'app_snapshot_v2_user%40example.com',
    );
  });
}
